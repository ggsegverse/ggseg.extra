#' @param smoothness Smoothing factor for 2D contours from screenshot-based
#'   pipelines. Higher values produce smoother region boundaries (typical
#'   range: 3--15). If not specified, uses
#'   `options("ggseg.extra.smoothness")` or the `GGSEG_EXTRA_SMOOTHNESS`
#'   environment variable. Default is 5. Note: for mesh-based pipelines,
#'   smoothing is handled by topology-preserving simplification via
#'   `tolerance`.
