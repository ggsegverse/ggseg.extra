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
#' @param input_lut Path to a color lookup table (LUT) file, or a data.frame
#'   with a `region` column (or a FreeSurfer-style `label` column) plus
#'   colour columns (R, G, B or hex). Rows must be in the same order as
#'   `input_tracts`. Use this to provide tract names and colours. If NULL,
#'   names are derived from filenames or list names, and colours will be
#'   auto-generated.
#' @template atlas_name
#' @template output_dir
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
#' @param slabs A data.frame specifying projection slabs. If NULL, a default
#'   set of tract slabs is derived from the volume dimensions.
#' @template vertex_size_limits
#' @template dilate
#' @template tolerance
#' @template smoothness
#' @template cleanup
#' @template verbose
#' @template skip_existing
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
#' @template views_deprecated
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
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  tube_radius = 5,
  tube_segments = 8,
  n_points = 50,
  centerline_method = c("mean", "medoid"),
  slabs = NULL,
  vertex_size_limits = NULL,
  dilate = NULL,
  tolerance = NULL,
  smoothness = NULL,
  cleanup = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  skip_existing = NULL,
  steps = NULL,
  views = lifecycle::deprecated()
) {
  if (lifecycle::is_present(views)) {
    lifecycle::deprecate_warn(
      "1.9.9.9005",
      "create_tract_from_tractography(views = )",
      "create_tract_from_tractography(slabs = )"
    )
    slabs <- views
  }

  warn_deprecated_sf_smoothing(
    # nolint: object_usage_linter.
    tolerance = tolerance,
    smoothness = smoothness,
    fn = "create_tract_from_tractography"
  )

  start_time <- Sys.time()

  setup <- tract_setup_pipeline(
    input_tracts,
    input_aseg,
    input_lut,
    atlas_name,
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

  tract_run_pipeline(setup, start_time, slabs, dilate, vertex_size_limits)
}


#' Validate arguments, create the output directories and parse the LUT
#' @noRd
tract_setup_pipeline <- function(
  input_tracts,
  input_aseg,
  input_lut,
  atlas_name,
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

  config$input_tracts <- input_tracts
  config$input_aseg <- input_aseg
  list(config = config, dirs = dirs, lut = lut_result)
}


#' Run the tract pipeline steps and assemble the atlas
#' @noRd
tract_run_pipeline <- function(
  setup,
  start_time,
  slabs,
  dilate,
  vertex_size_limits
) {
  config <- setup$config
  dirs <- setup$dirs

  step1 <- tract_resolve_step1(
    config,
    dirs,
    config$input_tracts,
    setup$lut$region_names,
    setup$lut$colours
  )

  if (max(config$steps) == 1L) {
    atlas <- tract_assemble_3d(step1)
    return(tract_finalize(atlas, config, dirs, start_time))
  }

  tract_check_aseg(config$input_aseg, config$steps)

  snaps <- tract_resolve_snapshots(
    config,
    dirs,
    step1,
    config$input_aseg,
    slabs
  )

  tract_image_steps(config, dirs, dilate, vertex_size_limits)

  if (7L %in% config$steps) {
    atlas <- tract_assemble_full(step1, dirs, snaps$slabs, snaps$cortex_slices)
    return(tract_finalize(atlas, config, dirs, start_time))
  }

  tract_finalize(NULL, config, dirs, start_time)
}


#' @noRd
tract_finalize <- function(atlas, config, dirs, start_time) {
  finalize_atlas(
    atlas,
    config,
    dirs,
    start_time,
    type_label = "Tract",
    unit = "tracts",
    early_step = 1L
  )
}


#' @noRd
tract_image_steps <- function(config, dirs, dilate, vertex_size_limits) {
  run_image_steps(
    config,
    dirs,
    step_map = list(process = 3L, extract = 4L, smooth = 5L, reduce = 6L),
    total_steps = 7L,
    dilate = dilate,
    vertex_size_limits = vertex_size_limits
  )
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
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    steps,
    max_step = 7L
  )
  config$output_dir <- normalizePath(config$output_dir, mustWork = FALSE)

  config$centerline_method <- match.arg(
    centerline_method,
    c("mean", "medoid")
  )
  config$tube_radius <- tube_radius
  if (
    !is.numeric(tube_segments) ||
      length(tube_segments) != 1L ||
      is.na(tube_segments) ||
      tube_segments < 3
  ) {
    cli::cli_abort(c(
      "{.arg tube_segments} must be a single integer >= 3.",
      "x" = "Got: {.val {tube_segments}}"
    ))
  }
  config$tube_segments <- as.integer(tube_segments)
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
  if (is.character(input_tracts)) {
    cli::cli_alert_info("Tract files: {.path {input_tracts}}")
  } else {
    n_tracts <- length(input_tracts)
    cli::cli_alert_info("Tracts: {n_tracts} in-memory coordinate matri{?x/ces}")
  }
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
  files <- as.character(fs::path(dirs$base, "step1_data.rds"))
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

  prepared <- tract_prepare_inputs(
    input_tracts,
    tract_names,
    colours,
    config$verbose
  )

  meshes_list <- tract_build_meshes(
    config,
    prepared$streamlines_data,
    prepared$tract_names
  )

  built <- tract_build_core(
    meshes_list,
    prepared$colours,
    prepared$tract_names
  )

  step1_data <- tract_step1_data(config, prepared, built)

  saveRDS(step1_data, as.character(fs::path(dirs$base, "step1_data.rds")))
  step1_data
}


