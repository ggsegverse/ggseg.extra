# Cortical step functions ----

# Camera positions from ggseg3d::camera_preset_to_position
# Each vector is the camera position; it looks at the origin.
camera_presets <- list(
  lh_lateral = c(-350, 0, 0),
  lh_medial = c(350, 0, 0),
  lh_superior = c(-120, 0, 330),
  lh_inferior = c(-120, 0, -330),
  rh_lateral = c(350, 0, 0),
  rh_medial = c(-350, 0, 0),
  rh_superior = c(120, 0, 330),
  rh_inferior = c(120, 0, -330)
)


#' @noRd
compute_vertex_normals <- function(mesh) {
  verts <- as.matrix(mesh$vertices)
  faces <- as.matrix(mesh$faces) + 1L
  normals <- matrix(0, nrow = nrow(verts), ncol = 3)

  v0 <- verts[faces[, 1], , drop = FALSE]
  v1 <- verts[faces[, 2], , drop = FALSE]
  v2 <- verts[faces[, 3], , drop = FALSE]
  e1 <- v1 - v0
  e2 <- v2 - v0
  fn <- cbind(
    e1[, 2] * e2[, 3] - e1[, 3] * e2[, 2],
    e1[, 3] * e2[, 1] - e1[, 1] * e2[, 3],
    e1[, 1] * e2[, 2] - e1[, 2] * e2[, 1]
  )

  for (j in 1:3) {
    sums <- rowsum(fn, faces[, j])
    vi <- as.integer(rownames(sums))
    normals[vi, ] <- normals[vi, ] + sums
  }

  norms <- sqrt(rowSums(normals^2))
  norms[norms == 0] <- 1
  normals / norms
}

#' @noRd
region_faces_camera <- function(vertex_normals, camera_pos) {
  dots <- vertex_normals %*% camera_pos
  any(dots > 0)
}


#' @noRd
filter_visible_regions <- function(region_grid, vertices_df) {
  mesh_lh <- ggseg.formats::get_brain_mesh("lh", "inflated")
  mesh_rh <- ggseg.formats::get_brain_mesh("rh", "inflated")

  meshes <- list(lh = mesh_lh, rh = mesh_rh)
  vnormals <- lapply(meshes, compute_vertex_normals)
  verbose <- is_verbose(2)

  keep <- vapply(
    seq_len(nrow(region_grid)),
    function(i) {
      region_visible_in_view(
        label = region_grid$region_label[i],
        hemi = region_grid$hemisphere[i],
        view = region_grid$view[i],
        vertices_df = vertices_df,
        vnormals = vnormals,
        verbose = verbose
      )
    },
    logical(1)
  )

  region_grid[keep, , drop = FALSE]
}


#' @noRd
region_visible_in_view <- function(
  label,
  hemi,
  view,
  vertices_df,
  vnormals,
  verbose
) {
  key <- paste(hemi, view, sep = "_")
  cam <- camera_presets[[key]]
  if (is.null(cam)) {
    return(TRUE)
  }

  idx <- which(vertices_df$label == label)
  if (length(idx) == 0) {
    if (verbose) {
      cli::cli_alert_info(
        "No vertex data for {.val {label}}, keeping"
      )
    }
    return(TRUE)
  }

  v_indices <- vertices_df$vertices[[idx[1]]]
  if (length(v_indices) == 0) {
    if (verbose) {
      cli::cli_alert_info(
        "Empty vertices for {.val {label}}, keeping"
      )
    }
    return(TRUE)
  }

  n_verts <- nrow(vnormals[[hemi]])
  r_indices <- v_indices + 1L
  r_indices <- r_indices[r_indices >= 1L & r_indices <= n_verts]
  if (length(r_indices) == 0) {
    return(TRUE)
  }

  region_normals <- vnormals[[hemi]][r_indices, , drop = FALSE]
  region_faces_camera(region_normals, cam)
}


#' @noRd
run_region_snapshot_batches <- function(
  atlas_3d,
  region_grid,
  dirs,
  skip_existing,
  snapshot_dim
) {
  batch_grid <- unique(region_grid[, c("region_label", "hemisphere")])

  p <- progressor(steps = nrow(batch_grid))
  invisible(safe_future_pmap(
    batch_grid,
    function(region_label, hemisphere) {
      batch_views <- region_grid$view[
        region_grid$region_label == region_label &
          region_grid$hemisphere == hemisphere
      ]
      snapshot_region_batch(
        atlas = atlas_3d,
        region_label = region_label,
        hemisphere = hemisphere,
        views = batch_views,
        surface = "inflated",
        output_dir = dirs$snapshots,
        skip_existing = skip_existing,
        snapshot_dim = snapshot_dim
      )
      p()
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c(
        "atlas_3d",
        "region_grid",
        "dirs",
        "skip_existing",
        "snapshot_dim",
        "p"
      )
    )
  ))
}


# Label atlas step functions ----

#' @noRd
labels_read_files <- function(
  label_files,
  region_names,
  colours,
  default_colours
) {
  p <- progressor(steps = length(label_files))

  all_data <- safe_future_pmap(
    list(
      label_file = label_files,
      i = seq_along(label_files)
    ),
    function(label_file, i) {
      filename <- basename(label_file)

      hemi_short <- if (grepl("^lh\\.", filename)) {
        "lh"
      } else if (grepl("^rh\\.", filename)) {
        "rh"
      } else {
        NA
      }
      hemi <- if (!is.na(hemi_short)) hemi_to_long(hemi_short) else NA

      region <- if (is.null(region_names)) {
        gsub("^[lr]h\\.", "", file_path_sans_ext(filename))
      } else {
        region_names[i]
      }

      label <- if (!is.na(hemi_short)) {
        paste(hemi_short, region, sep = "_")
      } else {
        region
      }
      colour <- if (is.null(colours)) default_colours[i] else colours[i]

      p()
      tibble(
        hemi = hemi,
        region = region,
        label = label,
        colour = colour,
        vertices = list(read_label_vertices(label_file))
      )
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("region_names", "colours", "default_colours", "p")
    )
  )

  bind_rows(all_data)
}


#' @noRd
run_na_region_snapshots <- function(
  atlas_3d,
  hemi_short,
  views,
  dirs,
  skip_existing,
  snapshot_dim
) {
  invisible(safe_future_map(
    hemi_short,
    function(hemi) {
      snapshot_na_regions_batch(
        atlas = atlas_3d,
        hemisphere = hemi,
        views = views,
        surface = "inflated",
        output_dir = dirs$snapshots,
        skip_existing = skip_existing,
        snapshot_dim = snapshot_dim
      )
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("atlas_3d", "dirs", "skip_existing", "snapshot_dim")
    )
  ))
}
