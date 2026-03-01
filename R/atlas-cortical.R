# Unified atlas creation ----

#' Create cortical atlas from FreeSurfer annotation
#'
#' @description
#' `r lifecycle::badge("maturing")`
#'
#' Turn FreeSurfer annotation files into a brain atlas you can plot with
#' ggseg and ggseg3d. The function reads the annotation, extracts which
#' vertices belong to each brain region, and (optionally) generates 2D
#' polygon outlines for flat brain plots.
#'
#' Use the `steps` parameter to control which pipeline steps to run. For
#' 3D-only atlases, use `steps = 1`. For iterating on contour parameters,
#' use `steps = 6:7` to re-run smoothing and reduction without regenerating
#' snapshots.
#'
#' @param input_annot Character vector of paths to annotation files.
#'   Files should follow FreeSurfer naming convention with `lh.` or `rh.`
#'   prefix (e.g., `c("lh.aparc.annot", "rh.aparc.annot")`).
#' @template atlas_name
#' @template output_dir
#' @param hemisphere Which hemispheres to include: "lh", "rh", or both.
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smoothness
#' @template snapshot_dim
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run. Default NULL runs all steps.
#'   Steps are:
#'   \itemize{
#'     \item 1: Read annotation files and build 3D atlas
#'     \item 2: Take full brain snapshots
#'     \item 3: Take region snapshots
#'     \item 4: Isolate regions from images
#'     \item 5: Extract contours
#'     \item 6: Smooth contours
#'     \item 7: Reduce vertices
#'     \item 8: Build final atlas with 2D geometry
#'   }
#'   Use `steps = 1` for 3D-only atlas. Use `steps = 1:4` to stop before
#'   contour extraction. Use `steps = 6:7` to iterate on smoothing and
#'   reduction parameters without re-extracting contours.
#'
#' @return A `ggseg_atlas` object containing region metadata (core), vertex
#'   indices for 3D rendering, a colour palette, and optionally sf geometry
#'   for 2D plots.
#' @export
#' @importFrom dplyr filter select mutate left_join group_by ungroup tibble
#'   bind_rows distinct
#' @importFrom freesurfer have_fs
#' @importFrom furrr future_pmap furrr_options
#' @importFrom grDevices rgb
#' @importFrom progressr progressor
#' @importFrom sf st_as_sf st_combine
#' @importFrom tools file_path_sans_ext
#'
#' @examples
#' \dontrun{
#' # Create 3D-only atlas from annotation files
#' atlas <- create_cortical_from_annotation(
#'   input_annot = c("lh.yeo7.annot", "rh.yeo7.annot"),
#'   steps = 1
#' )
#'
#' # Create full atlas with 2D geometry (requires FreeSurfer for rendering)
#' atlas <- create_cortical_from_annotation(
#'   input_annot = c("lh.aparc.DKTatlas.annot", "rh.aparc.DKTatlas.annot")
#' )
#' ggseg(atlas = atlas)
#'
#' # Iterate on smoothing parameters
#' atlas <- create_cortical_from_annotation(
#'   input_annot = c("lh.aparc.annot", "rh.aparc.annot"),
#'   steps = 6:8,
#'   smoothness = 10,
#'   tolerance = 0.5
#' )
#' }
# nolint next: object_length_linter.
create_cortical_from_annotation <- function(
  input_annot,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smoothness = NULL,
  snapshot_dim = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  steps = NULL
) {
  if (length(input_annot) == 0) {
    cli::cli_abort("{.arg input_annot} must not be empty")
  }

  config <- validate_cortical_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    snapshot_dim,
    steps
  )

  if (any(config$steps > 1L)) {
    check_fs(abort = TRUE)
    check_magick()
  }

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(input_annot[1])
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_annotation_data(input_annot),
    step_label = "1/8 Reading annotation files",
    cache_label = "Step 1 (Read annotations)",
    header_msg = "Creating brain atlas {.val {atlas_name}}",
    input_files = input_annot,
    hemisphere = hemisphere,
    views = views
  )
}


