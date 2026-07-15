# Subcortical geometry ----

#' Ensure NIfTI volume uses a FreeSurfer-compatible datatype
#'
#' FreeSurfer's mri_pretess does not support all NIfTI datatypes
#' (e.g. INT16/datatype 256). This converts incompatible volumes
#' to INT32 via RNifti, writing a converted copy to output_dir.
#'
#' @param volume_file Path to NIfTI volume
#' @param output_dir Directory for the converted file
#' @return Path to a compatible NIfTI (original if already compatible)
#' @noRd
ensure_fs_compatible_nifti <- function(volume_file, output_dir) {
  rlang::check_installed("RNifti", reason = "to read NIfTI headers")
  hdr <- tryCatch(
    suppressWarnings(RNifti::niftiHeader(volume_file)),
    error = function(e) NULL
  )
  if (is.null(hdr) || length(hdr$datatype) == 0) {
    return(volume_file)
  }
  # FreeSurfer supports: 2 (UINT8), 4 (INT16 with slope), 8 (INT32),
  # 16 (FLOAT32), 64 (FLOAT64). Datatype 256 (INT16 without slope) fails.
  fs_ok <- c(2L, 4L, 8L, 16L, 64L)
  if (hdr$datatype %in% fs_ok) {
    return(volume_file)
  }

  converted <- file.path(
    output_dir,
    paste0("_fs_compat_", basename(volume_file))
  )
  if (file.exists(converted)) {
    return(converted)
  }

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  vol <- RNifti::readNifti(volume_file)
  vol_int <- array(as.integer(vol), dim = dim(vol))
  out <- RNifti::asNifti(vol_int, reference = vol)
  RNifti::writeNifti(out, converted)
  converted
}


#' Tessellate a single label from a volume
#'
#' Creates a mesh from a single label in a segmentation volume using
#' FreeSurfer's tessellation pipeline.
#'
#' @param volume_file Path to segmentation volume
#' @param label_id Numeric label ID
#' @param output_dir Output directory for intermediate files
#' @param verbose Print progress
#' @param skip_existing If TRUE, skip files that already exist
#'
#' Isolate a label > 255 into a 0/1 mask volume for pretess/tessellate
#'
#' mri_pretess writes UCHAR output, so labels > 255 wrap around. This remaps
#' the target label to 1 in an isolated volume.
#'
#' @return list with `pretess_input` (path) and `tess_label` (numeric).
#' @noRd
tessellate_remap_label <- function(
  volume_file,
  label_id,
  base_name,
  skip_existing
) {
  if (label_id <= 255L) {
    return(list(pretess_input = volume_file, tess_label = label_id))
  }
  remapped_file <- paste0(base_name, "_remap.nii.gz")
  if (!skip_existing || !file.exists(remapped_file)) {
    vol <- RNifti::readNifti(volume_file)
    arr <- as.array(vol)
    mask <- array(0L, dim = dim(arr))
    mask[arr == label_id] <- 1L
    out <- RNifti::asNifti(mask, reference = vol)
    RNifti::writeNifti(out, remapped_file)
  }
  list(pretess_input = remapped_file, tess_label = 1L)
}


#' Smooth a tessellated mesh, warning and falling back if smoothing fails
#' @noRd
tessellate_smooth_mesh <- function(
  tess_file,
  smooth_file,
  label_id,
  skip_existing,
  verbose
) {
  if (!skip_existing || !file.exists(smooth_file)) {
    tryCatch(
      mri_smooth(
        input_file = tess_file,
        output_file = smooth_file,
        verbose = verbose
      ),
      error = function(e) {
        cli::cli_warn(
          "Smoothing failed for label {label_id}, using unsmoothed mesh"
        )
      }
    )
  }
  invisible(NULL)
}


#' @return list with vertices (data.frame) and faces (data.frame)
#' @keywords internal
#' @noRd
tessellate_label <- function(
  volume_file,
  label_id,
  output_dir,
  verbose = get_verbose(), # nolint: object_usage_linter
  skip_existing = get_skip_existing()
) {
  check_fs(abort = TRUE)

  paths <- tessellate_paths(output_dir, label_id)

  if (skip_existing && file.exists(paths$smooth)) {
    return(read_fs_surface(paths$smooth, verbose = verbose))
  }

  volume_file <- ensure_fs_compatible_nifti(volume_file, output_dir)

  remapped <- tessellate_remap_label(
    volume_file,
    label_id,
    paths$base,
    skip_existing
  )

  tessellate_run_pretess(remapped, paths$pretess, skip_existing, verbose)

  if (!file.exists(paths$pretess)) {
    cli::cli_abort("Pre-tessellation failed for label {label_id}")
  }

  tessellate_run_tess(remapped, paths, skip_existing, verbose)

  if (!file.exists(paths$tess)) {
    cli::cli_abort("Tessellation failed for label {label_id}")
  }

  tessellate_smooth_mesh(
    paths$tess,
    paths$smooth,
    label_id,
    skip_existing,
    verbose
  )

  surf_file <- if (file.exists(paths$smooth)) paths$smooth else paths$tess
  read_fs_surface(surf_file, verbose = verbose)
}


#' Intermediate file paths used by the tessellation pipeline
#' @noRd
tessellate_paths <- function(output_dir, label_id) {
  label_str <- sprintf("%04d", label_id)
  base_name <- file.path(output_dir, label_str)

  list(
    base = base_name,
    pretess = paste0(base_name, "_pretess.mgz"),
    tess = paste0(base_name, "_tess"),
    smooth = paste0(base_name, "_smooth")
  )
}


