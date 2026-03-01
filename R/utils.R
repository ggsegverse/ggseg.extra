# General utilities ----

fsaverage5_nverts <- 10242L

#' @importFrom future plan sequential multisession
#' @noRd
with_safe_plan <- function(expr) {
  if (inherits(plan(), "multicore")) {
    old_plan <- plan(multisession)
    on.exit(plan(old_plan), add = TRUE)
    cli::cli_alert_info(paste0(
      "Switching from multicore to multisession:",
      " fork is incompatible with chromote."
    ))
  }
  force(expr)
}

#' @noRd
safe_future_pmap <- function(
  .l,
  .f,
  ...,
  .options = furrr_options(seed = NULL)
) {
  with_safe_plan(future_pmap(.l, .f, ..., .options = .options))
}

#' @noRd
safe_future_map <- function(
  .x,
  .f,
  ...,
  .options = furrr_options(seed = NULL)
) {
  with_safe_plan(future_map(.x, .f, ..., .options = .options))
}

#' @noRd
safe_future_map2 <- function(
  .x,
  .y,
  .f,
  ...,
  .options = furrr_options(seed = NULL)
) {
  with_safe_plan(future_map2(.x, .y, .f, ..., .options = .options))
}

mkdir <- function(path, ...) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE, ...)
}

#' @noRd
close_chromote_workers <- function() {
  if (!requireNamespace("chromote", quietly = TRUE)) {
    return(invisible(NULL))
  }
  try(chromote::default_chromote_object()$close(), silent = TRUE)
  invisible(NULL)
}


#' @noRd
load_rda <- function(path, envir = parent.frame()) {
  if (!file.exists(path)) {
    cli::cli_abort("Required file not found: {.file {path}}")
  }
  load(path, envir = envir)
}


# Interactive preview ----

is_interactive <- function() rlang::is_interactive()
prompt_user <- function(msg) readline(msg)

#' Preview atlas plots interactively
#'
#' Shows ggseg (2D) and ggseg3d (3D) plots of the atlas one at a time,
#' waiting for user input between each. Only runs in interactive sessions.
#'
#' @param atlas A ggseg_atlas object
#' @return Invisible atlas
#' @noRd
preview_atlas <- function(atlas) {
  if (!is_interactive()) {
    return(invisible(atlas))
  }

  has_sf <- !is.null(atlas$data$sf)
  has_3d <- !is.null(atlas$data$vertices) ||
    !is.null(atlas$data$meshes)

  if (!has_sf && !has_3d) {
    cli::cli_alert_danger(
      "Atlas malformed and doesn't contain compatible data."
    )
    return(invisible(atlas))
  }

  if (has_3d) {
    tryCatch(
      {
        if (atlas$type == "cortical") {
          for (hemi in c("left", "right")) {
            p3d <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = hemi) |>
              ggseg3d::pan_camera(paste(hemi, "lateral")) |>
              ggseg3d::set_legend(show = FALSE)
            print(p3d)
            prompt_user(sprintf("3D %s hemisphere. Press Enter for next", hemi))
          }
        } else {
          p3d <- ggseg3d::ggseg3d(atlas = atlas) |>
            ggseg3d::set_legend(show = FALSE)
          print(p3d)
          prompt_user("3D preview. Press Enter to continue")
        }
      },
      error = function(e) NULL
    )
  }

  if (has_sf) {
    gp <- tryCatch(
      {
        p <- ggplot2::ggplot() +
          ggseg::geom_brain(
            atlas = atlas,
            position = ggseg::position_brain(nrow = 4),
            show.legend = FALSE,
            alpha = .7,
            ggplot2::aes(fill = label)
          )
        if (!is.null(atlas$palette)) {
          p <- p +
            ggplot2::scale_fill_manual(values = atlas$palette)
        }
        p
      },
      error = function(e) {
        plot(atlas$data$sf)
        NULL
      }
    )
    if (!is.null(gp)) {
      print(gp)
      prompt_user("2D preview. Press Enter to continue")
    }
  }
  invisible(atlas)
}


# Verbosity control ----

#' Coerce a value to a verbosity level
#'
#' Converts logical, numeric, or character input to an integer verbosity
#' level: `0L` (silent), `1L` (standard), or `2L` (debug).
#'
#' @param x Value to coerce. Logical `FALSE` becomes `0L`, `TRUE` becomes
#'   `1L`. Numeric values are clamped to 0--2. Invalid input defaults to `1L`.
#' @return Integer `0L`, `1L`, or `2L`
#' @export
#' @examples
#' as_verbosity(FALSE)
#' as_verbosity(TRUE)
#' as_verbosity(2)
as_verbosity <- function(x) {
  if (is.logical(x) && !is.na(x)) return(as.integer(x))
  x <- suppressWarnings(as.integer(x))
  if (is.na(x) || x < 0L) return(1L)
  min(x, 2L)
}