#' Run the standard cortical atlas creation sequence
#'
#' Shared by annotation, GIFTI, CIFTI, and neuromaps entry points.
#' Handles directory setup, logging, step 1 resolution, early return,
#' and full pipeline execution.
#'
#' @param atlas_name Atlas name string
#' @param config Validated cortical config
#' @param read_fn Zero-arg function returning atlas_data tibble
#' @param step_label Progress label for step 1
#' @param cache_label Cache label for step 1
#' @param header_msg CLI header message (glue string with `atlas_name`)
#' @param input_files Character vector for "Input files:" log line
#' @param hemisphere Hemisphere codes for pipeline
#' @param views View names for pipeline
#' @param region_snapshot_fn Snapshot function
#'   (default: cortical_region_snapshots)
#' @return ggseg_atlas object
#' @noRd
run_cortical_creation <- function(
  atlas_name,
  config,
  read_fn,
  step_label,
  cache_label,
  header_msg,
  input_files,
  hemisphere = c("rh", "lh"),
  hemisphere_fn = NULL,
  views = c("lateral", "medial", "superior", "inferior"),
  region_snapshot_fn = cortical_region_snapshots
) {
  start_time <- Sys.time()
  dirs <- setup_atlas_dirs(config$output_dir, atlas_name, type = "cortical")

  if (config$verbose) {
    cli::cli_h1(header_msg)
    cli::cli_alert_info("Input files: {.path {input_files}}")
    cli::cli_alert_info(
      "Setting output directory to {.path {config$output_dir}}"
    )
  }

  step1 <- cortical_resolve_step1(
    config,
    dirs,
    atlas_name,
    read_fn = read_fn,
    step_label = step_label,
    cache_label = cache_label
  )

  if (max(config$steps) == 1L) {
    return(cortical_finalize(step1$atlas_3d, config, dirs, start_time))
  }

  if (!is.null(hemisphere_fn)) {
    hemisphere <- hemisphere_fn(step1)
  }

  cortical_pipeline(
    atlas_3d = step1$atlas_3d,
    components = step1$components,
    atlas_name = atlas_name,
    hemisphere = hemisphere,
    views = views,
    region_snapshot_fn = region_snapshot_fn,
    config = config,
    dirs = dirs,
    start_time = start_time
  )
}


# Cortical pipeline helpers ----

#' @noRd
validate_cortical_config <- function(
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  tolerance,
  smoothness,
  snapshot_dim,
  steps
) {
  config <- resolve_common_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    steps,
    max_step = 8L
  )
  config$snapshot_dim <- get_snapshot_dim(snapshot_dim)
  config
}


#' @noRd
cortical_resolve_step1 <- function(
  config,
  dirs,
  atlas_name,
  read_fn,
  step_label,
  cache_label
) {
  files <- c(
    file.path(dirs$base, "atlas_3d.rds"),
    file.path(dirs$base, "components.rds")
  )
  cached <- load_or_run_step(
    1L,
    config$steps,
    files,
    config$skip_existing,
    cache_label
  )

  if (!cached$run) {
    if (config$verbose) {
      cli::cli_alert_success("1/8 Loaded existing atlas data")
    }
    return(list(
      atlas_3d = cached$data[["atlas_3d.rds"]],
      components = cached$data[["components.rds"]]
    ))
  }

  if (config$verbose) {
    cli::cli_progress_step(step_label)
  }

  atlas_data <- read_fn()
  if (nrow(atlas_data) == 0) {
    cli::cli_abort("No regions found in input files")
  }

  components <- build_atlas_components(atlas_data)
  atlas_3d <- ggseg_atlas(
    atlas = atlas_name,
    type = "cortical",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_cortical(sf = NULL, vertices = components$vertices_df)
  )

  saveRDS(atlas_3d, file.path(dirs$base, "atlas_3d.rds"))
  saveRDS(components, file.path(dirs$base, "components.rds"))
  cli::cli_progress_done()

  list(atlas_3d = atlas_3d, components = components)
}


