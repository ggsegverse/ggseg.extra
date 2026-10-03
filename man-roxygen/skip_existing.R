#' @param skip_existing Reuse a step's intermediate files when they already
#'   exist, instead of running the step. Default `FALSE`, from
#'   `options("ggseg.extra.skip_existing")` or `GGSEG_EXTRA_SKIP_EXISTING`.
#'
#'   A cache records which ggseg.extra wrote it, not what it was built from, so
#'   reuse cannot tell that the volume or lookup table has changed. Reuse is
#'   therefore asked for rather than assumed, and is reported when it happens.
#'   To continue an interrupted build, either pass `TRUE` or leave the finished
#'   steps out of `steps`.
