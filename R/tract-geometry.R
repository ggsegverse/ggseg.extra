# Centerline extraction ----

#' Extract centerline from streamlines
#'
#' Compute a single representative path from a bundle of streamlines.
#' Useful for creating a tube mesh that summarises a tract.
#'
#' The `"mean"` method resamples all streamlines to the same number of points
#' and averages coordinates. The `"medoid"` method picks the single streamline
#' that's most similar to all others (minimises total distance).
#'
#' @param streamlines A list of Nx3 matrices (one per streamline), or a
#'   single matrix if you have just one streamline.
#' @param method How to compute the centerline: `"mean"` averages point-wise,
#'   `"medoid"` selects the most representative streamline.
#' @param n_points Number of points to resample the centerline to.
#'
#' @return A matrix with `n_points` rows and 3 columns (x, y, z).
#' @keywords internal
extract_centerline <- function(
  streamlines,
  method = c("mean", "medoid"),
  n_points = 50
) {
  method <- match.arg(method)

  if (is.matrix(streamlines)) {
    return(resample_streamline(streamlines, n_points))
  }

  if (!is.list(streamlines) || length(streamlines) == 0) {
    return(NULL)
  }

  if (length(streamlines) == 1) {
    return(resample_streamline(streamlines[[1]], n_points))
  }

  resampled <- lapply(streamlines, resample_streamline, n_points = n_points)

  valid <- vapply(
    resampled,
    function(x) !is.null(x) && nrow(x) == n_points,
    logical(1)
  )
  resampled <- resampled[valid]

  if (length(resampled) == 0) {
    return(NULL)
  }

  if (method == "mean") {
    centerline <- Reduce(`+`, resampled) / length(resampled)
    colnames(centerline) <- c("x", "y", "z")
    return(centerline)
  }

  if (method == "medoid") {
    distances <- vapply(
      resampled,
      function(sl) {
        mean(vapply(
          resampled,
          function(other) sqrt(sum((sl - other)^2)),
          numeric(1)
        ))
      },
      numeric(1)
    )
    return(resampled[[which.min(distances)]])
  }

  NULL
}


#' Resample streamline to fixed number of points
#' @keywords internal
resample_streamline <- function(streamline, n_points) {
  if (!is.matrix(streamline) || nrow(streamline) < 2) {
    return(NULL)
  }

  diffs <- apply(streamline, 2, diff)
  if (is.matrix(diffs)) {
    segment_lengths <- sqrt(rowSums(diffs^2))
  } else {
    segment_lengths <- sqrt(sum(diffs^2))
  }
  cumulative_length <- c(0, cumsum(segment_lengths))
  total_length <- cumulative_length[length(cumulative_length)]

  if (total_length == 0) {
    return(NULL)
  }

  target_positions <- seq(0, total_length, length.out = n_points)
  resampled <- matrix(0, nrow = n_points, ncol = 3)

  for (i in seq_len(n_points)) {
    target_pos <- target_positions[i]
    segment_idx <- findInterval(target_pos, cumulative_length)
    segment_idx <- max(1, min(segment_idx, nrow(streamline) - 1))

    segment_start <- cumulative_length[segment_idx]
    segment_end <- cumulative_length[segment_idx + 1]

    t <- if (segment_end == segment_start) {
      0
    } else {
      (target_pos - segment_start) / (segment_end - segment_start)
    }
    resampled[i, ] <- (1 - t) *
      streamline[segment_idx, ] +
      t * streamline[segment_idx + 1, ]
  }

  colnames(resampled) <- c("x", "y", "z")
  resampled
}


# Tube mesh generation ----

