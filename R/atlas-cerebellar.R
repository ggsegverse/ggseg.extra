# SUIT surface helpers ----

#' Path to bundled SUIT flatmap surface
#'
#' Returns the path to the SUIT flatmap surface file (`tpl-SUIT_flat.surf.gii`)
#' shipped with ggseg.extra. This is the standard 2D representation of the
#' cerebellar cortex from the Diedrichsen Lab SUIT template.
#'
#' @return File path to the SUIT flatmap `.surf.gii` file.
#' @export
#' @examples
#' suit_flatmap_path()
suit_flatmap_path <- function() {
  path <- system.file(
    "extdata", "suit", "tpl-SUIT_flat.surf.gii",
    package = "ggseg.extra"
  )
  if (path == "") {
    cli::cli_abort(
      "SUIT flatmap surface not found in ggseg.extra installation"
    )
  }
  path
}

#' Path to bundled SUIT 3D cerebellar surface
#'
#' Returns the path to the SUIT 3D pial surface file (`tpl-SUIT_3d.surf.gii`)
#' shipped with ggseg.extra. Used for volume-to-surface sampling of
#' cerebellar parcellation volumes.
#'
#' @return File path to the SUIT 3D `.surf.gii` file.
#' @export
#' @examples
#' suit_3d_path()
suit_3d_path <- function() {
  path <- system.file(
    "extdata", "suit", "tpl-SUIT_3d.surf.gii",
    package = "ggseg.extra"
  )
  if (path == "") {
    cli::cli_abort(
      "SUIT 3D surface not found in ggseg.extra installation"
    )
  }
  path
}


#' Download SUIT deformation field for MNI-to-SUIT transforms
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads the nonlinear deformation field needed to transform volumes
#' from MNI152 space to SUIT cerebellar space. The files are cached in
#' the user's data directory so they only need to be downloaded once.
#'
#' Two MNI templates are supported:
#' - `"MNI152NLin6AsymC"`: FSL MNI152 template (used by FreeSurfer).
#'   Use this for FreeSurfer's Buckner cerebellar atlases.
#' - `"MNI152NLin2009cSymC"`: ICBM 2009c symmetric template.
#'
#' @param template Which MNI template the source volume is in.
#'   Default `"MNI152NLin6AsymC"` (FreeSurfer/FSL).
#' @param cache_dir Directory for caching downloaded files. Defaults to
#'   `tools::R_user_dir("ggseg.extra", "data")`.
#'
#' @return Path to the downloaded deformation field NIfTI file.
#' @export
#'
#' @examples
#' \dontrun{
#' xfm <- suit_deformation_field()
#' suit_vol <- transform_mni_to_suit(mni_volume, xfm)
#' }
suit_deformation_field <- function(
  template = c("MNI152NLin6AsymC", "MNI152NLin2009cSymC"),
  cache_dir = NULL
) {
  template <- match.arg(template)

  if (is.null(cache_dir)) {
    cache_dir <- tools::R_user_dir("ggseg.extra", "data")
  }
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  filename <- paste0(
    "tpl-SUIT_from-", template, "_mode-image_xfm.nii"
  )
  cached_path <- file.path(cache_dir, filename)

  if (file.exists(cached_path)) {
    return(cached_path)
  }

  if (!has_internet()) {
    cli::cli_abort(c(
      "No internet connection available",
      "i" = "The deformation field {.file {filename}} is not cached",
      "i" = "Connect to the internet and try again"
    ))
  }

  url <- paste0(
    "https://raw.githubusercontent.com/DiedrichsenLab/",
    "cerebellar_atlases/master/tpl-SUIT/", filename
  )

  cli::cli_alert_info("Downloading {.file {filename}} (~13 MB)")

  tryCatch(
    utils::download.file(url, cached_path, mode = "wb", quiet = TRUE),
    error = function(e) {
      unlink(cached_path)
      cli::cli_abort(c(
        "Failed to download deformation field",
        "i" = "URL: {.url {url}}",
        "x" = "{conditionMessage(e)}"
      ))
    }
  )

  if (!file.exists(cached_path) || file.size(cached_path) < 1e6) {
    unlink(cached_path)
    cli::cli_abort(
      "Download appears incomplete. Please try again."
    )
  }

  cli::cli_alert_success("Cached at {.path {cached_path}}")
  cached_path
}


#' Check internet connectivity
#' @noRd
has_internet <- function() {
  tryCatch(
    {
      con <- url("https://raw.githubusercontent.com", open = "r")
      close(con)
      TRUE
    },
    error = function(e) FALSE
  )
}


# MNI to SUIT transform ----