#' @noRd
cortical_pipeline <- function(
  atlas_3d,
  components,
  atlas_name,
  hemisphere,
  views,
  region_snapshot_fn,
  config,
  dirs,
  start_time
) {
  cortical_run_snapshot_steps(
    atlas_3d,
    components,
    hemisphere,
    views,
    region_snapshot_fn,
    config,
    dirs
  )

  cortical_run_contour_steps(config, dirs)

  if (8L %in% config$steps) {
    if (config$verbose) {
      cli::cli_progress_step("8/8 Building final atlas")
    }
    atlas <- cortical_assemble_full(atlas_name, components, dirs)
    if (config$verbose) {
      cli::cli_progress_done()
    }
    return(cortical_finalize(atlas, config, dirs, start_time))
  }

  cortical_finalize(atlas_3d, config, dirs, start_time, partial = TRUE)
}


#' @noRd
cortical_run_snapshot_steps <- function(
  atlas_3d,
  components,
  hemisphere,
  views,
  region_snapshot_fn,
  config,
  dirs
) {
  snapshot_dim <- config$snapshot_dim

  if (2L %in% config$steps) {
    if (config$verbose) {
      cli::cli_progress_step("2/8 Taking full brain snapshots")
    }
    cortical_brain_snapshots(
      atlas_3d,
      hemisphere,
      views,
      dirs,
      config$skip_existing,
      snapshot_dim
    )
    if (config$verbose) cli::cli_progress_done()
  }

  if (3L %in% config$steps) {
    if (config$verbose) {
      cli::cli_progress_step("3/8 Taking region snapshots")
    }
    region_snapshot_fn(
      atlas_3d,
      components,
      hemisphere,
      views,
      dirs,
      config$skip_existing,
      snapshot_dim
    )
    if (config$verbose) cli::cli_progress_done()
  }

  close_chromote_workers()

  if (4L %in% config$steps) {
    if (config$verbose) {
      cli::cli_progress_step("4/8 Isolating regions")
    }
    cortical_isolate_regions(dirs, config$skip_existing)
    if (config$verbose) cli::cli_progress_done()
  }
}


#' @noRd
cortical_run_contour_steps <- function(config, dirs) {
  if (5L %in% config$steps) {
    extract_contours(
      dirs$masks,
      dirs$base,
      step = "5/8",
      verbose = config$verbose
    )
  }
  if (6L %in% config$steps) {
    smooth_contours(
      dirs$base,
      config$smoothness,
      step = "6/8",
      verbose = config$verbose
    )
  }
  if (7L %in% config$steps) {
    reduce_vertex(
      dirs$base,
      config$tolerance,
      step = "7/8",
      verbose = config$verbose
    )
  }
}


#' @noRd
cortical_assemble_full <- function(atlas_name, components, dirs) {
  sf_data <- cortical_build_sf(dirs)
  ggseg_atlas(
    atlas = atlas_name,
    type = "cortical",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_cortical(
      sf = sf_data,
      vertices = components$vertices_df
    )
  )
}


#' @noRd
cortical_finalize <- function(
  atlas,
  config,
  dirs,
  start_time,
  partial = FALSE
) {
  if (config$cleanup && !partial) {
    unlink(dirs$base, recursive = TRUE)
    if (config$verbose) cli::cli_alert_success("Temporary files removed")
  }

  if (config$verbose) {
    if (partial) {
      cli::cli_alert_success("Completed steps {.val {config$steps}}")
    } else if (max(config$steps) == 1L) {
      cli::cli_alert_success(
        "3D atlas created with {nrow(atlas$core)} regions"
      )
    } else {
      cli::cli_alert_success(
        "Brain atlas created with {nrow(atlas$core)} regions"
      )
    }
    log_elapsed(start_time) # nolint: object_usage_linter.
  }

  if (!partial) {
    warn_if_large_atlas(atlas)
  }
  preview_atlas(atlas)
  if (partial) invisible(atlas) else atlas
}


# Label atlas creation ----

