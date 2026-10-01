#' Refuse any argument passed through a creator's dots
#'
#' The creators take `...` so that a mistyped or misplaced argument is caught
#' here, with the creator's name in the message, rather than silently
#' ignored. Post-creation tweaks such as smoothing and dilation belong to
#' `atlas_smooth()`, `atlas_dilate()` and `atlas_simplify()`, which act on a
#' finished atlas; nothing is accepted here.
#'
#' @param fn Name of the calling creator, for the message.
#' @param ... The caller's dots.
#' @return Invisibly `NULL`.
#' @noRd
check_unused_dots <- function(fn, ...) {
  dots <- list(...)
  if (!length(dots)) {
    return(invisible(NULL))
  }

  named <- names(dots)
  if (is.null(named)) {
    named <- rep("", length(dots))
  }
  unknown <- unique(named[nzchar(named)])
  unnamed <- sum(!nzchar(named))

  cli::cli_abort(c(
    "{length(unknown) + unnamed} unused argument{?s} passed to {.fn {fn}}.",
    "x" = if (length(unknown)) "Unknown: {.arg {unknown}}.",
    "x" = if (unnamed) "{unnamed} unnamed argument{?s}."
  ))
}
