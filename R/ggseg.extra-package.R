#' @import ggseg.formats
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom lifecycle badge
## usethis namespace: end
NULL

# nocov start
#' Utility to easily knit tutorial vignettes
#' @noRd
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

#' Utility to set tutorial build options
#' @noRd
set_tutorial_options <- function() {
  name <- tools::file_path_sans_ext(
    tools::file_path_sans_ext(basename(knitr::current_input()))
  )
  knitr::opts_chunk$set(
    collapse = TRUE,
    comment = "#>",
    error = FALSE,
    fig.path = paste0("figures/", name, "-"),
    fig.retina = 2,
    dpi = 96
  )
  options(
    freesurfer.verbose = FALSE,
    progressr.enabled = TRUE
  )
  rlang::is_installed("freesurfer") &&
    freesurfer::have_fs() &&
    has_magick()
}
# nocov end

## quiets concerns of R CMD check
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    ".id",
    ".subid",
    "filenm",
    "geometry",
    "ggseg_3d",
    "hemi",
    "key",
    "L2",
    "label",
    "region",
    "val",
    "view",
    "X",
    "Y"
  ))
}
