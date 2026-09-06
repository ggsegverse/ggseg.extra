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
    "extdata",
    "suit",
    "tpl-SUIT_flat.surf.gii",
    package = "ggseg.extra"
  )
  if (path == "") {
    # nocov start
    cli::cli_abort(
      "SUIT flatmap surface not found in ggseg.extra installation"
    )
    # nocov end
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
    "extdata",
    "suit",
    "tpl-SUIT_3d.surf.gii",
    package = "ggseg.extra"
  )
  if (path == "") {
    # nocov start
    cli::cli_abort(
      "SUIT 3D surface not found in ggseg.extra installation"
    )
    # nocov end
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
    "tpl-SUIT_from-",
    template,
    "_mode-image_xfm.nii"
  )
  cached_path <- as.character(fs::path(cache_dir, filename))

  if (file.exists(cached_path)) {
    return(cached_path)
  }

  download_suit_xfm(filename, cached_path)
}

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
#'   parcellations/labels) or `"linear"` (for continuous maps). Note that
#'   `"linear"` uses a pure-R trilinear loop and can be slow for large
#'   volumes.
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
#' atlas <- create_cerebellar_from_volume(input_volume = suit_vol)
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

  prep <- prepare_suit_resample(xfm, mni_vol)

  if (interpolation == "nearest") {
    result <- resample_nearest(
      prep$result,
      prep$vox_coords,
      prep$mni_arr,
      prep$mni_dims
    )
  } else {
    result <- resample_trilinear(
      prep$result,
      prep$vox_coords,
      prep$mni_arr,
      prep$mni_dims
    )
  }

  ref_nii <- RNifti::asNifti(array(0, dim = prep$suit_dims), reference = xfm)
  out_nii <- RNifti::asNifti(result, reference = ref_nii)
  RNifti::writeNifti(out_nii, output_file)

  invisible(output_file)
}

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
#' @template decimate
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object of type "cerebellar" containing region
#'   metadata (core), a colour palette, sf geometry for 2D plots, and
#'   optionally 3D meshes.
#' @template dots_post_creation
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
  decimate = 0.5,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  ...
) {
  dots <- check_post_creation_dots("create_cerebellar_from_gifti", ...)
  tolerance <- dots$tolerance
  if (length(gifti_files) == 0) {
    cli::cli_abort("{.arg gifti_files} must not be empty")
  }

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

  run_cerebellar_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_suit_parcellation(gifti_files),
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
#' @template decimate
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#'
#' @return A `ggseg_atlas` object of type "cerebellar".
#' @template dots_post_creation
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
  decimate = 0.5,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  ...
) {
  dots <- check_post_creation_dots("create_cerebellar_from_annotation", ...)
  tolerance <- dots$tolerance
  if (length(input_annot) == 0) {
    cli::cli_abort("{.arg input_annot} must not be empty")
  }

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

  run_cerebellar_creation(
    atlas_name = atlas_name,
    config = config,
    read_fn = function() read_cerebellar_annotation(input_annot),
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
#' @param input_volume Path to a cerebellar segmentation volume (NIfTI).
#' @param input_lut Optional path to a colour lookup table file, or a
#'   data.frame with columns `idx`, `label`, and optionally `R`, `G`, `B`.
#'   If NULL, labels are auto-generated from volume values.
#' @template atlas_name
#' @template output_dir
#' @template decimate
#' @template smooth_refinements
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param volume `r lifecycle::badge("deprecated")` Use `input_volume`
#'   instead.
#'
#' @return A `ggseg_atlas` object of type "cerebellar" with both sf geometry
#'   and 3D meshes.
#' @template dots_post_creation
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_cerebellar_from_volume(
#'   input_volume = "cerebellar_parcellation.nii.gz"
#' )
#' }
# nolint next: object_length_linter.
create_cerebellar_from_volume <- function(
  input_volume = NULL,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  decimate = 0.5,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  volume = lifecycle::deprecated(),
  ...
) {
  dots <- check_post_creation_dots("create_cerebellar_from_volume", ...)
  tolerance <- dots$tolerance
  if (lifecycle::is_present(volume)) {
    lifecycle::deprecate_warn(
      "1.9.9.9005",
      "create_cerebellar_from_volume(volume = )",
      "create_cerebellar_from_volume(input_volume = )"
    )
    input_volume <- volume
  }
  volume <- input_volume

  if (is.null(volume)) {
    cli::cli_abort("{.arg input_volume} is required")
  }
  if (!file.exists(volume)) {
    cli::cli_abort("Volume file not found: {.path {volume}}")
  }

  config <- validate_surface_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
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
    input_files = c(volume, suit_3d_path()),
    volume = volume
  )
}

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
  seen_vertices <- integer(0)

  for (gifti_file in gifti_files) {
    parsed <- read_suit_gifti_rows(gifti_file, seen_vertices)
    all_data <- c(all_data, parsed$rows)
    seen_vertices <- parsed$seen_vertices
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
      n_missing,
      palette = "Set2"
    )
  }

  result
}


