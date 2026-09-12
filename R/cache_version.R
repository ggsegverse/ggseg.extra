# Cache format versioning ----

#' Format version of cached pipeline intermediates
#'
#' Bump this whenever a pipeline change makes previously cached intermediates
#' wrong rather than merely old, so a rebuilt atlas cannot silently reuse
#' output from the pipeline the change fixed.
#'
#' @return Integer format version.
#' @noRd
cache_format_version <- function() {
  1L
}

cache_manifest_name <- "cache_manifest.rds"

#' @noRd
cache_manifest_file <- function(dir) {
  as.character(fs::path(dir, cache_manifest_name))
}

#' Read the cache manifest of a step directory
#'
#' @param dir Directory holding cached intermediates.
#' @return Named integer vector mapping file name to format version. Empty
#'   when the directory has no readable manifest.
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

#' Record the current format version for freshly written cache files
#'
#' The stamp lives in a sidecar manifest rather than on the objects
#' themselves: attributes do not survive the dplyr verbs the pipelines apply
#' to loaded data, and the same manifest covers `.rds` and `.rda` caches.
#'
#' @param files Character vector of cache file paths just written.
#' @return The files, invisibly.
#' @noRd
stamp_cache_files <- function(files) {
  dirs <- dirname(files)
  for (dir in unique(dirs)) {
    manifest <- read_cache_manifest(dir)
    manifest[basename(files[dirs == dir])] <- cache_format_version()
    saveRDS(manifest, cache_manifest_file(dir))
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

#' @noRd
cache_file_version <- function(file) {
  version <- read_cache_manifest(dirname(file))[basename(file)]
  if (is.na(version)) NA_integer_ else unname(version)
}

#' Cache files not written by the current cache format version
#'
#' @param files Character vector of cache file paths.
#' @return The subset of `files` that are missing a stamp or carry an older
#'   or newer one.
#' @noRd
stale_cache_files <- function(files) {
  is_stale <- vapply(
    files,
    function(file) !identical(cache_file_version(file), cache_format_version()),
    logical(1),
    USE.NAMES = FALSE
  )
  files[is_stale]
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
  cli::cli_abort(c(
    "Cached {.path {stale}} {?was/were} written by an older ggseg.extra.",
    "i" = "{cli::qty(length(stale))}Reusing {?it/them} would rebuild the
      atlas the old pipeline made.",
    "i" = remedy
  ))
}

#' @noRd
abort_stale_step_cache <- function(files, step_num, step_name) {
  # fmt: skip
  cli::cli_abort(c(
    "{step_name} has cached output from an older ggseg.extra.",
    "i" = "Stale: {.path {files}}",
    "i" = "{cli::qty(length(files))}Include step {step_num} in the steps
      argument to rebuild {?it/them}; steps whose cache is current are
      still reused."
  ))
}