#' Transform a volume from MNI space to SUIT cerebellar space
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Resamples a volumetric parcellation from MNI152 space into the SUIT
#' cerebellar template space using a nonlinear deformation field. This is
#' required when working with cerebellar atlases that are distributed in
#' MNI space (e.g., the Buckner cerebellar network parcellations shipped
#' with FreeSurfer).
#'
#' The deformation field must be a 5D NIfTI file where each SUIT-space
#' voxel stores the corresponding MNI coordinate to sample from. These
#' are available from the Diedrichsen Lab cerebellar atlases repository
#' as `tpl-SUIT_from-MNI152NLin*_mode-image_xfm.nii`.
#'
#' @param input_volume Path to the MNI-space volume (NIfTI).
#' @param deformation_field Path to the SUIT deformation field NIfTI.
#'   A 5D volume (x, y, z, 1, 3) mapping SUIT voxels to MNI coordinates.
#' @param output_file Path for the output SUIT-space volume. If NULL,
#'   writes to a temporary file.
#' @param interpolation Interpolation method: `"nearest"` (default, for
#'   parcellations/labels) or `"linear"` (for continuous maps).
#'
#' @return Path to the output SUIT-space NIfTI file (invisibly).
#' @export
#'
#' @examples
#' \dontrun{
#' suit_vol <- transform_mni_to_suit(
#'   input_volume = "Buckner2011_7Networks.nii.gz",
#'   deformation_field = "tpl-SUIT_from-MNI152NLin6AsymC_mode-image_xfm.nii"
#' )
#' atlas <- create_cerebellar_from_volume(volume = suit_vol)
#' }
transform_mni_to_suit <- function(
  input_volume,
  deformation_field,
  output_file = NULL,
  interpolation = c("nearest", "linear")
) {
  rlang::check_installed("RNifti", reason = "to read NIfTI volumes")
  interpolation <- match.arg(interpolation)

  if (!file.exists(input_volume)) {
    cli::cli_abort("Input volume not found: {.path {input_volume}}")
  }
  if (!file.exists(deformation_field)) {
    cli::cli_abort("Deformation field not found: {.path {deformation_field}}")
  }

  if (is.null(output_file)) {
    output_file <- tempfile(fileext = ".nii.gz")
  }

  mni_vol <- RNifti::readNifti(input_volume, internal = FALSE)
  xfm <- RNifti::readNifti(deformation_field, internal = FALSE)

  xfm_dims <- dim(xfm)
  if (length(xfm_dims) != 5 || xfm_dims[4] != 1 || xfm_dims[5] != 3) {
    cli::cli_abort(c(
      "Deformation field must be a 5D NIfTI (x, y, z, 1, 3)",
      "i" = "Got dimensions: {paste(xfm_dims, collapse = ' x ')}"
    ))
  }

  suit_dims <- xfm_dims[1:3]
  result <- array(0, dim = suit_dims)

  mni_coords_x <- xfm[, , , 1, 1]
  mni_coords_y <- xfm[, , , 1, 2]
  mni_coords_z <- xfm[, , , 1, 3]

  mni_coords <- cbind(
    c(mni_coords_x), c(mni_coords_y), c(mni_coords_z)
  )

  vox_coords <- RNifti::worldToVoxel(mni_coords, mni_vol)

  mni_arr <- drop(as.array(mni_vol))
  mni_dims <- dim(mni_arr)
  if (length(mni_dims) != 3) {
    cli::cli_abort("Input volume must be 3D, got {length(mni_dims)}D")
  }

  if (interpolation == "nearest") {
    vox_round <- round(vox_coords)
    valid <- vox_round[, 1] >= 1 & vox_round[, 1] <= mni_dims[1] &
      vox_round[, 2] >= 1 & vox_round[, 2] <= mni_dims[2] &
      vox_round[, 3] >= 1 & vox_round[, 3] <= mni_dims[3]
    idx <- which(valid)
    for (i in idx) {
      vi <- vox_round[i, ]
      result[i] <- mni_arr[vi[1], vi[2], vi[3]]
    }
  } else {
    for (i in seq_len(nrow(vox_coords))) {
      vi <- vox_coords[i, ]
      if (any(vi < 1) || vi[1] > mni_dims[1] ||
            vi[2] > mni_dims[2] || vi[3] > mni_dims[3]) next

      x0 <- floor(vi[1])
      x1 <- min(x0 + 1L, mni_dims[1])
      y0 <- floor(vi[2])
      y1 <- min(y0 + 1L, mni_dims[2])
      z0 <- floor(vi[3])
      z1 <- min(z0 + 1L, mni_dims[3])
      xd <- vi[1] - x0
      yd <- vi[2] - y0
      zd <- vi[3] - z0

      result[i] <-
        mni_arr[x0, y0, z0] * (1 - xd) * (1 - yd) * (1 - zd) +
        mni_arr[x1, y0, z0] * xd * (1 - yd) * (1 - zd) +
        mni_arr[x0, y1, z0] * (1 - xd) * yd * (1 - zd) +
        mni_arr[x0, y0, z1] * (1 - xd) * (1 - yd) * zd +
        mni_arr[x1, y1, z0] * xd * yd * (1 - zd) +
        mni_arr[x0, y1, z1] * (1 - xd) * yd * zd +
        mni_arr[x1, y0, z1] * xd * (1 - yd) * zd +
        mni_arr[x1, y1, z1] * xd * yd * zd
    }
  }

  ref_nii <- RNifti::asNifti(array(0, dim = suit_dims), reference = xfm)
  out_nii <- RNifti::asNifti(result, reference = ref_nii)
  RNifti::writeNifti(out_nii, output_file)

  invisible(output_file)
}