#' Download and validate a SUIT deformation field file
#'
#' Downloads to a temporary file in the same directory as `cached_path` and
#' only `file.rename()`s it into place once it has passed both the size and
#' NIfTI-header checks. This keeps a partial/corrupt transfer (e.g. an
#' interrupted download, or a captive-portal response padded past the size
#' threshold) from ever landing at `cached_path`, since
#' [suit_deformation_field()] trusts any file already there without
#' re-checking it.
#' @noRd
download_suit_xfm <- function(filename, cached_path) {
  if (!can_reach_github()) {
    cli::cli_abort(c(
      "Cannot reach GitHub to download deformation field",
      "i" = "The deformation field {.file {filename}} is not cached",
      "i" = "Check your internet connection and try again" # nolint
    ))
  }

  url <- paste0(
    "https://raw.githubusercontent.com/DiedrichsenLab/",
    "cerebellar_atlases/master/tpl-SUIT/",
    filename
  )

  cli::cli_alert_info("Downloading {.file {filename}} (~13 MB)")

  tmp_path <- tempfile(
    pattern = paste0(filename, "-"),
    tmpdir = dirname(cached_path),
    fileext = ".nii"
  )
  on.exit(unlink(tmp_path), add = TRUE)

  tryCatch(
    utils::download.file(url, tmp_path, mode = "wb", quiet = TRUE),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to download deformation field",
        "i" = "URL: {.url {url}}",
        "x" = "{conditionMessage(e)}"
      ))
    }
  )
  validate_suit_xfm_download(tmp_path)

  file.rename(tmp_path, cached_path)
  cli::cli_alert_success("Cached at {.path {cached_path}}")
  cached_path
}

#' @noRd
validate_suit_xfm_download <- function(tmp_path) {
  if (!file.exists(tmp_path) || file.size(tmp_path) < 1e6) {
    cli::cli_abort(
      "Download appears incomplete. Please try again."
    )
  }
  # RNifti::niftiHeader() warns (rather than errors) and returns NULL for a
  # malformed file; the warning is redundant with the cli_abort() below.
  header <- suppressWarnings(tryCatch(
    RNifti::niftiHeader(tmp_path),
    error = function(e) NULL
  ))
  if (is.null(header)) {
    cli::cli_abort(
      "Downloaded file is not a valid NIfTI image. Please try again."
    )
  }
  invisible(TRUE)
}


#' Validate the deformation field and build SUIT resampling inputs
#' @noRd
prepare_suit_resample <- function(xfm, mni_vol) {
  xfm_dims <- dim(xfm)
  if (length(xfm_dims) != 5 || xfm_dims[4] != 1 || xfm_dims[5] != 3) {
    cli::cli_abort(c(
      "Deformation field must be a 5D NIfTI (x, y, z, 1, 3)",
      "i" = "Got dimensions: {paste(xfm_dims, collapse = ' x ')}"
    ))
  }

  suit_dims <- xfm_dims[1:3]
  result <- array(0, dim = suit_dims)

  mni_coords_x <- xfm[,,, 1, 1] # nolint: commas_linter.
  mni_coords_y <- xfm[,,, 1, 2] # nolint: commas_linter.
  mni_coords_z <- xfm[,,, 1, 3] # nolint: commas_linter.

  mni_coords <- cbind(
    c(mni_coords_x),
    c(mni_coords_y),
    c(mni_coords_z)
  )

  vox_coords <- RNifti::worldToVoxel(mni_coords, mni_vol)

  mni_arr <- drop(as.array(mni_vol))
  mni_dims <- dim(mni_arr)
  if (length(mni_dims) != 3) {
    cli::cli_abort("Input volume must be 3D, got {length(mni_dims)}D")
  }

  list(
    suit_dims = suit_dims,
    result = result,
    vox_coords = vox_coords,
    mni_arr = mni_arr,
    mni_dims = mni_dims
  )
}


#' Check internet connectivity
#' @noRd
can_reach_github <- function() {
  tryCatch(
    {
      con <- url("https://raw.githubusercontent.com", open = "r")
      on.exit(try(close(con), silent = TRUE), add = TRUE)
      TRUE
    },
    error = function(e) FALSE
  )
}


# MNI to SUIT transform ----

#' Nearest-neighbour resample of MNI volume into SUIT grid
#' @noRd
resample_nearest <- function(result, vox_coords, mni_arr, mni_dims) {
  vox_round <- round(vox_coords)
  valid <- vox_round[, 1] >= 1 &
    vox_round[, 1] <= mni_dims[1] &
    vox_round[, 2] >= 1 &
    vox_round[, 2] <= mni_dims[2] &
    vox_round[, 3] >= 1 &
    vox_round[, 3] <= mni_dims[3]
  idx <- which(valid)
  lin_idx <- vox_round[idx, 1] +
    (vox_round[idx, 2] - 1L) * mni_dims[1] +
    (vox_round[idx, 3] - 1L) * mni_dims[1] * mni_dims[2]
  result[idx] <- mni_arr[lin_idx]
  result
}


