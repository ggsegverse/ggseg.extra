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
#'   or `ASegStatsLUT.txt`), or a data.frame with columns `idx`, `label`,
#'   `R`, `G`, `B` and `A` (see [is_lut()]). Either may also carry a
#'   `hemi` column (`"left"`, `"right"` or `"midline"`) that sets each
#'   region's hemisphere; a row left `NA`, or a table without the column, has
#'   it read from the label's name, and any other value is an error.
#'   [write_lut()] stores the column in a file. If NULL, region names will be
#'   generic (e.g., "region_0010") and the atlas will have no palette.
#' @template atlas_name
#' @template output_dir
#' @param slabs A data.frame specifying projection slabs with columns `name`,
#'   `type` ("axial", "coronal", "sagittal"), `start` (first slice), `end`
#'   (last slice). Defaults to three coronal and three axial slabs tiling the
#'   bounding box of the atlas's own labels, plus one left-hemisphere
#'   sagittal slab, so the band follows the anatomy of the volume rather than
#'   a fixed set of slice indices.
#'   Unlike slices, projections show ALL structures in their spatial
#'   relationships - like an X-ray view. May also be a named list of
#'   [subcortical_slabs()] arguments (e.g.
#'   `slabs = list(labels = 801:810, coronal = 3, axial = 2)`); it is expanded
#'   into a slab table with `volume` defaulting to `input_volume`, so the slab
#'   indices are computed in the builder's own frame.
#' @template vertex_size_limits
#' @template decimate
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run. Default NULL runs all six:
#'   \itemize{
#'     \item 1: Extract labels from the volume and read the colour table
#'     \item 2: Create a mesh for each structure
#'     \item 3: Build atlas data (3D only if stopping here)
#'     \item 4: Create projection snapshots
#'     \item 5: Extract contours
#'     \item 6: Build the final atlas with 2D geometry
#'   }
#'   Use `steps = 1:3` for a 3D-only atlas. Geometry is shaped after the
#'   build, not during it: see [atlas_polish()].
#' @param context Optional named list of [aseg_context()] arguments (e.g.
#'   `context = list(focus = "Hippocampus")`) applied to the finished 2D atlas
#'   to keep the focus regions coloured on grey anatomical context. `NULL`
#'   (default) leaves the atlas unchanged. Only applied when the 2D build
#'   (step 6) runs.
#'
#' @return A `ggseg_atlas` object with region metadata (core), 3D meshes,
#'   a colour palette, and optionally sf geometry for 2D slice plots.
#' @template dots_post_creation
#' @family atlas creation
#' @seealso [atlas_polish()] to simplify and round off the result, which
#'   most builds want next.
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
#' ggseg3d::ggseg3d(atlas = atlas)
#'
#' # Full atlas with 2D slices
#' atlas <- create_subcortical_from_volume(
#'   input_volume = "path/to/aseg.mgz",
#'   input_lut = "path/to/ASegStatsLUT.txt"
#' )
#'
#' # Post-process to remove/modify regions (functions from ggseg.formats)
#' atlas <- atlas |>
#'   atlas_region_remove("White-Matter", match_on = "label") |>
#'   atlas_region_contextual("Cortex", match_on = "label")
#' }
create_subcortical_from_volume <- function(
  input_volume,
  decimate = 0.5,
  verbose = get_verbose(), # nolint: object_usage_linter
  ...,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  slabs = NULL,
  vertex_size_limits = NULL,
  cleanup = NULL,
  skip_existing = NULL,
  steps = NULL,
  context = NULL
) {
  rlang::check_dots_empty()
  unpacked <- unpack_anatomical_input(input_volume, input_lut)

  start_time <- Sys.time()

  setup <- subcort_setup_pipeline(
    unpacked = unpacked,
    atlas_name = atlas_name,
    output_dir = output_dir,
    verbose = verbose,
    cleanup = cleanup,
    skip_existing = skip_existing,
    decimate = decimate,
    steps = steps,
    context = context
  )

  subcort_run_pipeline(
    setup,
    start_time,
    slabs,
    context,
    vertex_size_limits
  )
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
  context
) {
  config <- validate_subcort_config(
    input_volume = unpacked$input_volume,
    input_lut = unpacked$input_lut,
    atlas_name = atlas_name,
    output_dir = output_dir,
    verbose = verbose,
    cleanup = cleanup,
    skip_existing = skip_existing,
    decimate = decimate,
    steps = steps
  )

  validate_subcort_context_arg(context, config$steps)

  dirs <- setup_atlas_dirs(
    config$output_dir,
    atlas_name = config$atlas_name,
    type = "subcortical",
    cleanup = config$cleanup
  )
  subcort_log_header(config)

  list(config = config, dirs = dirs)
}


#' Run the subcortical pipeline steps and assemble the atlas
#' @noRd
#' Number of steps in the subcortical pipeline
#'
#' The last step assembles the 2D atlas, so this is both the ceiling `steps`
#' is validated against and the step that assembly is gated on. One value,
#' because it was once three and they drifted apart.
#' @noRd
subcort_total_steps <- function() 6L


