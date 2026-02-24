# White matter tract atlas creation ----

#' Create brain atlas from white matter tracts
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Turn tractography streamlines into a brain atlas where each tract is
#' rendered as a 3D tube. The function computes a centerline from the
#' streamlines and generates a tube mesh around it.
#'
#' You can provide tract data in several formats: TRK files from TrackVis,
#' TCK files from MRtrix, or coordinate matrices directly in R. The function
#' reads the streamlines, extracts a representative centerline (by averaging
#' or selecting the medoid), and builds a tube mesh for 3D rendering.
#'
#' For tracts with many streamlines, set `tube_radius = "density"` to make
#' the tube thicker where more streamlines pass through.
#'
#' @param input_tracts Paths to tractography files (`.trk` or `.tck`), or a
#'   named list of coordinate matrices where each matrix has N rows and 3
#'   columns (x, y, z).
#' @param input_aseg Path to a segmentation volume (`.mgz`, `.nii`) used to
#'   draw cortex outlines in 2D views. Required for steps 2+.
#' @template atlas_name
#' @param input_lut Path to a color lookup table (LUT) file, or a data.frame
#'   with columns `region` and colour columns (R, G, B or hex).
#'   Use this to provide tract names and colours. If NULL, names are derived
#'   from filenames or list names, and the atlas will have no palette.
#' @param tube_radius Controls the tube thickness. Either a single numeric
#'   value for uniform radius, or `"density"` to scale radius by how many
#'   streamlines pass through each point.
#' @param tube_segments Number of segments around the tube circumference.
#'   Higher values make smoother tubes but larger meshes. Default 8 is a
#'   good balance.
#' @param n_points Number of points to resample the centerline to. All tracts
#'   are resampled to this length for consistent tube generation.
#' @param centerline_method How to extract the centerline from multiple
#'   streamlines: `"mean"` averages coordinates point-by-point, `"medoid"`
#'   selects the single most representative streamline.
#' @param views A data.frame specifying projection views. If NULL, uses
#'   [default_tract_views()].
#' @template output_dir
#' @template verbose
#' @template smoothness
#' @template tolerance
#' @template cleanup
#' @template skip_existing
#' @template dilate
#' @template vertex_size_limits
#' @param steps Which pipeline steps to run. Default NULL runs all steps.
#'   Steps are:
#'   \itemize{
#'     \item 1: Read tractography and create tube meshes
#'     \item 2: Create projection snapshots
#'     \item 3: Process images
#'     \item 4: Extract contours
#'     \item 5: Smooth contours
#'     \item 6: Reduce vertices
#'     \item 7: Build atlas
#'   }
#'   Use `steps = 1` for 3D-only atlas. Use `steps = 5:7` to iterate on
#'   smoothing and vertex reduction.
#'
#' @return A `ggseg_atlas` object with type `"tract"`, containing region
#'   metadata, tube meshes for 3D rendering, colours, and optionally sf
#'   geometry for 2D projection plots.
#' @export
#' @importFrom dplyr tibble bind_rows distinct
#' @importFrom furrr future_map2 furrr_options
#' @importFrom grDevices rgb
#' @importFrom progressr progressor
#' @importFrom tools file_path_sans_ext file_ext
#'
#' @examples
#' \dontrun{
#' # From TRK files (names derived from filenames)
#' atlas <- create_tract_from_tractography(
#'   input_tracts = c("cst_left.trk", "cst_right.trk")
#' )
#'
#' # With custom names and colours via LUT
#' atlas <- create_tract_from_tractography(
#'   input_tracts = c("cst_left.trk", "cst_right.trk"),
#'   input_lut = "tract_colors.txt"
#' )
#'
#' # View with ggseg3d
#' ggseg3d(atlas = atlas)
#' }
create_tract_from_tractography <- function(
  input_tracts,
  input_aseg = NULL,
  atlas_name = NULL,
  input_lut = NULL,
  tube_radius = 5,
  tube_segments = 8,
  n_points = 50,
  centerline_method = c("mean", "medoid"),
  views = NULL,
  output_dir = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  tolerance = NULL,
  smoothness = NULL,
  cleanup = NULL,
  skip_existing = NULL,
  dilate = NULL,
  vertex_size_limits = NULL,
  steps = NULL
) {
  start_time <- Sys.time()

  config <- validate_tract_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    steps,
    centerline_method,
    tube_radius,
    tube_segments,
    n_points
  )

  if (is.null(atlas_name)) {
    atlas_name <- basename(config$output_dir)
  }

  dirs <- setup_atlas_dirs(config$output_dir, atlas_name, type = "tract")
  lut_result <- parse_lut_colours(input_lut)
  tract_log_header(config, input_tracts, input_aseg)

  step1 <- tract_resolve_step1(
    config,
    dirs,
    input_tracts,
    lut_result$region_names,
    lut_result$colours
  )

  tract_final <- function(atlas) {
    finalize_atlas(
      atlas, config, dirs, start_time,
      type_label = "Tract", unit = "tracts", early_step = 1L
    )
  }

  if (max(config$steps) == 1L) {
    atlas <- tract_assemble_3d(step1)
    return(tract_final(atlas))
  }

  tract_check_aseg(input_aseg, config$steps)

  snaps <- tract_resolve_snapshots(
    config,
    dirs,
    step1,
    input_aseg,
    views
  )

  run_image_steps(
    config, dirs,
    step_map = list(process = 3L, extract = 4L, smooth = 5L, reduce = 6L),
    total_steps = 7L,
    dilate = dilate,
    vertex_size_limits = vertex_size_limits
  )

  if (7L %in% config$steps) {
    atlas <- tract_assemble_full(step1, dirs, snaps$views, snaps$cortex_slices)
    return(tract_final(atlas))
  }

  tract_final(NULL)
}