#' Trilinear resample of MNI volume into SUIT grid
#' @noRd
resample_trilinear <- function(result, vox_coords, mni_arr, mni_dims) {
  cli::cli_alert_info(
    "Trilinear interpolation (may be slow for large volumes)"
  )
  for (i in seq_len(nrow(vox_coords))) {
    val <- trilinear_sample(vox_coords[i, ], mni_arr, mni_dims)
    if (!is.null(val)) {
      result[i] <- val
    }
  }
  result
}

#' Trilinearly sample one voxel coordinate, or `NULL` when out of bounds or NA
#'
#' The `anyNA()` check comes first so the bounds comparisons never run on a
#' non-finite coordinate (which would make `if ()` error).
#' @noRd
trilinear_sample <- function(vi, mni_arr, mni_dims) {
  if (anyNA(vi) || any(vi < 1 | vi > mni_dims)) {
    return(NULL)
  }

  x0 <- floor(vi[1])
  x1 <- min(x0 + 1L, mni_dims[1])
  y0 <- floor(vi[2])
  y1 <- min(y0 + 1L, mni_dims[2])
  z0 <- floor(vi[3])
  z1 <- min(z0 + 1L, mni_dims[3])
  xd <- vi[1] - x0
  yd <- vi[2] - y0
  zd <- vi[3] - z0

  mni_arr[x0, y0, z0] *
    (1 - xd) *
    (1 - yd) *
    (1 - zd) +
    mni_arr[x1, y0, z0] * xd * (1 - yd) * (1 - zd) +
    mni_arr[x0, y1, z0] * (1 - xd) * yd * (1 - zd) +
    mni_arr[x0, y0, z1] * (1 - xd) * (1 - yd) * zd +
    mni_arr[x1, y1, z0] * xd * yd * (1 - zd) +
    mni_arr[x0, y1, z1] * (1 - xd) * yd * zd +
    mni_arr[x1, y0, z1] * xd * (1 - yd) * zd +
    mni_arr[x1, y1, z1] * xd * yd * zd
}


# Cerebellar atlas creation ----

# Cerebellar pipeline helpers ----

#' @noRd
run_cerebellar_creation <- function(
  atlas_name,
  config,
  read_fn,
  input_files,
  volume = NULL
) {
  start_time <- Sys.time()
  dirs <- setup_atlas_dirs(config$output_dir, atlas_name, type = "cerebellar")

  if (config$verbose) {
    cli::cli_h1("Creating cerebellar atlas {.val {atlas_name}}")
    cli::cli_alert_info("Input files: {.path {input_files}}")
  }

  step1 <- cerebellar_read_data(
    config,
    dirs,
    read_fn = read_fn
  )

  cerebellar_project_and_build(
    components = step1$components,
    deep_data = step1$deep_data,
    volume = volume,
    atlas_name = atlas_name,
    config = config,
    dirs = dirs,
    start_time = start_time
  )
}


#' @noRd
cerebellar_read_data <- function(config, dirs, read_fn) {
  files <- as.character(fs::path(dirs$base, "components.rds"))
  deep_file <- as.character(fs::path(dirs$base, "deep_data.rds"))
  cached <- load_or_run_step(
    1L,
    config$steps,
    files,
    config$skip_existing,
    "Read parcellation"
  )

  if (!cached$run) {
    if (config$verbose) {
      cli::cli_alert_success("Loaded cached atlas data")
    }
    deep_data <- if (file.exists(deep_file)) readRDS(deep_file) else NULL
    return(list(
      components = cached$data[["components.rds"]],
      deep_data = deep_data
    ))
  }

  if (config$verbose) {
    cli::cli_progress_step("Reading SUIT parcellation")
  }

  atlas_data <- read_fn()
  if (nrow(atlas_data) == 0) {
    cli::cli_abort("No regions found in input files")
  }

  split <- split_cerebellar_surface_deep(atlas_data, config)
  components <- build_atlas_components(split$surface_data)
  components <- merge_deep_into_components(
    components,
    split$deep_data,
    deep_file
  )

  saveRDS(components, as.character(fs::path(dirs$base, "components.rds")))
  cli::cli_progress_done()

  list(components = components, deep_data = split$deep_data)
}


#' Split cerebellar atlas data into surface and deep-nuclei parts
#' @noRd
split_cerebellar_surface_deep <- function(atlas_data, config) {
  has_deep <- "deep" %in% names(atlas_data) && any(atlas_data$deep)
  deep_data <- NULL

  if (has_deep) {
    deep_data <- atlas_data[atlas_data$deep, , drop = FALSE]
    surface_data <- atlas_data[!atlas_data$deep, , drop = FALSE]

    if (config$verbose) {
      cli::cli_alert_info(
        "Found {nrow(deep_data)} deep cerebellar nucle{?us/i}"
      )
    }
  } else {
    surface_data <- atlas_data
  }

  list(surface_data = surface_data, deep_data = deep_data)
}


#' Merge deep-nuclei core/palette into surface components and cache them
#' @noRd
merge_deep_into_components <- function(components, deep_data, deep_file) {
  if (!is.null(deep_data) && nrow(deep_data) > 0) {
    deep_core <- dplyr::distinct(deep_data, hemi, region, label)
    components$core <- rbind(components$core, deep_core)

    deep_colours <- stats::setNames(deep_data$colour, deep_data$label)
    deep_colours <- deep_colours[!duplicated(names(deep_colours))]
    # Uncoloured nuclei stay NA rather than being given invented colours, so
    # they behave like every other region: see build_atlas_components().
    if (!is.null(components$palette)) {
      components$palette <- c(components$palette, deep_colours)
    }

    saveRDS(deep_data, deep_file)
  }

  components
}


