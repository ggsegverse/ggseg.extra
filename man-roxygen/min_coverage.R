#' @param min_coverage Smallest share of `core` labels that must end up with
#'   2D geometry, between 0 and 1. A build that falls below it warns and names
#'   the labels that have no shape; the warning fires whatever `verbose` is
#'   set to, because a region that cannot be drawn is data loss rather than
#'   progress chatter. The build itself still returns, so a long pipeline is
#'   never thrown away over a threshold. Use `0` to turn the check off.
#'   Defaults to `0.8`, or to `options("ggseg.extra.min_coverage")`, then
#'   `GGSEG_EXTRA_MIN_COVERAGE`.