# Cerebellar atlas creation ----

#' Create cerebellar atlas from SUIT flatmap
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Turn SUIT cerebellar parcellation files into a brain atlas you can plot
#' with ggseg and ggseg3d. Reads GIFTI label files containing vertex-to-region
#' assignments and projects them onto the SUIT flatmap surface to generate
#' 2D polygon geometry. Optionally tessellates per-region 3D meshes from a
#' cerebellar segmentation volume.
#'
#' The SUIT (Spatially Unbiased Infratentorial Template) flatmap is a standard
#' 2D representation of the cerebellar cortex. Unlike cortical atlases that
#' require orthographic projection of an inflated mesh, the flatmap surface
#' already contains 2D coordinates.
#'
#' @param gifti_files Character vector of paths to GIFTI label files
#'   (`.label.gii` or `.func.gii`) containing the cerebellar parcellation.
#' @param volume Optional path to a cerebellar segmentation volume (NIfTI)
#'   for 3D mesh generation. When provided, per-region meshes are tessellated
#'   using FreeSurfer tools and included in the atlas for 3D rendering.
#' @template atlas_name
#' @template output_dir
#' @template tolerance
#' @template smooth_refinements
#' @template decimate
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object of type "cerebellar" containing region
#'   metadata (core), a colour palette, sf geometry for 2D plots, and
#'   optionally 3D meshes.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cerebellar_from_gifti(
#'   gifti_files = "Lobules-SUIT.label.gii"
#' )
#' ggseg(atlas = atlas)
#' }
create_cerebellar_from_gifti <- function(
  gifti_files,
  volume = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  tolerance = NULL,
  smooth_refinements = NULL,
  decimate = 0.5,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
) {
  if (length(gifti_files) == 0) {
    cli::cli_abort("{.arg gifti_files} must not be empty")
  }

  config <- validate_cerebellar_config(
    output_dir, verbose, cleanup, skip_existing, tolerance,
    smooth_refinements
  )

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(gifti_files[1])
  }

  run_cerebellar_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_suit_parcellation(gifti_files),
    volume = volume,
    decimate = decimate,
    input_files = gifti_files
  )
}


#' Create cerebellar atlas from FreeSurfer annotation
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads FreeSurfer annotation files (`.annot`) on the SUIT cerebellar surface
#' and projects them onto the SUIT flatmap for 2D polygon geometry.
#'
#' @param input_annot Character vector of paths to annotation files on the
#'   SUIT cerebellar surface.
#' @param volume Optional path to a cerebellar segmentation volume (NIfTI)
#'   for 3D mesh generation.
#' @template atlas_name
#' @template output_dir
#' @template tolerance
#' @template smooth_refinements
#' @template decimate
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object of type "cerebellar".
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cerebellar_from_annotation(
#'   input_annot = "cerebellum.annot"
#' )
#' }
# nolint next: object_length_linter.
create_cerebellar_from_annotation <- function(
  input_annot,
  volume = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  tolerance = NULL,
  smooth_refinements = NULL,
  decimate = 0.5,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
) {
  if (length(input_annot) == 0) {
    cli::cli_abort("{.arg input_annot} must not be empty")
  }

  config <- validate_cerebellar_config(
    output_dir, verbose, cleanup, skip_existing, tolerance,
    smooth_refinements
  )

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(input_annot[1])
  }

  run_cerebellar_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_cerebellar_annotation(input_annot),
    volume = volume,
    decimate = decimate,
    input_files = input_annot
  )
}