#' @noRd
cerebellar_project_and_build <- function(
  components,
  deep_data = NULL,
  volume = NULL,
  atlas_name,
  config,
  dirs,
  start_time
) {
  if (config$verbose) {
    cli::cli_progress_step("Projecting parcellation onto SUIT flatmap")
  }

  sf_data <- cerebellar_build_sf_flatmap(
    components,
    suit_flatmap_path(),
    tolerance = config$tolerance,
    smooth_refinements = config$smooth_refinements,
    verbose = config$verbose
  )

  if (config$verbose) {
    cli::cli_progress_done()
  }

  deep_meshes_df <- NULL

  if (!is.null(deep_data) && nrow(deep_data) > 0 && !is.null(volume)) {
    deep_result <- cerebellar_process_deep_nuclei(
      volume = volume,
      deep_data = deep_data,
      dirs = dirs,
      verbose = config$verbose
    )
    sf_data <- merge_deep_nuclei_sf(sf_data, deep_result$sf)
    deep_meshes_df <- extract_deep_meshes(deep_result$meshes)
  }

  atlas <- ggseg_atlas(
    atlas = atlas_name,
    type = "cerebellar",
    palette = components$palette,
    core = components$core,
    data = ggseg_data_cerebellar(
      geom = sf_data,
      vertices = components$vertices_df,
      meshes = deep_meshes_df
    )
  )

  if (length(unique(sf_data$view)) > 1) {
    atlas <- ggseg.formats::atlas_view_gather(atlas)
  }

  cortical_finalize(atlas, config, dirs, start_time)
}


#' Append deep-nuclei sf geometry to the flatmap sf data
#' @noRd
merge_deep_nuclei_sf <- function(sf_data, deep_sf) {
  if (!is.null(deep_sf) && nrow(deep_sf) > 0) {
    sf_data <- sf::st_cast(sf_data, "MULTIPOLYGON")
    deep_sf <- sf::st_cast(deep_sf, "MULTIPOLYGON")
    sf_data <- rbind(sf_data, deep_sf)
  }
  sf_data
}


#' Return deep-nuclei mesh data frame or NULL when empty
#' @noRd
extract_deep_meshes <- function(deep_meshes) {
  if (!is.null(deep_meshes) && nrow(deep_meshes) > 0) {
    deep_meshes
  }
}


#' Process deep cerebellar nuclei
#'
#' Creates sf geometries (coronal projection) and 3D meshes for deep
#' cerebellar structures that are not on the cortical surface.
#' @noRd
cerebellar_process_deep_nuclei <- function(
  volume,
  deep_data,
  dirs,
  verbose = FALSE
) {
  rlang::check_installed("terra", reason = "to create nuclei projections")

  if (!"vol_idx" %in% names(deep_data)) {
    if (verbose) {
      cli::cli_warn(
        "Deep nuclei data has no {.field vol_idx} column; skipping"
      )
    }
    return(list(sf = NULL, meshes = NULL))
  }

  vol <- read_volume(volume, reorient = FALSE)

  deep_sf_list <- list()
  for (i in seq_len(nrow(deep_data))) {
    sf_row <- build_deep_nucleus_sf(
      vol,
      deep_data$vol_idx[i],
      deep_data$label[i]
    )
    if (!is.null(sf_row)) {
      deep_sf_list[[length(deep_sf_list) + 1]] <- sf_row
    }
  }

  deep_sf <- if (length(deep_sf_list) > 0) {
    do.call(rbind, deep_sf_list)
  }

  deep_meshes <- build_deep_nuclei_meshes(volume, deep_data, dirs, verbose)

  list(sf = deep_sf, meshes = deep_meshes)
}


#' Build a coronal-projection sf row for one deep nucleus
#'
#' Returns NULL when the nucleus has no voxels or no usable geometry.
#' @noRd
build_deep_nucleus_sf <- function(vol, idx, label) {
  n_voxels <- sum(vol == idx)
  if (n_voxels == 0) {
    return(NULL)
  }

  mask <- array(0L, dim = dim(vol))
  mask[vol == idx] <- 1L
  proj <- apply(mask, c(1, 3), max)

  if (sum(proj) == 0) {
    # nocov start
    return(NULL)
    # nocov end
  }

  r <- terra::rast(t(proj[, rev(seq_len(ncol(proj)))]))
  polys <- tryCatch(
    terra::as.polygons(r, dissolve = TRUE),
    error = function(e) NULL
  )
  if (is.null(polys)) {
    cli::cli_warn(c(
      "Could not polygonise deep nucleus {.val {label}}; dropping it.",
      "i" = "{.pkg terra} failed to extract polygons from its voxel mask."
    ))
    return(NULL)
  }

  polys <- polys[terra::values(polys) > 0, ]
  if (nrow(polys) == 0) {
    # nocov start
    return(NULL)
    # nocov end
  }

  sf_poly <- sf::st_as_sf(polys)
  geom <- sf::st_union(sf_poly$geometry)
  geom <- sf::st_buffer(geom, 1.5)
  geom <- sf::st_buffer(geom, -1.0)
  if (sf::st_is_empty(geom)) {
    # nocov start
    geom <- sf::st_union(sf::st_as_sf(polys)$geometry)
    geom <- sf::st_buffer(geom, 0.5)
    # nocov end
  }
  geom <- sf::st_cast(geom, "MULTIPOLYGON")

  sf::st_sf(
    label = label,
    view = "nuclei",
    geometry = geom
  )
}