#' Generate tube mesh from centerline
#'
#' Build a 3D tube mesh around a path. The tube follows the centerline with
#' consistent orientation (no twisting) using parallel transport frames.
#' Useful for visualising tracts as smooth tubes rather than raw streamlines.
#'
#' @param centerline A matrix with N rows and columns x, y, z defining the
#'   path the tube follows.
#' @param radius Tube radius. Either a single value for uniform thickness,
#'   or a vector of length N to vary the radius along the path.
#' @param segments Number of segments around the tube circumference. Higher
#'   values make smoother tubes but larger meshes.
#'
#' @return A list with:
#'   \itemize{
#'     \item `vertices`: data.frame with x, y, z columns
#'     \item `faces`: data.frame with i, j, k columns
#'       (1-indexed triangle vertices)
#'     \item metadata: list with n_centerline_points, centerline, tangents
#'   }
#' @keywords internal
generate_tube_mesh <- function(centerline, radius = 0.5, segments = 8) {
  if (!is.matrix(centerline) || nrow(centerline) < 2) {
    cli::cli_abort("centerline must be a matrix with at least 2 rows")
  }

  n_points <- nrow(centerline)
  frames <- compute_parallel_transport_frames(centerline)

  if (length(radius) == 1) {
    radius <- rep(radius, n_points)
  } else if (length(radius) != n_points) {
    cli::cli_abort(
      "radius must be length 1 or {n_points}, got {length(radius)}"
    )
  }

  n_vertices <- n_points * segments
  n_faces <- (n_points - 1) * segments * 2

  vertices <- matrix(0, nrow = n_vertices, ncol = 3)
  faces <- matrix(0L, nrow = n_faces, ncol = 3)

  angles <- seq(0, 2 * pi, length.out = segments + 1)[1:segments]

  for (i in seq_len(n_points)) {
    center <- centerline[i, ]
    normal <- frames$normals[i, ]
    binormal <- frames$binormals[i, ]
    r <- radius[i]

    for (j in seq_len(segments)) {
      angle <- angles[j]
      offset <- r * (cos(angle) * normal + sin(angle) * binormal)
      vertex_idx <- (i - 1) * segments + j
      vertices[vertex_idx, ] <- center + offset
    }
  }

  face_idx <- 1
  for (i in seq_len(n_points - 1)) {
    for (j in seq_len(segments)) {
      j_next <- if (j == segments) 1L else j + 1L

      v1 <- (i - 1L) * segments + j
      v2 <- (i - 1L) * segments + j_next
      v3 <- i * segments + j
      v4 <- i * segments + j_next

      faces[face_idx, ] <- c(v1, v2, v3)
      faces[face_idx + 1L, ] <- c(v2, v4, v3)
      face_idx <- face_idx + 2L
    }
  }

  list(
    vertices = data.frame(
      x = vertices[, 1],
      y = vertices[, 2],
      z = vertices[, 3]
    ),
    faces = data.frame(i = faces[, 1], j = faces[, 2], k = faces[, 3]),
    metadata = list(
      n_centerline_points = n_points,
      centerline = centerline,
      tangents = frames$tangents
    )
  )
}


#' Compute parallel transport frames along curve
#'
#' Uses the parallel transport method to compute stable perpendicular frames
#' along a 3D curve, avoiding the twisting artifacts of Frenet-Serret frames.
#'
#' @param curve Matrix with N rows and 3 columns
#' @return List with tangents, normals, and binormals matrices
#' @keywords internal
# nolint next: object_length_linter.
compute_parallel_transport_frames <- function(curve) {
  n <- nrow(curve)

  tangents <- matrix(0, nrow = n, ncol = 3)
  for (i in seq_len(n - 1)) {
    tangents[i, ] <- curve[i + 1, ] - curve[i, ]
    len <- sqrt(sum(tangents[i, ]^2))
    if (len > 0) tangents[i, ] <- tangents[i, ] / len
  }
  tangents[n, ] <- tangents[n - 1, ]

  t0 <- tangents[1, ]
  arbitrary <- if (abs(t0[1]) < 0.9) c(1, 0, 0) else c(0, 1, 0)
  n0 <- cross_product(t0, arbitrary)
  n0 <- n0 / sqrt(sum(n0^2))

  normals <- matrix(0, nrow = n, ncol = 3)
  binormals <- matrix(0, nrow = n, ncol = 3)

  normals[1, ] <- n0
  binormals[1, ] <- cross_product(t0, n0)

  for (i in seq_len(n - 1)) {
    t_curr <- tangents[i, ]
    t_next <- tangents[i + 1, ]

    cross_t <- cross_product(t_curr, t_next)
    cross_norm <- sqrt(sum(cross_t^2))

    if (cross_norm < 1e-10) {
      normals[i + 1, ] <- normals[i, ]
      binormals[i + 1, ] <- binormals[i, ]
    } else {
      axis <- cross_t / cross_norm
      angle <- acos(max(-1, min(1, sum(t_curr * t_next))))

      normals[i + 1, ] <- rotate_vector(normals[i, ], axis, angle)
      normals[i + 1, ] <- normals[i + 1, ] / sqrt(sum(normals[i + 1, ]^2))
      binormals[i + 1, ] <- cross_product(t_next, normals[i + 1, ])
    }
  }

  list(tangents = tangents, normals = normals, binormals = binormals)
}


