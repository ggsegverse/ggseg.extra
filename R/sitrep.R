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

  if (detail == "full") {
    freesurfer::fs_sitrep()
  } else if (detail == "simple") {
    if (has_fs) {
      cli::cli_alert_success("FreeSurfer")
    } else {
      cli::cli_alert_danger("FreeSurfer not configured")
    }
  }

  list(available = has_fs)
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
          "i" = "macOS: {.code brew install imagemagick}"
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
    "freesurferformats", "gifti", "ciftiTools",
    "RNifti", "smoothr", "Rvcg", "neuromapr"
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
    if (length(installed) > 0) {
      installed_str <- paste0( # nolint: object_usage_linter.
        "{.pkg ", installed, "}", collapse = ", "
      )
      cli::cli_alert_success("R packages: {installed_str}")
    }
    if (length(missing) > 0) {
      missing_str <- paste0( # nolint: object_usage_linter.
        "{.pkg ", missing, "}", collapse = ", "
      )
      cli::cli_alert_danger("Missing R packages: {missing_str}")
      if (detail == "full") {
        install_cmd <- paste0( # nolint: object_usage_linter.
          'install.packages(c("',
          paste(missing, collapse = '", "'), '"))'
        )
        cli::cli_bullets(c(
          "i" = "Install with: {.code {install_cmd}}"
        ))
      }
    }
  }

  results
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
        reinstall <- paste0( # nolint: object_usage_linter.
          'remotes::install_github("ggsegverse/ggseg.extra")'
        )
        cli::cli_bullets(c(
          "i" = "These should be bundled with the package.",
          "i" = "Try reinstalling: {.code {reinstall}}"
        ))
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
    "i" = "See {.code vignette(\"pipeline-configuration\")} for details"
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
  has_fs <- isTRUE(results$freesurfer$available)
  has_fsavg <- isTRUE(results$fsaverage$fsaverage5)
  has_gifti <- isTRUE(results$packages$gifti)
  has_fsformats <- isTRUE(results$packages$freesurferformats)
  has_rnifti <- isTRUE(results$packages$RNifti)
  has_cifti <- isTRUE(results$packages$ciftiTools)
  has_neuromapr <- isTRUE(results$packages$neuromapr)
  has_flatmap <- isTRUE(results$suit$flatmap)
  has_3d <- isTRUE(results$suit$surface_3d)

  make_pipeline <- function(name, fn, needs, install_hints = NULL) {
    checks <- vapply(needs, function(n) n$ok, logical(1))
    missing <- lapply(needs[!checks], function(n) {
      list(label = n$label, hint = n$hint)
    })
    list(
      name = name, fn = fn,
      ready = all(checks),
      missing = missing,
      install_hints = install_hints
    )
  }

  need <- function(ok, label, hint) list(ok = ok, label = label, hint = hint)

  # nolint start: indentation_linter.
  fs_need <- need(has_fs, "FreeSurfer",
    "Install from https://surfer.nmr.mgh.harvard.edu/")
  fsavg_need <- need(has_fsavg, "fsaverage5",
    "Ships with FreeSurfer ($SUBJECTS_DIR/fsaverage5)")
  gifti_need <- need(has_gifti, "{gifti}",
    'install.packages("gifti")')
  fsf_need <- need(has_fsformats, "{freesurferformats}",
    'install.packages("freesurferformats")')
  rnifti_need <- need(has_rnifti, "{RNifti}",
    'install.packages("RNifti")')
  cifti_need <- need(has_cifti, "{ciftiTools}",
    'install.packages("ciftiTools")')
  neuromapr_need <- need(has_neuromapr, "{neuromapr}",
    'remotes::install_github("ggseg/neuromapr")')
  flatmap_need <- need(has_flatmap, "SUIT flatmap",
    "Bundled; reinstall ggseg.extra")
  surf3d_need <- need(has_3d, "SUIT 3D surface",
    "Bundled; reinstall ggseg.extra")
  # nolint end

  list(
    cortical = list(
      header = "Cortical",
      pipelines = list(
        make_pipeline(
          "from annotation", "create_cortical_from_annotation()",
          list(fs_need, fsavg_need, fsf_need)
        ),
        make_pipeline(
          "from GIFTI", "create_cortical_from_gifti()",
          list(fsf_need)
        ),
        make_pipeline(
          "from CIFTI", "create_cortical_from_cifti()",
          list(cifti_need)
        ),
        make_pipeline(
          "from neuromaps", "create_cortical_from_neuromaps()",
          list(gifti_need, neuromapr_need)
        ),
        make_pipeline(
          "from labels", "create_cortical_from_labels()",
          list(fsf_need)
        )
      )
    ),
    subcortical = list(
      header = "Subcortical",
      pipelines = list(
        make_pipeline(
          "from volume", "create_subcortical_from_volume()",
          list(fs_need, rnifti_need)
        )
      )
    ),
    tract = list(
      header = "Tract",
      pipelines = list(
        make_pipeline(
          "from tractography", "create_tract_from_tractography()",
          list(rnifti_need)
        )
      )
    ),
    wholebrain = list(
      header = "Whole-brain",
      pipelines = list(
        make_pipeline(
          "from volume", "create_wholebrain_from_volume()",
          list(fs_need, fsavg_need, rnifti_need)
        )
      )
    ),
    cerebellar = list(
      header = "Cerebellar",
      pipelines = list(
        make_pipeline(
          "from GIFTI", "create_cerebellar_from_gifti()",
          list(gifti_need, flatmap_need)
        ),
        make_pipeline(
          "from annotation", "create_cerebellar_from_annotation()",
          list(fsf_need, flatmap_need)
        ),
        make_pipeline(
          "from volume", "create_cerebellar_from_volume()",
          list(fs_need, rnifti_need, gifti_need, flatmap_need, surf3d_need)
        ),
        make_pipeline(
          "MNI to SUIT transform", "transform_mni_to_suit()",
          list(rnifti_need)
        )
      )
    )
  )
}


summarize_pipelines <- function(results, detail = "simple") {
  registry <- pipeline_registry(results)

  all_pipelines <- unlist(
    lapply(registry, function(g) g$pipelines), recursive = FALSE
  )
  n_ready <- sum(vapply(all_pipelines, function(p) p$ready, logical(1)))
  n_total <- length(all_pipelines)

  cli::cli_h3("Pipeline readiness ({n_ready}/{n_total})")

  for (group in registry) {
    group_ready <- vapply(
      group$pipelines, function(p) p$ready, logical(1)
    )

    if (detail == "minimal" && all(group_ready)) {
      cli::cli_alert_success(
        "{group$header}: all {length(group$pipelines)} ready"
      )
      next
    }

    if (detail != "minimal") {
      cli::cli_text("{.strong {group$header}}")
    }

    for (p in group$pipelines) {
      if (p$ready) {
        if (detail == "minimal") {
          next
        }
        cli::cli_alert_success("{p$name}")
      } else {
        missing_labels <- vapply(
          p$missing, function(m) m$label, character(1)
        )
        missing_str <- paste( # nolint: object_usage_linter.
          missing_labels, collapse = ", "
        )
        cli::cli_alert_danger("{p$name}: needs {missing_str}")

        if (detail == "full") {
          hints <- vapply(p$missing, function(m) m$hint, character(1))
          for (h in hints) {
            cli::cli_bullets(c("i" = "{.code {h}}"))
          }
        }
      }
    }
  }

  cli::cli_text("")
  if (n_ready == n_total) {
    cli::cli_alert_success("All {n_total} pipelines ready")
  } else {
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
  }
}
