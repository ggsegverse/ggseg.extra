# Tract step functions ----

#' @noRd
tract_read_input <- function(input_tracts, tract_names) {
  if (is.list(input_tracts) && !is.character(input_tracts)) {
    streamlines_data <- input_tracts
    if (is.null(tract_names)) {
      tract_names <- names(input_tracts)
      if (is.null(tract_names)) {
        tract_names <- paste0("tract_", seq_along(input_tracts))
      }
    }
  } else {
    if (!all(file.exists(input_tracts))) {
      missing <- # nolint: object_usage_linter
        input_tracts[!file.exists(input_tracts)]
      cli::cli_abort("Tract files not found: {.path {missing}}")
    }

    if (is.null(tract_names)) {
      tract_names <- file_path_sans_ext(basename(input_tracts))
    }

    streamlines_data <- safe_future_map(
      input_tracts,
      read_tractography,
      .options = furrr_options(packages = "ggseg.extra")
    )
    names(streamlines_data) <- tract_names
  }

  if (length(streamlines_data) == 0) {
    cli::cli_abort("No tract data provided")
  }

  list(streamlines_data = streamlines_data, tract_names = tract_names)
}


#' @noRd
tract_create_meshes <- function(
  streamlines_data,
  tract_names,
  centerline_method,
  n_points,
  tube_radius,
  tube_segments,
  density_radius_range
) {
  p <- progressor(steps = length(streamlines_data))

  meshes_list <- safe_future_map2(
    streamlines_data,
    tract_names,
    function(streamlines, tract_name) {
      mesh <- tract_tube_mesh(
        streamlines,
        centerline_method,
        n_points,
        tube_radius,
        tube_segments,
        density_radius_range
      )
      p()
      mesh
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c(
        "centerline_method",
        "n_points",
        "tube_radius",
        "density_radius_range",
        "tube_segments",
        "p"
      )
    )
  )
  names(meshes_list) <- tract_names
  meshes_list <- Filter(Negate(is.null), meshes_list)

  if (length(meshes_list) == 0) {
    cli::cli_abort("No meshes were successfully created")
  }

  center_meshes(meshes_list)
}


#' Tube mesh for one tract, NULL when the centerline is degenerate
#' @noRd
tract_tube_mesh <- function(
  streamlines,
  centerline_method,
  n_points,
  tube_radius,
  tube_segments,
  density_radius_range
) {
  centerline <- extract_centerline(
    streamlines,
    method = centerline_method,
    n_points = n_points
  )

  if (is.null(centerline) || nrow(centerline) < 2) {
    return(NULL)
  }

  radius <- resolve_tube_radius(
    tube_radius,
    streamlines,
    centerline,
    density_radius_range
  )

  generate_tube_mesh(
    centerline = centerline,
    radius = radius,
    segments = tube_segments
  )
}


#' @noRd
tract_build_core <- function(meshes_list, colours, tract_names) {
  core_rows <- lapply(seq_along(meshes_list), function(i) {
    tract_name <- names(meshes_list)[i]
    data.frame(
      hemi = detect_hemi(tract_name, default = "midline"),
      region = clean_region_name(tract_name),
      label = tract_name,
      stringsAsFactors = FALSE
    )
  })

  core <- do.call(rbind, core_rows)

  raw_colours <- colours[names(meshes_list)]
  palette <- if (all(is.na(raw_colours))) {
    NULL
  } else {
    stats::setNames(raw_colours, names(meshes_list))
  }

  centerlines_df <- data.frame(
    label = names(meshes_list),
    stringsAsFactors = FALSE
  )
  centerlines_df$points <- lapply(meshes_list, function(m) {
    m$metadata$centerline
  })
  centerlines_df$tangents <- lapply(meshes_list, function(m) {
    m$metadata$tangents
  })

  atlas_name <- if (length(tract_names) == 1) tract_names[1] else "tracts"

  list(
    core = core,
    palette = palette,
    centerlines_df = centerlines_df,
    atlas_name = atlas_name
  )
}