#' Create cerebellar atlas from volume segmentation
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Creates a cerebellar atlas from a NIfTI segmentation volume. Uses the
#' bundled SUIT 3D surface for volume-to-surface sampling and the SUIT flatmap
#' for 2D polygon generation. Per-region 3D meshes are tessellated from the
#' volume for 3D rendering.
#'
#' @param volume Path to a cerebellar segmentation volume (NIfTI).
#' @param input_lut Optional path to a colour lookup table file, or a
#'   data.frame with columns `idx`, `label`, and optionally `R`, `G`, `B`.
#'   If NULL, labels are auto-generated from volume values.
#' @template atlas_name
#' @template output_dir
#' @template tolerance
#' @template smooth_refinements
#' @template decimate
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object of type "cerebellar" with both sf geometry
#'   and 3D meshes.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cerebellar_from_volume(
#'   volume = "cerebellar_parcellation.nii.gz"
#' )
#' }
# nolint next: object_length_linter.
create_cerebellar_from_volume <- function(
  volume,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  tolerance = NULL,
  smooth_refinements = NULL,
  decimate = 0.5,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
) {
  if (missing(volume) || is.null(volume)) {
    cli::cli_abort("{.arg volume} is required")
  }
  if (!file.exists(volume)) {
    cli::cli_abort("Volume file not found: {.path {volume}}")
  }

  config <- validate_cerebellar_config(
    output_dir, verbose, cleanup, skip_existing, tolerance,
    smooth_refinements
  )

  if (is.null(atlas_name)) {
    atlas_name <- derive_atlas_name(volume)
  }

  run_cerebellar_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() {
      read_cerebellar_volume(volume, suit_3d_path(), input_lut)
    },
    volume = volume,
    decimate = decimate,
    input_files = c(volume, suit_3d_path())
  )
}


# Cerebellar pipeline helpers ----

#' @noRd
validate_cerebellar_config <- function(
  output_dir, verbose, cleanup, skip_existing, tolerance,
  smooth_refinements = NULL
) {
  config <- resolve_common_config(
    output_dir, verbose, cleanup, skip_existing,
    tolerance, smoothness = NULL, steps = NULL, max_step = 2L
  )
  config$smooth_refinements <- get_smooth_refinements(smooth_refinements)

  config
}


#' @noRd
run_cerebellar_creation <- function(
  atlas_name,
  config,
  read_fn,
  volume = NULL,
  decimate = 0.5,
  input_files
) {
  start_time <- Sys.time()
  dirs <- setup_atlas_dirs(config$output_dir, atlas_name, type = "cerebellar")

  if (config$verbose) {
    cli::cli_h1("Creating cerebellar atlas {.val {atlas_name}}")
    cli::cli_alert_info("Input files: {.path {input_files}}")
    if (!is.null(volume)) {
      cli::cli_alert_info("Volume for 3D meshes: {.path {volume}}")
    }
  }

  step1 <- cerebellar_read_data(
    config, dirs, read_fn = read_fn
  )

  cerebellar_project_and_build(
    components = step1$components,
    volume = volume,
    decimate = decimate,
    atlas_name = atlas_name,
    config = config,
    dirs = dirs,
    start_time = start_time
  )
}


#' @noRd
cerebellar_read_data <- function(config, dirs, read_fn) {
  files <- file.path(dirs$base, "components.rds")
  cached <- load_or_run_step(
    1L, config$steps, files, config$skip_existing, "Read parcellation"
  )

  if (!cached$run) {
    if (config$verbose) {
      cli::cli_alert_success("Loaded cached atlas data")
    }
    return(list(
      components = cached$data[["components.rds"]]
    ))
  }

  if (config$verbose) {
    cli::cli_progress_step("Reading SUIT parcellation")
  }

  atlas_data <- read_fn()
  if (nrow(atlas_data) == 0) {
    cli::cli_abort("No regions found in input files")
  }

  components <- build_atlas_components(atlas_data)
  saveRDS(components, file.path(dirs$base, "components.rds"))
  cli::cli_progress_done()

  list(components = components)
}


#' @noRd
cerebellar_project_and_build <- function(
  components, volume = NULL, decimate = 0.5,
  atlas_name, config, dirs, start_time
) {
  if (config$verbose) {
    cli::cli_progress_step("Projecting parcellation onto SUIT flatmap")
  }

  sf_data <- cerebellar_build_sf_flatmap(
    components, suit_flatmap_path(),
    tolerance = config$tolerance,
    smooth_refinements = config$smooth_refinements,
    verbose = config$verbose
  )

  if (config$verbose) cli::cli_progress_done()

  meshes_df <- NULL
  if (!is.null(volume)) {
    if (config$verbose) {
      cli::cli_progress_step("Tessellating 3D meshes from volume")
    }
    meshes_df <- cerebellar_create_meshes(
      volume = volume,
      components = components,
      dirs = dirs,
      skip_existing = config$skip_existing,
      verbose = config$verbose,
      decimate = decimate
    )
    if (config$verbose) cli::cli_progress_done()
  }

  atlas <- ggseg_atlas(
    atlas = atlas_name,
    type = "cerebellar",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_cerebellar(
      sf = sf_data,
      meshes = meshes_df
    )
  )

  cortical_finalize(atlas, config, dirs, start_time)
}


