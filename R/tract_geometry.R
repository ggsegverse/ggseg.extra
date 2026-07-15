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
#' @noRd
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

  resampled <- resample_valid_streamlines(streamlines, n_points)

  if (length(resampled) == 0) {
    return(NULL)
  }

  switch(
    method,
    mean = centerline_mean(resampled),
    medoid = centerline_medoid(resampled),
    NULL
  )
}


#' Resample streamlines and keep only those with the target point count
#' @noRd
resample_valid_streamlines <- function(streamlines, n_points) {
  resampled <- lapply(streamlines, resample_streamline, n_points = n_points)
  valid <- vapply(
    resampled,
    function(x) !is.null(x) && nrow(x) == n_points,
    logical(1)
  )
  resampled[valid]
}


#' Average resampled streamlines point-wise
#' @noRd
centerline_mean <- function(resampled) {
  centerline <- Reduce(`+`, resampled) / length(resampled)
  colnames(centerline) <- c("x", "y", "z")
  centerline
}


#' Select the most representative resampled streamline
#' @noRd
centerline_medoid <- function(resampled) {
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
  resampled[[which.min(distances)]]
}


#' Resample streamline to fixed number of points
#' @keywords internal
#' @noRd
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
#' @noRd
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

  vertices <- tube_ring_vertices(centerline, radius, frames, segments)
  faces <- tube_ring_faces(n_points, segments)

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


#' Offset centerline points into a ring of tube vertices
#' @noRd
tube_ring_vertices <- function(centerline, radius, frames, segments) {
  n_points <- nrow(centerline)
  angles <- seq(0, 2 * pi, length.out = segments + 1)[1:segments]

  grid <- expand.grid(j = seq_len(segments), i = seq_len(n_points))
  cos_a <- cos(angles[grid$j])
  sin_a <- sin(angles[grid$j])
  r <- radius[grid$i]
  offsets <- r *
    (cos_a * frames$normals[grid$i, ] + sin_a * frames$binormals[grid$i, ])
  centerline[grid$i, ] + offsets
}


#' Triangulate consecutive tube rings into faces
#' @noRd
tube_ring_faces <- function(n_points, segments) {
  n_faces <- (n_points - 1) * segments * 2

  fg <- expand.grid(j = seq_len(segments), i = seq_len(n_points - 1))
  j_next <- ifelse(fg$j == segments, 1L, fg$j + 1L)
  v1 <- (fg$i - 1L) * segments + fg$j
  v2 <- (fg$i - 1L) * segments + j_next
  v3 <- fg$i * segments + fg$j
  v4 <- fg$i * segments + j_next
  faces <- matrix(0L, nrow = n_faces, ncol = 3)
  odds <- seq(1, n_faces, by = 2)
  faces[odds, ] <- cbind(v1, v2, v3)
  faces[odds + 1L, ] <- cbind(v2, v4, v3)
  faces
}


#' Compute parallel transport frames along curve
#'
#' Uses the parallel transport method to compute stable perpendicular frames
#' along a 3D curve, avoiding the twisting artifacts of Frenet-Serret frames.
#'
#' @param curve Matrix with N rows and 3 columns
#' @return List with tangents, normals, and binormals matrices
#' @keywords internal
#' @noRd
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


#' Rotate vector around axis by angle (Rodrigues' formula)
#' @keywords internal
#' @noRd
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
#' @noRd
compute_streamline_density <- function(
  streamlines,
  centerline,
  search_radius = 2
) {
  valid_sl <- Filter(function(sl) is.matrix(sl) && nrow(sl) > 0, streamlines)

  vapply(
    seq_len(nrow(centerline)),
    function(i) {
      center <- centerline[i, ]
      sum(vapply(
        valid_sl,
        function(sl) {
          any(rowSums(sweep(sl, 2, center)^2) <= search_radius^2)
        },
        logical(1)
      ))
    },
    numeric(1)
  )
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
#' @noRd
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
      suppressWarnings({
        hdr <- RNifti::niftiHeader(template_file)
        RNifti::xform(hdr)
      }),
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
  offsets <- as.matrix(expand.grid(
    dx = seq(-radius, radius),
    dy = seq(-radius, radius),
    dz = seq(-radius, radius)
  ))
  offsets <- offsets[rowSums(offsets^2) <= radius^2, , drop = FALSE]

  coords <- sweep(offsets, 2, center, "+")
  in_bounds <- coords[, 1] >= 1 &
    coords[, 1] <= dims[1] &
    coords[, 2] >= 1 &
    coords[, 2] <= dims[2] &
    coords[, 3] >= 1 &
    coords[, 3] <= dims[3]
  coords <- coords[in_bounds, , drop = FALSE]

  for (k in seq_len(nrow(coords))) {
    vol[coords[k, 1], coords[k, 2], coords[k, 3]] <- label_value
  }
  vol
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
  all_coords <- collect_streamline_coords(streamlines)

  if (is.null(all_coords) || nrow(all_coords) == 0) {
    return(FALSE)
  }

  min_coord <- min(all_coords, na.rm = TRUE)
  max_coord <- max(all_coords, na.rm = TRUE)

  if (min_coord < -10) {
    return(FALSE)
  }

  if (min_coord >= 0 && max_coord <= 300) {
    return(coords_fit_dims(max_coord, dims))
  }

  FALSE
}


#' Stack streamline xyz coordinates into a single matrix
#' @noRd
collect_streamline_coords <- function(streamlines) {
  do.call(
    rbind,
    lapply(streamlines, function(s) {
      if (is.matrix(s) && nrow(s) > 0) {
        s[, 1:3, drop = FALSE]
      } else {
        NULL
      }
    })
  )
}


#' Check whether the coordinate range is consistent with voxel dims
#' @noRd
coords_fit_dims <- function(max_coord, dims) {
  if (!is.null(dims) && max(dims) > 0) {
    return(max_coord <= max(dims) * 1.1)
  }
  TRUE
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

#' Snapshot every tract volume across every projection view
#' @noRd
snapshot_tract_views <- function(
  tract_volumes,
  tract_labels,
  views,
  dirs,
  skip_existing
) {
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
}


#' Snapshot cortex reference slices for anatomical context
#' @noRd
snapshot_cortex_views <- function(
  cortex_vol,
  cortex_slices,
  dirs,
  skip_existing
) {
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


#' Auto-detect tract coordinate space and report it when verbose
#' @noRd
detect_tract_coord_space <- function(streamlines, verbose) {
  all_streamlines <- unlist(streamlines, recursive = FALSE)
  coords_are_voxels <- detect_coords_are_voxels(all_streamlines)
  if (verbose) {
    space <- if (coords_are_voxels) "voxel" else "RAS" # nolint: object_usage_linter
    cli::cli_alert_info("Auto-detected coordinate space: {.val {space}}")
  }
  coords_are_voxels
}


#' Center meshes around origin
#'
#' Computes the global centroid of all mesh vertices and translates
#' all meshes to center around the origin.
#'
#' @param meshes_list Named list of meshes
#' @return Centered meshes list
#' @keywords internal
#' @noRd
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
