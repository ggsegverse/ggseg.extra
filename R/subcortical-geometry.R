# Subcortical geometry ----

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
#' @return list with vertices (data.frame) and faces (data.frame)
#' @keywords internal
tessellate_label <- function(
  volume_file,
  label_id,
  output_dir,
  verbose = get_verbose(), # nolint: object_usage_linter
  skip_existing = get_skip_existing()
) {
  check_fs(abort = TRUE)

  label_str <- sprintf("%04d", label_id)
  base_name <- file.path(output_dir, label_str)

  pretess_file <- paste0(base_name, "_pretess.mgz")
  tess_file <- paste0(base_name, "_tess")
  smooth_file <- paste0(base_name, "_smooth")

  if (skip_existing && file.exists(smooth_file)) {
    return(read_fs_surface(smooth_file, verbose = verbose))
  }

  if (!skip_existing || !file.exists(pretess_file)) {
    mri_pretess(
      template = volume_file,
      label = label_id,
      output_file = pretess_file,
      verbose = verbose
    )
  }

  if (!file.exists(pretess_file)) {
    cli::cli_abort("Pre-tessellation failed for label {label_id}")
  }

  if (!skip_existing || !file.exists(tess_file)) {
    mri_tessellate(
      input_file = pretess_file,
      label = label_id,
      output_file = tess_file,
      verbose = verbose
    )
  }

  if (!file.exists(tess_file)) {
    cli::cli_abort("Tessellation failed for label {label_id}")
  }

  if (!skip_existing || !file.exists(smooth_file)) {
    mri_smooth(
      input_file = tess_file,
      output_file = smooth_file,
      verbose = verbose
    )
  }

  if (!file.exists(smooth_file)) {
    cli::cli_abort("Smoothing failed for label {label_id}")
  }

  read_fs_surface(smooth_file, verbose = verbose)
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
#' Region names are generic and colours are NA (no palette).
#'
#' @param volume_file Path to volume file
#' @return data.frame with columns: idx, label, R, G, B, A, roi, color
#' @keywords internal
# nolint next: object_length_linter.
generate_colortable_from_volume <- function(volume_file) {
  vol <- read_volume(volume_file)
  vol_labels <- sort(unique(c(vol)))
  vol_labels <- vol_labels[vol_labels != 0]

  data.frame(
    idx = vol_labels,
    label = sprintf("region_%04d", vol_labels),
    R = NA_integer_,
    G = NA_integer_,
    B = NA_integer_,
    A = 0L,
    roi = sprintf("%04d", vol_labels),
    color = NA_character_,
    stringsAsFactors = FALSE
  )
}


#' Create 2D geometry for subcortical atlas using projections
#'
#' Generate polygon outlines for subcortical structures using volumetric
#' projections instead of slices. This shows all structures in their spatial
#' relationships - like an X-ray view.
#'
#' Subcortical structures are projected (all voxels visible), while cortex
#' reference outlines use single slices (to show outline, not filled blob).
#'
#' @param input_volume Path to segmentation volume
#' @param colortable Color lookup table data.frame
#' @param views A data.frame defining projection views. Columns:
#'   `name` (view label), `type` ("axial", "coronal", "sagittal"),
#'   `start` (first slice), `end` (last slice).
#' @param cortex_slices A data.frame specifying cortex slice positions.
#'   Columns: `x`, `y`, `z`, `view`, `name`. Cortex uses single slices
#'   (not projections) to show outlines rather than filled blobs.
#' @param output_dir Output directory for intermediate files
#' @param vertex_size_limits Size limits for contour filtering
#' @param dilate Dilation amount for image processing
#' @param tolerance Vertex reduction tolerance
#' @param smoothness Contour smoothing amount
#' @param verbose Print progress
#' @param cleanup Remove intermediate files
#' @param skip_existing Skip existing files
#'
#' @return sf data.frame with label, view, and geometry columns
#' @keywords internal
# nolint next: object_length_linter.
create_subcortical_geometry_projection <- function(
  input_volume,
  colortable,
  views = NULL,
  cortex_slices = NULL,
  output_dir = NULL,
  vertex_size_limits = NULL,
  dilate = NULL,
  tolerance = NULL,
  smoothness = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  cleanup = NULL,
  skip_existing = NULL
) {
  verbose <- is_verbose(verbose)
  cleanup <- get_cleanup(cleanup)
  skip_existing <- get_skip_existing(skip_existing)
  tolerance <- get_tolerance(tolerance)
  smoothness <- get_smoothness(smoothness)
  output_dir <- get_output_dir(output_dir)

  output_dir <- normalizePath(output_dir, mustWork = FALSE)

  dirs <- list(
    base = file.path(output_dir, "subcort_proj_geom"),
    snapshots = file.path(output_dir, "subcort_proj_geom", "snapshots"),
    processed = file.path(output_dir, "subcort_proj_geom", "processed"),
    masks = file.path(output_dir, "subcort_proj_geom", "masks")
  )
  for (d in dirs) {
    mkdir(d)
  }

  if (verbose) {
    cli::cli_alert_info("Reading volume")
  }

  vol <- read_volume(input_volume)
  dims <- dim(vol)

  if (is.null(views)) {
    mid_x <- dims[1] %/% 2
    views <- data.frame(
      name = c("axial", "coronal", "sagittal_left", "sagittal_right"),
      type = c("axial", "coronal", "sagittal", "sagittal"),
      start = c(1, 1, 1, mid_x + 1),
      end = c(dims[3], dims[2], mid_x, dims[1]),
      stringsAsFactors = FALSE
    )
  }

  if (is.null(cortex_slices)) {
    cortex_slices <- data.frame(
      x = c(NA, NA, dims[1] / 4, dims[1] * 3 / 4),
      y = c(dims[2] / 2, NA, NA, NA),
      z = c(NA, dims[3] / 2, NA, NA),
      view = c("coronal", "axial", "sagittal_left", "sagittal_right"),
      name = c("coronal", "axial", "sagittal_left", "sagittal_right"),
      stringsAsFactors = FALSE
    )
  }

  cortex_labels <- detect_cortex_labels(vol)

  if (verbose) {
    cli::cli_alert_info(
      "Creating projections for {nrow(colortable)} structures"
    )
  }

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

  if (verbose) {
    cli::cli_alert_info("Creating cortex reference slices")
  }

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

  if (verbose) {
    cli::cli_alert_info("Processing images")
  }

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

  extract_contours(
    dirs$masks,
    dirs$base,
    step = "",
    verbose = verbose,
    vertex_size_limits = vertex_size_limits
  )
  smooth_contours(dirs$base, smoothness, step = "", verbose = verbose)
  reduce_vertex(dirs$base, tolerance, step = "", verbose = verbose)

  if (verbose) {
    cli::cli_alert_info("Building sf geometry")
  }

  conts <- make_multipolygon(file.path(dirs$base, "contours_reduced.rda"))

  filenm_base <- sub("\\.png$", "", conts$filenm)

  conts$view <- vapply(
    filenm_base,
    function(fn) {
      for (vn in c(views$name, cortex_slices$name)) {
        if (startsWith(fn, paste0(vn, "_"))) {
          return(vn)
        }
      }
      NA_character_
    },
    character(1)
  )

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
  sf_data <- sf::st_as_sf(sf_data)

  if (cleanup) {
    unlink(dirs$base, recursive = TRUE)
  }

  sf_data
}
