# Unified atlas creation ----

#' Create cortical atlas from FreeSurfer annotation
#'
#' @description
#' `r lifecycle::badge("maturing")`
#'
#' Turn FreeSurfer annotation files into a brain atlas you can plot with
#' ggseg and ggseg3d. Reads the annotation, extracts vertex-to-region
#' assignments, and generates 2D polygon geometry by projecting the
#' inflated mesh triangles to 2D via orthographic projection.
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
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object containing region metadata (core), vertex
#'   indices for 3D rendering, a colour palette, and sf geometry for 2D plots.
#' @export
#' @importFrom dplyr filter select mutate left_join group_by ungroup tibble
#'   bind_rows distinct
#' @importFrom furrr future_pmap furrr_options
#' @importFrom grDevices rgb
#' @importFrom progressr progressor
#' @importFrom sf st_as_sf st_combine
#' @importFrom tools file_path_sans_ext
#'
#' @examples
#' \dontrun{
#' atlas <- create_cortical_from_annotation(
#'   input_annot = c("lh.aparc.DKTatlas.annot", "rh.aparc.DKTatlas.annot")
#' )
#' ggseg(atlas = atlas)
#' }
# nolint next: object_length_linter.
create_cortical_from_annotation <- function(
  input_annot,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
) {
  if (length(input_annot) == 0) {
    cli::cli_abort("{.arg input_annot} must not be empty")
  }

  warn_deprecated_sf_smoothing(
    # nolint: object_usage_linter.
    tolerance = tolerance,
    smooth_refinements = smooth_refinements,
    fn = "create_cortical_from_annotation"
  )

  config <- validate_surface_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smooth_refinements
  )

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(input_annot[1])
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_annotation_data(input_annot),
    step_label = "Reading annotation files",
    cache_label = "Read annotations",
    header_msg = "Creating brain atlas {.val {atlas_name}}",
    input_files = input_annot,
    hemisphere = hemisphere,
    views = views
  )
}

#' Create brain atlas from label files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build an atlas from individual FreeSurfer `.label` files rather than a
#' complete annotation. Each label file defines a single region by listing
#' which surface vertices belong to it.
#'
#' The function detects hemisphere from filename prefixes (`lh.` or `rh.`) and
#' derives region names from the rest of the filename.
#'
#' @param label_files Paths to `.label` files. Each file should follow
#'   FreeSurfer naming: `{hemi}.{regionname}.label` (e.g., `lh.motor.label`).
#' @template atlas_name
#' @param input_lut Path to a color lookup table (LUT) file, or a data.frame
#'   with columns `region` and colour columns (R, G, B or hex).
#' @template output_dir
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object.
#' @export
#' @importFrom dplyr tibble bind_rows distinct
#' @importFrom grDevices rgb
#' @importFrom tools file_path_sans_ext
#' @importFrom utils read.table
#'
#' @examples
#' \dontrun{
#' labels <- c("lh.region1.label", "lh.region2.label", "rh.region1.label")
#' atlas <- create_cortical_from_labels(labels)
#' }
create_cortical_from_labels <- function(
  label_files,
  atlas_name = NULL,
  input_lut = NULL,
  output_dir = NULL,
  views = c("lateral", "medial"),
  tolerance = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  skip_existing = NULL
) {
  warn_deprecated_sf_smoothing(
    # nolint: object_usage_linter.
    tolerance = tolerance,
    smooth_refinements = smooth_refinements,
    fn = "create_cortical_from_labels"
  )

  config <- validate_surface_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smooth_refinements
  )

  if (!all(file.exists(label_files))) {
    missing <- # nolint: object_usage_linter
      label_files[!file.exists(label_files)]
    cli::cli_abort("Label files not found: {missing}")
  }

  run_label_atlas_creation(
    label_files = label_files,
    atlas_name = atlas_name,
    input_lut = input_lut,
    config = config,
    views = views
  )
}

#' Create cortical atlas from GIFTI annotation files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build a brain atlas from GIFTI label files (`.label.gii`).
#' Assumes fsaverage5 surface space (10,242 vertices per hemisphere).
#'
#' @param gifti_files Character vector of paths to `.label.gii` files.
#'   Hemisphere is detected from filename patterns (`lh.`, `rh.`, `.L.`, `.R.`).
#' @template atlas_name
#' @template output_dir
#' @param hemisphere Which hemispheres to include: "lh", "rh", or both.
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cortical_from_gifti(
#'   gifti_files = c("lh.aparc.label.gii", "rh.aparc.label.gii")
#' )
#' }
create_cortical_from_gifti <- function(
  gifti_files,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
) {
  if (length(gifti_files) == 0) {
    cli::cli_abort("{.arg gifti_files} must not be empty")
  }

  warn_deprecated_sf_smoothing(
    # nolint: object_usage_linter.
    tolerance = tolerance,
    smooth_refinements = smooth_refinements,
    fn = "create_cortical_from_gifti"
  )

  config <- validate_surface_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smooth_refinements
  )

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(gifti_files[1])
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_gifti_annotation(gifti_files),
    step_label = "Reading GIFTI annotation files",
    cache_label = "Read GIFTI",
    header_msg = "Creating brain atlas {.val {atlas_name}} from GIFTI",
    input_files = gifti_files,
    hemisphere = hemisphere,
    views = views
  )
}

