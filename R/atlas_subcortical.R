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
#'   segmentation in the same space. May also be the
#'   `list(volume, lut, id_offset)` returned by
#'   [prepare_subcortical_anatomical()] /
#'   [project_volume_anatomical()], in which case its `volume` and `lut`
#'   are used (an explicit `input_lut` takes precedence over the bundled one).
#' @param input_lut Path to a FreeSurfer-style colour lookup table that maps
#'   label IDs to region names and colours (e.g., `FreeSurferColorLUT.txt`
#'   or `ASegStatsLUT.txt`), or a data.frame with columns `region` and colour
#'   columns (R, G, B or hex). If NULL, region names will be generic
#'   (e.g., "region_0010") and the atlas will have no palette.
#' @template atlas_name
#' @template output_dir
#' @param slabs A data.frame specifying projection slabs with columns `name`,
#'   `type` ("axial", "coronal", "sagittal"), `start` (first slice), `end`
#'   (last slice). Default projects entire volume from each direction.
#'   Unlike slices, projections show ALL structures in their spatial
#'   relationships - like an X-ray view. May also be a named list of
#'   [subcortical_slabs()] arguments (e.g.
#'   `slabs = list(labels = 801:810, coronal = 3, axial = 2)`); it is expanded
#'   into a slab table with `volume` defaulting to `input_volume`, so the slab
#'   indices are computed in the builder's own frame.
#' @template vertex_size_limits
#' @template dilate
#' @template decimate
#' @template tolerance
#' @template smoothness
#' @template cleanup
#' @template verbose
#' @template skip_existing
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
#' @param context Optional named list of [aseg_context()] arguments (e.g.
#'   `context = list(focus = "Hippocampus")`) applied to the finished 2D atlas
#'   to keep the focus regions coloured on grey anatomical context. `NULL`
#'   (default) leaves the atlas unchanged. Only applied when the 2D build
#'   (step 9) runs.
#' @template views_deprecated
#'
#' @return A `ggseg_atlas` object with region metadata (core), 3D meshes,
#'   a colour palette, and optionally sf geometry for 2D slice plots.
#' @export
#' @importFrom dplyr tibble bind_rows left_join filter distinct
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
  output_dir = NULL,
  slabs = NULL,
  vertex_size_limits = NULL,
  dilate = NULL,
  decimate = 0.5,
  tolerance = NULL,
  smoothness = NULL,
  cleanup = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  skip_existing = NULL,
  steps = NULL,
  context = NULL,
  views = lifecycle::deprecated()
) {
  warn_post_creation_args(
    "create_subcortical_from_volume",
    dilate = dilate,
    smoothness = smoothness,
    tolerance = tolerance
  )
  if (lifecycle::is_present(views)) {
    lifecycle::deprecate_warn(
      "1.9.9.9005",
      "create_subcortical_from_volume(views = )",
      "create_subcortical_from_volume(slabs = )"
    )
    slabs <- views
  }

  unpacked <- subcort_unpack_input(
    input_volume,
    input_lut,
    tolerance,
    smoothness
  )

  start_time <- Sys.time()

  setup <- subcort_setup_pipeline(
    unpacked,
    atlas_name,
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    decimate,
    steps,
    tolerance,
    smoothness,
    context
  )

  subcort_run_pipeline(
    setup,
    start_time,
    slabs,
    context,
    dilate,
    vertex_size_limits
  )
}


#' Warn about deprecated sf smoothing arguments and unpack the volume input
#' @noRd
subcort_unpack_input <- function(
  input_volume,
  input_lut,
  tolerance,
  smoothness
) {
  # nolint start: object_usage_linter.
  warn_deprecated_sf_smoothing(
    tolerance = tolerance,
    smoothness = smoothness,
    fn = "create_subcortical_from_volume"
  )
  # nolint end

  unpack_anatomical_input(input_volume, input_lut)
}