#' Tessellate per-region 3D meshes from cerebellar volume
#'
#' Wraps the subcortical tessellation machinery to create per-region meshes
#' from a cerebellar segmentation volume.
#'
#' @param volume Path to cerebellar segmentation NIfTI file.
#' @param components Atlas components from `build_atlas_components()`.
#' @param dirs Directory structure from `setup_atlas_dirs()`.
#' @param skip_existing Logical.
#' @param verbose Logical.
#' @param decimate Decimation factor (0-1).
#' @return Data frame with columns `label` and `mesh` (list-column),
#'   or NULL if tessellation fails entirely.
#' @noRd
cerebellar_create_meshes <- function(
  volume, components, dirs, skip_existing, verbose, decimate
) {
  check_fs(abort = TRUE)

  if (!file.exists(volume)) {
    cli::cli_abort("Volume file not found: {.path {volume}}")
  }

  vol <- read_volume(volume)
  vol_ids <- sort(unique(as.integer(vol)))
  vol_ids <- vol_ids[vol_ids > 0L]

  labels <- components$core$label
  if (length(vol_ids) < length(labels)) {
    cli::cli_warn(c(
      paste(
        "Volume has {length(vol_ids)} non-zero labels but atlas",
        "has {length(labels)} regions"
      ),
      "i" = "Only labels found in the volume will get 3D meshes"
    ))
    labels <- labels[seq_along(vol_ids)]
  }

  colortable <- data.frame(
    idx = vol_ids[seq_along(labels)],
    label = labels,
    stringsAsFactors = FALSE
  )

  meshes_list <- subcort_create_meshes(
    input_volume = volume,
    colortable = colortable,
    dirs = dirs,
    skip_existing = skip_existing,
    verbose = verbose,
    decimate = decimate
  )

  meshes_df <- data.frame(
    label = names(meshes_list),
    stringsAsFactors = FALSE
  )
  meshes_df$mesh <- unname(meshes_list)
  meshes_df
}


# SUIT parcellation reader ----

#' Read SUIT cerebellar parcellation from GIFTI
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads GIFTI label files containing cerebellar parcellations and returns
#' a data frame compatible with `build_atlas_components()`. Handles
#' SUIT-specific label conventions where regions are prefixed with
#' "Left", "Right", or "Vermis".
#'
#' @param gifti_files Character vector of paths to GIFTI label files.
#' @return A tibble with columns: `hemi`, `region`, `label`, `colour`,
#'   `vertices` (list-column of 0-indexed integer vectors).
#' @export
#'
#' @examples
#' \dontrun{
#' parcellation <- read_suit_parcellation("Lobules-SUIT.label.gii")
#' }
read_suit_parcellation <- function(gifti_files) {
  rlang::check_installed("gifti", reason = "to read GIFTI label files")

  if (!all(file.exists(gifti_files))) {
    missing <- gifti_files[!file.exists(gifti_files)] # nolint
    cli::cli_abort(
      "GIFTI file{?s} not found: {.path {missing}}"
    )
  }

  all_data <- list()

  for (gifti_file in gifti_files) {
    gii <- gifti::readgii(gifti_file)

    data_arrays <- gii$data
    if (is.null(data_arrays) || length(data_arrays) == 0) {
      cli::cli_warn("No data arrays in {.path {gifti_file}}, skipping")
      next
    }

    label_array <- data_arrays[[1]]
    if (is.matrix(label_array)) label_array <- label_array[, 1]
    values <- as.integer(label_array)

    if (length(values) == 0) {
      cli::cli_warn("Empty data array in {.path {gifti_file}}, skipping")
      next
    }

    label_table <- extract_gifti_label_table(gii)

    unique_ids <- sort(unique(values))

    for (pid in unique_ids) {
      if (pid == 0L) next

      region_vertices <- which(values == pid) - 1L
      if (length(region_vertices) == 0) next

      if (!is.null(label_table) && pid %in% label_table$id) {
        row <- label_table[label_table$id == pid, ]
        region_name <- row$name[1]
        colour <- row$colour[1]
      } else {
        region_name <- paste0("region_", pid)
        colour <- NA_character_
      }

      hemi <- detect_cerebellar_hemi(region_name)
      region <- clean_cerebellar_region(region_name)
      label <- paste(hemi, region, sep = "_")

      all_data[[length(all_data) + 1]] <- dplyr::tibble(
        hemi = hemi,
        region = region,
        label = label,
        colour = colour,
        vertices = list(region_vertices)
      )
    }
  }

  if (length(all_data) == 0) {
    return(dplyr::tibble(
      hemi = character(),
      region = character(),
      label = character(),
      colour = character(),
      vertices = list()
    ))
  }

  result <- dplyr::bind_rows(all_data)

  needs_colour <- is.na(result$colour) & result$region != "unknown"
  if (any(needs_colour)) {
    n_missing <- sum(needs_colour)
    result$colour[needs_colour] <- grDevices::hcl.colors(
      n_missing, palette = "Set2"
    )
  }

  result
}


