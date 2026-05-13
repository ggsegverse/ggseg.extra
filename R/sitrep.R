#' Check ggseg.extra setup status
#'
#' Performs diagnostic checks to verify that system dependencies
#' and environment variables required by ggseg.extra are properly
#' configured.
#'
#' @param detail Character. Level of detail to display:
#'   - `"simple"` (default): Quick pass/fail overview
#'   - `"full"`: Detailed diagnostics including `freesurfer::fs_sitrep()`
#'     when available
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
  results$options <- check_pipeline_options(detail)

  cli::cli_text("")
  summarize_sitrep(results, detail)

  invisible(results)
}


check_freesurfer <- function(detail = "simple") {
  if (!rlang::is_installed("freesurfer")) {
    cli::cli_alert_danger("freesurfer R package not installed")
    return(list(available = FALSE))
  }
  has_fs <- freesurfer::have_fs()

  if (detail == "full") {
    fs_sitrep_safe()
  } else {
    if (has_fs) {
      cli::cli_alert_success("FreeSurfer")
    } else {
      cli::cli_alert_danger("FreeSurfer not configured")
    }
  }

  list(available = has_fs)
}


# `fs_sitrep()` was added in freesurfer > 1.8.1 (CRAN). Call it via the
# namespace only if the binding exists so older installs don't error.
fs_sitrep_safe <- function() {
  ns <- asNamespace("freesurfer")
  if (exists("fs_sitrep", envir = ns, inherits = FALSE)) {
    get("fs_sitrep", envir = ns)()
  } else {
    cli::cli_alert_info(
      "Detailed {.pkg freesurfer} diagnostics require a newer version of the package."
    )
  }
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


summarize_sitrep <- function(results, detail = "simple") {
  has_fs <- isTRUE(results$freesurfer$available)
  has_magick <- isTRUE(results$system$imagemagick)
  has_chrome <- isTRUE(results$system$chrome)
  has_fsavg <- isTRUE(results$fsaverage$fsaverage5)

  all_ok <- has_fs && has_magick && has_chrome && has_fsavg

  if (all_ok) {
    cli::cli_alert_success("Ready for atlas creation")
  } else {
    cli::cli_alert_danger("Missing requirements for atlas creation")
    if (detail == "simple") {
      cli::cli_bullets(c(
        "i" = "Run {.code setup_sitrep(\"full\")} for details"
      ))
    }
  }
}