#' Cross product of two 3D vectors
#' @keywords internal
cross_product <- function(a, b) {
  c(
    a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1]
  )
}


#' Rotate vector around axis by angle (Rodrigues' formula)
#' @keywords internal
rotate_vector <- function(v, axis, angle) {
  cos_a <- cos(angle)
  sin_a <- sin(angle)
  v *
    cos_a +
    cross_product(axis, v) * sin_a +
    axis * sum(axis * v) * (1 - cos_a)
}


#' Compute streamline density for tract bundles
#'
#' Calculates how many streamlines pass through each point along the centerline.
#'
#' @param streamlines List of streamline matrices
#' @param centerline Centerline matrix (Nx3)
#' @param search_radius Radius around centerline points to count streamlines
#'
#' @return Numeric vector of density values (one per centerline point)
#' @keywords internal
compute_streamline_density <- function(
  streamlines,
  centerline,
  search_radius = 2
) {
  n_points <- nrow(centerline)
  density <- numeric(n_points)

  for (i in seq_len(n_points)) {
    center <- centerline[i, ]
    count <- 0
    for (sl in streamlines) {
      if (!is.matrix(sl) || nrow(sl) == 0) {
        next
      }
      dists <- sqrt(rowSums(sweep(sl, 2, center)^2))
      if (any(dists <= search_radius)) count <- count + 1
    }
    density[i] <- count
  }

  density
}


# 2D geometry creation for tracts (volumetric approach) ----

#' Convert streamlines/centerline to volumetric representation
#'
#' Creates a 3D volume where voxels containing tract coordinates are labeled.
#' Uses a template volume to define the output space dimensions and voxel size.
#'
#' The vox2ras matrix maps to the file's **native** voxel layout, so the
#' tract volume is built in native orientation, then reoriented to RAS+ at
#' the end for consistent downstream use.
#'
#' @param centerline Matrix with x, y, z columns
#' @param template_file Path to template volume (.mgz, .nii) that
#'   defines the output space
#' @param label_value Integer label value to assign to tract voxels (default 1)
#' @param radius Dilation radius in voxels to thicken the tract (default 2)
#' @param coords_are_voxels Logical. If TRUE, coordinates are
#'   already in voxel space
#'   (1-indexed). If FALSE (default), coordinates are in RAS space and will be
#'   transformed using the volume's vox2ras matrix.
#'
#' @return 3D array in RAS+ orientation, tract voxels set to label_value
#' @keywords internal
streamlines_to_volume <- function(
  centerline,
  template_file,
  label_value = 1L,
  radius = 2,
  coords_are_voxels = FALSE
) {
  if (!file.exists(template_file)) {
    cli::cli_abort("Template file not found: {.path {template_file}}")
  }

  template_nii <- read_volume(template_file, reorient = FALSE)
  dims <- dim(template_nii)
  vox2ras <- load_vox2ras_matrix(template_file, coords_are_voxels)
  vol <- array(0L, dim = dims)

  for (i in seq_len(nrow(centerline))) {
    vox_idx <- coord_to_voxel(
      centerline[i, ],
      dims,
      vox2ras,
      coords_are_voxels
    )
    vol <- set_sphere_voxels(vol, vox_idx, radius, label_value, dims)
  }

  nii <- RNifti::asNifti(vol, reference = template_nii)
  if (RNifti::orientation(nii) != "RAS") {
    RNifti::orientation(nii) <- "RAS"
  }
  as.array(nii)
}


