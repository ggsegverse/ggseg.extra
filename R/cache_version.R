# Cache format versioning ----

#' Format version of cached pipeline intermediates
#'
#' Bump this by hand whenever a pipeline change makes previously cached
#' intermediates wrong rather than merely old, so a rebuilt atlas cannot
#' silently reuse output from the pipeline the change fixed.
#'
#' Stamped, and so checked before reuse: the `.rds` step caches, the contour
#' `.rda` files, and the processed-image and mask directories. Not stamped,
#' and so still reused whenever the file exists: the snapshot PNGs, the
#' subcortical mesh directory (`dirs$meshes`), and the lookup table and
#' volume the wholebrain pipeline hands to the subcortical one. This is the
#' canonical list; `NEWS.md` and `.github/copilot-instructions.md` point
#' here rather than restating it.
#'
#' @return Integer format version.
#' @noRd
cache_format_version <- function() {
  1L
}

cache_manifest_name <- "cache_manifest.rds"

cache_dir_entry <- "."

contour_rerun_remedy <- paste(
  "Rerun the contour extraction, smoothing and reduction steps;",
  "cached snapshots and masks are reused."
)

image_rerun_remedy <- paste(
  "Rerun the image-processing step to rebuild the masks;",
  "the snapshots they are made from are reused."
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
  dirs <- dirname(files)
  for (dir in unique(dirs)) {
    manifest <- read_cache_manifest(dir)
    manifest[basename(files[dirs == dir])] <- cache_format_version()
    write_cache_manifest(dir, manifest)
  }
  invisible(files)
}

#' Stamp a directory whose contents are produced and reused as one unit
#' @noRd
stamp_cache_dir <- function(dir) {
  manifest <- read_cache_manifest(dir)
  manifest[cache_dir_entry] <- cache_format_version()
  write_cache_manifest(dir, manifest)
  invisible(dir)
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
check_cache_dir <- function(dir, remedy) {
  version <- cache_file_version(as.character(fs::path(dir, cache_dir_entry)))
  if (!is_stale_version(version)) {
    return(invisible(dir))
  }
  abort_stale_cache(dir, version, remedy)
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
