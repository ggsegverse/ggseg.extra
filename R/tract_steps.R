# Tract step functions ----

#' Say that `tube_radius = "density"` had no density to work with
#'
#' The radius is meant to follow how many streamlines pass each point of the
#' centerline. A volume-derived tract has no streamlines -- it has the one
#' centerline extracted from the volume -- so every point counts exactly
#' itself, the density is 1 throughout, and the tube came out uniform at the
#' *maximum* of `density_radius_range`. Silently, and while the documentation
#' recommends `"density"` for tracts with many streamlines.
#'
#' Uniform density carries no information, so the radius is the middle of the
#' range rather than either end, which is what the existing all-zero branch
#' already does for the same reason.
#' @noRd
warn_density_cannot_vary <- function(streamlines, density) {
  # nolint next: object_usage_linter.
  n <- if (is.matrix(streamlines)) 1L else length(streamlines)
  # nolint next: object_usage_linter.
  radius <- "density_radius_range"
  cli::cli_warn(
    c(
      "{.code tube_radius = \"density\"} has no density to follow: every
      centerline point counts {.val {unique(density)[1]}}
      streamline{?s}, from {n} given.",
      "i" = "The radius follows how many streamlines pass each point, so it
      needs a bundle. A tract derived from a volume has only its centerline.",
      "i" = "Using the middle of {.field {radius}} throughout. Pass a numeric
      {.arg tube_radius} to choose the width yourself."
    ),
    wrap = TRUE
  )
  invisible(NULL)
}

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
  check_tract_names_length(streamlines_data, tract_names)

  list(streamlines_data = streamlines_data, tract_names = tract_names)
}


#' Check there is exactly one name per tract
#'
#' The two are walked together by `safe_future_map2()` further down, and furrr
#' reports a length mismatch as `Can't recycle length 3 and length 2 at
#' location 2` -- which names neither the tracts, nor `tract_names`, nor the
#' lookup table the names usually come from. A lookup table with a row per
#' tract it does not have is the normal way to arrive here, so the mismatch is
#' named where it is still obvious what caused it.
#' @noRd
check_tract_names_length <- function(streamlines_data, tract_names) {
  n_tracts <- length(streamlines_data)
  n_names <- length(tract_names)
  if (n_tracts == n_names) {
    return(invisible(NULL))
  }
  cli::cli_abort(
    c(
      "{.arg tract_names} has {n_names} name{?s} for {n_tracts} tract{?s}.",
      "i" = "There must be exactly one name per tract. When the names come
      from a lookup table, check it has a row for each tract and no others."
    ),
    wrap = TRUE
  )
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
  dropped <- tract_names[vapply(meshes_list, is.null, logical(1))]
  meshes_list <- Filter(Negate(is.null), meshes_list)

  if (length(meshes_list) == 0) {
    cli::cli_abort("No meshes were successfully created")
  }
  warn_tracts_without_mesh(dropped)

  center_meshes(meshes_list)
}


#' Say which tracts produced no mesh and are not in the atlas
#'
#' A tract whose centerline is degenerate yields `NULL`, which was filtered
#' away without a word -- the only trace being a tract count lower than the
#' input's. Not gated on `verbose`: a tract missing from the atlas is not
#' progress chatter.
#' @noRd
warn_tracts_without_mesh <- function(dropped) {
  if (length(dropped) == 0) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "{length(dropped)} tract{?s} produced no mesh and {?is/are} not in the
      atlas.",
      "x" = "Dropped: {.val {dropped}}",
      "i" = "A tube needs a centerline, which needs streamlines that span a
      distance. Check these tracts have more than a few distinct points."
    ),
    wrap = TRUE
  )
  invisible(NULL)
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
      region = label_to_region(tract_name),
      label = tract_name,
      stringsAsFactors = FALSE
    )
  })

  core <- core_with_names(do.call(rbind, core_rows))

  # No lookup table means no palette. See build_atlas_components().
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
    atlas_name = atlas_name,
    center_offset = attr(meshes_list, "center_offset")
  )
}