#' Create brain atlas from label files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build an atlas from individual FreeSurfer `.label` files rather than a
#' complete annotation. Each label file defines a single region by listing
#' which surface vertices belong to it. Useful when you have analysis results
#' saved as labels, or when you want to combine regions from different sources
#' into a custom atlas.
#'
#' The function detects hemisphere from filename prefixes (`lh.` or `rh.`) and
#' derives region names from the rest of the filename.
#'
#' @param label_files Paths to `.label` files. Each file should follow
#'   FreeSurfer naming: `{hemi}.{regionname}.label` (e.g., `lh.motor.label`).
#' @template atlas_name
#' @param input_lut Path to a color lookup table (LUT) file, or a data.frame
#'   with columns `region` and colour columns (R, G, B or hex).
#'   Use this to provide region names and colours. If NULL, names are derived
#'   from filenames and the atlas will have no palette.
#' @template output_dir
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smoothness
#' @template snapshot_dim
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run. Default NULL runs all steps.
#'   Steps are:
#'   \itemize{
#'     \item 1: Read label files and build 3D atlas
#'     \item 2: Take full brain snapshots
#'     \item 3: Take region snapshots
#'     \item 4: Isolate regions from images
#'     \item 5: Extract contours
#'     \item 6: Smooth contours
#'     \item 7: Reduce vertices
#'     \item 8: Build final atlas with 2D geometry
#'   }
#'   Use `steps = 1` for 3D-only atlas. Use `steps = 6:7` to iterate on
#'   smoothing and reduction parameters.
#'
#' @return A `ggseg_atlas` object containing region metadata, vertex indices,
#'   colours, and optionally sf geometry for 2D plots.
#' @export
#' @importFrom dplyr tibble bind_rows distinct
#' @importFrom grDevices rgb
#' @importFrom tools file_path_sans_ext
#' @importFrom utils read.table
#'
#' @examples
#' \dontrun{
#' # Create 3D-only atlas from label files
#' labels <- c("lh.region1.label", "lh.region2.label", "rh.region1.label")
#' atlas <- create_cortical_from_labels(labels, steps = 1)
#' ggseg3d(atlas = atlas)
#'
#' # Full atlas with 2D geometry
#' atlas <- create_cortical_from_labels(labels)
#'
#' # Iterate on smoothing parameters
#' atlas <- create_cortical_from_labels(labels, steps = 6:8, smoothness = 10)
#' }
create_cortical_from_labels <- function(
  label_files,
  atlas_name = NULL,
  input_lut = NULL,
  output_dir = NULL,
  views = c("lateral", "medial"),
  tolerance = NULL,
  smoothness = NULL,
  snapshot_dim = NULL,
  cleanup = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  skip_existing = NULL,
  steps = NULL
) {
  config <- validate_cortical_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    snapshot_dim,
    steps
  )

  if (any(config$steps > 1L)) {
    check_fs(abort = TRUE)
    check_magick()
  }

  if (!all(file.exists(label_files))) {
    missing <- # nolint: object_usage_linter
      label_files[!file.exists(label_files)]
    cli::cli_abort("Label files not found: {missing}")
  }

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(label_files[1])
  }

  lut_result <- parse_lut_colours(input_lut)
  default_colours <- rep(NA_character_, length(label_files))

  derive_hemisphere <- function(step1) {
    hemisphere <- unique(
      step1$components$core$hemi[!is.na(step1$components$core$hemi)]
    )
    hemi_short <- vapply(
      hemisphere,
      hemi_to_short,
      character(1),
      USE.NAMES = FALSE
    )
    if (length(hemi_short) == 0) c("lh", "rh") else hemi_short
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() {
      labels_read_files(
        label_files,
        lut_result$region_names,
        lut_result$colours,
        default_colours
      )
    },
    step_label = paste("1/8 Reading", length(label_files), "label files"),
    cache_label = "Step 1 (Read labels)",
    header_msg = "Creating brain atlas {.val {atlas_name}}",
    input_files = label_files,
    hemisphere_fn = derive_hemisphere,
    views = views,
    region_snapshot_fn = labels_region_snapshots
  )
}


# GIFTI atlas creation ----

