# Cache format versioning ----

#' Format version of cached pipeline intermediates
#'
#' Bump this by hand whenever a pipeline change makes previously cached
#' intermediates wrong rather than merely old, so a rebuilt atlas cannot
#' silently reuse output from the pipeline the change fixed.
#'
#' Stamped, and so checked before reuse: the `.rds` step caches, and the
#' projection and contour `.rda` files. Not stamped, and so still reused
#' whenever the file exists: the subcortical mesh directory (`dirs$meshes`),
#' and the lookup table and volume the wholebrain pipeline hands to the
#' subcortical one.
#'
#' The subcortical snapshots are neither: they carry a signature of what
#' they were drawn from instead (see [snapshot_signature()]), which catches a
#' stale one whether the pipeline changed or only its inputs did. This format
#' version is part of that signature, so a bump invalidates them too. This is
#' the canonical list; `NEWS.md` and `.github/copilot-instructions.md` point
#' here rather than restating it.
#'
#' @return Integer format version.
#' @noRd
cache_format_version <- function() {
  2L
}

cache_manifest_name <- "cache_manifest.rds"

cache_dir_entry <- "."

contour_rerun_remedy <- paste(
  "Rerun the contour extraction, smoothing and reduction steps;",
  "cached projections are reused."
)

#' @noRd
step_rerun_remedy <- function(step_num) {
  cli::format_inline(
    "Include step {step_num} in the steps argument to rebuild it; ",
    "steps whose cache is current are still reused."
  )
}

#' @noRd
cache_manifest_file <- function(dir) {
  as.character(fs::path(dir, cache_manifest_name))
}

#' Read a directory's manifest of cache name to format version
#'
#' A missing, unreadable or malformed manifest reads as empty, which marks
#' that directory's caches stale: the pipeline redoes the work rather than
#' trusting output it cannot vouch for.
#' @noRd
read_cache_manifest <- function(dir) {
  manifest_file <- cache_manifest_file(dir)
  if (!file.exists(manifest_file)) {
    return(integer())
  }
  manifest <- tryCatch(readRDS(manifest_file), error = function(e) NULL)
  if (!is.integer(manifest) || is.null(names(manifest))) {
    return(integer())
  }
  manifest
}

#' Write a cache manifest without leaving a truncated file behind
#'
#' These builds run for hours and are routinely interrupted. Truncating the
#' manifest in place means a Ctrl-C mid-write loses every stamp in the
#' directory and turns the next partial rerun into an abort, so the new
#' manifest is staged beside it and renamed into place instead.
#' @noRd
write_cache_manifest <- function(dir, manifest) {
  manifest_file <- cache_manifest_file(dir)
  staged <- tempfile(pattern = "cache_manifest", tmpdir = dir, fileext = ".rds")
  saveRDS(manifest, staged)
  if (!file.rename(staged, manifest_file)) {
    unlink(staged)
    cli::cli_warn("Could not update the cache manifest in {.path {dir}}")
  }
  invisible(manifest_file)
}

#' Record the current format version for freshly written cache files
#'
#' The stamp lives in a sidecar manifest rather than on the objects
#' themselves: attributes do not survive the dplyr verbs the pipelines apply
#' to loaded data, and the same manifest covers `.rds` and `.rda` caches.
#'
#' Call this from the main thread only. It is a read-modify-write on state
#' shared by every cache in the directory, and the atomic rename protects
#' against a torn manifest, not against two workers each dropping the
#' other's rows.
#' @noRd
stamp_cache_files <- function(files) {
  files <- as.character(unlist(files))
  if (length(files) == 0L) {
    return(invisible(files))
  }
  dirs <- dirname(files)
  for (dir in unique(dirs)) {
    manifest <- read_cache_manifest(dir)
    manifest[basename(files[dirs == dir])] <- cache_format_version()
    write_cache_manifest(dir, manifest)
  }
  invisible(files)
}

#' Save pipeline intermediates into a step directory and stamp them
#'
#' @param dir Step directory to write into.
#' @param ... Objects to save, each named by the file to write it to. Pass
#'   every file a step writes in one call, so the manifest is written once.
#' @return The files written, invisibly.
#' @noRd
save_cache_rds <- function(dir, ...) {
  objects <- list(...)
  files <- as.character(fs::path(dir, names(objects)))
  for (i in seq_along(objects)) {
    saveRDS(objects[[i]], files[[i]])
  }
  stamp_cache_files(files)
  invisible(files)
}

#' Save contours as an `.rda` cache and stamp them
#'
#' The object is stored under the name `contours`, which is what
#' `load_cached_rda()` and the pipeline's loaders expect to find.
#' @noRd
save_cache_rda <- function(contours, dir, name) {
  file <- as.character(fs::path(dir, name))
  save(contours, file = file)
  stamp_cache_files(file)
  invisible(file)
}

#' Load an `.rda` cache, rejecting a stale one before deserializing it
#' @noRd
load_cached_rda <- function(file, remedy, envir = parent.frame()) {
  if (file.exists(file)) {
    check_cache_current(file, remedy)
  }
  load_rda(file, envir = envir)
}

