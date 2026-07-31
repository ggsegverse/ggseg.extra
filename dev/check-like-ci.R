# Reproduce the CI good-practice gate locally, before pushing.
#
#   Rscript dev/check-like-ci.R          # lintr checks only (~1 min)
#   Rscript dev/check-like-ci.R --full   # every check CI runs (slow)
#
# Why this exists: `lintr::lint_package()` uses the package .lintr, which is
# lintr's default linter set. The `code-quality / good-practice` job in
# ggsegverse/.github runs goodpractice, whose linter set is far broader. Code
# can be locally clean and still hard-fail CI -- that happened twice in one
# session (`<<-` via undesirable_operator_linter, and a non-fixed grepl() via
# fixed_regex_linter), each costing a ~50 minute CI cycle.
#
# This calls goodpractice itself rather than reimplementing its linting with
# lint_package(). That matters: a lint_package() reimplementation over-reports,
# flagging vignette library() calls and testthat assignment idioms that
# goodpractice does not flag. Only running the real thing matches CI.
#
# The default mode requests only the lintr checks, so goodpractice runs just
# its lintr prep and skips the slow rcmdcheck prep. Both lintr failures that
# have bitten this package would have been caught in that mode. Use --full
# before a release, when the rcmdcheck- and roxygen-based checks matter too.

if (!requireNamespace("goodpractice", quietly = TRUE)) {
  stop("install.packages('goodpractice')")
}

full <- "--full" %in% commandArgs(trailingOnly = TRUE)

# object_usage_linter resolves symbols against the *installed* namespace, so a
# stale install reports functions you just added as undefined. CI never hits
# this because setup-r-dependencies installs local::. first.
warn_if_stale_install <- function() {
  pkg <- read.dcf("DESCRIPTION", "Package")[[1]]
  declared <- grep(
    "^export\\(",
    readLines("NAMESPACE", warn = FALSE),
    value = TRUE
  )
  declared <- gsub("^export\\(|\\)$", "", declared)

  installed <- tryCatch(
    getNamespaceExports(pkg),
    error = function(e) NULL
  )
  if (is.null(installed)) {
    return(invisible(NULL))
  }

  missing <- setdiff(declared, installed)
  if (length(missing) > 0) {
    cat(
      "NOTE: the installed",
      pkg,
      "is missing",
      length(missing),
      "exported object(s):\n  ",
      paste(utils::head(missing, 5), collapse = ", "),
      "\n  object_usage_linter will report these as undefined.",
      "\n  Run `R CMD INSTALL .` first for an accurate result.\n\n"
    )
  }

  invisible(NULL)
}

warn_if_stale_install()

# Mirrors the `checks <- setdiff(...)` block in
# ggsegverse/.github/.github/workflows/code-quality.yaml. Keep in step with it.
excluded <- c(
  "lintr_strings_as_factors_linter",
  "tidyverse_r_file_names",
  "lintr_duplicate_argument_linter",
  "lintr_scalar_in_linter",
  "lintr_unnecessary_lambda_linter",
  "urlchecker_ok",
  "urlchecker_no_redirects",
  "covr",
  "complexity_function_length",
  "tidyverse_test_file_names"
)

checks <- setdiff(
  union(goodpractice::all_checks(), goodpractice::tidyverse_checks()),
  excluded
)

if (!full) {
  checks <- grep("^lintr_|^tidyverse_.*_linter$", checks, value = TRUE)
}

cat(
  "Running",
  length(checks),
  if (full) "checks (full)" else "lintr checks",
  "\n\n"
)

result <- goodpractice::gp(checks = checks)
failed <- goodpractice::failed_checks(result)

# These two fail only for local-environment reasons and are not real: CI
# installs tinytex, and .impeccable/ is gitignored so CI never sees it.
local_only <- c(
  "rcmdcheck_can_convert_rd_to_pdf_2",
  "rcmdcheck_hidden_files_and_directories"
)
noise <- intersect(failed, local_only)
real <- setdiff(failed, local_only)

if (length(noise)) {
  cat("Ignored (local environment only):\n")
  cat(paste0("  - ", noise, collapse = "\n"), "\n\n")
}

if (length(real) == 0) {
  cat("Clean -- this would pass the CI good-practice gate.\n")
} else {
  cat("FAILED:", length(real), "\n\n")
  for (f in real) {
    cat("-", f, "\n")
    pos <- result$checks[[f]]$positions
    for (p in utils::head(pos, 10)) {
      cat(sprintf("    %s:%s  %s\n", p$filename, p$line_number, trimws(p$line)))
    }
  }
  quit(status = 1L)
}