#' Load vox2ras transformation matrix from volume file
#' @noRd
load_vox2ras_matrix <- function(template_file, coords_are_voxels) {
  if (coords_are_voxels) {
    return(NULL)
  }

  ext <- tolower(tools::file_ext(template_file))
  if (ext == "gz") {
    ext <- tools::file_ext(sub("\\.gz$", "", template_file))
  }

  if (ext == "mgz") {
    if (!requireNamespace("freesurferformats", quietly = TRUE)) {
      return(NULL)
    }
    tryCatch(
      freesurferformats::read.fs.mgh(template_file, with_header = TRUE)$vox2ras,
      error = function(e) NULL
    )
  } else if (ext == "nii") {
    if (!requireNamespace("RNifti", quietly = TRUE)) {
      return(NULL)
    }
    tryCatch(
      {
        hdr <- RNifti::niftiHeader(template_file)
        RNifti::xform(hdr)
      },
      error = function(e) NULL
    )
  } else {
    NULL
  }
}


#' Convert world coordinate to voxel index
#'
#' Maps 3D coordinates to 1-based voxel array indices.
#' When coords_are_voxels is TRUE, assumes 0-based voxel indices
#' (TrackVis convention) and adds 1 for R indexing.
#' @noRd
coord_to_voxel <- function(coord, dims, vox2ras, coords_are_voxels) {
  if (coords_are_voxels) {
    return(round(coord) + 1L)
  }
  if (!is.null(vox2ras)) {
    ras2vox <- solve(vox2ras)
    vox_coord <- ras2vox %*% c(coord, 1)
    return(round(vox_coord[1:3]) + 1)
  }
  c(
    round(dims[1] / 2 - coord[1]) + 1,
    round(dims[2] / 2 + coord[2]) + 1,
    round(dims[3] / 2 + coord[3]) + 1
  )
}


#' Set voxels within a sphere around center point
#' @noRd
set_sphere_voxels <- function(vol, center, radius, label_value, dims) {
  for (dx in seq(-radius, radius)) {
    for (dy in seq(-radius, radius)) {
      for (dz in seq(-radius, radius)) {
        if (dx^2 + dy^2 + dz^2 > radius^2) {
          next
        }

        vx <- center[1] + dx
        vy <- center[2] + dy
        vz <- center[3] + dz

        if (voxel_in_bounds(vx, vy, vz, dims)) {
          vol[vx, vy, vz] <- label_value
        }
      }
    }
  }
  vol
}


#' Check if voxel coordinates are within volume bounds
#' @noRd
voxel_in_bounds <- function(x, y, z, dims) {
  x >= 1 && x <= dims[1] && y >= 1 && y <= dims[2] && z >= 1 && z <= dims[3]
}


#' Detect if streamline coordinates are in voxel space
#'
#' Uses heuristics to guess whether coordinates are in voxel space (0 to dims)
#' or RAS/world space (centered around 0).
#'
#' @param streamlines List of streamline matrices (each with x, y, z columns)
#' @param dims Optional volume dimensions for validation
#' @return TRUE if likely voxel space, FALSE if likely RAS
#' @noRd
detect_coords_are_voxels <- function(streamlines, dims = NULL) {
  all_coords <- do.call(
    rbind,
    lapply(streamlines, function(s) {
      if (is.matrix(s) && nrow(s) > 0) {
        s[, 1:3, drop = FALSE]
      } else {
        NULL
      }
    })
  )

  if (is.null(all_coords) || nrow(all_coords) == 0) {
    return(FALSE)
  }

  min_coord <- min(all_coords, na.rm = TRUE)
  max_coord <- max(all_coords, na.rm = TRUE)

  if (min_coord < -10) {
    return(FALSE)
  }

  if (min_coord >= 0 && max_coord <= 300) {
    if (!is.null(dims) && max(dims) > 0) {
      max_dim <- max(dims)
      if (max_coord <= max_dim * 1.1) {
        return(TRUE)
      }
    } else {
      return(TRUE)
    }
  }

  FALSE
}


