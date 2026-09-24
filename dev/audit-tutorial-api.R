#!/usr/bin/env Rscript
# Check that every call in the vignettes still resolves against the package
# API, and exit non-zero when one does not.
#
# Why this exists: most tutorials are pre-compiled, so their code is text that
# nobody re-runs. Nine documents once told readers to call
# `atlas_smooth(keep = 0.2)` for months after `keep` moved to
# `atlas_simplify()` -- valid prose, valid-looking code, and an error for
# anyone who followed it. Rendering catches that only for the tutorials CI can
# actually build; this catches it for all of them, in seconds, with no
# FreeSurfer and no external data.
#
# It is a static check and deliberately narrow. It answers "does this function
# exist, and does it take these arguments", not "is the output still right".
# Only the second question needs a real render.
#
#   Rscript dev/audit-tutorial-api.R

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("install.packages('pkgload')")
}

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# Functions from packages a vignette attaches are fair game, so the check
# knows the difference between a call this package owns and one it does not.
namespaces_for <- function(code) {
  attached <- unlist(regmatches(
    code,
    gregexpr("(?<=library\\()[A-Za-z0-9._]+", code, perl = TRUE)
  ))
  candidates <- unique(c("ggseg.extra", attached))
  candidates[vapply(candidates, requireNamespace, logical(1), quietly = TRUE)]
}

chunk_code <- function(lines) {
  starts <- grep("^```[{ ]*[rR]", lines)
  ends <- grep("^```\\s*$", lines)
  code <- character()
  for (s in starts) {
    e <- ends[ends > s][1]
    if (!is.na(e) && e > s + 1) {
      code <- c(code, lines[(s + 1):(e - 1)])
    }
  }
  # Pre-compiled tutorials interleave captured output with the code that
  # produced it; only the code is ours to check.
  grep("^#>", code, value = TRUE, invert = TRUE)
}

# A chunk that does not parse on its own (a snippet, a deliberate fragment)
# must not take the rest of the file down with it.
parse_leniently <- function(lines) {
  whole <- tryCatch(
    parse(text = paste(lines, collapse = "\n")),
    error = function(e) NULL
  )
  if (!is.null(whole)) {
    return(as.list(whole))
  }

  starts <- grep("^```[{ ]*[rR]", lines)
  ends <- grep("^```\\s*$", lines)
  out <- list()
  for (s in starts) {
    e <- ends[ends > s][1]
    if (is.na(e) || e <= s + 1) {
      next
    }
    chunk <- grep("^#>", lines[(s + 1):(e - 1)], value = TRUE, invert = TRUE)
    parsed <- tryCatch(
      parse(text = paste(chunk, collapse = "\n")),
      error = function(e) NULL
    )
    if (!is.null(parsed)) {
      out <- c(out, as.list(parsed))
    }
  }
  out
}

lookup <- function(name, namespaces) {
  for (ns in namespaces) {
    if (name %in% getNamespaceExports(ns)) {
      return(get(name, envir = asNamespace(ns)))
    }
  }
  NULL
}

# Only names that look like this ecosystem's are reported as missing. A
# vignette is free to call anything else; we have no business judging it.
owned_pattern <- paste0(
  "^(atlas_|create_|read_|write_|lut_|setup_|use_|new_project_|prepare_|",
  "project_|convert_|coregister_|label_|subcortical_|suit_|transform_|",
  "aseg_|context_|get_|is_|mri_|as_verbosity)"
)

check_call <- function(x, namespaces, issues) {
  head <- x[[1]]

  # A qualified call names its own package, so it is checked against that one
  # and skipped when the package is not installed here.
  if (is.call(head) && identical(as.character(head[[1]]), "::")) {
    pkg <- as.character(head[[2]])
    name <- as.character(head[[3]])
    if (!requireNamespace(pkg, quietly = TRUE)) {
      return(issues)
    }
    if (!name %in% getNamespaceExports(pkg)) {
      return(c(issues, sprintf("%s::%s() does not exist", pkg, name)))
    }
    return(check_formals(
      get(name, envir = asNamespace(pkg)),
      paste0(pkg, "::", name),
      x,
      issues
    ))
  }

  if (!is.name(head)) {
    return(issues)
  }
  name <- as.character(head)

  fn <- lookup(name, namespaces)
  if (is.null(fn)) {
    if (grepl(owned_pattern, name) && !exists(name, envir = baseenv())) {
      issues <- c(issues, sprintf("%s() does not exist", name))
    }
    return(issues)
  }

  check_formals(fn, name, x, issues)
}


check_formals <- function(fn, label, x, issues) {
  formal_names <- names(formals(fn))
  if (is.null(formal_names) || "..." %in% formal_names) {
    return(issues)
  }

  supplied <- names(x)[-1]
  supplied <- supplied[!is.na(supplied) & nzchar(supplied)]
  unknown <- setdiff(supplied, formal_names)
  if (length(unknown) > 0) {
    issues <- c(
      issues,
      sprintf(
        "%s() has no argument %s",
        label,
        paste(unknown, collapse = ", ")
      )
    )
  }
  issues
}

walk_calls <- function(x, namespaces, issues) {
  if (!is.call(x)) {
    return(issues)
  }
  issues <- check_call(x, namespaces, issues)

  # An empty argument (`x[, 1]`) is a missing-arg marker: binding it to a
  # variable and touching it raises "argument is missing". Single-bracket
  # indexing compares it without forcing it, so those slots are skipped
  # rather than evaluated.
  parts <- as.list(x)
  for (i in seq_along(parts)) {
    if (identical(parts[i], list(quote(expr = )))) {
      next
    }
    issues <- walk_calls(parts[[i]], namespaces, issues)
  }
  issues
}

# An unclosed fence is not a cosmetic problem. Prose after it renders as
# code, and every later chunk shifts by one, so the code this script reads
# stops being the code the page shows -- which is how a stale
# `atlas_smooth(keep = )` hid here for a whole review.
check_fences <- function(lines) {
  fences <- grep("^```", lines)
  if (length(fences) %% 2 == 0) {
    return(character())
  }
  sprintf(
    "unbalanced code fences (%d of them); a chunk is never closed",
    length(fences)
  )
}

audit_file <- function(path) {
  lines <- readLines(path, warn = FALSE)
  issues <- check_fences(lines)

  code <- chunk_code(lines)
  if (length(code) == 0) {
    return(issues)
  }

  namespaces <- namespaces_for(code)
  for (expr in parse_leniently(lines)) {
    issues <- walk_calls(expr, namespaces, issues)
  }
  unique(issues)
}

files <- list.files(
  "vignettes",
  pattern = "[.](qmd|Rmd)([.]orig)?$",
  full.names = TRUE
)

failed <- 0L
for (path in sort(files)) {
  issues <- audit_file(path)
  if (length(issues) == 0) {
    next
  }
  failed <- failed + 1L
  cat(sprintf("\n%s\n", path))
  cat(sprintf("  - %s\n", issues), sep = "")
  if (nzchar(Sys.getenv("GITHUB_ACTIONS"))) {
    for (issue in issues) {
      cat(sprintf("::error file=%s::%s\n", path, issue))
    }
  }
}

if (failed > 0L) {
  cat(sprintf(
    "\n%d vignette%s call the package in ways it no longer supports.\n",
    failed,
    if (failed == 1L) "" else "s"
  ))
  quit(status = 1L)
}

cat(sprintf("Checked %d vignettes; every call resolves.\n", length(files)))