#' Validate arguments, create the output directories and log the header
#' @noRd
subcort_setup_pipeline <- function(
  unpacked,
  atlas_name,
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  decimate,
  steps,
  tolerance,
  smoothness,
  context
) {
  config <- validate_subcort_config(
    unpacked$input_volume,
    unpacked$input_lut,
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

  validate_subcort_context_arg(context, config$steps)

  dirs <- setup_atlas_dirs(
    config$output_dir,
    config$atlas_name,
    type = "subcortical"
  )
  subcort_log_header(config)

  list(config = config, dirs = dirs)
}


#' Run the subcortical pipeline steps and assemble the atlas
#' @noRd
subcort_run_pipeline <- function(
  setup,
  start_time,
  slabs,
  context,
  dilate,
  vertex_size_limits
) {
  config <- setup$config
  dirs <- setup$dirs

  labels <- subcort_resolve_labels(config, dirs)
  meshes_list <- subcort_resolve_meshes(config, dirs, labels$colortable)
  components <- subcort_resolve_components(
    config,
    dirs,
    labels$colortable,
    meshes_list
  )

  if (max(config$steps) == 3L) {
    atlas <- subcort_assemble_3d(config$atlas_name, components)
    return(subcort_finalize(atlas, config, dirs, start_time))
  }

  slabs <- resolve_subcort_slabs_spec(slabs, config$input_volume)
  snaps <- subcort_resolve_snapshots(config, dirs, labels$colortable, slabs)
  subcort_image_steps(config, dirs, dilate, vertex_size_limits)

  if (9L %in% config$steps) {
    atlas <- subcort_build_2d_atlas(config, components, dirs, snaps, context)
    return(subcort_finalize(atlas, config, dirs, start_time))
  }

  subcort_finalize(NULL, config, dirs, start_time)
}


#' @noRd
subcort_finalize <- function(atlas, config, dirs, start_time) {
  finalize_atlas(
    atlas,
    config,
    dirs,
    start_time,
    type_label = "Subcortical",
    unit = "structures",
    early_step = 3L
  )
}


#' @noRd
subcort_image_steps <- function(config, dirs, dilate, vertex_size_limits) {
  run_image_steps(
    config,
    dirs,
    step_map = list(process = 5L, extract = 6L, smooth = 7L, reduce = 8L),
    total_steps = 9L,
    dilate = dilate,
    vertex_size_limits = vertex_size_limits
  )
}


#' @noRd
subcort_build_2d_atlas <- function(config, components, dirs, snaps, context) {
  atlas <- subcort_assemble_full(
    config$atlas_name,
    components,
    dirs,
    snaps$slabs,
    snaps$cortex_slices
  )
  apply_subcort_context_spec(atlas, context)
}


#' Unpack a `prepare_subcortical_anatomical()` result into volume + lut
#'
#' [prepare_subcortical_anatomical()] / [project_volume_anatomical()] return a
#' `list(volume, lut, id_offset)`. Accepting that list directly as
#' `input_volume` lets the anatomical-context pipeline compose without the
#' caller hand-threading the shifted colour table. An explicit `input_lut`
#' still wins over the bundled one.
#' @noRd
unpack_anatomical_input <- function(input_volume, input_lut) {
  if (
    is.list(input_volume) &&
      all(c("volume", "lut") %in% names(input_volume))
  ) {
    if (is.null(input_lut)) {
      input_lut <- input_volume$lut
    }
    input_volume <- input_volume$volume
  }
  list(input_volume = input_volume, input_lut = input_lut)
}


#' Resolve the `slabs` argument of `create_subcortical_from_volume()`
#'
#' Passes a data.frame through unchanged; expands a list spec into a slab
#' table via [subcortical_slabs()], defaulting `volume` to the atlas volume.
#' @noRd
resolve_subcort_slabs_spec <- function(slabs, input_volume) {
  if (is.null(slabs) || is.data.frame(slabs)) {
    return(slabs)
  }
  if (!is.list(slabs)) {
    cli::cli_abort(c(
      "{.arg slabs} must be a data.frame or a list of
       {.fn subcortical_slabs} arguments.",
      "i" = "Got {.cls {class(slabs)}}."
    ))
  }
  do.call(subcortical_slabs, c(list(volume = input_volume), slabs))
}


#' Validate the `context` argument of `create_subcortical_from_volume()`
#'
#' `context` is only applied when the 2D build (step 9) runs; warn otherwise.
#' @noRd
validate_subcort_context_arg <- function(context, steps) {
  if (is.null(context)) {
    return(invisible(NULL))
  }
  if (!is.list(context)) {
    cli::cli_abort(c(
      "{.arg context} must be a list of {.fn aseg_context} arguments.",
      "i" = "Got {.cls {class(context)}}."
    ))
  }
  if (!(9L %in% steps)) {
    cli::cli_warn(
      "{.arg context} is ignored unless step 9 (the 2D build) runs."
    )
  }
  invisible(NULL)
}


#' Run [aseg_context()] on a built atlas from a `context` list spec
#' @noRd
apply_subcort_context_spec <- function(atlas, context) {
  if (is.null(context)) {
    return(atlas)
  }
  do.call(aseg_context, c(list(atlas = atlas), context))
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
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    steps,
    max_step = 9L
  )

  validate_decimate(decimate)

  check_fs(abort = TRUE)

  validate_subcort_inputs(input_volume, input_lut)

  config$output_dir <- normalizePath(config$output_dir, mustWork = FALSE)

  if (is.null(atlas_name)) {
    atlas_name <- default_atlas_name_from_volume(input_volume)
  }

  config$input_volume <- input_volume
  config$input_lut <- input_lut
  config$atlas_name <- atlas_name
  config$decimate <- decimate
  config
}


