#' Upgrade the atlases an atlas package ships
#'
#' Rewrites every atlas in a package's `R/sysdata.rda` through
#' [ggseg.formats::as_ggseg_atlas()], which brings it to the current object
#' representation and schema. Nothing is recomputed: no source volume is read,
#' no surface is projected, no geometry is touched. The atlas comes out with
#' the same core table, the same palette and the same geometry it went in
#' with, in the shape the installed `ggseg.formats` expects.
#'
#' This is deliberately **not** a rebuild. Re-running a package's `data-raw`
#' scripts reruns the pipeline, which picks up every pipeline fix since the
#' atlas was last built and is not output-identical -- the MCALT cerebellar
#' atlas changed eight labels the last time it was rebuilt, and `label` is the
#' key every user's data joins on. Upgrading changes the container; rebuilding
#' changes the contents. Do them as separate pieces of work, so that when
#' something moves you know which one moved it.
#'
#' It also works for packages that cannot be rebuilt at all: those whose
#' source volumes were never committed, or whose build script points at a
#' machine that is not yours.
#'
#' @param path Path to the atlas package. Defaults to the working directory.
#' @param dry_run If `TRUE` (the default), report what would change and write
#'   nothing.
#' @param repair If `TRUE`, run the migration verbs on an atlas the current
#'   constructor refuses, and upgrade the result. Off by default: a repair
#'   changes stored data, where an upgrade does not. Some published atlases
#'   need it -- `ggsegAal`'s `.aal3_cerebellum` carries the pre-vocabulary
#'   `hemi` value `"middle"` and no verb that validates will touch it.
#'
#' @return Invisibly, a data frame with one row per atlas object: its name,
#'   the schema it carried, the schema it now carries, and whether its
#'   contents verified identical.
#' @export
#'
#' @examples
#' \dontrun{
#' # See what would change
#' upgrade_atlas_package("~/workspace/ggseg/atlases/ggsegSchaefer")
#'
#' # Do it
#' upgrade_atlas_package(
#'   "~/workspace/ggseg/atlases/ggsegSchaefer",
#'   dry_run = FALSE
#' )
#' }
upgrade_atlas_package <- function(path = ".", dry_run = TRUE, repair = FALSE) {
  sysdata <- file.path(path, "R", "sysdata.rda")
  if (!file.exists(sysdata)) {
    cli::cli_abort(c(
      "No {.file R/sysdata.rda} in {.path {path}}.",
      "i" = "An atlas package ships its atlases there."
    ))
  }

  env <- new.env(parent = emptyenv())
  load(sysdata, envir = env)
  names <- ls(env, all.names = TRUE)

  results <- lapply(names, upgrade_one_atlas, env = env, repair = repair)
  results <- do.call(rbind, Filter(Negate(is.null), results))

  if (is.null(results)) {
    cli::cli_alert_info("No atlases in {.file {sysdata}}.")
    return(invisible(results))
  }

  report_atlas_upgrade(results, sysdata, dry_run)

  if (!dry_run && any(results$changed & results$status != "failed")) {
    save(list = names, file = sysdata, envir = env, compress = "xz")
  }

  invisible(results)
}


#' Upgrade one object, if it is an atlas, verifying it survived
#'
#' The verification is the point of doing this per object rather than in a
#' loop over the file: an upgrade that quietly altered a core table would be
#' indistinguishable from a rebuild, which is the one thing this must not be.
#' @noRd
upgrade_one_atlas <- function(name, env, repair = FALSE) {
  old <- get(name, envir = env)
  if (!ggseg.formats::is_atlas_class(old)) {
    return(NULL)
  }

  before <- ggseg.formats::atlas_schema(old)
  status <- "upgraded"

  new <- try_upgrade(old)
  if (inherits(new, "try-error")) {
    if (!repair) {
      return(failed_upgrade_row(
        name,
        before,
        conditionMessage(attr(
          new,
          "condition"
        ))
      ))
    }
    # The migration verbs take an atlas the constructor refuses and return one
    # it accepts. They change stored data, which is why this is opt-in.
    repaired <- try(
      ggseg.formats::migrate_atlas_hemi(old),
      silent = TRUE
    )
    if (inherits(repaired, "try-error")) {
      return(failed_upgrade_row(
        name,
        before,
        conditionMessage(attr(
          repaired,
          "condition"
        ))
      ))
    }
    new <- try_upgrade(repaired)
    if (inherits(new, "try-error")) {
      return(failed_upgrade_row(
        name,
        before,
        conditionMessage(attr(
          new,
          "condition"
        ))
      ))
    }
    status <- "repaired"
  }

  identical_contents <- identical(
    as.data.frame(ggseg.formats::atlas_core(old)),
    as.data.frame(ggseg.formats::atlas_core(new))
  ) &&
    identical(
      ggseg.formats::atlas_palette(old),
      ggseg.formats::atlas_palette(new)
    ) &&
    identical(ggseg.formats::atlas_type(old), ggseg.formats::atlas_type(new))

  # ggseg.formats repairs a legacy `hemi` spelling at the boundary, so an
  # upgrade can change stored data without the constructor ever refusing it.
  # What separates an upgrade from a repair is whether contents changed, not
  # which path produced the atlas -- and a repair stays opt-in, so without
  # `repair` nothing that rewrites stored data is written.
  if (!identical_contents) {
    if (!repair) {
      return(failed_upgrade_row(
        name,
        before,
        paste0(
          "Upgrading would change stored data (",
          upgrade_changed_parts(old, new),
          "). Re-run with `repair = TRUE`."
        )
      ))
    }
    status <- "repaired"
  }

  assign(name, new, envir = env)

  data.frame(
    object = name,
    status = status,
    schema_before = before,
    schema_after = ggseg.formats::atlas_schema(new),
    identical_contents = identical_contents,
    # A legacy list atlas carries no stamp and reads as schema 0, so the
    # version comparison catches both kinds of staleness -- the old
    # representation and the old schema -- without asking about S7 at all.
    changed = before != ggseg.formats::atlas_schema(new),
    note = NA_character_,
    stringsAsFactors = FALSE
  )
}