#' Get verbose setting
#'
#' Returns the verbosity level from option, environment variable, or default.
#' Checks in order: `ggseg.extra.verbose` option, `GGSEG_EXTRA_VERBOSE` env var,
#' then defaults to `1L`.
#'
#' Verbosity levels:
#' - `0` — Silent: no console output
#' - `1` — Standard (default): pipeline progress and step summaries
#' - `2` — Debug: includes FreeSurfer command output
#'
#' Logical values are accepted for backward compatibility
#' (`FALSE` = 0, `TRUE` = 1).
#'
#' @return Integer `0L`, `1L`, or `2L`
#' @export
#' @examples
#' get_verbose()
#' options(ggseg.extra.verbose = 0)
#' get_verbose()
#' options(ggseg.extra.verbose = NULL)
get_verbose <- function() {
  val <- getOption("ggseg.extra.verbose")
  if (!is.null(val)) return(as_verbosity(val))
  env <- Sys.getenv("GGSEG_EXTRA_VERBOSE", unset = NA)
  if (!is.na(env)) return(as_verbosity(env))
  1L
}

#' Get verbosity level
#'
#' @param verbose Optional explicit value. If NULL, reads from
#'   option/env via [get_verbose()]. Accepts logical or integer (0/1/2).
#' @return Integer `0L`, `1L`, or `2L`
#' @export
#' @examples
#' is_verbose()
#' is_verbose(FALSE)
#' is_verbose(2)
is_verbose <- function(verbose = NULL) {
  if (is.null(verbose)) return(get_verbose())
  as_verbosity(verbose)
}

#' Log elapsed pipeline time
#'
#' @param start_time POSIXct start time
#' @return Invisible NULL, called for side effect
#' @noRd
log_elapsed <- function(start_time) {
  # fmt: skip
  elapsed <- round(# nolint: object_usage_linter.
    difftime(Sys.time(), start_time, units = "mins"),
    1
  )
  cli::cli_alert_info("Pipeline completed in {elapsed} minutes")
}


# Step data handling ----

#' Load or run a pipeline step
#'
#' Handles the logic for loading cached data or running a step:
#' - If skip_existing and files exist, load and return data
#' - If step is in steps list, return NULL to signal step should run
#' - If step not in steps and files don't exist, throw error
#'
#' @param step_num Integer step number
#' @param steps Integer vector of steps to run
#' @param files Character vector of file paths that must exist
#' @param skip_existing Logical, try to load existing files first
#' @param step_name Human-readable step name for error messages
#'
#' @return List with loaded data if files exist and should be skipped,
#'   NULL if step should run, or throws error if files missing
#' @noRd
load_or_run_step <- function(
  step_num,
  steps,
  files,
  skip_existing,
  step_name = paste("Step", step_num)
) {
  files_exist <- all(file.exists(files))
  step_requested <- step_num %in% steps

  if (files_exist && skip_existing) {
    data <- lapply(files, readRDS)
    names(data) <- basename(files)
    return(list(run = FALSE, data = data))
  }

  if (step_requested) {
    return(list(run = TRUE, data = NULL))
  }

  if (!files_exist) {
    missing <- files[!file.exists(files)] # nolint: object_usage_linter
    cli::cli_abort(c(
      "{step_name} was not run but required files are missing",
      "i" = "Missing: {.path {missing}}",
      "i" = paste(
        "Include step {step_num} in the steps",
        "argument to generate these files"
      )
    ))
  }

  data <- lapply(files, readRDS)
  names(data) <- basename(files)
  list(run = FALSE, data = data)
}


# Pipeline parameter defaults ----

#' Get cleanup setting
#'
#' Returns the cleanup setting from options or environment variable.
#' Controls whether intermediate files are removed after pipeline completion.
#'
#' @param cleanup Optional explicit value. If NULL, reads from options/env.
#' @return Logical TRUE to remove intermediate files
#' @noRd
get_cleanup <- function(cleanup = NULL) {
  get_bool_option(cleanup, "ggseg.extra.cleanup", "GGSEG_EXTRA_CLEANUP", TRUE)
}