#' @noRd
tract_create_snapshots <- function(
  centerlines_df,
  input_aseg,
  slabs,
  dirs,
  coords_are_voxels,
  skip_existing,
  tract_radius,
  verbose,
  center_offset = NULL
) {
  aseg_vol <- read_volume(input_aseg)
  dims <- dim(aseg_vol)

  if (is.null(slabs)) {
    slabs <- default_tract_slabs(aseg_vol)
  }
  cortex_slices <- create_cortex_slices(slabs, dims, vol = aseg_vol)

  tract_labels <- centerlines_df$label
  # center_meshes() translated these for 3D display; rasterising them against
  # the anatomical reference needs them back in world coordinates.
  centerlines <- stats::setNames(
    lapply(centerlines_df$points, uncenter_coords, offset = center_offset),
    tract_labels
  )

  tract_volumes <- tract_volume_map(
    centerlines,
    tract_labels,
    input_aseg,
    tract_radius,
    coords_are_voxels
  )

  cortex_labels <- detect_cortex_labels(aseg_vol)
  reference_labels <- c(
    cortex_labels$left,
    cortex_labels$right,
    detect_context_labels(aseg_vol)
  )

  cortex_vol <- array(0L, dim = dims)
  for (lbl in reference_labels) {
    cortex_vol[aseg_vol == lbl] <- 1L
  }

  snapshot_tract_views(
    tract_volumes = tract_volumes,
    tract_labels = tract_labels,
    slabs = slabs,
    dirs = dirs,
    skip_existing = skip_existing
  )

  if (verbose) {
    cli::cli_alert_info("Creating cortex reference slices")
  }

  snapshot_cortex_views(cortex_vol, cortex_slices, dirs, skip_existing)

  list(slabs = slabs, cortex_slices = cortex_slices)
}


#' Rasterise every tract centerline into its own label volume
#' @noRd
tract_volume_map <- function(
  centerlines,
  tract_labels,
  input_aseg,
  tract_radius,
  coords_are_voxels
) {
  p <- progressor(steps = length(tract_labels))

  tract_volumes <- safe_future_pmap(
    list(label = tract_labels, i = seq_along(tract_labels)),
    function(label, i) {
      # Reuse the centerline computed for the 3D tube (with the configured
      # n_points / centerline_method) so the 2D projection matches it exactly
      # instead of recomputing a different one here.
      vol <- streamlines_to_volume(
        centerline = centerlines[[label]],
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
        "centerlines",
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


#' Default projection slabs for a tract atlas
#'
#' Slabs are placed from where the labelled voxels of the reference volume
#' sit, not from the size of the grid: four axial and five coronal slabs tile
#' the brain's extent, and three sagittal slabs sit at the midline and out in
#' each hemisphere.
#'
#' @param vol Reference volume in RAS+ orientation, as [read_volume()] returns
#'   it. Any non-zero voxel counts as brain.
#'
#' @return data.frame with columns: name, type, start, end
#' @keywords internal
#' @noRd
default_tract_slabs <- function(vol) {
  labelled <- which(vol != 0, arr.ind = TRUE)
  if (nrow(labelled) == 0) {
    cli::cli_abort(c(
      "{.arg input_aseg} has no labelled voxels to place the 2D views on.",
      "i" = "Pass {.arg slabs} to place them yourself."
    ))
  }
  extent <- apply(labelled, 2, range)

  rbind(
    view_slabs(extent[1, 3], extent[2, 3], 4, "axial"),
    view_slabs(extent[1, 2], extent[2, 2], 5, "coronal"),
    tract_sagittal_slabs(extent[, 1])
  )
}


#' Midline, left and right sagittal slabs across a left-right extent
#'
#' In RAS+ orientation the first axis runs from left to right, so the left
#' hemisphere is on its low side. The lateral slabs are centred most of the
#' way out from the midline and all three are about a quarter of a hemisphere
#' thick -- the proportions the previous fixed positions had on a conformed
#' FreeSurfer brain.
#' @param x_extent First and last labelled index along the first axis.
#' @noRd
tract_sagittal_slabs <- function(x_extent) {
  mid <- round(mean(x_extent))
  hemisphere_width <- (x_extent[2] - x_extent[1]) / 2
  half_thickness <- max(1L, round(hemisphere_width * 0.23))
  lateral_offset <- round(hemisphere_width * 0.78)

  centres <- c(
    sagittal_midline = mid,
    sagittal_left = mid - lateral_offset,
    sagittal_right = mid + lateral_offset
  )
  data.frame(
    name = names(centres),
    type = "sagittal",
    start = pmax(x_extent[1], unname(centres) - half_thickness),
    end = pmin(x_extent[2], unname(centres) + half_thickness),
    stringsAsFactors = FALSE
  )
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
    if (length(unique(density)) < 2L) {
      warn_density_cannot_vary(streamlines, density)
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