#' @noRd
validate_decimate <- function(decimate) {
  if (
    !is.null(decimate) &&
      (!is.numeric(decimate) ||
        length(decimate) != 1 || # nolint: indentation_linter.
        decimate <= 0 ||
        decimate >= 1)
  ) {
    cli::cli_abort(c(
      "{.arg decimate} must be a single number between 0 and 1 (exclusive)",
      "x" = "Got {.val {decimate}}",
      "i" = "Use {.code NULL} to skip mesh decimation"
    ))
  }
  invisible(NULL)
}


#' Derive a default atlas name from a volume file path
#'
#' Strips the directory and the full extension, including the `.gz`/`.bz2`
#' compression suffix, so `aseg.nii.gz` and `aseg.mgz` both become `aseg`
#' rather than leaving a stray `.nii` on gzipped inputs.
#' @noRd
default_atlas_name_from_volume <- function(input_volume) {
  file_path_sans_ext(basename(input_volume), compression = TRUE)
}


#' @noRd
validate_subcort_inputs <- function(input_volume, input_lut) {
  if (!file.exists(input_volume)) {
    cli::cli_abort("Volume file not found: {.path {input_volume}}")
  }
  if (
    !is.null(input_lut) && is.character(input_lut) && !file.exists(input_lut)
  ) {
    cli::cli_abort("Color lookup table not found: {.path {input_lut}}")
  }
  invisible(NULL)
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
    as.character(fs::path(dirs$base, "colortable.rds")),
    as.character(fs::path(dirs$base, "vol_labels.rds"))
  )
  cached <- load_or_run_step(
    1L,
    config$steps,
    files,
    config$skip_existing,
    "Step 1 (Extract labels)"
  )

  if (!cached$run) {
    return(subcort_cached_labels(cached, config$verbose))
  }

  colortable <- subcort_load_colortable(config$input_lut, config$input_volume)

  if (config$verbose) {
    cli::cli_progress_step("1/9 Extracting labels from volume")
  }

  vol <- read_volume(config$input_volume)
  vol_labels <- unique(c(vol))
  vol_labels <- vol_labels[!is.na(vol_labels) & vol_labels != 0]
  colortable <- colortable[colortable$idx %in% vol_labels, ]

  colortable$label <- sanitize_label(colortable$label)

  if (nrow(colortable) == 0) {
    cli::cli_abort("No matching labels found in volume and color table")
  }

  if (config$verbose) {
    cli::cli_alert_success("Found {nrow(colortable)} subcortical structures")
  }

  saveRDS(colortable, as.character(fs::path(dirs$base, "colortable.rds")))
  saveRDS(vol_labels, as.character(fs::path(dirs$base, "vol_labels.rds")))
  if (config$verbose) {
    cli::cli_progress_done()
  }

  list(colortable = colortable, vol_labels = vol_labels)
}


