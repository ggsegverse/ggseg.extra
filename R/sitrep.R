#' Check ggseg.extra setup status
#'
#' Performs diagnostic checks to verify that system dependencies
#' and R packages required by ggseg.extra are properly configured.
#' Shows per-pipeline readiness so you can see which atlas creation
#' workflows are available and what to install for the ones that aren't.
#'
#' @param detail Character. Level of detail to display:
#'   - `"minimal"`: Just the pipeline readiness summary
#'   - `"simple"` (default): System checks + pipeline readiness
#'   - `"full"`: Everything above + install commands, paths, options,
#'     and FreeSurfer diagnostics
#'
#' @return Invisibly returns a list with check results.
#' @export
#'
#' @examples
#' setup_sitrep()
#' setup_sitrep("full")
setup_sitrep <- function(detail = c("simple", "minimal", "full")) {
  detail <- match.arg(detail)

  results <- list()
  results$freesurfer <- check_freesurfer(detail)
  results$system <- check_other_system_deps(detail)
  results$fsaverage <- check_fsaverage(detail)
  results$packages <- check_optional_packages(detail)
  results$suit <- check_suit_surfaces(detail)

  if (detail != "minimal") {
    cli::cli_text("")
  }

  if (detail == "full") {
    check_pipeline_options(detail)
    cli::cli_text("")
  }

  summarize_pipelines(results, detail)

  invisible(results)
}


check_freesurfer <- function(detail = "simple") {
  if (!rlang::is_installed("freesurfer")) {
    if (detail != "minimal") {
      cli::cli_alert_danger("freesurfer R package not installed")
      if (detail == "full") {
        cli::cli_bullets(c(
          "i" = 'Install with: {.code install.packages("freesurfer")}'
        ))
      }
    }
    return(list(available = FALSE))
  }
  has_fs <- freesurfer::have_fs()

  if (detail == "full" && has_fs_sitrep()) {
    freesurfer::fs_sitrep()
  } else if (detail != "minimal") {
    if (has_fs) {
      cli::cli_alert_success("FreeSurfer")
    } else {
      cli::cli_alert_danger("FreeSurfer not configured")
    }
  }

  list(available = has_fs)
}


# `fs_sitrep()` is only exported by newer `freesurfer` versions; guard so the
# diagnostic degrades gracefully on older/CRAN installs rather than aborting.
# `check_freesurfer()` only reaches here once `freesurfer` is installed.
#' @noRd
has_fs_sitrep <- function() {
  "fs_sitrep" %in% getNamespaceExports("freesurfer")
}


check_other_system_deps <- function(detail = "simple") {
  results <- list()

  results$imagemagick <- has_magick()
  if (detail != "minimal") {
    if (results$imagemagick) {
      cli::cli_alert_success("ImageMagick")
    } else {
      cli::cli_alert_danger("ImageMagick not found")
      if (detail == "full") {
        cli::cli_bullets(c(
          "i" = paste(
            "Install from",
            "{.url https://imagemagick.org/script/download.php}"
          ),
          "i" = "macOS: {.code brew install imagemagick}" # nolint
        ))
      }
    }
  }

  chrome_path <- find_chrome_path()
  results$chrome <- !is.null(chrome_path)
  if (detail != "minimal") {
    if (results$chrome) {
      if (detail == "full") {
        cli::cli_alert_success("Chrome/Chromium: {.path {chrome_path}}")
      } else {
        cli::cli_alert_success("Chrome/Chromium")
      }
    } else {
      cli::cli_alert_danger("Chrome/Chromium not found")
      if (detail == "full") {
        cli::cli_bullets(c(
          "i" = "Install Chrome, Chromium, or Edge for webshot functionality"
        ))
      }
    }
  }

  results
}