#' Create cortical atlas from a CIFTI file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build a brain atlas from a CIFTI dense label file (`.dlabel.nii`).
#' The file must be in fsaverage5 space (10,242 vertices per hemisphere).
#'
#' @inheritParams read_cifti_annotation
#' @template atlas_name
#' @template output_dir
#' @param hemisphere Which hemispheres to include: "lh", "rh", or both.
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cortical_from_cifti(
#'   cifti_file = "parcellation.dlabel.nii"
#' )
#' }
create_cortical_from_cifti <- function(
  cifti_file,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
) {
  if (!file.exists(cifti_file)) {
    cli::cli_abort("CIFTI file not found: {.path {cifti_file}}")
  }

  warn_deprecated_sf_smoothing(
    # nolint: object_usage_linter.
    tolerance = tolerance,
    smooth_refinements = smooth_refinements,
    fn = "create_cortical_from_cifti"
  )

  config <- validate_surface_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smooth_refinements
  )

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(cifti_file)
  }

  run_cortical_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_cifti_annotation(cifti_file),
    step_label = "Reading CIFTI file",
    cache_label = "Read CIFTI",
    header_msg = "Creating brain atlas {.val {atlas_name}} from CIFTI",
    input_files = cifti_file,
    hemisphere = hemisphere,
    views = views
  )
}

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
#' @param source Neuromaps source identifier (e.g., `"schaefer"`).
#' @param desc Neuromaps descriptor key (e.g., `"400Parcels7Networks"`).
#' @param space Coordinate space. Defaults to `"fsaverage"`.
#' @param density Surface vertex density. Defaults to `"10k"`.
#' @param label_table Optional data.frame mapping parcel IDs to region names.
#' @param n_bins Number of quantile bins for continuous brain maps.
#' @template atlas_name
#' @template output_dir
#' @param hemisphere Which hemispheres to include: "lh", "rh", or both.
#' @param views Which views to include: "lateral", "medial",
#'   "superior", "inferior".
#' @template tolerance
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cortical_from_neuromaps(
#'   source = "abagen",
#'   desc = "genepc1",
#'   n_bins = 7
#' )
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
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
) {
  rlang::check_installed(
    "neuromapr",
    reason = "to download neuromaps annotations"
  )

  config <- setup_neuromaps_config(
    output_dir = output_dir,
    verbose = verbose,
    cleanup = cleanup,
    skip_existing = skip_existing,
    tolerance = tolerance,
    smooth_refinements = smooth_refinements
  )

  run_neuromaps_creation(
    source = source,
    desc = desc,
    space = space,
    density = density,
    label_table = label_table,
    n_bins = n_bins,
    atlas_name = atlas_name,
    config = config,
    hemisphere = hemisphere,
    views = views
  )
}


#' Derive, read and build a cortical atlas from FreeSurfer label files
#' @noRd
run_label_atlas_creation <- function(
  label_files,
  atlas_name,
  input_lut,
  config,
  views
) {
  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(label_files[1])
  }

  lut_result <- parse_lut_colours(input_lut)
  default_colours <- rep(NA_character_, length(label_files))

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
    step_label = paste("Reading", length(label_files), "label files"),
    cache_label = "Read labels",
    header_msg = "Creating brain atlas {.val {atlas_name}}",
    input_files = label_files,
    hemisphere_fn = derive_label_hemisphere,
    views = views
  )
}


#' @noRd
derive_label_hemisphere <- function(step1) {
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


#' Warn about deprecated smoothing args and resolve the cortical config
#' @noRd
setup_neuromaps_config <- function(
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  tolerance,
  smooth_refinements
) {
  warn_deprecated_sf_smoothing(
    tolerance = tolerance,
    smooth_refinements = smooth_refinements,
    fn = "create_cortical_from_neuromaps"
  )

  validate_surface_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smooth_refinements
  )
}


