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
    progressr.enabled = TRUE,
    # cli and print() wrap to the console, so a narrow terminal and a runner
    # produce different line breaks throughout. Pinning the width makes a
    # re-knit differ only where the output itself differs.
    width = 80,
    cli.width = 80
  )
  scrub_machine_paths()
  # ImageMagick used to be required because the cortical pipeline built
  # polygons by screenshotting a 3D scene. mesh_projection.R replaced that
  # with direct geometry, so the only thing the check still did was disable
  # every tutorial on machines without ImageMagick -- the CI image among
  # them, since the slim build drops it.
  rlang::is_installed("freesurfer") && freesurfer::have_fs()
}


# Pipelines print the absolute paths they were handed, so a tutorial knitted
# on a laptop and the same tutorial knitted in the container differ on every
# such line. The paths cannot be made stable at the source -- where FreeSurfer
# lives is a property of the machine -- so they are rewritten to the names
# people actually use for them. That keeps a re-knit reviewable: a diff then
# means the output changed, not that someone else ran it.
scrub_machine_paths <- function() {
  # tempdir() is reported both as R returns it and as normalizePath() gives
  # it back, and on macOS those differ (/var/... against /private/var/...).
  # Longest first, so the normalized form is not half-replaced by the raw one.
  temp_paths <- unique(c(normalize_existing(tempdir()), tempdir()))
  temp_paths <- temp_paths[nzchar(temp_paths)]
  temp_paths <- temp_paths[order(nchar(temp_paths), decreasing = TRUE)]

  replacements <- c(
    stats::setNames("$FREESURFER_HOME", fs_home_path()),
    stats::setNames(rep("<tempdir>", length(temp_paths)), temp_paths)
  )
  replacements <- replacements[nzchar(names(replacements))]

  # cli writes progress and alerts to the message stream, so hooking `output`
  # alone leaves most of the paths in place.
  for (stream in c("output", "message", "warning", "error")) {
    hook_stream(stream, replacements)
  }
}

hook_stream <- function(stream, replacements) {
  previous <- knitr::knit_hooks$get(stream)
  hook <- function(x, options) {
    for (path in names(replacements)) {
      x <- gsub(path, replacements[[path]], x, fixed = TRUE)
    }
    previous(x, options)
  }
  knitr::knit_hooks$set(stats::setNames(list(hook), stream))
}

fs_home_path <- function() {
  if (!rlang::is_installed("freesurfer")) {
    return("")
  }
  tryCatch(normalize_existing(freesurfer::fs_dir()), error = function(e) "")
}

normalize_existing <- function(path) {
  if (length(path) != 1 || is.na(path) || !nzchar(path)) {
    return("")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}


# The cerebellar tutorial needs a real SUIT parcellation, which is not
# bundled: it lives in the Diedrichsen Lab repository the package already
# fetches the deformation field from. Twelve kilobytes, cached under the
# session's temp directory so a re-knit does not re-fetch.
#
# Returns NULL rather than failing when there is no network, so the tutorial
# degrades to its unevaluated form instead of taking the build down. CI
# asserts the download separately, so a silent skip there is not possible.
tutorial_suit_parcellation <- function() {
  filename <- "atl-Anatom_dseg.label.gii"
  cached <- file.path(tempdir(), filename)
  if (file.exists(cached)) {
    return(cached)
  }

  url <- paste0(
    "https://raw.githubusercontent.com/DiedrichsenLab/cerebellar_atlases/",
    "master/Diedrichsen_2009/",
    filename
  )

  ok <- tryCatch(
    {
      utils::download.file(url, cached, mode = "wb", quiet = TRUE)
      file.exists(cached) && file.size(cached) > 0
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )

  if (!ok) {
    unlink(cached)
    return(NULL)
  }
  cached
}
