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


#' Create and return the working directories for projection geometry
#' @noRd
geom_proj_dirs <- function(output_dir) {
  dirs <- list(
    base = file.path(output_dir, "subcort_proj_geom"),
    snapshots = file.path(output_dir, "subcort_proj_geom", "snapshots"),
    processed = file.path(output_dir, "subcort_proj_geom", "processed"),
    masks = file.path(output_dir, "subcort_proj_geom", "masks")
  )
  for (d in dirs) {
    mkdir(d)
  }
  dirs
}


#' Read the volume and resolve the views/slices/labels it drives
#' @noRd
geom_proj_inputs <- function(input_volume, views, cortex_slices, verbose) {
  if (verbose) {
    cli::cli_alert_info("Reading volume")
  }

  vol <- read_volume(input_volume)
  dims <- dim(vol)

  if (is.null(views)) {
    views <- default_projection_views(dims)
  }

  if (is.null(cortex_slices)) {
    cortex_slices <- default_cortex_slices(dims)
  }

  cortex_labels <- detect_cortex_labels(vol)

  list(
    vol = vol,
    dims = dims,
    views = views,
    cortex_slices = cortex_slices,
    cortex_labels = cortex_labels
  )
}


#' Render structure and cortex snapshots, then process them into masks
#' @noRd
geom_proj_snapshots <- function(
  prep,
  colortable,
  dirs,
  dilate,
  skip_existing,
  verbose
) {
  if (verbose) {
    cli::cli_alert_info(
      "Creating projections for {nrow(colortable)} structures"
    )
  }

  snapshot_projection_structures(
    prep$vol,
    prep$dims,
    colortable,
    prep$views,
    dirs,
    skip_existing = skip_existing
  )

  if (verbose) {
    cli::cli_alert_info("Creating cortex reference slices")
  }

  snapshot_projection_cortex(
    prep$vol,
    prep$dims,
    prep$cortex_labels,
    prep$cortex_slices,
    dirs,
    skip_existing = skip_existing
  )

  if (verbose) {
    cli::cli_alert_info("Processing images")
  }

  process_projection_images(dirs, dilate, skip_existing)
}


#' Extract, smooth and reduce the contours of the projection masks
#' @noRd
geom_proj_contours <- function(
  dirs,
  vertex_size_limits,
  tolerance,
  smoothness,
  verbose
) {
  extract_contours(
    dirs$masks,
    dirs$base,
    step = "",
    verbose = verbose,
    vertex_size_limits = vertex_size_limits
  )
  smooth_contours(dirs$base, smoothness, step = "", verbose = verbose)
  reduce_vertex(
    dirs$base,
    tolerance,
    smoothness = smoothness,
    step = "",
    verbose = verbose
  )
}


#' Default whole-volume projection views keyed off volume dimensions
#' @noRd
default_projection_views <- function(dims) {
  mid_x <- dims[1] %/% 2
  data.frame(
    name = c("axial", "coronal", "sagittal_left", "sagittal_right"),
    type = c("axial", "coronal", "sagittal", "sagittal"),
    start = c(1, 1, 1, mid_x + 1),
    end = c(dims[3], dims[2], mid_x, dims[1]),
    stringsAsFactors = FALSE
  )
}


#' Default cortex reference slice positions keyed off volume dimensions
#' @noRd
default_cortex_slices <- function(dims) {
  data.frame(
    x = c(NA, NA, dims[1] / 4, dims[1] * 3 / 4),
    y = c(dims[2] / 2, NA, NA, NA),
    z = c(NA, dims[3] / 2, NA, NA),
    view = c("coronal", "axial", "sagittal_left", "sagittal_right"),
    name = c("coronal", "axial", "sagittal_left", "sagittal_right"),
    stringsAsFactors = FALSE
  )
}


