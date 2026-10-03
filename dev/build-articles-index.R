#!/usr/bin/env Rscript
# Write pkgdown/assets/articles.json: a machine-readable index of the pkgdown
# tutorials that are not included in the package tarball.
#
# Why this exists: `vignettes/articles/` is Rbuildignored, so the pre-knit
# tutorials never reach the tarball and r-universe's package metadata never
# lists them. The ggsegverse website builds its documentation page from that
# metadata, so nine tutorials -- the most substantial docs the package has --
# were invisible there. pkgdown copies `pkgdown/assets/` to the site root, so
# this file ships to https://ggsegverse.github.io/ggseg.extra/articles.json
# alongside the pages it describes.
#
# Sections, order and membership come from the `articles:` index in
# _pkgdown.yml -- the same source pkgdown renders articles/index.html from.
# Shipped vignettes are left to r-universe's package metadata. Titles come
# from each source file's YAML front matter.
#
#   Rscript dev/build-articles-index.R            # write the file
#   Rscript dev/build-articles-index.R --check    # fail if it is out of date

args <- commandArgs(trailingOnly = TRUE)
check_only <- "--check" %in% args

for (pkg in c("yaml", "jsonlite")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("install.packages('%s')", pkg))
  }
}

out_file <- "pkgdown/assets/articles.json"
extensions <- "\\.(qmd|Rmd|rmd)$"

config <- yaml::read_yaml("_pkgdown.yml")
if (!length(config$articles)) {
  stop("_pkgdown.yml has no `articles:` index to build from")
}
if (!length(config$url)) {
  stop("_pkgdown.yml has no `url:`, so the index cannot say where it points")
}

# R CMD build drops a file when any Rbuildignore pattern matches the file or
# one of its parent directories, so a per-file regex test is not enough:
# `^vignettes/articles$` excludes the tutorials without ever matching their
# paths.
build_ignored <- local({
  patterns <- if (file.exists(".Rbuildignore")) {
    Filter(nzchar, trimws(readLines(".Rbuildignore", warn = FALSE)))
  } else {
    character()
  }

  function(path) {
    parts <- strsplit(path, "/", fixed = TRUE)[[1]]
    ancestors <- Reduce(
      function(a, b) paste(a, b, sep = "/"),
      parts,
      accumulate = TRUE
    )
    any(vapply(
      patterns,
      function(p) any(grepl(p, ancestors, perl = TRUE)),
      logical(1)
    ))
  }
})

# An article's source is `vignettes/<slug>.<ext>`, where the slug may itself
# contain `articles/`. The extension varies per file, so it is discovered
# rather than assumed.
source_for <- function(slug) {
  candidates <- file.path("vignettes", paste0(slug, c(".qmd", ".Rmd", ".rmd")))
  found <- candidates[file.exists(candidates)]
  if (!length(found)) {
    stop(sprintf(
      "article '%s' is listed in _pkgdown.yml but has no source file",
      slug
    ))
  }
  found[1]
}

front_matter_title <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (!length(lines) || !grepl("^---\\s*$", lines[1])) {
    stop(sprintf("'%s' has no YAML front matter", path))
  }
  closing <- grep("^(---|\\.\\.\\.)\\s*$", lines[-1])[1]
  if (is.na(closing)) {
    stop(sprintf("'%s' has an unterminated YAML front matter block", path))
  }
  front <- yaml::yaml.load(paste(lines[2:closing], collapse = "\n"))
  if (!length(front$title)) {
    stop(sprintf("'%s' has no title in its front matter", path))
  }
  as.character(front$title)[1]
}

articles <- list()
for (section in config$articles) {
  selectors <- grep("[()]", section$contents, value = TRUE)
  if (length(selectors)) {
    stop(
      "this index only understands literal article names, but _pkgdown.yml ",
      "uses the selector(s): ",
      paste(selectors, collapse = ", ")
    )
  }

  for (slug in section$contents) {
    path <- source_for(slug)
    if (!startsWith(section$title, "Tutorials:") || !build_ignored(path)) {
      next
    }
    articles[[length(articles) + 1]] <- list(
      slug = slug,
      title = front_matter_title(path),
      href = paste0("articles/", basename(slug), ".html"),
      section = if (length(section$title)) section$title else NULL,
      section_desc = if (length(section$desc)) trimws(section$desc) else NULL,
      # The point of the index: which articles a consumer reading the
      # installed package or r-universe metadata cannot see.
      vignette = !build_ignored(path)
    )
  }
}

listed <- vapply(articles, function(a) a$slug, character(1))
duplicated_slugs <- unique(listed[duplicated(listed)])
if (length(duplicated_slugs)) {
  stop(
    "the `articles:` index in _pkgdown.yml lists these more than once: ",
    paste(duplicated_slugs, collapse = ", ")
  )
}
on_disk <- sub(
  extensions,
  "",
  list.files("vignettes", pattern = extensions, recursive = TRUE)
)
missing <- setdiff(on_disk, listed)
if (length(missing)) {
  stop(
    "these articles exist but are absent from the `articles:` index in ",
    "_pkgdown.yml, so neither the site nor this index lists them: ",
    paste(missing, collapse = ", ")
  )
}

index <- list(
  package = unname(read.dcf("DESCRIPTION", fields = "Package")[1, 1]),
  url = sub("/?$", "/", config$url),
  # Deliberately no timestamp: a regenerated but unchanged file has to be
  # byte-identical for --check to mean anything.
  source = "_pkgdown.yml",
  articles = articles
)

json <- paste0(
  jsonlite::toJSON(index, auto_unbox = TRUE, pretty = 2, null = "null"),
  "\n"
)

if (check_only) {
  current <- if (file.exists(out_file)) {
    paste0(paste(readLines(out_file, warn = FALSE), collapse = "\n"), "\n")
  } else {
    ""
  }
  if (!identical(current, json)) {
    stop(sprintf(
      paste(
        "%s is out of date; run `Rscript dev/build-articles-index.R`",
        "and commit the result"
      ),
      out_file
    ))
  }
  cat(sprintf("%s is up to date (%d articles)\n", out_file, length(articles)))
} else {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  cat(json, file = out_file)
  cat(sprintf("wrote %s (%d articles)\n", out_file, length(articles)))
}