#' @noRd
tract_create_snapshots <- function(
  streamlines_data,
  centerlines_df,
  input_aseg,
  views,
  dirs,
  coords_are_voxels,
  skip_existing,
  tract_radius,
  verbose
) {
  aseg_vol <- read_volume(input_aseg)
  dims <- dim(aseg_vol)

  if (is.null(views)) {
    views <- default_tract_views(dims)
  }
  cortex_slices <- create_cortex_slices(views, dims)

  tract_labels <- centerlines_df$label

  tract_volumes <- tract_volume_map(
    streamlines_data,
    tract_labels,
    input_aseg,
    tract_radius,
    coords_are_voxels
  )

  cortex_labels <- detect_cortex_labels(aseg_vol)

  cortex_vol <- array(0L, dim = dims)
  for (lbl in c(cortex_labels$left, cortex_labels$right)) {
    cortex_vol[aseg_vol == lbl] <- 1L
  }

  snapshot_tract_views(
    tract_volumes = tract_volumes,
    tract_labels = tract_labels,
    views = views,
    dirs = dirs,
    skip_existing = skip_existing
  )

  if (verbose) {
    cli::cli_alert_info("Creating cortex reference slices")
  }

  snapshot_cortex_views(cortex_vol, cortex_slices, dirs, skip_existing)

  list(views = views, cortex_slices = cortex_slices)
}


#' Rasterise every tract centerline into its own label volume
#' @noRd
tract_volume_map <- function(
  streamlines_data,
  tract_labels,
  input_aseg,
  tract_radius,
  coords_are_voxels
) {
  p <- progressor(steps = length(tract_labels))

  tract_volumes <- safe_future_pmap(
    list(label = tract_labels, i = seq_along(tract_labels)),
    function(label, i) {
      centerline <- streamlines_data[[label]]

      if (is.list(centerline) && !is.matrix(centerline)) {
        centerline <- extract_centerline(centerline, n_points = 50)
      }

      vol <- streamlines_to_volume(
        centerline = centerline,
        template_file = input_aseg,
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
        "streamlines_data",
        "input_aseg",
        "tract_radius",
        "coords_are_voxels",
        "p"
      )
    )
  )
  names(tract_volumes) <- tract_labels

  tract_volumes
}


#' Default tract atlas view configuration
#'
#' Creates projection views optimized for white matter tract visualization.
#' Tracts typically span large portions of the brain, so projections cover
#' wider ranges than subcortical views.
#'
#' @inheritParams default_subcortical_views
#'
#' @return data.frame with columns: name, type, start, end
#' @keywords internal
#' @noRd
default_tract_views <- function(dims) {
  scale <- dims[1] / 256
  chunk_size <- round(30 * scale)
  half_chunk <- chunk_size %/% 2

  z_lo <- round(60 * scale)
  z_hi <- round(180 * scale)
  y_lo <- round(50 * scale)
  y_hi <- round(200 * scale)

  axial_views <- make_view_chunks(z_lo, z_hi, chunk_size, "axial")
  coronal_views <- make_view_chunks(y_lo, y_hi, chunk_size, "coronal")

  mid_x <- dims[1] %/% 2
  gap <- round(10 * scale)
  lateral_peak <- round(40 * scale)

  sagittal_views <- data.frame(
    name = c("sagittal_midline", "sagittal_left", "sagittal_right"),
    type = "sagittal",
    start = c(
      mid_x - half_chunk,
      mid_x + gap + lateral_peak - half_chunk,
      mid_x - gap - lateral_peak - half_chunk
    ),
    end = c(
      mid_x + half_chunk,
      mid_x + gap + lateral_peak + half_chunk,
      mid_x - gap - lateral_peak + half_chunk
    ),
    stringsAsFactors = FALSE
  )

  rbind(axial_views, coronal_views, sagittal_views)
}


#' Resolve tube radius specification
#' @keywords internal
#' @noRd
resolve_tube_radius <- function(
  tube_radius,
  streamlines,
  centerline,
  density_range
) {
  n_points <- nrow(centerline)

  if (is.numeric(tube_radius)) {
    if (length(tube_radius) == 1) {
      return(rep(tube_radius, n_points))
    }
    if (length(tube_radius) == n_points) {
      return(tube_radius)
    }
    cli::cli_abort("Numeric tube_radius must be length 1 or {n_points}")
  }

  if (is.character(tube_radius) && tube_radius == "density") {
    density <- compute_streamline_density(
      streamlines,
      centerline,
      search_radius = 2
    )
    if (max(density) == 0) {
      return(rep(mean(density_range), n_points))
    }
    normalized <- density / max(density)
    return(
      density_range[1] + normalized * (density_range[2] - density_range[1])
    )
  }

  cli::cli_abort(
    "{.arg tube_radius} must be numeric or the string {.val density}, not
    {.val {tube_radius}}"
  )
}
