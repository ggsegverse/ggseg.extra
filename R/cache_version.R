# Cache format versioning ----

#' Format version of cached pipeline intermediates
#'
#' Bump this by hand whenever a pipeline change makes previously cached
#' intermediates wrong rather than merely old, so a rebuilt atlas cannot
#' silently reuse output from the pipeline the change fixed.
#'
#' What this covers: the serialized step caches written by
#' `save_cache_rds()` and the contour `.rda` files. What it does not cover:
#' the snapshot PNGs, processed images and masks, and the intermediate LUT
#' and volume the wholebrain pipeline hands to the subcortical one. Those are
#' still reused on file existence alone, so a fix to snapshot rendering or
#' masking still needs its cache purged by hand. The image directories are
#' scanned with `list.files()`, which would read a manifest sidecar as a
#' region or image.
#'
#' @return Integer format version.
#' @noRd
cache_format_version <- function() {
  1L
}

cache_manifest_name <- "cache_manifest.rds"

contour_rerun_remedy <- paste(
  "Rerun the contour extraction, smoothing and reduction steps;",
  "cached snapshots and masks are reused."
)

cerebellar_rerun_remedy <-
  "Include step 1 in the steps argument to reread the parcellation."

#' @noRd
cache_manifest_file <- function(dir) {
  as.character(fs::path(dir, cache_manifest_name))
}

#' @noRd
empty_cache_manifest <- function() {
  data.frame(
    file = character(),
    version = integer(),
    mtime = numeric(),
    stringsAsFactors = FALSE
  )
}

#' Read the cache manifest of a step directory
#'
#' A manifest that is missing, unreadable or malformed reads as empty, which
#' marks every file in the directory stale. That is the safe direction: the
#' pipeline reruns work rather than trusting output it cannot vouch for.
#'
#' @param dir Directory holding cached intermediates.
#' @return Data frame with `file`, `version` and `mtime` columns.
#' @noRd
read_cache_manifest <- function(dir) {
  manifest_file <- cache_manifest_file(dir)
  if (!file.exists(manifest_file)) {
    return(empty_cache_manifest())
  }
  manifest <- tryCatch(readRDS(manifest_file), error = function(e) NULL)
  if (
    !is.data.frame(manifest) ||
      !all(c("file", "version", "mtime") %in% names(manifest))
  ) {
    return(empty_cache_manifest())
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
#' Each entry records the file's modification time as well as the format
#' version, so a stamped name cannot vouch for content written after it.
#'
#' @param files Character vector of cache file paths just written.
#' @return The files, invisibly.
#' @noRd
stamp_cache_files <- function(files) {
  dirs <- dirname(files)
  for (dir in unique(dirs)) {
    stamped <- files[dirs == dir]
    manifest <- read_cache_manifest(dir)
    manifest <- manifest[!manifest$file %in% basename(stamped), , drop = FALSE]
    manifest <- rbind(
      manifest,
      data.frame(
        file = basename(stamped),
        version = cache_format_version(),
        mtime = as.numeric(file.mtime(stamped)),
        stringsAsFactors = FALSE
      )
    )
    write_cache_manifest(dir, manifest)
  }
  invisible(files)
}

#' Save a pipeline intermediate and stamp its format version
#' @noRd
save_cache_rds <- function(object, file) {
  saveRDS(object, file)
  stamp_cache_files(file)
  invisible(file)
}

#' Format version a cache file was stamped with
#'
#' @return The recorded version, or `NA_integer_` when the file has no entry
#'   or has changed since it was stamped.
#' @noRd
cache_file_version <- function(file, manifest = NULL) {
  if (is.null(manifest)) {
    manifest <- read_cache_manifest(dirname(file))
  }
  entry <- manifest[manifest$file == basename(file), , drop = FALSE]
  if (nrow(entry) != 1L) {
    return(NA_integer_)
  }
  if (!identical(entry$mtime, as.numeric(file.mtime(file)))) {
    return(NA_integer_)
  }
  as.integer(entry$version)
}

#' Cache files not written by the current cache format version
#'
#' @param files Character vector of cache file paths.
#' @return The subset of `files` missing a stamp, carrying a different
#'   format version, or changed since they were stamped.
#' @noRd
stale_cache_files <- function(files) {
  dirs <- dirname(files)
  is_stale <- logical(length(files))
  for (dir in unique(dirs)) {
    in_dir <- dirs == dir
    manifest <- read_cache_manifest(dir)
    is_stale[in_dir] <- vapply(
      files[in_dir],
      function(file) {
        !identical(cache_file_version(file, manifest), cache_format_version())
      },
      logical(1),
      USE.NAMES = FALSE
    )
  }
  files[is_stale]
}

#' Name the ggseg.extra that wrote a set of stale caches
#'
#' Stamps from a newer ggseg.extra are rejected just as older ones are, so
#' the message says which it was rather than assuming a downgrade is an
#' upgrade.
#' @noRd
stale_cache_origin <- function(files) {
  versions <- vapply(files, cache_file_version, integer(1), USE.NAMES = FALSE)
  known <- versions[!is.na(versions)]
  if (
    length(known) == length(versions) && all(known > cache_format_version())
  ) {
    return("a newer ggseg.extra")
  }
  if (all(is.na(versions)) || all(known < cache_format_version())) {
    return("an older ggseg.extra")
  }
  "a different version of ggseg.extra"
}

#' Stop when cached files were written by another ggseg.extra
#'
#' @param files Cache files about to be reused.
#' @param remedy Instruction telling the user which step to rerun.
#' @return The files, invisibly, when all are current.
#' @noRd
check_cache_current <- function(files, remedy) {
  stale <- stale_cache_files(files)
  if (length(stale) == 0L) {
    return(invisible(files))
  }
  origin <- stale_cache_origin(stale) # nolint: object_usage_linter.
  cli::cli_abort(c(
    "Cached {.path {stale}} {?was/were} written by {origin}.",
    "i" = "{cli::qty(length(stale))}Reusing {?it/them} would rebuild the
      atlas that pipeline made.",
    "i" = remedy
  ))
}

#' @noRd
abort_stale_step_cache <- function(files, step_num, step_name) {
  origin <- stale_cache_origin(files) # nolint: object_usage_linter.
  # fmt: skip
  cli::cli_abort(c(
    "{step_name} has cached output from {origin}.",
    "i" = "Stale: {.path {files}}",
    "i" = "{cli::qty(length(files))}Include step {step_num} in the steps
      argument to rebuild {?it/them}; steps whose cache is current are
      still reused."
  ))
}