#' Get skip_existing setting
#'
#' Returns the skip_existing setting from options or environment variable.
#' Controls whether to reuse existing intermediate files.
#'
#' @param skip_existing Optional explicit value.
#'   If NULL, reads from options/env.
#' @return Logical TRUE to skip existing files
#' @noRd
get_skip_existing <- function(skip_existing = NULL) {
  get_bool_option(
    skip_existing,
    "ggseg.extra.skip_existing",
    "GGSEG_EXTRA_SKIP_EXISTING",
    TRUE
  )
}

#' Get tolerance setting
#'
#' Returns the tolerance setting from options or environment variable.
#' Controls vertex reduction during contour simplification.
#'
#' @param tolerance Optional explicit value. If NULL, reads from options/env.
#' @return Numeric tolerance value (0 = no simplification)
#' @noRd
get_tolerance <- function(tolerance = NULL) {
  get_numeric_option(
    tolerance,
    "ggseg.extra.tolerance",
    "GGSEG_EXTRA_TOLERANCE",
    1
  )
}

#' Get smoothness setting
#'
#' Returns the smoothness setting from options or environment variable.
#' Controls contour smoothing during geometry extraction.
#'
#' @param smoothness Optional explicit value. If NULL, reads from options/env.
#' @return Numeric smoothness value
#' @noRd
get_smoothness <- function(smoothness = NULL) {
  get_numeric_option(
    smoothness,
    "ggseg.extra.smoothness",
    "GGSEG_EXTRA_SMOOTHNESS",
    5
  )
}

#' Get snapshot dimension setting
#'
#' Returns the snapshot dimension (width and height in pixels) for brain
#' surface snapshots. Higher values capture more detail for dense parcellations.
#'
#' @param snapshot_dim Optional explicit value. If NULL, reads from options/env.
#' @return Numeric pixel dimension
#' @noRd
get_snapshot_dim <- function(snapshot_dim = NULL) {
  get_numeric_option(
    snapshot_dim,
    "ggseg.extra.snapshot_dim",
    "GGSEG_EXTRA_SNAPSHOT_DIM",
    800
  )
}

#' Helper to get boolean option with fallback
#' @noRd
get_bool_option <- function(explicit, option_name, env_name, default) {
  if (!is.null(explicit)) {
    return(as.logical(explicit))
  }

  opt <- getOption(option_name)
  if (!is.null(opt)) {
    return(as.logical(opt))
  }

  env <- Sys.getenv(env_name, unset = NA)
  if (!is.na(env)) {
    return(tolower(env) %in% c("true", "1", "yes"))
  }

  default
}

#' Helper to get numeric option with fallback
#' @noRd
get_numeric_option <- function(explicit, option_name, env_name, default) {
  if (!is.null(explicit)) {
    return(as.numeric(explicit))
  }

  opt <- getOption(option_name)
  if (!is.null(opt)) {
    return(as.numeric(opt))
  }

  env <- Sys.getenv(env_name, unset = NA)
  if (!is.na(env)) {
    val <- suppressWarnings(as.numeric(env))
    if (!is.na(val)) {
      return(val)
    }
  }

  default
}

#' Helper to get string option with fallback
#' @noRd
get_string_option <- function(explicit, option_name, env_name, default) {
  if (!is.null(explicit)) {
    return(as.character(explicit))
  }

  opt <- getOption(option_name)
  if (!is.null(opt)) {
    return(as.character(opt))
  }

  env <- Sys.getenv(env_name, unset = NA)
  if (!is.na(env) && nzchar(env)) {
    return(env)
  }

  default
}

#' Get output_dir setting
#'
#' Returns the output directory from options or environment variable.
#' Used as default output directory for atlas creation pipelines.
#'
#' @param output_dir Optional explicit value. If NULL, reads from options/env.
#' @return Character path to output directory
#' @noRd
get_output_dir <- function(output_dir = NULL) {
  get_string_option(
    output_dir,
    "ggseg.extra.output_dir",
    "GGSEG_EXTRA_OUTPUT_DIR",
    tempdir(check = TRUE)
  )
}


# Atlas validation ----

#' @noRd
warn_if_large_atlas <- function(atlas, max_vertices = 10000) {
  if (is.null(atlas$data$sf)) {
    return(invisible(NULL))
  }

  n_vertices <- sum(count_vertices(atlas$data$sf))

  if (n_vertices > max_vertices) {
    cli::cli_warn(c(
      paste(
        "Atlas has {.val {n_vertices}} vertices",
        "(threshold: {.val {max_vertices}})"
      ),
      "i" = "Large atlases may be slow to plot and increase package size",
      "i" = "Re-run with higher {.arg tolerance} to reduce vertices"
    ))
  }

  invisible(NULL)
}
