#' @param cleanup Remove the intermediate files afterwards. Default `TRUE`,
#'   from `options("ggseg.extra.cleanup")` or `GGSEG_EXTRA_CLEANUP`.
#'
#'   The intermediate files live in a folder named after the atlas inside
#'   `output_dir`, and the whole folder is removed. A build therefore refuses
#'   to start if that folder already holds files it did not write, since
#'   removing it would take them too. Choose another `output_dir` or
#'   `atlas_name`, or pass `FALSE` to build there and keep everything.