#' @noRd
cache_file_version <- function(file, manifest = NULL) {
  if (is.null(manifest)) {
    manifest <- read_cache_manifest(dirname(file))
  }
  version <- manifest[basename(file)]
  if (is.na(version)) NA_integer_ else unname(version)
}

#' Format version each file was stamped with, reading each manifest once
#' @noRd
cache_file_versions <- function(files) {
  dirs <- dirname(files)
  versions <- rep(NA_integer_, length(files))
  for (dir in unique(dirs)) {
    in_dir <- dirs == dir
    manifest <- read_cache_manifest(dir)
    versions[in_dir] <- vapply(
      files[in_dir],
      cache_file_version,
      integer(1),
      manifest = manifest,
      USE.NAMES = FALSE
    )
  }
  versions
}

#' @noRd
is_stale_version <- function(versions) {
  is.na(versions) | versions != cache_format_version()
}

#' @noRd
stale_cache_files <- function(files) {
  files[is_stale_version(cache_file_versions(files))]
}

#' Stop when caches were written by a different cache format version
#'
#' @param files Cache files about to be reused.
#' @param remedy Instruction telling the user how to rebuild them.
#' @return The files, invisibly, when all are current.
#' @noRd
check_cache_current <- function(files, remedy) {
  versions <- cache_file_versions(files)
  stale <- is_stale_version(versions)
  if (!any(stale)) {
    return(invisible(files))
  }
  abort_stale_cache(files[stale], versions[stale], remedy)
}

#' @noRd
abort_stale_cache <- function(paths, versions, remedy) {
  # nolint next: object_usage_linter.
  found <- unique(ifelse(is.na(versions), "none", as.character(versions)))
  cli::cli_abort(c(
    "Cached {.path {paths}} {?was/were} written by cache format {found}.",
    "i" = "This ggseg.extra writes cache format {cache_format_version()}.",
    "i" = remedy
  ))
}


# Snapshot provenance ----

#' Signature of everything a snapshot was drawn from
#'
#' The format version alone cannot catch a stale snapshot, because a snapshot
#' can go stale without the pipeline changing at all. `<view>_<label>.rda`
#' says which label and which slab, but not *which voxels* that label held,
#' and both move underneath it: `reindex_reserved_subcort_idx()` can hand a
#' structure a different index, and a rebuilt volume can hand an index
#' different voxels. An atlas cache predating the reindexing reuses
#' `axial_1_Pallidum_l.rda` drawn when 42 meant Pallidum and now means the
#' right cortical hemisphere, and renders a nucleus as a solid hemisphere.
#'
#' So the signature hashes the voxels themselves, not the label id: the
#' structure's voxel indices, the slab that frames them, the volume's
#' dimensions, and the cache format version. Anything that can change the
#' picture changes the signature, and a snapshot whose signature does not
#' match what this run would draw is redrawn.
#'
#' @param ... The inputs the snapshot depends on.
#' @return A single hash string.
#' @noRd
snapshot_signature <- function(...) {
  rlang::hash(list(cache_format_version(), ...))
}

snapshot_manifest_name <- "snapshot_manifest.rds"

#' Read a snapshot directory's filename-to-signature map
#'
#' A missing, unreadable or malformed manifest reads as empty, which marks
#' every snapshot in that directory stale: they are redrawn rather than
#' trusted. That is also what an atlas cache from before signatures existed
#' looks like.
#' @noRd
read_snapshot_manifest <- function(dir) {
  file <- as.character(fs::path(dir, snapshot_manifest_name))
  if (!file.exists(file)) {
    return(character())
  }
  manifest <- tryCatch(readRDS(file), error = function(e) NULL)
  if (!is.character(manifest) || is.null(names(manifest))) {
    return(character())
  }
  manifest
}

#' Record the signatures of the snapshots this run drew or reused
#'
#' Merged into whatever the directory already holds, because structure and
#' cortex snapshots share it and are written in separate passes. Call from
#' the main thread only: it is a read-modify-write on state shared by every
#' snapshot in the directory.
#' @noRd
record_snapshot_signatures <- function(dir, signatures) {
  if (length(signatures) == 0L) {
    return(invisible(signatures))
  }
  manifest <- read_snapshot_manifest(dir)
  manifest[names(signatures)] <- unname(signatures)

  file <- as.character(fs::path(dir, snapshot_manifest_name))
  staged <- tempfile(
    pattern = "snapshot_manifest",
    tmpdir = dir,
    fileext = ".rds"
  )
  saveRDS(manifest, staged)
  if (!file.rename(staged, file)) {
    unlink(staged)
    cli::cli_warn("Could not update the snapshot manifest in {.path {dir}}")
  }
  invisible(signatures)
}

#' Can an existing snapshot be reused, or must it be redrawn?
#'
#' @param file Path to the snapshot.
#' @param signature What this run would draw there.
#' @param manifest The directory's recorded signatures.
#' @param skip_existing Whether reuse was asked for at all.
#' @noRd
snapshot_is_current <- function(file, signature, manifest, skip_existing) {
  skip_existing &&
    file.exists(file) &&
    identical(unname(manifest[basename(file)]), signature)
}
