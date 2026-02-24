# Cortical step functions ----


# Camera positions from ggseg3d::camera_preset_to_position
# Each vector is the camera position; it looks at the origin.
camera_presets <- list(
  lh_lateral  = c(-350,   0,    0),
  lh_medial   = c(350,    0,    0),
  lh_superior = c(-120,   0,  330),
  lh_inferior = c(-120,   0, -330),
  rh_lateral  = c(350,    0,    0),
  rh_medial   = c(-350,   0,    0),
  rh_superior = c(120,    0,  330),
  rh_inferior = c(120,    0, -330)
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
    for (col in 1:3) {
      acc <- tapply(fn[, col], faces[, j], sum)
      vi <- as.integer(names(acc))
      normals[vi, col] <- normals[vi, col] + as.numeric(acc)
    }
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

  keep <- vapply(seq_len(nrow(region_grid)), function(i) {
    label <- region_grid$region_label[i]
    hemi <- region_grid$hemisphere[i]
    view <- region_grid$view[i]

    key <- paste(hemi, view, sep = "_")
    cam <- camera_presets[[key]]
    if (is.null(cam)) return(TRUE)

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
    if (length(r_indices) == 0) return(TRUE)

    region_normals <- vnormals[[hemi]][r_indices, , drop = FALSE]
    region_faces_camera(region_normals, cam)
  }, logical(1))

  region_grid[keep, , drop = FALSE]
}


#' @noRd
cortical_brain_snapshots <- function(
  atlas_3d,
  hemisphere,
  views,
  dirs,
  skip_existing,
  snapshot_dim = 800
) {
  p <- progressor(steps = length(hemisphere))
  invisible(safe_future_map(
    hemisphere,
    function(hemi) {
      snapshot_brain_full_batch(
        atlas = atlas_3d,
        hemisphere = hemi,
        views = views,
        surface = "inflated",
        output_dir = dirs$base,
        skip_existing = skip_existing,
        snapshot_dim = snapshot_dim
      )
      p()
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("atlas_3d", "dirs", "skip_existing", "snapshot_dim", "p")
    )
  ))
}


#' @noRd
cortical_region_snapshots <- function(
  atlas_3d,
  components,
  hemisphere,
  views,
  dirs,
  skip_existing,
  snapshot_dim = 800
) {
  region_labels <- unique(components$core$label[
    !is.na(components$core$label)
  ])

  region_grid <- expand.grid(
    region_label = region_labels,
    hemisphere = hemisphere,
    view = views,
    stringsAsFactors = FALSE
  )

  region_grid <- region_grid[
    (grepl("^lh_", region_grid$region_label) &
       region_grid$hemisphere == "lh") |
      (grepl("^rh_", region_grid$region_label) &
         region_grid$hemisphere == "rh"),
  ]

  region_grid <- filter_visible_regions(region_grid, components$vertices_df)

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
        "atlas_3d", "region_grid", "dirs",
        "skip_existing", "snapshot_dim", "p"
      )
    )
  ))
}


#' @noRd
cortical_isolate_regions <- function(dirs, skip_existing) {
  ffs <- list.files(dirs$snapshots, full.names = TRUE)
  file_grid <- data.frame(
    input_file = ffs,
    output_file = file.path(dirs$masks, basename(ffs)),
    interim_file = file.path(dirs$processed, basename(ffs))
  )

  p <- progressor(steps = nrow(file_grid))
  invisible(safe_future_pmap(
    file_grid,
    function(input_file, output_file, interim_file) {
      isolate_region(
        input_file = input_file,
        output_file = output_file,
        interim_file = interim_file,
        skip_existing = skip_existing
      )
      p()
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("skip_existing", "p")
    )
  ))
}


#' @noRd
cortical_build_sf <- function(dirs) {
  load_reduced_contours(dirs$base) |>
    layout_cortical_views() |> # nolint: object_usage_linter.
    group_by(view, label) |>
    mutate(geometry = st_combine(geometry)) |>
    ungroup() |>
    select(label, view, geometry) |>
    sf::st_as_sf()
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
labels_region_snapshots <- function(
  atlas_3d,
  components,
  hemi_short,
  views,
  dirs,
  skip_existing,
  snapshot_dim = 800
) {
  region_labels <- unique(
    components$core$label[!is.na(components$core$region)]
  )
  region_grid <- expand.grid(
    region_label = region_labels,
    hemisphere = hemi_short,
    view = views,
    stringsAsFactors = FALSE
  )

  region_grid <- region_grid[
    (grepl("^lh_", region_grid$region_label) &
       region_grid$hemisphere == "lh") |
      (grepl("^rh_", region_grid$region_label) &
         region_grid$hemisphere == "rh") |
      (!grepl("^[lr]h_", region_grid$region_label)),
  ]

  region_grid <- filter_visible_regions(region_grid, components$vertices_df)

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
        "atlas_3d", "region_grid", "dirs",
        "skip_existing", "snapshot_dim", "p"
      )
    )
  ))

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
