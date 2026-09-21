# Grouped-argument helpers ----
#
# The creators grew flat argument lists that mixed unrelated settings, and
# these are the pieces that move a retired argument into the list which
# replaced it. They are shared so the creators agree about what a deprecation
# looks like rather than each inventing its own wording.

#' Fold a retired flat argument into the list that replaced it
#'
#' Passing both the old argument and the new list entry is an error rather
#' than a precedence rule: the two disagree about the same setting, and
#' silently preferring one is how a build ends up not doing what its script
#' says.
#'
#' @param target The list being built up.
#' @param entry Name the value takes inside `target`.
#' @param value The value passed for the retired argument.
#' @param old_name The retired argument's name, for the message.
#' @param new_arg The list argument that replaced it.
#' @param fn The creator being called, for the deprecation notice.
#' @param when Version the argument was retired in. Each creator was grouped
#'   in a different release, and a notice naming the wrong one sends people
#'   to the wrong NEWS entry.
#' @noRd
absorb_retired_arg <- function(
  target,
  entry,
  value,
  old_name,
  new_arg,
  fn,
  when
) {
  if (entry %in% names(target)) {
    cli::cli_abort(c(
      "Cannot use both {.arg {old_name}} and {.code {new_arg}${entry}}.",
      "i" = "{.arg {old_name}} is deprecated; keep {.code {new_arg}} alone."
    ))
  }
  lifecycle::deprecate_warn(
    when,
    paste0(fn, "(", old_name, " = )"),
    paste0(fn, "(", new_arg, " = )")
  )
  target[[entry]] <- value
  target
}


#' Move every retired flat argument in `dots` into the list that holds it now
#'
#' @param opts Named list of the lists being built, by argument name.
#' @param mapping Named character vector: retired argument name to
#'   `"<list argument>.<entry>"`. Only the first dot separates the two, so an
#'   entry name may itself contain one.
#' @param dots The `...` the creator was called with.
#' @param fn The creator being called.
#' @param when Version the arguments were retired in.
#' @return `opts`, updated, plus the dots that were not retired arguments.
#' @noRd
group_retired_dots <- function(opts, mapping, dots, fn, when) {
  named <- names(dots)
  if (is.null(named)) {
    named <- rep("", length(dots))
  }
  for (nm in intersect(named, names(mapping))) {
    target <- sub("\\..*$", "", mapping[[nm]])
    entry <- sub("^[^.]*\\.", "", mapping[[nm]])
    opts[[target]] <- absorb_retired_arg(
      opts[[target]],
      entry,
      dots[[nm]],
      nm,
      target,
      fn,
      when
    )
  }
  list(opts = opts, dots = dots[!named %in% names(mapping)])
}


#' Validate a grouped-argument list and fill it out with its defaults
#' @noRd
resolve_opts <- function(opts, arg_name, defaults) {
  opts <- validate_pipeline_opts(opts, arg_name, names(defaults))
  utils::modifyList(defaults, opts)
}
