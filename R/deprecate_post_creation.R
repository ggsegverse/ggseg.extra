#' Catch post-creation tweaks passed to a pipeline
#'
#' Smoothing, dilation and vertex reduction are steps you apply to a finished
#' atlas, not settings you bake into the build - retuning one should not cost
#' a rebuild, which for these pipelines is minutes of snapshots and contours.
#' `atlas_smooth()`, `atlas_dilate()` and `atlas_simplify()` are where they
#' live.
#'
#' Catching them in `...` means they no longer appear in the signature or the
#' help page, while a call that still passes one keeps working and says so.
#' Anything else in `...` is a typo, and errors the way an unused argument
#' always did.
#'
#' `tolerance`, `smoothness` and `smooth_refinements` were already deprecated
#' by [warn_deprecated_sf_smoothing()], which this defers to; they were kept
#' as formals only so the warning had something to fire on. `dilate` is newly
#' deprecated here and still honoured for now.
#'
#' @param fn Name of the calling creator, for the deprecation message.
#' @param ... The caller's dots.
#'
#' @return Invisibly, the named list of deprecated arguments that were given,
#'   so a caller can go on honouring one during its deprecation window.
#' @noRd
check_post_creation_dots <- function(fn, ...) {
  dots <- list(...)
  if (!length(dots)) {
    return(invisible(list()))
  }

  known <- c("dilate", "smoothness", "tolerance", "smooth_refinements")

  named <- names(dots)
  if (is.null(named)) {
    named <- rep("", length(dots))
  }

  unknown <- setdiff(named, known)
  if (length(unknown)) {
    unnamed <- sum(!nzchar(unknown))
    unknown <- unknown[nzchar(unknown)]
    cli::cli_abort(c(
      "unused argument{?s} passed to {.fn {fn}}.",
      "x" = if (length(unknown)) "Unknown: {.arg {unknown}}.",
      "x" = if (unnamed) "{unnamed} unnamed argument{?s}."
    ))
  }

  # tolerance, smoothness and smooth_refinements already have a deprecation
  # notice; reuse it rather than writing a second one that says the same
  # thing in different words.
  warn_deprecated_sf_smoothing(
    tolerance = dots$tolerance,
    smoothness = dots$smoothness,
    smooth_refinements = dots$smooth_refinements,
    fn = fn
  )

  if (!is.null(dots$dilate)) {
    lifecycle::deprecate_warn(
      when = "1.9.9.9016",
      what = paste0(fn, "(dilate)"),
      with = "ggseg.extra::atlas_dilate()",
      details = paste(
        "Apply it to the finished atlas instead, so retuning it does not",
        "mean rebuilding."
      )
    )
  }

  invisible(dots)
}
