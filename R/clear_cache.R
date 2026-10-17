#' Clear an atlas's build cache
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Removes the intermediates a build left under `output_dir`, so the next run
#' recomputes from the source files rather than reusing anything.
#'
#' A build reuses what it finds, which is what makes `skip_existing` worth
#' having on a pipeline that takes minutes. The cache knows the format that
#' wrote it, the version of this package, and what each step was given, and
#' recomputes when any of those move. It cannot know that a source file was
#' regenerated in place with the same size and timestamp, or that you want to
#' see a build from nothing. Clear it when you want to be sure.
#'
#' @param atlas_name Name of the atlas whose cache to clear. `NULL` clears
#'   every atlas under `output_dir`, which is only sensible when `output_dir`
#'   is a directory kept for builds.
#' @param output_dir Where the build wrote its intermediates. Defaults to the
#'   `ggseg.extra.output_dir` option, as a build does.
#' @param force Remove the directory even when it holds files this package did
#'   not write. `FALSE`, the default, refuses rather than delete your data.
#' @return Invisibly, the paths removed.
#' @export
#' @examples
#' \dontrun{
#' # after changing a lookup table the pipeline cannot see into
#' clear_atlas_cache("shen268_subcortical", output_dir = "data-raw")
#'
#' # start a build from nothing
#' clear_atlas_cache("glasser", output_dir = "data-raw")
#' create_cortical_from_annotation(annot, atlas_name = "glasser")
#' }
clear_atlas_cache <- function(
  atlas_name = NULL,
  output_dir = get_output_dir(),
  force = FALSE
) {
  if (!dir.exists(output_dir)) {
    cli::cli_warn("Nothing to clear: {.path {output_dir}} does not exist.")
    return(invisible(character()))
  }

  targets <- if (is.null(atlas_name)) {
    list.dirs(output_dir, recursive = FALSE)
  } else {
    vapply(
      atlas_name,
      function(nm) as.character(fs::path(output_dir, nm)),
      character(1),
      USE.NAMES = FALSE
    )
  }
  targets <- targets[dir.exists(targets)]

  if (length(targets) == 0L) {
    cli::cli_alert_info("Nothing to clear in {.path {output_dir}}.")
    return(invisible(character()))
  }

  foreign <- targets[vapply(targets, holds_foreign_files, logical(1))]
  if (length(foreign) > 0L && !force) {
    cli::cli_abort(c(
      "{.path {foreign}} holds files this package did not write.",
      "i" = "Remove them yourself, or pass {.code force = TRUE} to clear the
      directory anyway."
    ))
  }

  unlink(targets, recursive = TRUE)
  cli::cli_alert_success(
    "Cleared {length(targets)} atlas cache{?s} from {.path {output_dir}}."
  )
  invisible(targets)
}