#' Create cortical atlas from GIFTI annotation files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build a brain atlas from GIFTI label files (`.label.gii`). This is the
#' entry point for parcellations distributed in GIFTI format, such as those
#' from the Human Connectome Project or neuromaps.
#'
#' The function assumes fsaverage5 surface space (10,242 vertices per
#' hemisphere). No FreeSurfer installation is needed for 3D-only atlases
#' (`steps = 1`).
#'
#' @param gifti_files Character vector of paths to `.label.gii` files.
#'   Hemisphere is detected from filename patterns (`lh.`, `rh.`, `.L.`, `.R.`).
#' @template atlas_name
#' @template output_dir
#' @param hemisphere Which hemispheres to include: "lh", "rh", or both.
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smoothness
#' @template snapshot_dim
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run.
#'   See [create_cortical_from_annotation()] for step descriptions.
#'   Use `steps = 1` for 3D-only atlas.
#'
#' @return A `ggseg_atlas` object.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cortical_from_gifti(
#'   gifti_files = c("lh.aparc.label.gii", "rh.aparc.label.gii"),
#'   steps = 1
#' )
#' ggseg3d::ggseg3d(atlas = atlas)
#' }
create_cortical_from_gifti <- function(
  gifti_files,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smoothness = NULL,
  snapshot_dim = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  steps = NULL
) {
  if (length(gifti_files) == 0) {
    cli::cli_abort("{.arg gifti_files} must not be empty")
  }

  config <- validate_cortical_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    snapshot_dim,
    steps
  )

  if (any(config$steps > 1L)) {
    check_fs(abort = TRUE)
    check_magick()
  }

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(gifti_files[1])
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_gifti_annotation(gifti_files),
    step_label = "1/8 Reading GIFTI annotation files",
    cache_label = "Step 1 (Read GIFTI)",
    header_msg = "Creating brain atlas {.val {atlas_name}} from GIFTI",
    input_files = gifti_files,
    hemisphere = hemisphere,
    views = views
  )
}


# CIFTI atlas creation ----

#' Create cortical atlas from a CIFTI file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build a brain atlas from a CIFTI dense label file (`.dlabel.nii`).
#' A single CIFTI file contains data for both hemispheres. The file must
#' be in fsaverage5 space (10,242 vertices per hemisphere).
#'
#' No FreeSurfer installation is needed for 3D-only atlases (`steps = 1`).
#'
#' @param cifti_file Path to a `.dlabel.nii` CIFTI file.
#' @template atlas_name
#' @template output_dir
#' @param hemisphere Which hemispheres to include: "lh", "rh", or both.
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smoothness
#' @template snapshot_dim
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run.
#'   See [create_cortical_from_annotation()] for step descriptions.
#'   Use `steps = 1` for 3D-only atlas.
#'
#' @return A `ggseg_atlas` object.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cortical_from_cifti(
#'   cifti_file = "parcellation.dlabel.nii",
#'   steps = 1
#' )
#' ggseg3d::ggseg3d(atlas = atlas)
#' }
create_cortical_from_cifti <- function(
  cifti_file,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smoothness = NULL,
  snapshot_dim = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  steps = NULL
) {
  if (!file.exists(cifti_file)) {
    cli::cli_abort("CIFTI file not found: {.path {cifti_file}}")
  }

  config <- validate_cortical_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    snapshot_dim,
    steps
  )

  if (any(config$steps > 1L)) {
    check_fs(abort = TRUE)
    check_magick()
  }

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(cifti_file)
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_cifti_annotation(cifti_file),
    step_label = "1/8 Reading CIFTI file",
    cache_label = "Step 1 (Read CIFTI)",
    header_msg = "Creating brain atlas {.val {atlas_name}} from CIFTI",
    input_files = cifti_file,
    hemisphere = hemisphere,
    views = views
  )
}


# Neuromaps atlas creation ----