check_fsaverage <- function(detail = "simple") {
  results <- list()

  subj_dir <- if (rlang::is_installed("freesurfer")) {
    tryCatch(freesurfer::fs_subj_dir(), error = function(e) "")
  } else {
    ""
  }

  subj <- "fsaverage5"
  subj_path <- file.path(subj_dir, subj)
  results[[subj]] <- dir.exists(subj_path)
  if (detail != "minimal") {
    if (results[[subj]]) {
      if (detail == "full") {
        cli::cli_alert_success("{subj}: {.path {subj_path}}")
      } else {
        cli::cli_alert_success("{subj}")
      }
    } else {
      cli::cli_alert_danger("{subj} not found")
      if (detail == "full") {
        cli::cli_bullets(c(
          "i" = "Ships with FreeSurfer in $SUBJECTS_DIR"
        ))
      }
    }
  }

  results
}


check_optional_packages <- function(detail = "simple") {
  pkgs <- c(
    "freesurferformats",
    "gifti",
    "ciftiTools",
    "RNifti",
    "Rvcg",
    "neuromapr"
  )

  results <- list()
  installed <- character()
  missing <- character()

  for (pkg in pkgs) {
    results[[pkg]] <- rlang::is_installed(pkg)
    if (results[[pkg]]) {
      installed <- c(installed, pkg)
    } else {
      missing <- c(missing, pkg)
    }
  }

  if (detail != "minimal") {
    report_optional_packages(installed, missing, detail)
  }

  results
}


#' Report which optional R packages are installed and how to get the rest
#' @noRd
report_optional_packages <- function(installed, missing, detail) {
  # nolint start: object_usage_linter.
  if (length(installed) > 0) {
    installed_str <- paste0(
      "{.pkg ",
      installed,
      "}",
      collapse = ", "
    )
    cli::cli_alert_success("R packages: {installed_str}")
  }
  if (length(missing) > 0) {
    missing_str <- paste0(
      "{.pkg ",
      missing,
      "}",
      collapse = ", "
    )
    cli::cli_alert_danger("Missing R packages: {missing_str}")
    if (detail == "full") {
      install_cmd <- paste0(
        'install.packages(c("',
        paste(missing, collapse = '", "'),
        '"))'
      )
      cli::cli_bullets(c(
        "i" = "Install with: {.code {install_cmd}}"
      ))
    }
  }
  # nolint end
  invisible(NULL)
}


check_suit_surfaces <- function(detail = "simple") {
  flatmap <- tryCatch(suit_flatmap_path(), error = function(e) "")
  surface_3d <- tryCatch(suit_3d_path(), error = function(e) "")

  has_flatmap <- nzchar(flatmap) && file.exists(flatmap)
  has_3d <- nzchar(surface_3d) && file.exists(surface_3d)

  if (detail != "minimal") {
    if (has_flatmap && has_3d) {
      cli::cli_alert_success("SUIT surfaces (bundled)")
    } else {
      if (!has_flatmap) {
        cli::cli_alert_danger("SUIT flatmap surface missing")
      }
      if (!has_3d) {
        cli::cli_alert_danger("SUIT 3D surface missing")
      }
      if (detail == "full") {
        # nolint start: object_usage_linter.
        reinstall <- paste0(
          'remotes::install_github("ggsegverse/ggseg.extra")'
        )
        cli::cli_bullets(c(
          "i" = "These should be bundled with the package.",
          "i" = "Try reinstalling: {.code {reinstall}}" # nolint
        ))
        # nolint end
      }
    }
  }

  list(flatmap = has_flatmap, surface_3d = has_3d)
}


check_pipeline_options <- function(detail = "simple") {
  opts <- list(
    verbose = get_verbose(),
    cleanup = get_cleanup(),
    skip_existing = get_skip_existing(),
    tolerance = get_tolerance(),
    smoothness = get_smoothness(),
    output_dir = get_output_dir()
  )

  cli::cli_h3("Pipeline options")
  cli::cli_dl(c(
    verbose = "{opts$verbose}",
    cleanup = "{opts$cleanup}",
    skip_existing = "{opts$skip_existing}",
    tolerance = "{opts$tolerance}",
    smoothness = "{opts$smoothness}",
    output_dir = "{.path {opts$output_dir}}"
  ))

  cli::cli_text("")
  cli::cli_bullets(c(
    "i" = paste(
      "Set via {.code options(ggseg.extra.<name> = value)} or",
      "environment variables {.envvar GGSEG_EXTRA_<NAME>}"
    ),
    "i" = "See {.code vignette(\"pipeline-configuration\")} for details" # nolint
  ))

  opts
}