subcort_run_pipeline <- function(
  setup,
  start_time,
  slabs,
  context,
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
  prune_stale_snapshots(
    dirs,
    subcort_snapshot_names(
      labels$colortable,
      snaps$slabs,
      snaps$cortex_slices
    ),
    verbose = config$verbose
  )
  subcort_extract_contours(config, dirs, vertex_size_limits)

  if (subcort_total_steps() %in% config$steps) {
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
subcort_extract_contours <- function(config, dirs, vertex_size_limits) {
  if (!(5L %in% config$steps)) {
    return(invisible(NULL))
  }
  # Each projection carries its own cache stamp and read_projection() rejects
  # a stale one, so there is no directory-level check to make.
  extract_contours(
    dirs$snapshots,
    dirs$base,
    step = sprintf("5/%d", subcort_total_steps()),
    verbose = config$verbose,
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
#' `context` is only applied when the 2D build (step 6) runs; warn otherwise.
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
  if (!(subcort_total_steps() %in% steps)) {
    cli::cli_warn(
      "{.arg context} is ignored unless step {subcort_total_steps()} (the 2D
      build) runs."
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
  steps
) {
  config <- resolve_common_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    steps,
    max_step = subcort_total_steps()
  )

  validate_decimate(decimate)

  check_fs(abort = TRUE)

  validate_subcort_inputs(input_volume, input_lut)

  config$output_dir <- absolute_path(config$output_dir)

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
  check_lut_hemi(input_lut)
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

  if (config$verbose) {
    cli::cli_progress_step(
      "1/{subcort_total_steps()} Extracting labels from volume"
    )
  }

  loaded <- load_volume_colortable(
    config$input_lut,
    config$input_volume,
    config$verbose
  )
  colortable <- loaded$colortable
  vol_labels <- loaded$vol_labels
  colortable$label <- sanitize_label(colortable$label)

  if (config$verbose) {
    cli::cli_alert_success("Found {nrow(colortable)} subcortical structures")
  }

  save_cache_rds(
    dirs$base,
    colortable.rds = colortable,
    vol_labels.rds = vol_labels
  )
  if (config$verbose) {
    cli::cli_progress_done()
  }

  list(colortable = colortable, vol_labels = vol_labels)
}


#' @noRd
subcort_cached_labels <- function(cached, verbose) {
  if (verbose) {
    cli::cli_alert_success("1/{subcort_total_steps()} Loaded existing labels")
  }
  list(
    colortable = cached$data[["colortable.rds"]],
    vol_labels = cached$data[["vol_labels.rds"]]
  )
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
        cli::cli_alert_success(
          "2/{subcort_total_steps()} Loaded existing meshes"
        )
      }
      return(cached$data[["meshes_list.rds"]])
    }
    return(NULL)
  }

  if (config$verbose) {
    cli::cli_progress_step(
      "2/{subcort_total_steps()} Creating meshes for each structure"
    )
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
  save_cache_rds(dirs$base, meshes_list.rds = meshes_list)
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
        cli::cli_alert_success(
          "3/{subcort_total_steps()} Loaded existing components"
        )
      }
      return(cached$data[["components.rds"]])
    }
    return(NULL)
  }

  if (config$verbose) {
    cli::cli_progress_step("3/{subcort_total_steps()} Building atlas data")
  }

  components <- subcort_build_components(colortable, meshes_list)
  save_cache_rds(dirs$base, components.rds = components)
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

  # Reuse without looking at the snapshots only when step 4 was excluded on
  # purpose. When it was requested, its `.rds` cache being reusable is not
  # enough: the volume and lookup table the wholebrain pipeline hands down to
  # this one are not stamped (see `cache_format_version()`), so a changed
  # volume leaves a directory of projections drawn from the old one. Step 5
  # then traces them as though they were current and aborts with "No contours
  # were extracted from any region", blaming the regions for a stale cache.
  # subcort_create_snapshots() already checks each snapshot against a
  # signature of what it was drawn from and redraws only what moved, so
  # calling it here costs a volume read rather than a full redraw.
  if (!cached$run && !(4L %in% config$steps)) {
    if (config$verbose) {
      cli::cli_alert_success(
        "4/{subcort_total_steps()} Loaded existing slabs"
      )
    }
    return(list(
      slabs = cached$data[["slabs.rds"]],
      cortex_slices = cached$data[["cortex_slices.rds"]]
    ))
  }

  if (config$verbose) {
    cli::cli_progress_step(
      "4/{subcort_total_steps()} Creating projection snapshots"
    )
  }

  result <- subcort_create_snapshots(
    config$input_volume,
    colortable,
    slabs,
    dirs,
    config$skip_existing
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
  contours_file <- as.character(fs::path(dirs$base, "contours.rda"))
  if (!file.exists(contours_file)) {
    cli::cli_abort(c(
      "Step {subcort_total_steps()} needs {.path contours.rda}, which does
      not exist.",
      "i" = "Run step 5 first to extract contour data."
    ))
  }

  sf_data <- build_contour_sf(contours_file, slabs, cortex_slices)
  components <- drop_labels_without_geometry(components, sf_data)

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