#' @noRd
try_upgrade <- function(atlas) {
  try(
    withCallingHandlers(
      ggseg.formats::as_ggseg_atlas(atlas),
      condition = function(cnd) {
        if (inherits(cnd, c("lifecycle_warning_deprecated", "message"))) {
          rlang::cnd_muffle(cnd)
        }
      }
    ),
    silent = TRUE
  )
}


#' @noRd
failed_upgrade_row <- function(name, before, note) {
  data.frame(
    object = name,
    status = "failed",
    schema_before = before,
    schema_after = NA_integer_,
    identical_contents = NA,
    changed = FALSE,
    note = gsub("[\n]+", " ", note),
    stringsAsFactors = FALSE
  )
}


#' @noRd
report_atlas_upgrade <- function(results, sysdata, dry_run) {
  n <- nrow(results) # nolint: object_usage_linter.
  n_changed <- sum(results$changed)
  failed <- results[results$status == "failed", , drop = FALSE]
  repaired <- results[results$status == "repaired", , drop = FALSE]

  cli::cli_alert_info(
    "{n} atlas{?es} in {.file {sysdata}}; {n_changed} need{?s/} upgrading."
  )

  if (nrow(repaired) > 0) {
    cli::cli_alert_warning(
      "Repaired {nrow(repaired)} atlas{?es} the constructor refused:
       {.val {repaired$object}}."
    )
    cli::cli_bullets(c(
      "!" = "Stored data changed. A repair rewrites the atlas; an upgrade does
             not.",
      "i" = "Anything joining to these atlases on a repaired column is
             affected."
    ))
  }

  if (nrow(failed) > 0) {
    cli::cli_alert_danger(
      "{nrow(failed)} atlas{?es} could not be upgraded: {.val {failed$object}}."
    )
    for (i in seq_len(nrow(failed))) {
      cli::cli_bullets(c("x" = "{failed$object[i]}: {failed$note[i]}"))
    }
    cli::cli_alert_info(
      "Try {.code repair = TRUE}, which runs the migration verbs first."
    )
  }

  if (n_changed == 0) {
    return(invisible())
  }

  if (dry_run) {
    cli::cli_alert_warning(
      "Dry run; nothing written. Pass {.code dry_run = FALSE} to write."
    )
  } else {
    cli::cli_alert_success("Rewrote {.file {sysdata}}.")
  }
}

#' Name the parts of an atlas an upgrade would rewrite
#'
#' The note has to say what would change, not only that something would:
#' `core$hemi` is the usual answer, and it is what tells the reader this is
#' the legacy vocabulary rather than lost geometry.
#' @noRd
upgrade_changed_parts <- function(old, new) {
  old_core <- as.data.frame(ggseg.formats::atlas_core(old))
  new_core <- as.data.frame(ggseg.formats::atlas_core(new))

  shared <- intersect(names(old_core), names(new_core))
  changed <- shared[
    !vapply(
      shared,
      function(col) identical(old_core[[col]], new_core[[col]]),
      logical(1)
    )
  ]
  parts <- sprintf("core$%s", changed)

  if (!setequal(names(old_core), names(new_core))) {
    parts <- c(parts, "core columns")
  }
  if (
    !identical(
      ggseg.formats::atlas_palette(old),
      ggseg.formats::atlas_palette(new)
    )
  ) {
    parts <- c(parts, "palette")
  }
  if (
    !identical(ggseg.formats::atlas_type(old), ggseg.formats::atlas_type(new))
  ) {
    parts <- c(parts, "type")
  }

  if (length(parts) == 0) {
    return("row count")
  }
  toString(parts)
}
