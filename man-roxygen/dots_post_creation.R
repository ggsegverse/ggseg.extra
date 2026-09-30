#' @param ... Catches the retired `dilate`, `smoothness`, `tolerance` and
#'   `smooth_refinements` arguments, so a call that still passes one keeps
#'   working and says so. These are post-creation steps now: see
#'   [atlas_polish()], or [atlas_simplify()], [atlas_smooth()] and
#'   [atlas_dilate()] individually. Anything else in `...` is an error, as an
#'   unused argument always was.