#' Extract label table from GIFTI metadata
#'
#' GIFTI label files store region names and colours in a LabelTable element.
#' The `gifti` package parses this into a matrix/data.frame with rownames as
#' label names, and columns Key, Red, Green, Blue, Alpha (all character).
#'
#' @param gii A GIFTI object from `gifti::readgii()`.
#' @return Data frame with columns: id, name, colour. NULL if no label table.
#' @noRd
extract_gifti_label_table <- function(gii) {
  lt <- gii$label
  if (is.null(lt)) return(NULL)

  if (is.data.frame(lt) || is.matrix(lt)) {
    col_names <- if (is.matrix(lt)) colnames(lt) else names(lt)

    if ("Key" %in% col_names) {
      result <- data.frame(
        id = as.integer(lt[, "Key"]),
        name = rownames(lt),
        stringsAsFactors = FALSE
      )
      if (all(c("Red", "Green", "Blue") %in% col_names)) {
        result$colour <- grDevices::rgb(
          as.numeric(lt[, "Red"]),
          as.numeric(lt[, "Green"]),
          as.numeric(lt[, "Blue"])
        )
      } else {
        result$colour <- NA_character_
      }
      return(result)
    }

    if ("key" %in% col_names && "label" %in% col_names) {
      result <- data.frame(
        id = as.integer(lt[, "key"]),
        name = as.character(lt[, "label"]),
        stringsAsFactors = FALSE
      )
      if (all(c("red", "green", "blue") %in% col_names)) {
        result$colour <- grDevices::rgb(
          as.numeric(lt[, "red"]),
          as.numeric(lt[, "green"]),
          as.numeric(lt[, "blue"])
        )
      } else {
        result$colour <- NA_character_
      }
      return(result)
    }
  }

  NULL
}


#' Detect cerebellar hemisphere from region name
#'
#' Maps SUIT-style region names to hemisphere values. Recognises
#' "Left"/"Right" prefixes and assigns "Vermis" labels to the
#' "vermis" hemisphere. Unlabelled regions default to "midline".
#'
#' @param region_name Character string.
#' @return "left", "right", "vermis", or "midline".
#' @noRd
detect_cerebellar_hemi <- function(region_name) {
  if (grepl("^(Left|left|L)[- _.]", region_name)) return("left")
  if (grepl("^(Right|right|R)[- _.]", region_name)) return("right")
  if (grepl("^(Vermis|vermis|V)[- _.]", region_name)) return("vermis")
  if (grepl("vermis", region_name, ignore.case = TRUE)) return("vermis")

  hemi <- detect_hemi(region_name, default = "midline")
  hemi
}


#' Clean cerebellar region name
#'
#' Removes hemisphere/vermis prefix from SUIT label names to produce
#' a clean region identifier.
#'
#' @param region_name Raw label name from GIFTI.
#' @return Cleaned region name.
#' @noRd
clean_cerebellar_region <- function(region_name) {
  region <- gsub(
    "^(Left|Right|Vermis|left|right|vermis|L|R|V)[- _.]\\s*",
    "", region_name
  )
  region <- trimws(region)
  if (nchar(region) == 0) region <- region_name
  region <- gsub("\\s+", " ", region)
  region
}


# Cerebellar annotation reader ----