#' Create 2D geometry for tract atlas
#'
#' Generate polygon outlines for tract visualisation in 2D. The function
#' projects tract centerlines onto slice views (coronal, axial) and extracts
#' contours. Also creates cortex outlines for anatomical context.
#'
#' This is typically called automatically by
#' [create_tract_from_tractography()] when
#' `include_geometry = TRUE`, but you can call it separately
#' if you want custom views or need to regenerate geometry.
#'
#' @param atlas A `ggseg_atlas` of type `"tract"`
#'   (from [create_tract_from_tractography()]).
#' @param aseg_file Path to a segmentation volume (`.mgz`, `.nii`) used to
#'   draw cortex outlines for anatomical context.
#' @param streamlines Named list of streamline matrices (Nx3 with x, y, z).
#'   Names must match tract labels in the atlas. Required because atlas
#'   centerlines are centred for 3D rendering and don't match volumetric space.
#' @param views A data.frame defining which projection views to create. Columns:
#'   `name` (view label), `type` (`"coronal"` or `"axial"`), `start` (first
#'   slice), `end` (last slice). Default creates upper/lower coronal and
#'   anterior/posterior axial views.
#' @param cortex_slices A data.frame specifying cortex slice positions for
#'   reference outlines. Columns: `x`, `y`, `z`, `view`, `name`. Default uses
#'   central slices for each view.
#' @template output_dir
#' @param tract_radius Dilation radius when rasterising tract coordinates.
#' @param coords_are_voxels If TRUE, streamline coordinates are in voxel
#'   space (0-indexed). If FALSE, coordinates are in RAS space. If NULL
#'   (default), auto-detects by checking coordinate ranges.
#' @template vertex_size_limits
#' @template dilate
#' @template tolerance
#' @template smoothness
#' @template verbose
#' @template cleanup
#' @template skip_existing
#'
#' @return An sf data.frame with columns `label`, `side` (view name), and
#'   `geometry`.
#' @keywords internal
#' @importFrom dplyr bind_rows left_join select
#' @importFrom furrr future_pmap furrr_options
#' @importFrom progressr progressor

#' @noRd
tract_create_volumes <- function(
  tract_labels, streamlines, aseg_file,
  tract_radius, coords_are_voxels, verbose
) {
  if (verbose) {
    cli::cli_alert_info("Converting tracts to volumes")
  }

  p <- progressor(steps = length(tract_labels))

  tract_volumes <- safe_future_pmap(
    list(
      label = tract_labels,
      i = seq_along(tract_labels)
    ),
    function(label, i) {
      centerline <- streamlines[[label]]

      if (is.list(centerline) && !is.matrix(centerline)) {
        centerline <- extract_centerline(centerline, n_points = 50)
      }

      vol <- streamlines_to_volume(
        centerline = centerline,
        template_file = aseg_file,
        label_value = i,
        radius = tract_radius,
        coords_are_voxels = coords_are_voxels
      )

      p()
      vol
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c(
        "streamlines",
        "aseg_file",
        "tract_radius",
        "coords_are_voxels",
        "p"
      )
    )
  )
  names(tract_volumes) <- tract_labels
  tract_volumes
}


