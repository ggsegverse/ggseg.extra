#' @param tolerance Proportion of vertices to retain during topology-preserving
#'   simplification (0--1). Lower values produce simpler, smoother shapes.
#'   Passed to [rmapshaper::ms_simplify()].
#'   If not specified, uses `options("ggseg.extra.tolerance")` or the
#'   `GGSEG_EXTRA_TOLERANCE` environment variable. Default is 0.05.
