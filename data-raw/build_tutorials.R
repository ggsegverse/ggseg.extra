# Developer tooling for building the tutorial vignettes from their `.orig`
# sources. Not part of the package: source this file (after
# `devtools::load_all()`) and call `knit_tutorials()`. The `.qmd.orig` setup
# chunks call `set_tutorial_options()`, so it must be in scope when knitting.

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