#' @noRd
tract_snapshot_projections <- function(
  tract_volumes, tract_labels, aseg_vol, dims,
  views, cortex_slices, dirs, skip_existing, verbose
) {
  if (verbose) {
    cli::cli_alert_info("Creating projections")
  }

  cortex_labels <- detect_cortex_labels(aseg_vol)

  cortex_vol <- array(0L, dim = dims)
  for (lbl in c(cortex_labels$left, cortex_labels$right)) {
    cortex_vol[aseg_vol == lbl] <- 1L
  }

  snapshot_grid <- expand.grid(
    view_idx = seq_len(nrow(views)),
    label = tract_labels,
    stringsAsFactors = FALSE
  )

  p <- progressor(steps = nrow(snapshot_grid))

  invisible(safe_future_pmap(
    list(
      view_type = views$type[snapshot_grid$view_idx],
      view_start = views$start[snapshot_grid$view_idx],
      view_end = views$end[snapshot_grid$view_idx],
      view_name = views$name[snapshot_grid$view_idx],
      label = snapshot_grid$label
    ),
    function(view_type, view_start, view_end, view_name, label) {
      tract_vol <- tract_volumes[[label]]
      hemi <- extract_hemi_from_view(view_type, view_name)

      snapshot_partial_projection(
        vol = tract_vol,
        view = view_type,
        start = view_start,
        end = view_end,
        view_name = view_name,
        label = label,
        output_dir = dirs$snapshots,
        colour = "red",
        hemi = hemi,
        skip_existing = skip_existing
      )
      p()
      NULL
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("tract_volumes", "dirs", "skip_existing", "p")
    )
  ))

  p2 <- progressor(steps = nrow(cortex_slices))

  invisible(safe_future_pmap(
    list(
      x = cortex_slices$x,
      y = cortex_slices$y,
      z = cortex_slices$z,
      slice_view = cortex_slices$view,
      view_name = cortex_slices$name
    ),
    function(x, y, z, slice_view, view_name) {
      hemi <- extract_hemi_from_view(slice_view, view_name)

      snapshot_cortex_slice(
        vol = cortex_vol,
        x = x,
        y = y,
        z = z,
        slice_view = slice_view,
        view_name = view_name,
        hemi = hemi,
        output_dir = dirs$snapshots,
        skip_existing = skip_existing
      )
      p2()
      NULL
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("cortex_vol", "dirs", "skip_existing", "p2")
    )
  ))
}


#' @noRd
tract_process_and_extract <- function(
  dirs, dilate, skip_existing, verbose,
  vertex_size_limits, smoothness, tolerance
) {
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
    step = NULL,
    verbose = verbose,
    vertex_size_limits = vertex_size_limits
  )
  smooth_contours(dirs$base, smoothness, step = NULL, verbose = verbose)
  reduce_vertex(dirs$base, tolerance, step = NULL, verbose = verbose)
}