#' @noRd
subcort_cached_labels <- function(cached, verbose) {
  if (verbose) {
    cli::cli_alert_success("1/9 Loaded existing labels")
  }
  list(
    colortable = cached$data[["colortable.rds"]],
    vol_labels = cached$data[["vol_labels.rds"]]
  )
}


#' @noRd
subcort_load_colortable <- function(input_lut, input_volume) {
  if (is.null(input_lut)) {
    cli::cli_warn(c(
      "No color lookup table provided",
      "i" = "Region names will be generic (e.g., 'region_0010')",
      "i" = "The atlas will have no palette; plotting picks its own colours"
    ))
    return(generate_colortable_from_volume(input_volume))
  }
  get_lut(input_lut)
}


#' @noRd
subcort_resolve_meshes <- function(config, dirs, colortable) {
  files <- as.character(fs::path(dirs$base, "meshes_list.rds"))
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
  saveRDS(meshes_list, as.character(fs::path(dirs$base, "meshes_list.rds")))
  meshes_list
}


#' @noRd
subcort_resolve_components <- function(config, dirs, colortable, meshes_list) {
  files <- as.character(fs::path(dirs$base, "components.rds"))
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
  saveRDS(components, as.character(fs::path(dirs$base, "components.rds")))
  if (config$verbose) {
    cli::cli_progress_done()
  }
  components
}


#' @noRd
subcort_resolve_snapshots <- function(config, dirs, colortable, slabs) {
  files <- c(
    as.character(fs::path(dirs$base, "slabs.rds")),
    as.character(fs::path(dirs$base, "cortex_slices.rds"))
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
        cli::cli_alert_success("4/9 Loaded existing slabs")
      }
      return(list(
        slabs = cached$data[["slabs.rds"]],
        cortex_slices = cached$data[["cortex_slices.rds"]]
      ))
    }
    return(list(slabs = NULL, cortex_slices = NULL))
  }

  if (config$verbose) {
    cli::cli_progress_step("4/9 Creating projection snapshots")
  }

  result <- subcort_create_snapshots(
    config$input_volume,
    colortable,
    slabs,
    dirs,
    config$skip_existing
  )

  saveRDS(result$slabs, as.character(fs::path(dirs$base, "slabs.rds")))
  saveRDS(
    result$cortex_slices,
    as.character(fs::path(dirs$base, "cortex_slices.rds"))
  )
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
    data = ggseg_data_subcortical(meshes = components$meshes_df)
  )
}


#' @noRd
subcort_assemble_full <- function(
  atlas_name,
  components,
  dirs,
  slabs,
  cortex_slices
) {
  contours_file <- as.character(fs::path(dirs$base, "contours_reduced.rda"))
  if (!file.exists(contours_file)) {
    cli::cli_abort(c(
      "Step 9 requires contours_reduced.rda which doesn't exist",
      "i" = "Run steps 5-8 first to generate contour data"
    ))
  }

  sf_data <- build_contour_sf(contours_file, slabs, cortex_slices)
  components <- subcort_drop_missing_labels(components, sf_data)

  atlas <- ggseg_atlas(
    atlas = atlas_name,
    type = "subcortical",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_subcortical(geom = sf_data, meshes = components$meshes_df)
  )

  atlas <- ggseg.formats::atlas_view_gather(atlas)

  warn_if_large_atlas(atlas)
  preview_atlas(atlas)
  atlas
}


#' Drop core/palette/mesh entries that have no contour geometry
#' @noRd
subcort_drop_missing_labels <- function(components, sf_data) {
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
  components
}
