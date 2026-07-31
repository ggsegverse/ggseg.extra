#' Add ggsegverse GitHub Actions workflows to a package
#'
#' Writes caller stubs for the shared workflows maintained in
#' [ggsegverse/.github](https://github.com/ggsegverse/.github) into
#' `.github/workflows/`. Each stub is a short `uses:` block, so a package
#' picks up changes to the shared workflow without needing to be updated
#' itself.
#'
#' Run this on a newly scaffolded atlas package, or on an existing one to
#' replace hand-maintained workflows with the shared set.
#' [setup_atlas_repo()] calls it for you unless `github_actions = FALSE`.
#'
#' The workflows written by default are:
#'
#' * `R-CMD-check` — multi-platform `R CMD check`
#' * `code-quality` — air, lintr, and goodpractice
#' * `pkgdown` — build and deploy the documentation site
#' * `render-readme` — re-render `README.qmd` on change
#' * `update-codemeta` — refresh `codemeta.json` when DESCRIPTION changes
#'
#' @param workflows Names of workflows to add. Defaults to all of the above.
#' @param path Path to the package. Defaults to the working directory.
#' @param overwrite Overwrite workflows that already exist. Default is FALSE,
#'   which leaves existing files untouched and reports them.
#'
#' @return Invisibly, the paths written.
#' @export
#'
#' @examples
#' \dontrun{
#' # Add the full set to the package in the working directory
#' use_atlas_github_actions()
#'
#' # Add just one, replacing any existing copy
#' use_atlas_github_actions("pkgdown", overwrite = TRUE)
#' }
use_atlas_github_actions <- function(
  workflows = atlas_github_actions(),
  path = ".",
  overwrite = FALSE
) {
  available <- atlas_github_actions()
  unknown <- setdiff(workflows, available)
  if (length(unknown) > 0) {
    cli::cli_abort(c(
      "Unknown workflow{?s}: {.val {unknown}}",
      "i" = "Available: {.val {available}}"
    ))
  }

  if (!file.exists(file.path(path, "DESCRIPTION"))) {
    cli::cli_abort(c(
      "No package found at {.path {path}}",
      "x" = "{.file DESCRIPTION} is missing",
      "i" = "Run this from a package directory, or set {.arg path}"
    ))
  }

  dest_dir <- file.path(path, ".github", "workflows")
  mkdir(dest_dir)

  written <- character()
  skipped <- character()

  for (workflow in workflows) {
    file <- paste0(workflow, ".yaml")
    dest <- file.path(dest_dir, file)

    if (file.exists(dest) && !overwrite) {
      skipped <- c(skipped, file)
      next
    }

    src <- system.file(
      "templates",
      "workflows",
      file,
      package = "ggseg.extra"
    )

    if (!file.copy(src, dest, overwrite = TRUE)) {
      cli::cli_warn("Could not write {.file {file}}")
      next
    }
    written <- c(written, dest)
  }

  report_github_actions(written, skipped)

  invisible(written)
}


#' Workflows [use_atlas_github_actions()] can write
#'
#' @return A character vector of workflow names.
#' @export
#'
#' @examples
#' atlas_github_actions()
atlas_github_actions <- function() {
  c(
    "R-CMD-check",
    "code-quality",
    "pkgdown",
    "render-readme",
    "update-codemeta"
  )
}


#' @keywords internal
#' @noRd
report_github_actions <- function(written, skipped) {
  if (length(written) > 0) {
    cli::cli_alert_success(
      "Added {length(written)} workflow{?s} to {.path .github/workflows/}"
    )
    cli::cli_ul(basename(written))
  }

  if (length(skipped) > 0) {
    cli::cli_alert_info(
      "Kept {length(skipped)} existing workflow{?s}: {.file {skipped}}"
    )
    cli::cli_alert_info(
      "{.code overwrite = TRUE} replaces {cli::qty(length(skipped))}{?it/them}"
    )
  }

  invisible(NULL)
}