create_tract_geometry_volumetric <- function( # nolint: object_length_linter.
  atlas,
  aseg_file,
  streamlines,
  views = NULL,
  cortex_slices = NULL,
  output_dir = NULL,
  tract_radius = 3,
  coords_are_voxels = NULL,
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

  if (atlas$type != "tract") {
    cli::cli_abort("Atlas must be of type 'tract'")
  }

  if (!file.exists(aseg_file)) {
    cli::cli_abort("Aseg file not found: {.path {aseg_file}}")
  }

  if (missing(streamlines) || is.null(streamlines)) {
    cli::cli_abort(c(
      "{.arg streamlines} is required for volumetric geometry",
      "i" = paste(
        "Atlas centerlines are centered for 3D",
        "rendering and don't match volumetric space"
      ),
      "i" = "Pass the original streamlines/centerlines in RAS coordinates"
    ))
  }

  if (is.null(coords_are_voxels)) {
    all_streamlines <- unlist(streamlines, recursive = FALSE)
    coords_are_voxels <- detect_coords_are_voxels(all_streamlines)
    if (verbose) {
      space <- if (coords_are_voxels) "voxel" else "RAS" # nolint: object_usage_linter
      cli::cli_alert_info("Auto-detected coordinate space: {.val {space}}")
    }
  }

  output_dir <- path.expand(output_dir)
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  if (verbose) {
    cli::cli_alert_info("Setting output directory to {.path {output_dir}}")
  }

  dirs <- setup_atlas_dirs(output_dir, type = "tract")
  dirs$vols <- dirs$volumes

  centerlines <- atlas$data$centerlines
  if (is.null(centerlines)) {
    cli::cli_abort("Atlas must have centerlines data for volumetric geometry")
  }
  tract_labels <- centerlines$label

  missing_labels <- setdiff(tract_labels, names(streamlines))
  if (length(missing_labels) > 0) {
    cli::cli_abort(c(
      "Streamlines missing for tracts: {.val {missing_labels}}",
      "i" = "streamlines must be a named list with names matching tract labels"
    ))
  }

  contours_file <- file.path(dirs$base, "contours_reduced.rda")
  views_file <- file.path(dirs$base, "views.rds")
  if (skip_existing && file.exists(contours_file)) {
    if (file.exists(views_file)) {
      views <- readRDS(views_file)
    } else {
      dims <- dim(read_volume(aseg_file))
      views <- default_tract_views(dims)
    }
    if (verbose) {
      cli::cli_alert_success("Loaded existing 2D geometry from cache")
    }
  } else {
    aseg_vol <- read_volume(aseg_file)
    dims <- dim(aseg_vol)

    if (is.null(views)) {
      views <- default_tract_views(dims)
    }
    saveRDS(views, views_file)

    if (is.null(cortex_slices)) {
      cortex_slices <- create_cortex_slices(views, dims)
    }

    n_snapshots <- nrow(views) * length(tract_labels) + nrow(cortex_slices)
    existing_snaps <- length(list.files(dirs$snapshots, pattern = "\\.png$"))

    if (skip_existing && existing_snaps >= n_snapshots) {
      if (verbose) {
        cli::cli_alert_success(
          "Using existing snapshots ({existing_snaps} files)"
        )
      }
    } else {
      tract_volumes <- tract_create_volumes(
        tract_labels, streamlines, aseg_file,
        tract_radius, coords_are_voxels, verbose
      )

      tract_snapshot_projections(
        tract_volumes, tract_labels, aseg_vol, dims,
        views, cortex_slices, dirs, skip_existing, verbose
      )
    }

    tract_process_and_extract(
      dirs, dilate, skip_existing, verbose,
      vertex_size_limits, smoothness, tolerance
    )
  }

  if (verbose) {
    cli::cli_alert_info("Building sf geometry")
  }

  sf_data <- build_contour_sf(
    file.path(dirs$base, "contours_reduced.rda"),
    views,
    cortex_slices
  )

  if (cleanup) {
    unlink(dirs$base, recursive = TRUE)
  }

  sf_data
}


#' Center meshes around origin
#'
#' Computes the global centroid of all mesh vertices and translates
#' all meshes to center around the origin.
#'
#' @param meshes_list Named list of meshes
#' @return Centered meshes list
#' @keywords internal
center_meshes <- function(meshes_list) {
  all_vertices <- do.call(rbind, lapply(meshes_list, function(m) m$vertices))

  centroid <- c(
    mean(all_vertices$x),
    mean(all_vertices$y),
    mean(all_vertices$z)
  )

  for (name in names(meshes_list)) {
    meshes_list[[name]]$vertices$x <- meshes_list[[name]]$vertices$x -
      centroid[1]
    meshes_list[[name]]$vertices$y <- meshes_list[[name]]$vertices$y -
      centroid[2]
    meshes_list[[name]]$vertices$z <- meshes_list[[name]]$vertices$z -
      centroid[3]

    if (!is.null(meshes_list[[name]]$metadata$centerline)) {
      meshes_list[[name]]$metadata$centerline[, 1] <- meshes_list[[
        name
      ]]$metadata$centerline[, 1] -
        centroid[1]
      meshes_list[[name]]$metadata$centerline[, 2] <- meshes_list[[
        name
      ]]$metadata$centerline[, 2] -
        centroid[2]
      meshes_list[[name]]$metadata$centerline[, 3] <- meshes_list[[
        name
      ]]$metadata$centerline[, 3] -
        centroid[3]
    }
  }

  meshes_list
}