#' Run mri_pretess unless the pre-tessellated volume is already cached
#' @noRd
tessellate_run_pretess <- function(
  remapped,
  pretess_file,
  skip_existing,
  verbose
) {
  if (!skip_existing || !file.exists(pretess_file)) {
    mri_pretess(
      template = remapped$pretess_input,
      label = remapped$tess_label,
      output_file = pretess_file,
      verbose = verbose
    )
  }
  invisible(NULL)
}


#' Run mri_tessellate unless the tessellated surface is already cached
#' @noRd
tessellate_run_tess <- function(remapped, paths, skip_existing, verbose) {
  if (!skip_existing || !file.exists(paths$tess)) {
    mri_tessellate(
      input_file = paths$pretess,
      label = remapped$tess_label,
      output_file = paths$tess,
      verbose = verbose
    )
  }
  invisible(NULL)
}


#' Decimate a mesh using quadric edge decimation
#'
#' Reduces the number of faces in a triangular mesh while preserving
#' topology and shape. Requires the Rvcg package.
#'
#' @param mesh list with `vertices` (data.frame x,y,z) and `faces`
#'   (data.frame i,j,k, 1-indexed)
#' @param percent Target face count as proportion of original (0-1)
#'
#' @return Decimated mesh in the same format
#' @keywords internal
#' @noRd
decimate_mesh <- function(mesh, percent = 0.5) {
  rlang::check_installed("Rvcg", reason = "for mesh decimation")

  m3d <- rgl::tmesh3d(
    vertices = t(as.matrix(mesh$vertices)),
    indices = t(as.matrix(mesh$faces)),
    homogeneous = FALSE
  )

  decimated <- Rvcg::vcgQEdecim(
    m3d,
    percent = percent,
    topo = TRUE,
    silent = TRUE
  )

  list(
    vertices = data.frame(
      x = decimated$vb[1, ],
      y = decimated$vb[2, ],
      z = decimated$vb[3, ]
    ),
    faces = data.frame(
      i = decimated$it[1, ],
      j = decimated$it[2, ],
      k = decimated$it[3, ]
    )
  )
}


#' Read FreeSurfer surface file
#'
#' Reads FreeSurfer surface files including QUAD format from mri_tessellate.
#' Uses FreeSurfer's mris_convert for robust handling of all surface formats.
#'
#' @param file Path to FreeSurfer surface file
#' @param verbose Verbosity level (0/1/2)
#' @return list with vertices and faces data.frames (faces are 1-indexed)
#' @keywords internal
#' @noRd
read_fs_surface <- function(file, verbose = get_verbose()) {
  dpv_file <- paste0(file, ".dpv")

  result <- tryCatch(
    {
      surf2asc(file, dpv_file, verbose = verbose)
      mesh <- read_dpv(dpv_file)

      vertices <- mesh$vertices
      faces <- data.frame(
        i = mesh$faces$i + 1L,
        j = mesh$faces$j + 1L,
        k = mesh$faces$k + 1L
      )

      list(vertices = vertices, faces = faces)
    },
    error = function(e) NULL
  )

  if (!is.null(result)) {
    return(result)
  }

  if (!requireNamespace("freesurferformats", quietly = TRUE)) {
    cli::cli_abort(c(
      "Failed to read surface file: {.path {file}}",
      "i" = "FreeSurfer conversion failed and freesurferformats not available"
    ))
  }

  surf <- freesurferformats::read.fs.surface(file)

  vertices <- data.frame(
    x = surf$vertices[, 1],
    y = surf$vertices[, 2],
    z = surf$vertices[, 3]
  )
  faces <- data.frame(
    i = surf$faces[, 1],
    j = surf$faces[, 2],
    k = surf$faces[, 3]
  )

  list(vertices = vertices, faces = faces)
}


#' Generate colour table from volume labels
#'
#' Creates a colour lookup table from unique labels in a volume file.
#' Region names are generic (`region_XXXX`) and RGB colours are spread
#' evenly around the HCL hue wheel so downstream atlases render with
#' distinct colours instead of the default black.
#'
#' @param volume_file Path to volume file
#' @return data.frame with columns: idx, label, R, G, B, A, roi, color
#' @keywords internal
#' @importFrom grDevices col2rgb hcl
#' @noRd
# nolint next: object_length_linter.
generate_colortable_from_volume <- function(volume_file) {
  vol <- read_volume(volume_file)
  vol_labels <- sort(unique(c(vol)))
  vol_labels <- vol_labels[vol_labels != 0]

  hex <- generate_region_palette(length(vol_labels))
  rgb_mat <- col2rgb(hex)

  data.frame(
    idx = vol_labels,
    label = sprintf("region_%04d", vol_labels),
    R = as.integer(rgb_mat["red", ]),
    G = as.integer(rgb_mat["green", ]),
    B = as.integer(rgb_mat["blue", ]),
    A = 0L,
    roi = sprintf("%04d", vol_labels),
    color = hex,
    stringsAsFactors = FALSE
  )
}


#' Evenly spaced HCL palette for generic region colouring
#'
#' @param n Number of colours to generate.
#' @return Character vector of `n` hex colours.
#' @keywords internal
#' @importFrom grDevices hcl
#' @noRd
generate_region_palette <- function(n) {
  if (n <= 0) {
    return(character(0))
  }
  hues <- seq(15, 375, length.out = n + 1)[seq_len(n)]
  hcl(h = hues, l = 65, c = 100)
}
