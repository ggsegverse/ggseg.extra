# Subcortical atlas creation ----

#' Create brain atlas from subcortical segmentation
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Turn a subcortical segmentation volume (like `aseg.mgz`) into a brain
#' atlas with 3D meshes for each structure. The function extracts each labelled
#' region from the volume, creates a surface mesh, and smooths it.
#'
#' For 2D plotting, the function can also generate slice views by taking
#' snapshots at specified coordinates and extracting contours.
#'
#' Requires FreeSurfer for mesh generation.
#'
#' @param input_volume Path to the segmentation volume. Supports `.mgz`, `.nii`,
#'   and `.nii.gz` formats. Typically this is `aseg.mgz` or a custom
#'   segmentation in the same space.
#' @param input_lut Path to a FreeSurfer-style colour lookup table that maps
#'   label IDs to region names and colours (e.g., `FreeSurferColorLUT.txt`
#'   or `ASegStatsLUT.txt`), or a data.frame with columns `region` and colour
#'   columns (R, G, B or hex). If NULL, region names will be generic
#'   (e.g., "region_0010") and the atlas will have no palette.
#' @template atlas_name
#' @param views A data.frame specifying projection views with columns `name`,
#'   `type` ("axial", "coronal", "sagittal"), `start` (first slice), `end`
#'   (last slice). Default projects entire volume from each direction.
#'   Unlike slices, projections show ALL structures in their spatial
#'   relationships - like an X-ray view.
#' @template output_dir
#' @template vertex_size_limits
#' @template dilate
#' @template tolerance
#' @template smoothness
#' @template verbose
#' @template cleanup
#' @template skip_existing
#' @template decimate
#' @param steps Which pipeline steps to run. Default NULL runs all steps.
#'   Steps are:
#'   \itemize{
#'     \item 1: Extract labels from volume and get colour table
#'     \item 2: Create meshes for each structure
#'     \item 3: Build atlas data (3D only if stopping here)
#'     \item 4: Create projection snapshots
#'     \item 5: Process images
#'     \item 6: Extract contours
#'     \item 7: Smooth contours
#'     \item 8: Reduce vertices
#'     \item 9: Build final atlas with 2D geometry
#'   }
#'   Use `steps = 1:3` for 3D-only atlas. Use `steps = 7:8` to iterate on
#'   smoothing and reduction parameters.
#'
#' @return A `ggseg_atlas` object with region metadata (core), 3D meshes,
#'   a colour palette, and optionally sf geometry for 2D slice plots.
#' @export
#' @importFrom dplyr tibble bind_rows left_join filter distinct
#' @importFrom freesurfer have_fs fs_dir fs_subj_dir
#' @importFrom furrr future_pmap furrr_options
#' @importFrom progressr progressor
#' @importFrom tools file_path_sans_ext
#'
#' @examples
#' \dontrun{
#' # Create 3D-only subcortical atlas from aseg
#' atlas <- create_subcortical_from_volume(
#'   input_volume = "path/to/aseg.mgz",
#'   input_lut = "path/to/FreeSurferColorLUT.txt",
#'   steps = 1:3
#' )
#'
#' # View with ggseg3d
#' ggseg3d(atlas = atlas, hemisphere = "subcort")
#'
#' # Full atlas with 2D slices
#' atlas <- create_subcortical_from_volume(
#'   input_volume = "path/to/aseg.mgz",
#'   input_lut = "path/to/ASegStatsLUT.txt"
#' )
#'
#' # Post-process to remove/modify regions (functions from ggseg.formats)
#' atlas <- atlas |>
#'   atlas_region_remove("White-Matter") |>
#'   atlas_region_contextual("Cortex")
#' }
create_subcortical_from_volume <- function(
  input_volume,
  input_lut = NULL,
  atlas_name = NULL,
  views = NULL,
  output_dir = NULL,
  vertex_size_limits = NULL,
  dilate = NULL,
  tolerance = NULL,
  smoothness = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  cleanup = NULL,
  skip_existing = NULL,
  decimate = 0.5,
  steps = NULL
) {
  start_time <- Sys.time()

  config <- validate_subcort_config(
    input_volume,
    input_lut,
    atlas_name,
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    decimate,
    steps,
    tolerance,
    smoothness
  )

  dirs <- setup_atlas_dirs(
    config$output_dir,
    config$atlas_name,
    type = "subcortical"
  )
  subcort_log_header(config)

  labels <- subcort_resolve_labels(config, dirs)
  meshes_list <- subcort_resolve_meshes(config, dirs, labels$colortable)
  components <- subcort_resolve_components(
    config,
    dirs,
    labels$colortable,
    meshes_list
  )

  subcort_final <- function(atlas) {
    finalize_atlas(
      atlas, config, dirs, start_time,
      type_label = "Subcortical", unit = "structures", early_step = 3L
    )
  }

  if (max(config$steps) == 3L) {
    atlas <- subcort_assemble_3d(config$atlas_name, components)
    return(subcort_final(atlas))
  }

  snaps <- subcort_resolve_snapshots(config, dirs, labels$colortable, views)
  run_image_steps(
    config, dirs,
    step_map = list(process = 5L, extract = 6L, smooth = 7L, reduce = 8L),
    total_steps = 9L,
    dilate = dilate,
    vertex_size_limits = vertex_size_limits
  )

  if (9L %in% config$steps) {
    atlas <- subcort_assemble_full(
      config$atlas_name,
      components,
      dirs,
      snaps$views,
      snaps$cortex_slices
    )
    return(subcort_final(atlas))
  }

  subcort_final(NULL)
}


