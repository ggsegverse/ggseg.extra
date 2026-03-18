#' @param smoothness Smoothing factor for 2D contours. Higher values produce
#'   smoother region boundaries (typical range: 3--15). Passed to
#'   [smoothr::smooth()]. If not specified, uses
#'   `options("ggseg.extra.smoothness")` or the `GGSEG_EXTRA_SMOOTHNESS`
#'   environment variable. Default is 5.