#' Read cerebellar annotation files
#'
#' Reads FreeSurfer `.annot` files on a SUIT cerebellar surface and returns
#' atlas data with cerebellar hemisphere detection (Left/Right/Vermis).
#'
#' @param annot_files Character vector of paths to annotation files.
#' @return A tibble with columns: hemi, region, label, colour, vertices.
#' @noRd
read_cerebellar_annotation <- function(annot_files) {
  rlang::check_installed(
    "freesurferformats",
    reason = "to read annotation files"
  )

  if (!all(file.exists(annot_files))) {
    missing <- annot_files[!file.exists(annot_files)] # nolint
    cli::cli_abort("Annotation file{?s} not found: {.path {missing}}")
  }

  all_data <- list()

  for (annot_file in annot_files) {
    annot <- freesurferformats::read.fs.annot(annot_file)
    ct <- annot$colortable_df
    ct <- ct[!is.na(ct$r), ]

    label_codes <- annot$label_codes

    for (i in seq_len(nrow(ct))) {
      code <- ct$code[i]
      region_name <- ct$struct_name[i]
      colour <- ct$hex_color_string_rgb[i]

      region_vertices <- which(label_codes == code) - 1L
      if (length(region_vertices) == 0) next

      if (tolower(region_name) %in% c("unknown", "corpuscallosum")) next

      hemi <- detect_cerebellar_hemi(region_name)
      region <- clean_cerebellar_region(region_name)
      label <- paste(hemi, region, sep = "_")

      all_data[[length(all_data) + 1]] <- dplyr::tibble(
        hemi = hemi,
        region = region,
        label = label,
        colour = colour,
        vertices = list(region_vertices)
      )
    }
  }

  if (length(all_data) == 0) {
    cli::cli_abort("No regions found in annotation files")
  }

  dplyr::bind_rows(all_data)
}


# Cerebellar volume reader ----

#' Read cerebellar volume and sample onto SUIT surface
#'
#' Reads a NIfTI cerebellar segmentation volume and samples it at each vertex
#' of the SUIT 3D cerebellar surface. Returns vertex-to-region mappings
#' compatible with the cerebellar flatmap projection pipeline.
#'
#' @param volume Path to NIfTI cerebellar segmentation file.
#' @param suit_3d_surface Path to SUIT 3D cerebellar surface (`.surf.gii`).
#' @param input_lut Optional LUT: path to a colour table file, or a
#'   data.frame with columns `idx`, `label`, and optionally `R`, `G`, `B`.
#' @return A tibble with columns: hemi, region, label, colour, vertices.
#' @noRd
read_cerebellar_volume <- function(volume, suit_3d_surface, input_lut = NULL) {
  rlang::check_installed("gifti", reason = "to read SUIT surface files")
  rlang::check_installed("RNifti", reason = "to read NIfTI volumes")

  vol <- read_volume(volume, reorient = FALSE)
  vertex_labels <- sample_volume_at_surface(vol, volume, suit_3d_surface)

  colortable <- resolve_cerebellar_lut(vol, vertex_labels, input_lut)

  all_data <- list()

  for (i in seq_len(nrow(colortable))) {
    idx <- colortable$idx[i]
    region_name <- colortable$label[i]
    colour <- if ("color" %in% names(colortable)) {
      colortable$color[i]
    } else {
      NA_character_
    }

    region_vertices <- which(vertex_labels == idx) - 1L
    if (length(region_vertices) == 0) next

    hemi <- detect_cerebellar_hemi(region_name)
    region <- clean_cerebellar_region(region_name)
    label <- paste(hemi, region, sep = "_")

    all_data[[length(all_data) + 1]] <- dplyr::tibble(
      hemi = hemi,
      region = region,
      label = label,
      colour = colour,
      vertices = list(region_vertices)
    )
  }

  if (length(all_data) == 0) {
    cli::cli_abort("No regions found after sampling volume onto surface")
  }

  result <- dplyr::bind_rows(all_data)

  needs_colour <- is.na(result$colour) & result$region != "unknown"
  if (any(needs_colour)) {
    n_missing <- sum(needs_colour)
    result$colour[needs_colour] <- grDevices::hcl.colors(
      n_missing, palette = "Set2"
    )
  }

  result
}


#' Sample volume labels at SUIT surface vertex positions
#'
#' For each vertex on the SUIT 3D surface, looks up the corresponding voxel
#' in the segmentation volume and returns its label value.
#'
#' @param vol 3D array from `read_volume()`.
#' @param volume_path Path to the volume file (for reading the affine).
#' @param suit_3d_surface Path to SUIT 3D surface GIFTI.
#' @return Integer vector of length n_vertices with volume label values.
#' @noRd
sample_volume_at_surface <- function(vol, volume_path, suit_3d_surface) {
  gii <- gifti::readgii(suit_3d_surface)
  verts_3d <- gii$data$pointset

  if (is.null(verts_3d)) {
    cli::cli_abort(c(
      "File does not appear to be a valid GIFTI surface",
      "i" = "File: {.path {suit_3d_surface}}"
    ))
  }

  nii <- RNifti::readNifti(volume_path)
  vox_coords <- RNifti::worldToVoxel(verts_3d, nii)

  dims <- dim(vol)
  n_verts <- nrow(vox_coords)
  labels <- integer(n_verts)

  for (i in seq_len(n_verts)) {
    vi <- round(vox_coords[i, ])
    if (all(vi >= 1) && vi[1] <= dims[1] &&
          vi[2] <= dims[2] && vi[3] <= dims[3]) {
      labels[i] <- vol[vi[1], vi[2], vi[3]]
    }
  }

  labels <- fill_unlabelled_from_voxel_neighbors(labels, vox_coords, vol, dims)
  labels <- fill_unlabelled_from_mesh_neighbors(
    labels, gii$data$triangle + 1L, n_verts
  )

  labels
}