# Subcortical pipeline helpers ----

#' @noRd
validate_subcort_config <- function(
  input_volume,
  input_lut,
  atlas_name,
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  decimate,
  steps,
  tolerance,
  smoothness
) {
  config <- resolve_common_config(
    output_dir, verbose, cleanup, skip_existing,
    tolerance, smoothness, steps, max_step = 9L
  )

  if (!is.null(decimate) && (
    !is.numeric(decimate) ||
      length(decimate) != 1 ||
      decimate <= 0 ||
      decimate >= 1
  )) {
    cli::cli_abort(c(
      "{.arg decimate} must be a single number between 0 and 1 (exclusive)",
      "x" = "Got {.val {decimate}}",
      "i" = "Use {.code NULL} to skip mesh decimation"
    ))
  }

  check_fs(abort = TRUE)

  if (!file.exists(input_volume)) {
    cli::cli_abort("Volume file not found: {.path {input_volume}}")
  }
  if (!is.null(input_lut) && !file.exists(input_lut)) {
    cli::cli_abort("Color lookup table not found: {.path {input_lut}}")
  }

  config$output_dir <- normalizePath(config$output_dir, mustWork = FALSE)

  if (is.null(atlas_name)) {
    atlas_name <- file_path_sans_ext(basename(input_volume))
  }

  config$input_volume <- input_volume
  config$input_lut <- input_lut
  config$atlas_name <- atlas_name
  config$decimate <- decimate
  config
}


#' @noRd
subcort_log_header <- function(config) {
  if (!config$verbose) {
    return(invisible(NULL))
  }
  cli::cli_h1("Creating subcortical atlas {.val {config$atlas_name}}")
  cli::cli_alert_info("Volume: {.path {config$input_volume}}")
  if (!is.null(config$input_lut) && is.character(config$input_lut)) {
    cli::cli_alert_info("Color LUT: {.path {config$input_lut}}")
  }
  cli::cli_alert_info(
    "Setting output directory to {.path {config$output_dir}}"
  )
}


#' @noRd
subcort_resolve_labels <- function(config, dirs) {
  files <- c(
    file.path(dirs$base, "colortable.rds"),
    file.path(dirs$base, "vol_labels.rds")
  )
  cached <- load_or_run_step(
    1L,
    config$steps,
    files,
    config$skip_existing,
    "Step 1 (Extract labels)"
  )

  if (!cached$run) {
    if (config$verbose) {
      cli::cli_alert_success("1/9 Loaded existing labels")
    }
    return(list(
      colortable = cached$data[["colortable.rds"]],
      vol_labels = cached$data[["vol_labels.rds"]]
    ))
  }

  colortable <- if (is.null(config$input_lut)) {
    cli::cli_warn(c(
      "No color lookup table provided",
      "i" = "Region names will be generic (e.g., 'region_0010')",
      "i" = "Atlas will have no palette"
    ))
    generate_colortable_from_volume(config$input_volume)
  } else {
    get_ctab(config$input_lut)
  }

  if (config$verbose) {
    cli::cli_progress_step("1/9 Extracting labels from volume")
  }

  vol <- read_volume(config$input_volume)
  vol_labels <- unique(c(vol))
  vol_labels <- vol_labels[vol_labels != 0]
  colortable <- colortable[colortable$idx %in% vol_labels, ]

  colortable$label <- sanitize_label(colortable$label)

  if (nrow(colortable) == 0) {
    cli::cli_abort("No matching labels found in volume and color table")
  }

  if (config$verbose) {
    cli::cli_alert_success("Found {nrow(colortable)} subcortical structures")
  }

  saveRDS(colortable, file.path(dirs$base, "colortable.rds"))
  saveRDS(vol_labels, file.path(dirs$base, "vol_labels.rds"))
  if (config$verbose) {
    cli::cli_progress_done()
  }

  list(colortable = colortable, vol_labels = vol_labels)
}