# nocov start
#' Tessellate and world-transform a single deep nucleus mesh
#'
#' Returns NULL when tessellation fails.
#' @noRd
build_deep_nucleus_mesh <- function(
  volume,
  idx,
  label,
  mesh_dir,
  tkr_to_world,
  verbose
) {
  mesh <- tryCatch(
    tessellate_label(
      volume_file = volume,
      label_id = idx,
      output_dir = mesh_dir,
      verbose = verbose > 1,
      skip_existing = FALSE
    ),
    error = function(e) {
      if (verbose) {
        cli::cli_warn("Failed to tessellate {label}: {e$message}")
      }
      NULL
    }
  )

  if (is.null(mesh)) {
    return(NULL)
  }

  mesh <- decimate_mesh(mesh, percent = 0.5)
  verts <- as.matrix(mesh$vertices)
  verts_h <- cbind(verts, 1)
  world <- verts_h %*% t(tkr_to_world)
  mesh$vertices <- data.frame(
    x = world[, 1],
    y = world[, 2],
    z = world[, 3]
  )
  mesh
}
# nocov end

#' Build the deep-nuclei 3D mesh data frame
#'
#' Returns NULL when FreeSurfer is unavailable or no meshes were produced.
#' @noRd
build_deep_nuclei_meshes <- function(volume, deep_data, dirs, verbose) {
  if (!check_fs(abort = FALSE)) {
    if (verbose) {
      cli::cli_warn(
        "FreeSurfer not found; skipping 3D mesh tessellation for deep nuclei"
      )
    }
    return(NULL)
  }

  # nocov start
  mesh_dir <- as.character(fs::path(dirs$base, "deep_meshes"))
  dir.create(mesh_dir, showWarnings = FALSE, recursive = TRUE)

  tkr_to_world <- get_tkras_to_world(volume)

  meshes_list <- list()
  for (i in seq_len(nrow(deep_data))) {
    label <- deep_data$label[i]
    mesh <- build_deep_nucleus_mesh(
      volume,
      deep_data$vol_idx[i],
      label,
      mesh_dir,
      tkr_to_world,
      verbose
    )
    if (!is.null(mesh)) {
      meshes_list[[label]] <- mesh
    }
  }

  if (length(meshes_list) == 0) {
    return(NULL)
  }

  if (verbose) {
    cli::cli_alert_success("Created {length(meshes_list)} meshes")
  }
  deep_meshes <- data.frame(
    label = names(meshes_list),
    stringsAsFactors = FALSE
  )
  deep_meshes$mesh <- unname(meshes_list)
  deep_meshes
  # nocov end
}


# nocov start
#' Compute tkRAS-to-world transform for a NIfTI volume
#'
#' FreeSurfer tessellation outputs surfaces in tkRAS coordinates.
#' This computes the transform to convert them to the volume's world
#' (scanner RAS / MNI) coordinates: world = vox2ras * inv(vox2ras_tkr) * tkRAS
#' @noRd
get_tkras_to_world <- function(volume_path) {
  check_fs(abort = TRUE)

  vox2ras_tkr <- mri_info_matrix("--vox2ras-tkr", volume_path)
  vox2ras <- mri_info_matrix("--vox2ras", volume_path)

  vox2ras %*% solve(vox2ras_tkr)
}
# nocov end

