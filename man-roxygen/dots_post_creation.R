#' @param ... Catches the retired `dilate`, `smoothness` and `tolerance`
#'   arguments, so a call that still passes one keeps working and says so.
#'   These are post-creation steps now: see [atlas_dilate()],
#'   [atlas_smooth()] and [atlas_simplify()]. Anything else in `...` is an
#'   error, as an unused argument always was.
