# Developer tooling for building the tutorial vignettes from their `.orig`
# sources. Not part of the package: source this file (after
# `devtools::load_all()`) and call `knit_tutorials()`. The `.qmd.orig` setup
# chunks call `set_tutorial_options()`, so it must be in scope when knitting.
#
# Only tutorials that cannot run unattended are pre-compiled. A tutorial earns
# a `.orig` by needing something a runner does not have: a FreeSurfer subject
# directory, a SUIT template, a Harvard-Oxford volume, a neuromaps download --
# or, as in the publishing tutorial, a network fetch that degrades to a
# fallback with different output instead of failing, which would silently
# change the rendered page.
#
# Everything else is a plain `.qmd` that renders live when pkgdown builds the
# site, so its code is executed on every build and cannot quietly drift out of
# step with the API. `tutorial-lookup-tables.qmd` is the current example: pure
# data-frame work, no external files, milliseconds to run.
#
# Note that live articles render against the *installed* package. CI installs
# the current source first, so the site exercises the real thing; a local
# render may not, if the installed copy is older.

knit_tutorials <- function(tutorials = NULL) {
  if (is.null(tutorials)) {
    tutorials <- list.files("vignettes", "orig$", full.names = TRUE)
  }

  build_tutorials <- function(file) {
    cli::cli_h1("Building {basename(file)}")

    knitr::opts_knit$set(base.dir = "vignettes/")
    knitr::knit(
      file,
      sub("\\.orig$", "", file)
    )
  }

  lapply(tutorials, build_tutorials)
}

set_tutorial_options <- function() {
  name <- tools::file_path_sans_ext(
    tools::file_path_sans_ext(basename(knitr::current_input()))
  )
  knitr::opts_chunk$set(
    collapse = TRUE,
    comment = "#>",
    error = FALSE,
    fig.path = as.character(fs::path("figures", paste0(name, "-"))),
    fig.retina = 2,
    dpi = 96
  )
  options(
    freesurfer.verbose = FALSE,
    progressr.enabled = TRUE
  )
  rlang::is_installed("freesurfer") &&
    freesurfer::have_fs() &&
    nzchar(Sys.which("magick"))
}