#' Run `mri_info` and parse its printed matrix
#'
#' `mri_info` can print informational/warning lines (e.g. about a missing
#' qform) ahead of the requested matrix, so only the matrix's own 4 lines
#' -- always the last non-empty lines of output -- are parsed; naively
#' parsing every line would silently fold stray numbers from those messages
#' into the matrix. Aborts loudly if the subprocess fails or the tail lines
#' don't parse into a complete 4x4 matrix, rather than returning garbage.
#' @noRd
mri_info_matrix <- function(flag, volume_path) {
  lines <- system2(
    "mri_info",
    c(flag, shQuote(volume_path)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(lines, "status")
  if (!is.null(status) && status != 0L) {
    cli::cli_abort(c(
      "{.code mri_info {flag}} failed for {.path {volume_path}} \\
       (exit {status}).",
      "x" = paste(lines, collapse = "\n")
    ))
  }

  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  vals <- suppressWarnings(as.numeric(unlist(
    strsplit(utils::tail(lines, 4L), "\\s+")
  )))

  if (length(vals) != 16L || anyNA(vals)) {
    cli::cli_abort(
      "{.code mri_info {flag}} did not return a valid 4x4 matrix for \\
       {.path {volume_path}}."
    )
  }
  matrix(vals, nrow = 4, ncol = 4, byrow = TRUE)
}


# SUIT parcellation reader ----

#' Parse one SUIT GIFTI file into region rows
#'
#' Returns a list with `rows` (list of tibbles) and the updated
#' `seen_vertices` vector. Skipped files yield zero rows.
#' @noRd
read_suit_gifti_rows <- function(gifti_file, seen_vertices) {
  gii <- gifti::readgii(gifti_file)

  data_arrays <- gii$data
  if (is.null(data_arrays) || length(data_arrays) == 0) {
    cli::cli_warn("No data arrays in {.path {gifti_file}}, skipping")
    return(list(rows = list(), seen_vertices = seen_vertices))
  }

  label_array <- data_arrays[[1]]
  if (is.matrix(label_array)) {
    label_array <- label_array[, 1]
  }
  values <- as.integer(label_array)

  if (length(values) == 0) {
    cli::cli_warn("Empty data array in {.path {gifti_file}}, skipping")
    return(list(rows = list(), seen_vertices = seen_vertices))
  }

  label_table <- extract_gifti_label_table(gii)
  unique_ids <- sort(unique(values))

  rows <- list()
  for (pid in unique_ids) {
    if (pid == 0L) {
      next
    }

    region_vertices <- which(values == pid) - 1L
    if (length(region_vertices) == 0) {
      # nocov start
      next
      # nocov end
    }

    warn_vertex_overlap(region_vertices, seen_vertices, pid, gifti_file)
    seen_vertices <- union(seen_vertices, region_vertices)

    rows[[length(rows) + 1]] <- build_suit_region_row(
      pid,
      region_vertices,
      label_table
    )
  }

  list(rows = rows, seen_vertices = seen_vertices)
}


#' Warn about vertices already assigned to another SUIT region
#' @noRd
warn_vertex_overlap <- function(
  region_vertices,
  seen_vertices,
  pid,
  gifti_file
) {
  overlap <- intersect(region_vertices, seen_vertices)
  if (length(overlap) > 0) {
    cli::cli_warn(c(
      "Region {.val {pid}} in {.path {gifti_file}} overlaps
      {length(overlap)} previously assigned vertex{?es}",
      "i" = "Last file wins for overlapping vertices"
    ))
  }
}


#' Build a single SUIT parcellation region row
#' @noRd
build_suit_region_row <- function(pid, region_vertices, label_table) {
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

  dplyr::tibble(
    hemi = hemi,
    region = region,
    label = label,
    colour = colour,
    vertices = list(region_vertices)
  )
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
  if (is.null(lt)) {
    return(NULL)
  }

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
  if (grepl("^(Left|left)[- _.]", region_name)) {
    return("left")
  }
  if (grepl("^(Right|right)[- _.]", region_name)) {
    return("right")
  }
  if (grepl("^(Vermis|vermis)[- _.]", region_name)) {
    return("vermis")
  }
  if (grepl("vermis", region_name, ignore.case = TRUE)) {
    return("vermis")
  }

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
    "^(Left|Right|Vermis|left|right|vermis)[- _.]\\s*",
    "",
    region_name
  )
  region <- trimws(region)
  if (nchar(region) == 0) {
    region <- region_name
  }
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

  all_data <- lapply(annot_files, read_one_cerebellar_annotation)

  all_data <- Filter(Negate(is.null), all_data)

  if (length(all_data) == 0) {
    cli::cli_abort("No regions found in annotation files")
  }

  dplyr::bind_rows(all_data)
}


#' Read one cerebellar annotation file into a region tibble
#'
#' Returns NULL when the file yields no usable regions.
#' @noRd
read_one_cerebellar_annotation <- function(annot_file) {
  annot <- freesurferformats::read.fs.annot(annot_file)
  ct <- annot$colortable_df
  ct <- ct[!is.na(ct$r), ]
  label_codes <- annot$label_codes

  skip <- tolower(ct$struct_name) %in% c("unknown", "corpuscallosum")
  ct <- ct[!skip, ]
  if (nrow(ct) == 0) {
    return(NULL)
  }

  region_verts <- lapply(ct$code, function(code) {
    which(label_codes == code) - 1L
  })
  has_verts <- lengths(region_verts) > 0
  ct <- ct[has_verts, ]
  region_verts <- region_verts[has_verts]
  if (nrow(ct) == 0) {
    return(NULL)
  }

  hemi <- unname(vapply(ct$struct_name, detect_cerebellar_hemi, character(1)))
  region <- unname(vapply(
    ct$struct_name,
    clean_cerebellar_region,
    character(1)
  ))

  dplyr::tibble(
    hemi = hemi,
    region = region,
    label = paste(hemi, region, sep = "_"),
    colour = ct$hex_color_string_rgb,
    vertices = region_verts
  )
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
    built <- build_cerebellar_volume_row(
      i,
      colortable,
      vol,
      vertex_labels,
      volume,
      suit_3d_surface
    )
    vertex_labels <- built$vertex_labels
    if (!is.null(built$row)) {
      all_data[[length(all_data) + 1]] <- built$row
    }
  }

  if (length(all_data) == 0) {
    cli::cli_abort("No regions found after sampling volume onto surface")
  }

  result <- dplyr::bind_rows(all_data)
  fill_missing_region_colours(result)
}