# Tract pipeline helpers ----

#' @noRd
validate_tract_config <- function(
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  tolerance,
  smoothness,
  steps,
  centerline_method,
  tube_radius,
  tube_segments,
  n_points
) {
  config <- resolve_common_config(
    output_dir, verbose, cleanup, skip_existing,
    tolerance, smoothness, steps, max_step = 7L
  )
  config$output_dir <- normalizePath(config$output_dir, mustWork = FALSE)

  config$centerline_method <- match.arg(
    centerline_method, c("mean", "medoid")
  )
  config$tube_radius <- tube_radius
  config$tube_segments <- tube_segments
  config$n_points <- n_points
  config$density_radius_range <- c(0.2, 1.0)
  config$tract_radius <- 3
  config
}


#' @noRd
tract_log_header <- function(config, input_tracts, input_aseg) {
  if (!config$verbose) {
    return(invisible(NULL))
  }
  cli::cli_h1("Creating tractography atlas")
  cli::cli_alert_info("Tract files: {.path {input_tracts}}")
  if (!is.null(input_aseg)) {
    cli::cli_alert_info("Anatomical reference: {.path {input_aseg}}")
  }
}


#' @noRd
tract_resolve_step1 <- function(
  config,
  dirs,
  input_tracts,
  tract_names,
  colours
) {
  files <- file.path(dirs$base, "step1_data.rds")
  cached <- load_or_run_step(
    1L,
    config$steps,
    files,
    config$skip_existing,
    "Step 1 (Read tracts & create tube meshes)"
  )

  if (!cached$run) {
    if (config$verbose) {
      cli::cli_alert_success("1/7 Loaded existing tract data")
    }
    return(cached$data[["step1_data.rds"]])
  }

  input_result <- tract_read_input(input_tracts, tract_names)
  streamlines_data <- input_result$streamlines_data
  tract_names <- sanitize_label(input_result$tract_names)
  names(streamlines_data) <- tract_names

  coords_are_voxels <- detect_tract_coord_space(
    streamlines_data,
    config$verbose
  )

  if (is.null(colours)) {
    colours <- rep(NA_character_, length(streamlines_data))
  }
  names(colours) <- tract_names

  if (config$verbose) {
    cli::cli_progress_step(
      "1/7 Creating tube meshes for {length(streamlines_data)} tracts"
    )
  }

  meshes_list <- tract_create_meshes(
    streamlines_data,
    tract_names,
    config$centerline_method,
    config$n_points,
    config$tube_radius,
    config$tube_segments,
    config$density_radius_range
  )

  if (config$verbose) {
    cli::cli_progress_done()
  }

  built <- tract_build_core(meshes_list, colours, tract_names)

  step1_data <- list(
    streamlines_data = streamlines_data,
    centerlines_df = built$centerlines_df,
    core = built$core,
    palette = built$palette,
    atlas_name = built$atlas_name,
    tube_radius = config$tube_radius,
    tube_segments = config$tube_segments,
    coords_are_voxels = coords_are_voxels
  )

  saveRDS(step1_data, file.path(dirs$base, "step1_data.rds"))
  step1_data
}