#' Fetch a neuromaps annotation and run the cortical creation sequence
#' @noRd
run_neuromaps_creation <- function(
  source,
  desc,
  space,
  density,
  label_table,
  n_bins,
  atlas_name,
  config,
  hemisphere,
  views
) {
  warn_neuromaps_space(space, density)

  gifti_files <- fetch_neuromaps_files(
    source = source,
    desc = desc,
    space = space,
    density = density,
    config = config
  )

  is_volume <- detect_neuromaps_volume(gifti_files, config)

  if (is.null(atlas_name)) {
    atlas_name <- paste(source, desc, sep = "_")
  }

  output_base <- file.path(config$output_dir, atlas_name)
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
    step_label = "Reading neuromaps annotation",
    cache_label = "Read neuromaps",
    header_msg = "Creating brain atlas {.val {atlas_name}} from neuromaps",
    input_files = gifti_files,
    hemisphere = hemisphere,
    views = views
  )
}


#' Warn when the neuromaps space/density is not fsaverage5
#' @noRd
warn_neuromaps_space <- function(space, density) {
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
}


#' Download the neuromaps annotation files
#' @noRd
fetch_neuromaps_files <- function(source, desc, space, density, config) {
  if (config$verbose) {
    cli::cli_alert_info(
      "Fetching neuromaps: source={.val {source}}, desc={.val {desc}}"
    )
  }

  neuromapr::fetch_neuromaps_annotation(
    source = source,
    desc = desc,
    space = space,
    density = density,
    verbose = config$verbose
  )
}


#' Detect a volume annotation and check FreeSurfer is available for it
#' @noRd
detect_neuromaps_volume <- function(gifti_files, config) {
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

  is_volume
}


#' Run the standard cortical atlas creation sequence
#'
#' Shared by annotation, GIFTI, CIFTI, and neuromaps entry points.
#' Reads input data (with caching), projects mesh to 2D, and returns atlas.
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
  views = c("lateral", "medial", "superior", "inferior")
) {
  start_time <- Sys.time()
  dirs <- setup_atlas_dirs(config$output_dir, atlas_name, type = "cortical")

  if (config$verbose) {
    cli::cli_h1(header_msg)
    cli::cli_alert_info("Input files: {.path {input_files}}")
  }

  step1 <- cortical_read_data(
    config,
    dirs,
    atlas_name,
    read_fn = read_fn,
    step_label = step_label,
    cache_label = cache_label
  )

  if (!is.null(hemisphere_fn)) {
    hemisphere <- hemisphere_fn(step1)
  }

  cortical_project_and_build(
    components = step1$components,
    atlas_name = atlas_name,
    hemisphere = hemisphere,
    views = views,
    config = config,
    dirs = dirs,
    start_time = start_time
  )
}


# Cortical pipeline helpers ----

#' @noRd
cortical_read_data <- function(
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
      cli::cli_alert_success("Loaded cached atlas data")
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
    data = ggseg_data_cortical(vertices = components$vertices_df)
  )

  saveRDS(atlas_3d, file.path(dirs$base, "atlas_3d.rds"))
  saveRDS(components, file.path(dirs$base, "components.rds"))
  cli::cli_progress_done()

  list(atlas_3d = atlas_3d, components = components)
}


#' @noRd
cortical_project_and_build <- function(
  components,
  atlas_name,
  hemisphere,
  views,
  config,
  dirs,
  start_time
) {
  if (config$verbose) {
    cli::cli_progress_step("Projecting mesh to 2D polygons")
  }

  sf_data <- cortical_build_sf_projected(
    components,
    hemisphere,
    views,
    tolerance = config$tolerance,
    smooth_refinements = config$smooth_refinements,
    verbose = config$verbose
  )

  if (config$verbose) {
    cli::cli_progress_done()
  }

  atlas <- ggseg_atlas(
    atlas = atlas_name,
    type = "cortical",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_cortical(
      geom = sf_data,
      vertices = components$vertices_df
    )
  )

  atlas <- ggseg.formats::atlas_view_gather(atlas)

  cortical_finalize(atlas, config, dirs, start_time)
}


#' @noRd
cortical_finalize <- function(atlas, config, dirs, start_time) {
  if (config$cleanup) {
    unlink(dirs$base, recursive = TRUE)
    if (config$verbose) cli::cli_alert_success("Temporary files removed")
  }

  if (config$verbose) {
    cli::cli_alert_success(
      "Brain atlas created with {nrow(atlas$core)} regions"
    )
    log_elapsed(start_time) # nolint: object_usage_linter.
  }

  warn_if_large_atlas(atlas)
  preview_atlas(atlas)

  if (ggseg.formats::is_atlas_sf(atlas)) {
    atlas <- ggseg.formats::as_polygon_atlas(atlas)
  }
  atlas
}

# Label atlas creation ----

# GIFTI atlas creation ----

# CIFTI atlas creation ----

# Neuromaps atlas creation ----
