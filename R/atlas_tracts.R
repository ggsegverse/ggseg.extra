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
#' @param tube_opts Named list controlling how a bundle of streamlines
#'   becomes a 3D tube mesh, with these entries and defaults:
#'   \itemize{
#'     \item `centerline_method` (`"mean"`) and `n_points` (`50`): how one
#'       centerline is derived from many streamlines, and how many points it
#'       is resampled to. All tracts are resampled to the same length so the
#'       tubes are consistent.
#'     \item `tube_radius` (`5`) and `tube_segments` (`8`): the thickness of
#'       the tube drawn along that centerline, and how many segments go
#'       around its circumference. `tube_radius` also takes `"density"`, to
#'       scale thickness by how many streamlines pass through each point.
#'   }
#'   Unknown entries error. Replaces the flat `tube_radius`,
#'   `tube_segments`, `n_points` and `centerline_method` arguments.
#' @param ... `r lifecycle::badge("deprecated")` The flat arguments that
#'   `tube_opts` replaced, plus the retired post-creation tweaks. Each is
#'   folded into the list that now holds it and raises a deprecation warning;
#'   supplying both the old argument and its list entry is an error.
#' @param slabs A data.frame specifying projection slabs. If NULL, a default
#'   set of tract slabs is derived from the volume dimensions.
#' @template vertex_size_limits
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
#' @template dots_post_creation
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
  verbose = get_verbose(), # nolint: object_usage_linter
  views = lifecycle::deprecated(),
  ...,
  input_aseg = NULL,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  tube_opts = list(),
  slabs = NULL,
  vertex_size_limits = NULL,
  steps = NULL,
  cleanup = NULL,
  skip_existing = NULL
) {
  grouped <- group_retired_dots(
    opts = list(tube_opts = tube_opts),
    mapping = TRACT_RETIRED_TUBE,
    dots = list(...),
    fn = "create_tract_from_tractography",
    when = "1.9.9.9053"
  )
  tube <- resolve_opts(grouped$opts$tube_opts, "tube_opts", TRACT_TUBE_DEFAULTS)

  dots <- do.call(
    check_post_creation_dots,
    c(list("create_tract_from_tractography"), grouped$dots)
  )
  if (lifecycle::is_present(views)) {
    lifecycle::deprecate_warn(
      "1.9.9.9005",
      "create_tract_from_tractography(views = )",
      "create_tract_from_tractography(slabs = )"
    )
    slabs <- views
  }

  start_time <- Sys.time()

  setup <- tract_setup_pipeline(
    input_tracts = input_tracts,
    input_aseg = input_aseg,
    input_lut = input_lut,
    atlas_name = atlas_name,
    output_dir = output_dir,
    verbose = verbose,
    cleanup = cleanup,
    skip_existing = skip_existing,
    tolerance = dots$tolerance,
    smoothness = dots$smoothness,
    steps = steps,
    centerline_method = tube$centerline_method,
    tube_radius = tube$tube_radius,
    tube_segments = tube$tube_segments,
    n_points = tube$n_points
  )

  tract_run_pipeline(setup, start_time, slabs, vertex_size_limits)
}


# nolint start: object_name_linter.
#' Defaults for the grouped `tube_opts` argument
#'
#' Everything about turning a bundle of streamlines into a 3D tube mesh.
#' `vertex_size_limits` is deliberately not here: it filters finished 2D
#' polygons by vertex count, so it belongs with `slabs` rather than with the
#' mesh, whatever its name suggests.
#' @noRd
TRACT_TUBE_DEFAULTS <- list(
  tube_radius = 5,
  tube_segments = 8,
  n_points = 50,
  centerline_method = c("mean", "medoid")
)

#' Flat arguments retired into `tube_opts`
#' @noRd
TRACT_RETIRED_TUBE <- c(
  tube_radius = "tube_opts.tube_radius",
  tube_segments = "tube_opts.tube_segments",
  n_points = "tube_opts.n_points",
  centerline_method = "tube_opts.centerline_method"
)
# nolint end

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

  dirs <- setup_atlas_dirs(
    config$output_dir,
    atlas_name = atlas_name,
    type = "tract"
  )
  lut_result <- parse_lut_colours(input_lut)
  tract_log_header(config, input_tracts, input_aseg)

  config$input_tracts <- input_tracts
  config$input_aseg <- input_aseg
  # Carried through so the finished atlas is named what the caller asked for,
  # not the name derived from the tract labels.
  config$atlas_name <- atlas_name
  list(config = config, dirs = dirs, lut = lut_result)
}


#' Run the tract pipeline steps and assemble the atlas
#' @noRd
tract_run_pipeline <- function(
  setup,
  start_time,
  slabs,
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

  tract_image_steps(config, dirs, vertex_size_limits)

  if (tract_total_steps() %in% config$steps) {
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
#' Number of steps in the tract pipeline
#'
#' Step 7 assembles the atlas. Same story as `subcort_total_steps()`: the
#' ceiling and the progress total dropped to 6 while everything else stayed
#' on 7, so the last step could never run.
#' @noRd
tract_total_steps <- function() 7L


tract_image_steps <- function(config, dirs, vertex_size_limits) {
  run_image_steps(
    config,
    dirs,
    step_map = list(extract = 3L, smooth = 4L, reduce = 5L),
    total_steps = tract_total_steps(),
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
    max_step = tract_total_steps()
  )
  config$output_dir <- absolute_path(config$output_dir)

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
    cli::cli_alert_info(
      "Tracts: {length(input_tracts)} in-memory coordinate matri{?x/ces}"
    )
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

  save_cache_rds(dirs$base, step1_data.rds = step1_data)
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
    atlas_name = config$atlas_name %||% built$atlas_name,
    tube_radius = config$tube_radius,
    tube_segments = config$tube_segments,
    coords_are_voxels = prepared$coords_are_voxels,
    center_offset = built$center_offset
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
# Reads a real aseg volume and caches projections (native
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
    config$verbose,
    step1$center_offset
  )

  save_cache_rds(
    dirs$base,
    slabs.rds = result$slabs,
    cortex_slices.rds = result$cortex_slices
  )
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