#' Fill unlabelled surface vertices from neighboring voxels
#'
#' For vertices that landed on a zero voxel, search the 26-connected
#' neighborhood for the nearest non-zero label.
#' @noRd
fill_unlabelled_from_voxel_neighbors <- function(
  labels, vox_coords, vol, dims
) {
  unlabelled <- which(labels == 0L)
  if (length(unlabelled) == 0) return(labels)

  offsets <- as.matrix(expand.grid(-1:1, -1:1, -1:1))
  offsets <- offsets[rowSums(offsets^2) > 0, , drop = FALSE]
  dists <- sqrt(rowSums(offsets^2))

  for (i in unlabelled) {
    vc <- round(vox_coords[i, ])
    best_dist <- Inf
    best_label <- 0L

    for (j in seq_len(nrow(offsets))) {
      vi <- vc + offsets[j, ]
      if (all(vi >= 1) && vi[1] <= dims[1] &&
            vi[2] <= dims[2] && vi[3] <= dims[3]) {
        val <- vol[vi[1], vi[2], vi[3]]
        if (val > 0 && dists[j] < best_dist) {
          best_dist <- dists[j]
          best_label <- val
        }
      }
    }
    if (best_label > 0L) labels[i] <- best_label
  }

  labels
}


#' Fill remaining unlabelled vertices from mesh neighbors
#'
#' Propagates labels along surface mesh edges using majority vote,
#' repeating until no further vertices can be filled.
#' @noRd
fill_unlabelled_from_mesh_neighbors <- function(labels, faces, n_verts) {
  n_unlabelled <- sum(labels == 0L)
  if (n_unlabelled == 0) return(labels)

  adjacency <- vector("list", n_verts)
  for (fi in seq_len(nrow(faces))) {
    v <- faces[fi, ]
    adjacency[[v[1]]] <- c(adjacency[[v[1]]], v[2], v[3])
    adjacency[[v[2]]] <- c(adjacency[[v[2]]], v[1], v[3])
    adjacency[[v[3]]] <- c(adjacency[[v[3]]], v[1], v[2])
  }

  max_passes <- 10L
  for (pass in seq_len(max_passes)) {
    still_zero <- which(labels == 0L)
    if (length(still_zero) == 0) break

    changed <- 0L
    for (i in still_zero) {
      nbr_labels <- labels[unique(adjacency[[i]])]
      nbr_labels <- nbr_labels[nbr_labels > 0L]
      if (length(nbr_labels) > 0) {
        labels[i] <- as.integer(
          names(sort(table(nbr_labels), decreasing = TRUE))[1]
        )
        changed <- changed + 1L
      }
    }
    if (changed == 0L) break
  }

  labels
}


#' Resolve cerebellar colour lookup table
#'
#' @param vol 3D volume array.
#' @param vertex_labels Integer vector of sampled labels.
#' @param input_lut User-provided LUT (path, data.frame, or NULL).
#' @return Data frame with at least columns `idx` and `label`.
#' @noRd
resolve_cerebellar_lut <- function(vol, vertex_labels, input_lut = NULL) {
  unique_ids <- sort(unique(c(as.integer(vol), vertex_labels)))
  unique_ids <- unique_ids[unique_ids > 0L]

  if (!is.null(input_lut)) {
    if (is.character(input_lut) && length(input_lut) == 1) {
      lut <- get_ctab(input_lut)
      lut <- lut[lut$idx %in% unique_ids, , drop = FALSE]
      return(lut)
    }

    if (is.data.frame(input_lut)) {
      if (!all(c("idx", "label") %in% names(input_lut))) {
        cli::cli_abort(c(
          "{.arg input_lut} must have columns {.field idx} and {.field label}",
          "i" = "Got columns: {.field {names(input_lut)}}"
        ))
      }
      lut <- input_lut[input_lut$idx %in% unique_ids, , drop = FALSE]
      if ("R" %in% names(lut) && "G" %in% names(lut) && "B" %in% names(lut)) {
        lut$color <- grDevices::rgb(lut$R, lut$G, lut$B, maxColorValue = 255)
      }
      return(lut)
    }
  }

  if (length(unique_ids) == 0) {
    return(data.frame(
      idx = integer(), label = character(), stringsAsFactors = FALSE
    ))
  }

  data.frame(
    idx = unique_ids,
    label = paste0("region_", unique_ids),
    stringsAsFactors = FALSE
  )
}