#' Render projection snapshots for every structure x view combination
#' @noRd
snapshot_projection_structures <- function(
  vol,
  dims,
  colortable,
  views,
  dirs,
  skip_existing
) {
  snapshot_grid <- expand.grid(
    struct_idx = seq_len(nrow(colortable)),
    view_idx = seq_len(nrow(views)),
    stringsAsFactors = FALSE
  )

  p <- progressor(steps = nrow(snapshot_grid))

  invisible(safe_future_pmap(
    list(
      label_id = colortable$idx[snapshot_grid$struct_idx],
      label_name = colortable$label[snapshot_grid$struct_idx],
      view_type = views$type[snapshot_grid$view_idx],
      view_start = views$start[snapshot_grid$view_idx],
      view_end = views$end[snapshot_grid$view_idx],
      view_name = views$name[snapshot_grid$view_idx]
    ),
    function(label_id, label_name, view_type, view_start, view_end, view_name) {
      structure_vol <- array(0L, dim = dims)
      structure_vol[vol == label_id] <- 1L

      if (sum(structure_vol) > 0) {
        snapshot_partial_projection(
          vol = structure_vol,
          view = view_type,
          start = view_start,
          end = view_end,
          view_name = view_name,
          label = label_name,
          output_dir = dirs$snapshots,
          colour = "red",
          skip_existing = skip_existing
        )
      }
      p()
      NULL
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("dims", "vol", "dirs", "skip_existing", "p")
    )
  ))
}


#' Render cortex reference slice snapshots
#' @noRd
snapshot_projection_cortex <- function(
  vol,
  dims,
  cortex_labels,
  cortex_slices,
  dirs,
  skip_existing
) {
  cortex_vol <- array(0L, dim = dims)
  for (lbl in c(cortex_labels$left, cortex_labels$right)) {
    cortex_vol[vol == lbl] <- 1L
  }

  for (i in seq_len(nrow(cortex_slices))) {
    cs <- cortex_slices[i, ]

    snapshot_cortex_slice(
      vol = cortex_vol,
      x = cs$x,
      y = cs$y,
      z = cs$z,
      slice_view = cs$view,
      view_name = cs$name,
      hemi = "cortex",
      output_dir = dirs$snapshots,
      skip_existing = skip_existing
    )
  }
}


#' Process snapshot PNGs into alpha masks via the dilation/mask pipeline
#' @noRd
process_projection_images <- function(dirs, dilate, skip_existing) {
  files <- list.files(dirs$snapshots, full.names = TRUE, pattern = "\\.png$")

  for (f in files) {
    process_snapshot_image(
      input_file = f,
      output_file = file.path(dirs$processed, basename(f)),
      dilate = dilate,
      skip_existing = skip_existing
    )
  }

  for (f in list.files(dirs$processed, full.names = TRUE)) {
    extract_alpha_mask(
      f,
      file.path(dirs$masks, basename(f)),
      skip_existing = skip_existing
    )
  }
}


#' Assemble reduced contours into a labelled, view-laid-out sf data.frame
#' @noRd
build_projection_sf <- function(dirs, views, cortex_slices) {
  conts <- make_multipolygon(file.path(dirs$base, "contours_reduced.rda"))

  filenm_base <- sub("\\.png$", "", conts$filenm)

  view_names <- c(views$name, cortex_slices$name)
  view_pattern <- paste0("^(", paste(view_names, collapse = "|"), ")_")
  conts$view <- sub(paste0(view_pattern, ".*"), "\\1", filenm_base)
  conts$view[!grepl(view_pattern, filenm_base)] <- NA_character_

  conts$geometry <- conts$geometry * matrix(c(1, 0, 0, -1), 2, 2)

  conts <- layout_volumetric_views(conts) # nolint: object_usage_linter.

  conts$label <- vapply(
    seq_along(filenm_base),
    function(i) {
      fn <- filenm_base[i]
      vn <- conts$view[i]
      if (is.na(vn)) {
        return(fn)
      }
      sub(paste0("^", vn, "_"), "", fn)
    },
    character(1)
  )

  sf_data <- dplyr::select(conts, label, view, geometry)
  sf::st_as_sf(sf_data)
}