#' Read the tractography input, sanitize names and resolve colours
#' @noRd
tract_prepare_inputs <- function(input_tracts, tract_names, colours, verbose) {
  input_result <- tract_read_input(input_tracts, tract_names)
  streamlines_data <- input_result$streamlines_data
  tract_names <- sanitize_label(input_result$tract_names)
  names(streamlines_data) <- tract_names

  coords_are_voxels <- detect_tract_coord_space(
    streamlines_data,
    verbose
  )

  if (is.null(colours)) {
    colours <- rep(NA_character_, length(streamlines_data))
  }
  names(colours) <- tract_names

  list(
    streamlines_data = streamlines_data,
    tract_names = tract_names,
    colours = colours,
    coords_are_voxels = coords_are_voxels
  )
}


#' @noRd
tract_build_meshes <- function(config, streamlines_data, tract_names) {
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

  meshes_list
}


#' @noRd
tract_step1_data <- function(config, prepared, built) {
  list(
    streamlines_data = prepared$streamlines_data,
    centerlines_df = built$centerlines_df,
    core = built$core,
    palette = built$palette,
    atlas_name = built$atlas_name,
    tube_radius = config$tube_radius,
    tube_segments = config$tube_segments,
    coords_are_voxels = prepared$coords_are_voxels
  )
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
tract_resolve_snapshots <- function(config, dirs, step1, input_aseg, slabs) {
  files <- c(
    as.character(fs::path(dirs$base, "slabs.rds")),
    as.character(fs::path(dirs$base, "cortex_slices.rds"))
  )
  cached <- load_or_run_step(
    2L,
    config$steps,
    files,
    config$skip_existing,
    "Step 2 (Create projection snapshots)"
  )

  if (!cached$run) {
    return(tract_cached_snapshots(cached, config))
  }

  tract_run_snapshots(config, dirs, step1, input_aseg, slabs, files)
}


# nocov start
# Reads a real aseg volume and renders projection snapshots (magick/native
# geometry): unavailable on CI, so this run path is excluded from coverage.
#' @noRd
tract_run_snapshots <- function(config, dirs, step1, input_aseg, slabs, files) {
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
    step1$centerlines_df,
    input_aseg,
    slabs,
    dirs,
    coords_are_voxels,
    config$skip_existing,
    config$tract_radius,
    config$verbose
  )

  saveRDS(result$slabs, files[1])
  saveRDS(result$cortex_slices, files[2])
  if (config$verbose) {
    cli::cli_progress_done()
  }
  result
}
# nocov end

#' @noRd
tract_cached_snapshots <- function(cached, config) {
  if (any(config$steps > 2L)) {
    if (config$verbose) {
      cli::cli_alert_success("2/7 Loaded existing snapshots")
    }
    return(list(
      slabs = cached$data[["slabs.rds"]],
      cortex_slices = cached$data[["cortex_slices.rds"]]
    ))
  }
  list(slabs = NULL, cortex_slices = NULL)
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
tract_assemble_full <- function(step1, dirs, slabs, cortex_slices) {
  contours_file <- as.character(fs::path(dirs$base, "contours_reduced.rda"))
  if (!file.exists(contours_file)) {
    cli::cli_abort(c(
      "Step 7 requires contours_reduced.rda which doesn't exist",
      "i" = "Run steps 3-6 first to generate contour data"
    ))
  }

  sf_data <- build_contour_sf(
    contours_file,
    slabs,
    cortex_slices
  )

  atlas <- ggseg_atlas(
    atlas = step1$atlas_name,
    type = "tract",
    palette = step1$palette,
    core = step1$core,
    data = ggseg_data_tract(
      geom = sf_data,
      centerlines = step1$centerlines_df
    )
  )

  atlas <- ggseg.formats::atlas_view_gather(atlas)

  warn_if_large_atlas(atlas)
  preview_atlas(atlas)
  atlas
}