#' @noRd
detect_tract_coord_space <- function(streamlines_data, verbose) {
  all_streamlines <- unlist(streamlines_data, recursive = FALSE)
  coords_are_voxels <- detect_coords_are_voxels(all_streamlines)
  if (verbose) {
    space <- if (coords_are_voxels) "voxel" else "RAS" # nolint: object_usage_linter
    cli::cli_alert_info("Auto-detected coordinate space: {.val {space}}")
  }
  coords_are_voxels
}


#' @noRd
tract_check_aseg <- function(input_aseg, steps) {
  if (any(2L:7L %in% steps) && is.null(input_aseg)) {
    cli::cli_abort(c(
      "{.arg input_aseg} is required for steps 2-7",
      "i" = "Provide a segmentation volume (e.g., aparc+aseg.nii.gz)"
    ))
  }
}


#' @noRd
tract_resolve_snapshots <- function(config, dirs, step1, input_aseg, views) {
  files <- c(
    file.path(dirs$base, "views.rds"),
    file.path(dirs$base, "cortex_slices.rds")
  )
  cached <- load_or_run_step(
    2L,
    config$steps,
    files,
    config$skip_existing,
    "Step 2 (Create projection snapshots)"
  )

  if (!cached$run) {
    if (any(config$steps > 2L)) {
      if (config$verbose) {
        cli::cli_alert_success("2/7 Loaded existing snapshots")
      }
      return(list(
        views = cached$data[["views.rds"]],
        cortex_slices = cached$data[["cortex_slices.rds"]]
      ))
    }
    return(list(views = NULL, cortex_slices = NULL))
  }

  if (config$verbose) {
    cli::cli_progress_step("2/7 Creating projection snapshots")
  }

  coords_are_voxels <- step1$coords_are_voxels
  if (is.null(coords_are_voxels)) {
    coords_are_voxels <- detect_tract_coord_space(
      step1$streamlines_data,
      config$verbose
    )
  }

  result <- tract_create_snapshots(
    step1$streamlines_data,
    step1$centerlines_df,
    input_aseg,
    views,
    dirs,
    coords_are_voxels,
    config$skip_existing,
    config$tract_radius,
    config$verbose
  )

  saveRDS(result$views, file.path(dirs$base, "views.rds"))
  saveRDS(result$cortex_slices, file.path(dirs$base, "cortex_slices.rds"))
  if (config$verbose) {
    cli::cli_progress_done()
  }
  result
}


#' @noRd
tract_assemble_3d <- function(step1) {
  ggseg_atlas(
    atlas = step1$atlas_name,
    type = "tract",
    palette = step1$palette,
    core = step1$core,
    data = ggseg_data_tract(
      centerlines = step1$centerlines_df
    )
  )
}


#' @noRd
tract_assemble_full <- function(step1, dirs, views, cortex_slices) {
  contours_file <- file.path(dirs$base, "contours_reduced.rda")
  if (!file.exists(contours_file)) {
    cli::cli_abort(c(
      "Step 7 requires contours_reduced.rda which doesn't exist",
      "i" = "Run steps 3-6 first to generate contour data"
    ))
  }

  sf_data <- build_contour_sf(
    contours_file,
    views,
    cortex_slices
  )

  atlas <- ggseg_atlas(
    atlas = step1$atlas_name,
    type = "tract",
    palette = step1$palette,
    core = step1$core,
    data = ggseg_data_tract(
      sf = sf_data,
      centerlines = step1$centerlines_df
    )
  )

  warn_if_large_atlas(atlas)
  preview_atlas(atlas)
  atlas
}