#' Create cortical atlas from a neuromaps annotation
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build a brain atlas directly from a [neuromaps](
#' https://github.com/netneurolab/neuromaps) annotation. The annotation
#' is downloaded via [neuromapr::fetch_neuromaps_annotation()].
#'
#' Supports both surface (`.func.gii`) and volume (`.nii`/`.nii.gz`)
#' annotations. Volume annotations in MNI152 space are automatically
#' projected to fsaverage5 via FreeSurfer's `mri_vol2surf`.
#'
#' Continuous brain maps (PET, gene expression, etc.) are discretized
#' into quantile bins via `n_bins`. Integer parcellation maps use
#' vertex value 0 as medial wall.
#'
#' Defaults to fsaverage5 surface space (`space = "fsaverage"`,
#' `density = "10k"`, 10,242 vertices per hemisphere). Surface
#' annotations need no FreeSurfer for 3D-only atlases (`steps = 1`);
#' volume annotations always require FreeSurfer.
#'
#' @param source Neuromaps source identifier (e.g., `"schaefer"`).
#'   See [neuromapr::neuromaps_available()] for options.
#' @param desc Neuromaps descriptor key (e.g., `"400Parcels7Networks"`).
#' @param space Coordinate space. Defaults to `"fsaverage"`.
#' @param density Surface vertex density. Defaults to `"10k"`
#'   (fsaverage5, 10,242 vertices).
#' @param label_table Optional data.frame mapping parcel IDs to region
#'   names. Must have columns `id` (integer) and `region` (character).
#'   Optionally include `colour` (hex string). When `NULL`, regions are
#'   auto-named.
#' @param n_bins Number of quantile bins for continuous brain maps.
#'   When `NULL` (default), auto-detected via Sturges' rule
#'   (`1 + log2(n)`, clamped to 5--20). Ignored for integer parcellation
#'   data. See [read_neuromaps_annotation()].
#' @template atlas_name
#' @template output_dir
#' @param hemisphere Which hemispheres to include: "lh", "rh", or both.
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smoothness
#' @template snapshot_dim
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run.
#'   See [create_cortical_from_annotation()] for step descriptions.
#'   Use `steps = 1` for 3D-only atlas.
#'
#' @return A `ggseg_atlas` object.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cortical_from_neuromaps(
#'   source = "abagen",
#'   desc = "genepc1",
#'   n_bins = 7,
#'   steps = 1
#' )
#' ggseg3d::ggseg3d(atlas = atlas)
#' }
create_cortical_from_neuromaps <- function(
  source,
  desc,
  space = "fsaverage",
  density = "10k",
  label_table = NULL,
  n_bins = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smoothness = NULL,
  snapshot_dim = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  steps = NULL
) {
  rlang::check_installed(
    "neuromapr",
    reason = "to download neuromaps annotations"
  )

  config <- validate_cortical_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness,
    snapshot_dim,
    steps
  )

  if (any(config$steps > 1L)) {
    check_fs(abort = TRUE)
    check_magick()
  }

  if (space != "fsaverage" || density != "10k") {
    cli::cli_warn(c(
      "Non-default space/density: {.val {space}} / {.val {density}}",
      "i" = paste(
        "The cortical pipeline requires fsaverage5",
        "(space='fsaverage', density='10k').",
        "Other values may cause vertex count mismatches."
      )
    ))
  }

  if (config$verbose) {
    cli::cli_alert_info(
      "Fetching neuromaps: source={.val {source}}, desc={.val {desc}}"
    )
  }

  gifti_files <- neuromapr::fetch_neuromaps_annotation(
    source = source,
    desc = desc,
    space = space,
    density = density,
    verbose = config$verbose
  )

  is_volume <- any(grepl(
    "\\.(nii|nii\\.gz)$",
    gifti_files,
    ignore.case = TRUE
  ))

  if (is_volume) {
    check_fs(abort = TRUE)
    if (config$verbose) {
      cli::cli_alert_info(
        paste(
          "Volume annotation detected --",
          "projecting to fsaverage5 surface via mri_vol2surf"
        )
      )
    }
  }

  if (is.null(atlas_name)) {
    atlas_name <- paste(source, desc, sep = "_")
  }

  output_base <- file.path(
    config$output_dir,
    atlas_name
  )
  mkdir(output_base)

  read_fn <- if (is_volume) {
    function() read_neuromaps_volume(gifti_files[1], n_bins, output_base)
  } else {
    function() read_neuromaps_annotation(gifti_files, label_table, n_bins)
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = read_fn,
    step_label = "1/8 Reading neuromaps annotation",
    cache_label = "Step 1 (Read neuromaps)",
    header_msg = "Creating brain atlas {.val {atlas_name}} from neuromaps",
    input_files = gifti_files,
    hemisphere = hemisphere,
    views = views
  )
}