#' @noRd
find_chrome_path <- function() {
  for (name in c("google-chrome", "chromium-browser", "chromium", "chrome")) {
    path <- Sys.which(name)
    if (nzchar(path)) return(path)
  }
  candidates <- c(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe"
  )
  for (p in candidates) {
    if (file.exists(p)) return(p)
  }
  NULL
}


#' @noRd
pipeline_registry <- function(results) {
  needs <- c(pipeline_tool_needs(results), pipeline_pkg_needs(results))

  list(
    cortical = list(
      header = "Cortical",
      pipelines = cortical_pipelines(needs)
    ),
    subcortical = list(
      header = "Subcortical",
      pipelines = list(
        make_pipeline(
          "from volume",
          "create_subcortical_from_volume()",
          list(needs$fs, needs$rnifti)
        )
      )
    ),
    tract = list(
      header = "Tract",
      pipelines = list(
        make_pipeline(
          "from tractography",
          "create_tract_from_tractography()",
          list(needs$rnifti)
        )
      )
    ),
    wholebrain = list(
      header = "Whole-brain",
      pipelines = list(
        make_pipeline(
          "from volume",
          "create_wholebrain_from_volume()",
          list(needs$fs, needs$fsavg, needs$rnifti)
        )
      )
    ),
    cerebellar = list(
      header = "Cerebellar",
      pipelines = cerebellar_pipelines(needs)
    )
  )
}


#' A single pipeline requirement: whether it is met, and how to meet it
#' @noRd
pipeline_need <- function(ok, label, hint) {
  list(ok = ok, label = label, hint = hint)
}


#' Describe one pipeline and which of its requirements are missing
#' @noRd
make_pipeline <- function(name, fn, needs, install_hints = NULL) {
  checks <- vapply(needs, function(n) n$ok, logical(1))
  missing <- lapply(needs[!checks], function(n) {
    list(label = n$label, hint = n$hint)
  })
  list(
    name = name,
    fn = fn,
    ready = all(checks),
    missing = missing,
    install_hints = install_hints
  )
}


#' Requirements met by external tools and bundled data
#' @noRd
pipeline_tool_needs <- function(results) {
  list(
    fs = pipeline_need(
      isTRUE(results$freesurfer$available),
      "FreeSurfer",
      "Install from https://surfer.nmr.mgh.harvard.edu/"
    ),
    fsavg = pipeline_need(
      isTRUE(results$fsaverage$fsaverage5),
      "fsaverage5",
      "Ships with FreeSurfer ($SUBJECTS_DIR/fsaverage5)"
    ),
    flatmap = pipeline_need(
      isTRUE(results$suit$flatmap),
      "SUIT flatmap",
      "Bundled; reinstall ggseg.extra"
    ),
    surf3d = pipeline_need(
      isTRUE(results$suit$surface_3d),
      "SUIT 3D surface",
      "Bundled; reinstall ggseg.extra"
    )
  )
}


#' Requirements met by optional R packages
#' @noRd
pipeline_pkg_needs <- function(results) {
  list(
    gifti = pipeline_need(
      isTRUE(results$packages$gifti),
      "{gifti}",
      'install.packages("gifti")'
    ),
    fsf = pipeline_need(
      isTRUE(results$packages$freesurferformats),
      "{freesurferformats}",
      'install.packages("freesurferformats")'
    ),
    rnifti = pipeline_need(
      isTRUE(results$packages$RNifti),
      "{RNifti}",
      'install.packages("RNifti")'
    ),
    cifti = pipeline_need(
      isTRUE(results$packages$ciftiTools),
      "{ciftiTools}",
      'install.packages("ciftiTools")'
    ),
    neuromapr = pipeline_need(
      isTRUE(results$packages$neuromapr),
      "{neuromapr}",
      'remotes::install_github("ggseg/neuromapr")'
    )
  )
}


