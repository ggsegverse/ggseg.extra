#' Warn about post-creation tweaks passed to a pipeline
#'
#' Smoothing, dilation and vertex reduction are steps you apply to a finished
#' atlas, not settings you bake into the build - retuning them should not
#' cost a rebuild. `smoothness` and `tolerance` have already been inert for a
#' while: the pipeline steps that once consumed them now only filter invalid
#' geometries, so a build passing them was quietly getting nothing.
#'
#' @param fn Name of the calling creator, for the deprecation message.
#' @param dilate,smoothness,tolerance The values the caller was given.
#' @noRd
warn_post_creation_args <- function(
  fn,
  dilate = NULL,
  smoothness = NULL,
  tolerance = NULL
) {
  replacements <- c(
    dilate = "ggseg.extra::atlas_dilate()",
    smoothness = "ggseg.extra::atlas_smooth()",
    tolerance = "ggseg.extra::atlas_simplify()"
  )
  given <- list(
    dilate = dilate,
    smoothness = smoothness,
    tolerance = tolerance
  )

  for (nm in names(given)) {
    if (is.null(given[[nm]])) {
      next
    }
    lifecycle::deprecate_warn(
      when = "1.9.9.9016",
      what = paste0(fn, "(", nm, ")"),
      with = replacements[[nm]],
      details = paste(
        "Apply it to the finished atlas instead, so retuning it does not",
        "mean rebuilding."
      )
    )
  }

  invisible(NULL)
}
