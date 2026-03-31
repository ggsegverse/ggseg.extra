#' Check ggseg.extra setup status
#'
#' Performs diagnostic checks to verify that system dependencies
#' and environment variables required by ggseg.extra are properly
#' configured. Shows per-pipeline readiness so you can see which
#' atlas creation workflows are available.
#'
#' @param detail Character. Level of detail to display:
#'   - `"simple"` (default): Quick pass/fail overview
#'   - `"full"`: Detailed diagnostics including [freesurfer::fs_sitrep()]
#'
#' @return Invisibly returns a list with check results.
#' @export
#'
#' @examples
#' setup_sitrep()
#' setup_sitrep("full")
setup_sitrep <- function(detail = c("simple", "full")) {
  detail <- match.arg(detail)

  results <- list()
  results$freesurfer <- check_freesurfer(detail)
  results$system <- check_other_system_deps(detail)
  results$fsaverage <- check_fsaverage(detail)
  results$packages <- check_optional_packages()
  results$suit <- check_suit_surfaces()

  cli::cli_text("")
  check_pipeline_options(detail)
  cli::cli_text("")
  summarize_pipelines(results, detail)

  invisible(results)
}


check_freesurfer <- function(detail = "simple") {
  if (!rlang::is_installed("freesurfer")) {
    cli::cli_alert_danger("freesurfer R package not installed")
    return(list(available = FALSE))
  }
  has_fs <- freesurfer::have_fs()

  if (detail == "full") {
    freesurfer::fs_sitrep()
  } else {
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
  if (results$imagemagick) {
    cli::cli_alert_success("ImageMagick")
  } else {
    cli::cli_alert_danger("ImageMagick not found")
    if (detail == "full") {
      cli::cli_bullets(c(
        "i" = "Install from {.url https://imagemagick.org/script/download.php}"
      ))
    }
  }

  chrome_path <- find_chrome_path()
  results$chrome <- !is.null(chrome_path)
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
  if (results[[subj]]) {
    cli::cli_alert_success("{subj}")
  } else {
    cli::cli_alert_danger("{subj} not found")
  }

  results
}


check_optional_packages <- function() {
  pkgs <- c(
    "freesurferformats", "gifti", "ciftiTools",
    "RNifti", "smoothr", "Rvcg", "neuromapr"
  )

  results <- list()
  for (pkg in pkgs) {
    results[[pkg]] <- rlang::is_installed(pkg)
  }
  results
}


check_suit_surfaces <- function() {
  flatmap <- tryCatch(suit_flatmap_path(), error = function(e) "")
  surface_3d <- tryCatch(suit_3d_path(), error = function(e) "")

  list(
    flatmap = nzchar(flatmap) && file.exists(flatmap),
    surface_3d = nzchar(surface_3d) && file.exists(surface_3d)
  )
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

  if (detail == "full") {
    cli::cli_text("")
    cli::cli_bullets(c(
      "i" = paste(
        "Set via {.code options(ggseg.extra.<name> = value)} or",
        "environment variables {.envvar GGSEG_EXTRA_<NAME>}"
      ),
      "i" = "See {.code vignette(\"pipeline-configuration\")} for details"
    ))
  }

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


summarize_pipelines <- function(results, detail = "simple") {
  has_fs <- isTRUE(results$freesurfer$available)
  has_magick <- isTRUE(results$system$imagemagick)
  has_chrome <- isTRUE(results$system$chrome)
  has_fsavg <- isTRUE(results$fsaverage$fsaverage5)
  has_gifti <- isTRUE(results$packages$gifti)
  has_fsformats <- isTRUE(results$packages$freesurferformats)
  has_rnifti <- isTRUE(results$packages$RNifti)
  has_smoothr <- isTRUE(results$packages$smoothr)
  has_rvcg <- isTRUE(results$packages$Rvcg)
  has_cifti <- isTRUE(results$packages$ciftiTools)
  has_neuromapr <- isTRUE(results$packages$neuromapr)
  has_flatmap <- isTRUE(results$suit$flatmap)
  has_3d <- isTRUE(results$suit$surface_3d)

  cli::cli_h3("Pipeline readiness")

  pipelines <- list(
    list(
      name = "Cortical from annotation",
      fn = "create_cortical_from_annotation()",
      ready = has_fs && has_fsavg && has_fsformats,
      missing = c(
        if (!has_fs) "FreeSurfer",
        if (!has_fsavg) "fsaverage5",
        if (!has_fsformats) "{freesurferformats}"
      )
    ),
    list(
      name = "Cortical from GIFTI",
      fn = "create_cortical_from_gifti()",
      ready = has_fsformats,
      missing = c(
        if (!has_fsformats) "{freesurferformats}"
      )
    ),
    list(
      name = "Cortical from CIFTI",
      fn = "create_cortical_from_cifti()",
      ready = has_cifti,
      missing = c(
        if (!has_cifti) "{ciftiTools}"
      )
    ),
    list(
      name = "Cortical from neuromaps",
      fn = "create_cortical_from_neuromaps()",
      ready = has_gifti && has_neuromapr,
      missing = c(
        if (!has_gifti) "{gifti}",
        if (!has_neuromapr) "{neuromapr}"
      )
    ),
    list(
      name = "Cortical from labels",
      fn = "create_cortical_from_labels()",
      ready = has_fsformats,
      missing = c(
        if (!has_fsformats) "{freesurferformats}"
      )
    ),
    list(
      name = "Subcortical from volume",
      fn = "create_subcortical_from_volume()",
      ready = has_fs && has_rnifti,
      missing = c(
        if (!has_fs) "FreeSurfer",
        if (!has_rnifti) "{RNifti}"
      )
    ),
    list(
      name = "Tract from tractography",
      fn = "create_tract_from_tractography()",
      ready = has_rnifti,
      missing = c(
        if (!has_rnifti) "{RNifti}"
      )
    ),
    list(
      name = "Whole-brain from volume",
      fn = "create_wholebrain_from_volume()",
      ready = has_fs && has_fsavg && has_rnifti,
      missing = c(
        if (!has_fs) "FreeSurfer",
        if (!has_fsavg) "fsaverage5",
        if (!has_rnifti) "{RNifti}"
      )
    ),
    list(
      name = "Cerebellar from GIFTI",
      fn = "create_cerebellar_from_gifti()",
      ready = has_gifti && has_flatmap,
      missing = c(
        if (!has_gifti) "{gifti}",
        if (!has_flatmap) "SUIT flatmap (bundled)"
      )
    ),
    list(
      name = "Cerebellar from annotation",
      fn = "create_cerebellar_from_annotation()",
      ready = has_fsformats && has_flatmap,
      missing = c(
        if (!has_fsformats) "{freesurferformats}",
        if (!has_flatmap) "SUIT flatmap (bundled)"
      )
    ),
    list(
      name = "Cerebellar from volume",
      fn = "create_cerebellar_from_volume()",
      ready = has_fs && has_rnifti && has_gifti && has_flatmap && has_3d,
      missing = c(
        if (!has_fs) "FreeSurfer",
        if (!has_rnifti) "{RNifti}",
        if (!has_gifti) "{gifti}",
        if (!has_flatmap) "SUIT flatmap (bundled)",
        if (!has_3d) "SUIT 3D surface (bundled)"
      )
    ),
    list(
      name = "MNI to SUIT transform",
      fn = "transform_mni_to_suit()",
      ready = has_rnifti,
      missing = c(
        if (!has_rnifti) "{RNifti}"
      )
    )
  )

  n_ready <- sum(vapply(pipelines, function(p) p$ready, logical(1)))
  n_total <- length(pipelines)

  for (p in pipelines) {
    if (p$ready) {
      cli::cli_alert_success("{p$name}")
    } else {
      missing_str <- paste(p$missing, collapse = ", ")
      cli::cli_alert_danger("{p$name}: needs {missing_str}")
    }
  }

  cli::cli_text("")
  if (n_ready == n_total) {
    cli::cli_alert_success("All {n_total} pipelines ready")
  } else {
    cli::cli_alert_info(
      "{n_ready}/{n_total} pipelines ready"
    )
    if (detail == "simple") {
      cli::cli_bullets(c(
        "i" = "Run {.code setup_sitrep(\"full\")} for details"
      ))
    }
  }
}