#' Cortical pipeline entries
#' @noRd
cortical_pipelines <- function(needs) {
  list(
    make_pipeline(
      "from annotation",
      "create_cortical_from_annotation()",
      list(needs$fs, needs$fsavg, needs$fsf)
    ),
    make_pipeline(
      "from GIFTI",
      "create_cortical_from_gifti()",
      list(needs$fsf)
    ),
    make_pipeline(
      "from CIFTI",
      "create_cortical_from_cifti()",
      list(needs$cifti)
    ),
    make_pipeline(
      "from neuromaps",
      "create_cortical_from_neuromaps()",
      list(needs$gifti, needs$neuromapr)
    ),
    make_pipeline(
      "from labels",
      "create_cortical_from_labels()",
      list(needs$fsf)
    )
  )
}


#' Cerebellar pipeline entries
#' @noRd
cerebellar_pipelines <- function(needs) {
  list(
    make_pipeline(
      "from GIFTI",
      "create_cerebellar_from_gifti()",
      list(needs$gifti, needs$flatmap)
    ),
    make_pipeline(
      "from annotation",
      "create_cerebellar_from_annotation()",
      list(needs$fsf, needs$flatmap)
    ),
    make_pipeline(
      "from volume",
      "create_cerebellar_from_volume()",
      list(needs$fs, needs$rnifti, needs$gifti, needs$flatmap, needs$surf3d)
    ),
    make_pipeline(
      "MNI to SUIT transform",
      "transform_mni_to_suit()",
      list(needs$rnifti)
    )
  )
}


summarize_pipelines <- function(results, detail = "simple") {
  registry <- pipeline_registry(results)

  all_pipelines <- unlist(
    lapply(registry, function(g) g$pipelines),
    recursive = FALSE
  )
  n_ready <- sum(vapply(all_pipelines, function(p) p$ready, logical(1)))
  n_total <- length(all_pipelines)

  cli::cli_h3("Pipeline readiness ({n_ready}/{n_total})")

  for (group in registry) {
    summarize_pipeline_group(group, detail)
  }

  summarize_pipeline_footer(n_ready, n_total, detail)
}


#' Render one pipeline group's readiness lines
#' @noRd
summarize_pipeline_group <- function(group, detail) {
  group_ready <- vapply(
    group$pipelines,
    function(p) p$ready,
    logical(1)
  )

  if (detail == "minimal" && all(group_ready)) {
    cli::cli_alert_success(
      "{group$header}: all {length(group$pipelines)} ready"
    )
    return(invisible(NULL))
  }

  if (detail != "minimal") {
    cli::cli_text("{.strong {group$header}}")
  }

  for (p in group$pipelines) {
    summarize_pipeline_entry(p, detail)
  }

  invisible(NULL)
}


#' Render one pipeline's readiness line and optional hints
#' @noRd
summarize_pipeline_entry <- function(p, detail) {
  if (p$ready) {
    if (detail == "minimal") {
      return(invisible(NULL))
    }
    cli::cli_alert_success("{p$name}")
    return(invisible(NULL))
  }

  missing_labels <- vapply(
    p$missing,
    function(m) m$label,
    character(1)
  )
  # nolint start: object_usage_linter.
  missing_str <- toString(missing_labels)
  # nolint end
  cli::cli_alert_danger("{p$name}: needs {missing_str}")

  if (detail == "full") {
    hints <- vapply(p$missing, function(m) m$hint, character(1))
    for (h in hints) {
      cli::cli_bullets(c("i" = "{.code {h}}"))
    }
  }

  invisible(NULL)
}


#' Render the overall pipeline-readiness footer
#' @noRd
summarize_pipeline_footer <- function(n_ready, n_total, detail) {
  cli::cli_text("")
  if (n_ready == n_total) {
    cli::cli_alert_success("All {n_total} pipelines ready")
    return(invisible(NULL))
  }

  cli::cli_alert_info("{n_ready}/{n_total} pipelines ready")
  if (detail == "minimal") {
    cli::cli_bullets(c(
      "i" = "Run {.code setup_sitrep()} for details"
    ))
  } else if (detail == "simple") {
    cli::cli_bullets(c(
      "i" = paste(
        "Run {.code setup_sitrep(\"full\")} for",
        "install instructions"
      )
    ))
  }

  invisible(NULL)
}