#' Build one cerebellar volume region row and update surface labels
#'
#' Returns a list with `row` (a region tibble or NULL when the region has no
#' voxels or vertices) and the possibly-updated `vertex_labels` vector (the
#' orphan-rescue branch reassigns nearest vertices in place).
#' @noRd
build_cerebellar_volume_row <- function(
  i,
  colortable,
  vol,
  vertex_labels,
  volume,
  suit_3d_surface
) {
  idx <- colortable$idx[i]
  region_name <- colortable$label[i]
  colour <- colortable_colour(colortable, i)

  region_vertices <- which(vertex_labels == idx) - 1L
  n_voxels <- sum(vol == idx)

  if (length(region_vertices) == 0 && n_voxels == 0) {
    return(list(row = NULL, vertex_labels = vertex_labels))
  }

  hemi <- detect_cerebellar_hemi(region_name)
  region <- clean_cerebellar_region(region_name)
  label <- paste(hemi, region, sep = "_")

  resolved <- resolve_orphan_region(
    region_vertices,
    n_voxels,
    region_name,
    vol,
    idx,
    volume,
    suit_3d_surface,
    vertex_labels
  )
  region_vertices <- resolved$region_vertices
  vertex_labels <- resolved$vertex_labels
  is_deep <- resolved$is_deep

  row <- dplyr::tibble(
    hemi = hemi,
    region = region,
    label = label,
    colour = colour,
    vol_idx = idx,
    vertices = list(region_vertices),
    deep = is_deep
  )
  list(row = row, vertex_labels = vertex_labels)
}


#' Colour for a colortable row, NA when the table carries no colours
#' @noRd
colortable_colour <- function(colortable, i) {
  if ("color" %in% names(colortable)) {
    colortable$color[i]
  } else {
    NA_character_
  }
}


#' Classify a region with no surface vertices as deep, or rescue it
#'
#' Known deep nuclei are flagged; anything else is reassigned to its nearest
#' surface vertices.
#' @noRd
resolve_orphan_region <- function(
  region_vertices,
  n_voxels,
  region_name,
  vol,
  idx,
  volume,
  suit_3d_surface,
  vertex_labels
) {
  is_deep <- FALSE
  if (length(region_vertices) == 0 && n_voxels > 0) {
    is_known_nucleus <- grepl(
      "Dentate|Interposed|Fastigial",
      region_name,
      ignore.case = TRUE
    )
    if (is_known_nucleus) {
      is_deep <- TRUE
      cli::cli_warn(c(
        "Region {.val {region_name}} has {n_voxels} volume voxel{?s} but",
        "0 surface vertices (deep/non-surface structure)",
        "i" = "Will be treated as a deep cerebellar nucleus"
      ))
    } else {
      nearest <- rescue_orphaned_region(
        vol,
        idx,
        volume,
        suit_3d_surface,
        vertex_labels
      )
      if (length(nearest) > 0) {
        region_vertices <- nearest
        vertex_labels[nearest + 1L] <- idx
        cli::cli_warn(c(
          "Region {.val {region_name}} ({n_voxels} voxels) had 0 surface",
          "vertices; assigned {length(nearest)} nearest vertex{?es}"
        ))
      }
    }
  }

  list(
    region_vertices = region_vertices,
    vertex_labels = vertex_labels,
    is_deep = is_deep
  )
}