#' @noRd
subcort_resolve_meshes <- function(config, dirs, colortable) {
  files <- file.path(dirs$base, "meshes_list.rds")
  cached <- load_or_run_step(
    2L,
    config$steps,
    files,
    config$skip_existing,
    "Step 2 (Create meshes)"
  )

  if (!cached$run) {
    if (any(config$steps > 2L)) {
      if (config$verbose) {
        cli::cli_alert_success("2/9 Loaded existing meshes")
      }
      return(cached$data[["meshes_list.rds"]])
    }
    return(NULL)
  }

  if (config$verbose) {
    cli::cli_progress_step("2/9 Creating meshes for each structure")
  }

  meshes_list <- subcort_create_meshes(
    config$input_volume,
    colortable,
    dirs,
    config$skip_existing,
    config$verbose,
    decimate = config$decimate
  )

  if (config$verbose) {
    cli::cli_progress_done()
  }
  saveRDS(meshes_list, file.path(dirs$base, "meshes_list.rds"))
  meshes_list
}


#' @noRd
subcort_resolve_components <- function(config, dirs, colortable, meshes_list) {
  files <- file.path(dirs$base, "components.rds")
  cached <- load_or_run_step(
    3L,
    config$steps,
    files,
    config$skip_existing,
    "Step 3 (Build atlas data)"
  )

  if (!cached$run) {
    if (any(config$steps > 3L)) {
      if (config$verbose) {
        cli::cli_alert_success("3/9 Loaded existing components")
      }
      return(cached$data[["components.rds"]])
    }
    return(NULL)
  }

  if (config$verbose) {
    cli::cli_progress_step("3/9 Building atlas data")
  }

  components <- subcort_build_components(colortable, meshes_list)
  saveRDS(components, file.path(dirs$base, "components.rds"))
  if (config$verbose) {
    cli::cli_progress_done()
  }
  components
}


#' @noRd
subcort_resolve_snapshots <- function(config, dirs, colortable, views) {
  files <- c(
    file.path(dirs$base, "views.rds"),
    file.path(dirs$base, "cortex_slices.rds")
  )
  cached <- load_or_run_step(
    4L,
    config$steps,
    files,
    config$skip_existing,
    "Step 4 (Create snapshots)"
  )

  if (!cached$run) {
    if (any(config$steps > 4L)) {
      if (config$verbose) {
        cli::cli_alert_success("4/9 Loaded existing views")
      }
      return(list(
        views = cached$data[["views.rds"]],
        cortex_slices = cached$data[["cortex_slices.rds"]]
      ))
    }
    return(list(views = NULL, cortex_slices = NULL))
  }

  if (config$verbose) {
    cli::cli_progress_step("4/9 Creating projection snapshots")
  }

  result <- subcort_create_snapshots(
    config$input_volume,
    colortable,
    views,
    dirs,
    config$skip_existing
  )

  saveRDS(result$views, file.path(dirs$base, "views.rds"))
  saveRDS(result$cortex_slices, file.path(dirs$base, "cortex_slices.rds"))
  if (config$verbose) {
    cli::cli_progress_done()
  }
  result
}


#' @noRd
subcort_assemble_3d <- function(atlas_name, components) {
  ggseg_atlas(
    atlas = atlas_name,
    type = "subcortical",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_subcortical(sf = NULL, meshes = components$meshes_df)
  )
}


#' @noRd
subcort_assemble_full <- function(
  atlas_name,
  components,
  dirs,
  views,
  cortex_slices
) {
  contours_file <- file.path(dirs$base, "contours_reduced.rda")
  if (!file.exists(contours_file)) {
    cli::cli_abort(c(
      "Step 9 requires contours_reduced.rda which doesn't exist",
      "i" = "Run steps 5-8 first to generate contour data"
    ))
  }

  sf_data <- build_contour_sf(contours_file, views, cortex_slices)

  sf_labels <- if (is.data.frame(sf_data)) {
    unique(sf_data$label[!is.na(sf_data$label)])
  } else {
    character(0)
  }
  core_labels <- components$core$label[!is.na(components$core$label)]
  missing <- setdiff(core_labels, sf_labels)

  if (length(missing) > 0) {
    cli::cli_warn(c(
      "Dropping {length(missing)} label{?s} with no valid contour data.",
      "i" = "Dropped: {.val {missing}}."
    ))
    keep <- !components$core$label %in% missing
    components$core <- components$core[keep, ]
    components$palette <- components$palette[
      !names(components$palette) %in% missing
    ]
    components$meshes_df <- components$meshes_df[
      !components$meshes_df$label %in% missing,
    ]
  }

  if (nrow(components$core) == 0) {
    cli::cli_abort(
      "No labels with valid contour data remain. Cannot build atlas."
    )
  }

  atlas <- ggseg_atlas(
    atlas = atlas_name,
    type = "subcortical",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_subcortical(sf = sf_data, meshes = components$meshes_df)
  )

  warn_if_large_atlas(atlas)
  preview_atlas(atlas)
  atlas
}