#' Assign fallback palette colours to regions missing a colour
#' @noRd
fill_missing_region_colours <- function(result) {
  needs_colour <- is.na(result$colour) & result$region != "unknown"
  if (any(needs_colour)) {
    n_missing <- sum(needs_colour)
    result$colour[needs_colour] <- grDevices::hcl.colors(
      n_missing,
      palette = "Set2"
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

  # Label volumes are integer parcellations, but read_volume() returns a double
  # array for float-typed files (e.g. a SUIT volume from transform_mni_to_suit).
  # Force integer storage so the neighbour lookup's vapply(integer(1)) template
  # holds instead of erroring on a double element.
  storage.mode(vol) <- "integer"

  dims <- dim(vol)
  n_verts <- nrow(vox_coords)
  labels <- integer(n_verts)

  vox_round <- round(vox_coords)
  valid <- vox_round[, 1] >= 1 &
    vox_round[, 1] <= dims[1] &
    vox_round[, 2] >= 1 &
    vox_round[, 2] <= dims[2] &
    vox_round[, 3] >= 1 &
    vox_round[, 3] <= dims[3]
  idx <- which(valid)
  lin_idx <- vox_round[idx, 1] +
    (vox_round[idx, 2] - 1L) * dims[1] +
    (vox_round[idx, 3] - 1L) * dims[1] * dims[2]
  labels[idx] <- vol[lin_idx]

  labels <- fill_unlabelled_from_voxel_neighbors(labels, vox_coords, vol, dims)
  labels <- fill_unlabelled_from_mesh_neighbors(
    labels,
    gii$data$triangle + 1L,
    n_verts
  )

  labels
}


#' Fill unlabelled surface vertices from neighboring voxels
#'
#' For vertices that landed on a zero voxel, search an expanding neighborhood
#' for the nearest non-zero label. Starts at radius 1 (26-connected) and
#' expands up to `max_radius` if unlabelled vertices remain after each shell.
#' @noRd
# nolint next: object_length_linter.
fill_unlabelled_from_voxel_neighbors <- function(
  labels,
  vox_coords,
  vol,
  dims,
  max_radius = 3L
) {
  for (radius in seq_len(max_radius)) {
    unlabelled <- which(labels == 0L)
    if (length(unlabelled) == 0) {
      return(labels)
    }

    r <- radius
    offsets <- as.matrix(expand.grid(-r:r, -r:r, -r:r))
    if (radius == 1L) {
      offsets <- offsets[rowSums(offsets^2) > 0, , drop = FALSE]
    } else {
      offsets <- offsets[apply(abs(offsets), 1, max) == r, , drop = FALSE]
    }
    dists <- sqrt(rowSums(offsets^2))

    for (i in unlabelled) {
      if (labels[i] != 0L) {
        # nocov start
        next
        # nocov end
      }
      vc <- round(vox_coords[i, ])
      nbrs <- sweep(offsets, 2, vc, "+")
      in_bounds <- nbrs[, 1] >= 1 &
        nbrs[, 1] <= dims[1] &
        nbrs[, 2] >= 1 &
        nbrs[, 2] <= dims[2] &
        nbrs[, 3] >= 1 &
        nbrs[, 3] <= dims[3]
      nbrs <- nbrs[in_bounds, , drop = FALSE]
      nbr_dists <- dists[in_bounds]

      vals <- vapply(
        seq_len(nrow(nbrs)),
        function(k) {
          vol[nbrs[k, 1], nbrs[k, 2], nbrs[k, 3]]
        },
        integer(1)
      )

      has_label <- vals > 0L
      if (any(has_label)) {
        labels[i] <- vals[has_label][which.min(nbr_dists[has_label])]
      }
    }
  }

  labels
}


#' Fill remaining unlabelled vertices from mesh neighbors
#'
#' Propagates labels along surface mesh edges using majority vote,
#' repeating until no further vertices can be filled.
#' @noRd
# nolint next: object_length_linter.
fill_unlabelled_from_mesh_neighbors <- function(labels, faces, n_verts) {
  n_unlabelled <- sum(labels == 0L)
  if (n_unlabelled == 0) {
    return(labels)
  }

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
    if (length(still_zero) == 0) {
      break
    }

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


#' Rescue an orphaned surface region by finding nearest vertices
#'
#' For regions that have volume voxels but no surface vertices (even after
#' expanded fill), find the surface vertices closest to the region's voxel
#' centroid and assign them.
#' @return Integer vector of 0-based vertex indices (may be empty)
#' @noRd
rescue_orphaned_region <- function(
  vol,
  label_id,
  volume_path,
  suit_3d_surface,
  vertex_labels,
  n_vertices = 5L
) {
  voxel_locs <- which(vol == label_id, arr.ind = TRUE)
  if (nrow(voxel_locs) == 0) {
    return(integer(0))
  }

  nii <- RNifti::readNifti(volume_path)
  centroid_vox <- colMeans(voxel_locs)
  centroid_world <- RNifti::voxelToWorld(
    matrix(centroid_vox, nrow = 1),
    nii
  )

  gii <- gifti::readgii(suit_3d_surface)
  verts_3d <- gii$data$pointset

  dists <- sqrt(
    (verts_3d[, 1] - centroid_world[1])^2 +
      (verts_3d[, 2] - centroid_world[2])^2 +
      (verts_3d[, 3] - centroid_world[3])^2
  )

  unassigned <- which(vertex_labels == 0L)
  if (length(unassigned) > 0) {
    candidates <- unassigned[order(dists[unassigned])]
    n <- min(n_vertices, length(candidates))
    return(as.integer(candidates[seq_len(n)] - 1L))
  }

  nearest_idx <- order(dists)[seq_len(min(n_vertices, length(dists)))]
  as.integer(nearest_idx - 1L)
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
    resolved <- resolve_provided_lut(input_lut, unique_ids)
    if (!is.null(resolved)) {
      return(resolved)
    }
  }

  if (length(unique_ids) == 0) {
    return(data.frame(
      idx = integer(),
      label = character(),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    idx = unique_ids,
    label = paste0("region_", unique_ids),
    stringsAsFactors = FALSE
  )
}


#' Resolve a user-provided cerebellar LUT
#'
#' Handles a LUT path or data.frame. Returns NULL when `input_lut` is
#' neither, so the caller falls back to an auto-generated LUT.
#' @noRd
resolve_provided_lut <- function(input_lut, unique_ids) {
  if (is.character(input_lut) && length(input_lut) == 1) {
    lut <- get_lut(input_lut)
    return(lut[lut$idx %in% unique_ids, , drop = FALSE])
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

  NULL
}
