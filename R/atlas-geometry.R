# Geometry processing functions for atlas creation ----
# These functions are shared across volumetric and cortical atlas pipelines

#' @noRd
#' @importFrom dplyr bind_rows group_by summarise
#' @importFrom furrr future_map furrr_options
#' @importFrom progressr progressor
#' @importFrom sf st_is_empty st_combine st_as_sf st_make_valid
#' @importFrom tools file_path_sans_ext
extract_contours <- function(
  input_dir,
  output_dir,
  verbose = get_verbose(), # nolint: object_usage_linter
  step = "",
  vertex_size_limits = NULL
) {
  rlang::check_installed(
    "terra",
    reason = "for contour extraction from raster images"
  )
  if (verbose) {
    cli::cli_progress_step("{step} Extracting contours")
  }

  regions <- list.files(input_dir, full.names = TRUE)
  region_names <- file_path_sans_ext(basename(regions))

  max_val <- 0
  for (f in regions[seq_len(min(10, length(regions)))]) {
    r <- suppressWarnings(terra::rast(f))
    m <- terra::global(r, fun = "max", na.rm = TRUE)[1, 1]
    if (m > max_val) {
      max_val <- m
    }
    if (max_val > 0) break
  }
  if (max_val == 0) {
    max_val <- 1
  }

  p <- progressor(
    steps = length(regions),
    label = paste(step, "Extracting contours")
  )
  contourobjs <- safe_future_map(
    regions,
    function(region_file) {
      r <- suppressWarnings(terra::rast(region_file))
      result <- get_contours(
        r,
        max_val = max_val,
        vertex_size_limits = vertex_size_limits,
        verbose = get_verbose() # nolint: object_usage_linter
      )
      p()
      result
    },
    .options = furrr::furrr_options(
      packages = c("terra", "ggseg.extra"),
      globals = c("max_val", "vertex_size_limits", "p")
    )
  )
  names(contourobjs) <- region_names

  kp <- !vapply(contourobjs, is.null, logical(1))
  contourobjs2 <- contourobjs[kp]

  contours <- bind_rows(contourobjs2, .id = "filenm")
  contours <- group_by(contours, filenm)
  contours <- summarise(contours, geometry = st_combine(geometry))
  contours <- st_as_sf(contours)
  contours <- st_make_valid(contours)

  save(contours, file = file.path(output_dir, "contours.rda"))

  if (verbose) {
    cli::cli_progress_done()
  }

  invisible(contours)
}


#' Pass extracted contours through unchanged
#'
#' Pipeline smoothing and simplification have been removed from atlas
#' creation. Apply [atlas_smooth()] after the atlas is built instead.
#' This function only filters out invalid geometries and writes the
#' result to `contours_smoothed.rda` so downstream pipeline steps that
#' load that filename continue to work.
#'
#' @noRd
smooth_contours <- function(
  dir,
  smoothness = NULL, # nolint: object_usage_linter.
  step = "",
  verbose = get_verbose() # nolint: object_usage_linter
) {
  load_rda(file.path(dir, "contours.rda"))

  contours <- filter_valid_geometries(contours)
  if (nrow(contours) == 0) {
    cli::cli_warn("No valid contours found after extraction")
  }

  save(contours, file = file.path(dir, "contours_smoothed.rda"))
  invisible(contours)
}


#' Pass smoothed contours through unchanged
#'
#' Pipeline simplification has been removed; this writes the loaded
#' contours back to `contours_reduced.rda` after filtering invalid
#' geometries so the assembly step can keep reading that filename.
#'
#' @noRd
reduce_vertex <- function(
  dir,
  tolerance = NULL,
  smoothness = NULL,
  step = "",
  verbose = get_verbose() # nolint: object_usage_linter
) {
  load_rda(file.path(dir, "contours_smoothed.rda"))

  contours <- filter_valid_geometries(contours)
  if (nrow(contours) == 0) {
    cli::cli_warn("No valid contours to simplify")
  }
  save(contours, file = file.path(dir, "contours_reduced.rda"))
  invisible(contours)
}


#' Filter out geometries with non-finite bounds or coordinates
#' @noRd
#' @importFrom sf st_bbox st_is_empty st_coordinates st_make_valid
filter_valid_geometries <- function(sf_obj) {
  if (nrow(sf_obj) == 0) {
    return(sf_obj)
  }

  sf_obj <- st_make_valid(sf_obj)

  valid_idx <- vapply(
    seq_len(nrow(sf_obj)),
    function(i) {
      geom <- sf_obj$geometry[i]

      if (st_is_empty(geom)) {
        return(FALSE)
      }

      coords <- tryCatch(
        st_coordinates(geom),
        error = function(e) NULL
      )
      if (is.null(coords) || nrow(coords) == 0) {
        return(FALSE)
      }
      if (!all(is.finite(coords[, 1:2]))) {
        return(FALSE)
      }

      bbox <- tryCatch(
        st_bbox(geom),
        error = function(e) NULL
      )
      if (is.null(bbox)) {
        return(FALSE)
      }
      if (!all(is.finite(bbox))) {
        return(FALSE)
      }

      TRUE
    },
    logical(1)
  )

  sf_obj[valid_idx, , drop = FALSE]
}


# Atlas geometry post-processing ----

#' Smooth and simplify atlas 2D contours
#'
#' Topology-preserving simplification of atlas sf geometry via
#' [rmapshaper::ms_simplify()], with optional morphological closing
#' (positive then negative [sf::st_buffer()]) layered on top to round
#' off voxel-edge stair-steps into smooth curves. Shared boundaries
#' between adjacent regions are simplified together, preventing gaps.
#'
#' By default all labels are smoothed equally. Use `labels` to smooth only
#' matching labels, or `exclude` to smooth everything except matching labels.
#' Only one of `labels` or `exclude` may be specified.
#'
#' @param atlas A `ggseg_atlas` object with sf data.
#' @param keep Proportion of vertices to retain (0--1), or `NULL` to skip
#'   vertex simplification. Lower values produce simpler shapes; values
#'   near 1 are an effective no-op. Default 0.05.
#' @param smoothness Buffer distance in geometry units for morphological
#'   closing after simplification. 0 (the default) skips closing. Values
#'   of 2--3 round off voxel-edge stair-steps on millimetre voxel grids
#'   without merging adjacent regions; larger values produce rounder
#'   shapes but can bleed nearby region boundaries together.
#' @param labels Optional regex pattern. Only labels matching this pattern
#'   are smoothed; others are left unchanged.
#' @param exclude Optional regex pattern. Labels matching this pattern are
#'   left unchanged; all others are smoothed.
#'
#' @return A modified `ggseg_atlas` with simplified sf geometry.
#' @export
#' @importFrom sf st_make_valid
#'
#' @examples
#' \dontrun{
#' # Vertex reduction only (legacy behaviour).
#' atlas <- atlas_smooth(my_atlas, keep = 0.05)
#'
#' # Keep cortex outline detailed, simplify everything else.
#' atlas <- atlas_smooth(my_atlas, keep = 0.2, exclude = "cortex_|Cortex")
#'
#' # Round off jagged voxel edges without dropping vertices.
#' atlas <- atlas_smooth(my_atlas, keep = NULL, smoothness = 3)
#'
#' # Per-region tuning: hard simplification for tiny nuclei, gentle
#' # closing for the brain outline.
#' atlas <- atlas_smooth(my_atlas, keep = 0.05, exclude = "cortex_")
#' atlas <- atlas_smooth(atlas, keep = NULL, smoothness = 3, labels = "cortex_")
#' }
atlas_smooth <- function(
  atlas,
  keep = 0.05,
  smoothness = 0,
  labels = NULL,
  exclude = NULL
) {
  geom <- ggseg.formats::atlas_geom(atlas)
  if (is.null(geom)) {
    cli::cli_warn("Atlas has no 2D geometry, nothing to smooth")
    return(atlas)
  }

  if (!is.null(labels) && !is.null(exclude)) {
    cli::cli_abort(
      "Specify only one of {.arg labels} or {.arg exclude}, not both."
    )
  }

  do_simplify <- !is.null(keep) && !is.na(keep)
  do_close <- isTRUE(smoothness > 0)
  if (!do_simplify && !do_close) {
    return(atlas)
  }

  apply_ops <- function(d) {
    if (do_simplify) {
      d <- simplify_sf_topology(d, keep = keep)
    }
    if (do_close) {
      d <- smooth_sf_light(d, smoothness = smoothness)
    }
    d
  }

  # Smoothing is an sf/GEOS operation; work on the sf representation and
  # restore the atlas's original representation afterwards.
  was_polygon <- ggseg.formats::is_atlas_polygon(atlas)
  sf_data <- ggseg.formats::atlas_geom(ggseg.formats::as_sf_atlas(atlas))

  if (!is.null(labels) || !is.null(exclude)) {
    sf_labels <- sf_data$label
    if (!is.null(labels)) {
      mask <- grepl(labels, sf_labels, ignore.case = TRUE)
    } else {
      mask <- !grepl(exclude, sf_labels, ignore.case = TRUE)
    }
    mask[is.na(sf_labels)] <- FALSE

    # Preserve the caller's row order: smoothing must not change which
    # regions draw on top (e.g. context regions placed behind core regions
    # by atlas_region_contextual()). Tag rows, process the target subset,
    # reassemble, then restore the original order.
    sf_data$.smooth_order <- seq_len(nrow(sf_data))
    target <- sf_data[mask, , drop = FALSE]
    rest <- sf_data[!mask, , drop = FALSE]

    target <- apply_ops(target)
    sf_data <- rbind(target, rest)
    sf_data <- sf_data[order(sf_data$.smooth_order), , drop = FALSE]
    sf_data$.smooth_order <- NULL
    sf_data <- sf::st_make_valid(sf_data)
  } else {
    sf_data <- apply_ops(sf_data)
  }

  atlas$data$geom <- sf_data
  # Drop any legacy slots so they can't shadow $geom with stale, unsmoothed
  # geometry for direct readers / re-serialisation.
  atlas$data$sf <- NULL
  atlas$data$polygons <- NULL
  if (was_polygon) {
    atlas <- ggseg.formats::as_polygon_atlas(atlas)
  }
  atlas
}


#' @rdname atlas_smooth
#' @export
atlas_simplify <- function(atlas, keep = 0.05) {
  lifecycle::deprecate_warn(
    "1.9.9.9003",
    "atlas_simplify()",
    "atlas_smooth()"
  )
  atlas_smooth(atlas, keep = keep)
}


#' Topology-preserving simplification of sf polygons
#'
#' Wraps [rmapshaper::ms_simplify()] to reduce vertex count while keeping
#' shared boundaries between adjacent regions aligned. Used by all atlas
#' pipelines and the user-facing [atlas_smooth()]/[atlas_simplify()].
#'
#' @param sf_data An sf data.frame.
#' @param keep Proportion of vertices to retain (0--1). Default 0.05.
#' @return Simplified sf data.frame.
#' @noRd
simplify_sf_topology <- function(sf_data, keep = 0.05) {
  group_col <- if ("view" %in% names(sf_data)) {
    "view"
  } else if ("filenm" %in% names(sf_data)) {
    sf_data$.view_group <- sub("_[^_]+$", "", sf_data$filenm)
    ".view_group"
  } else {
    NULL
  }

  if (!is.null(group_col)) {
    groups <- unique(sf_data[[group_col]])
    if (length(groups) > 1) {
      parts <- lapply(groups, function(g) {
        group_sf <- sf_data[sf_data[[group_col]] == g, , drop = FALSE]
        rmapshaper::ms_simplify(group_sf, keep = keep, keep_shapes = TRUE)
      })
      sf_data <- do.call(rbind, parts)
      if (".view_group" %in% names(sf_data)) {
        sf_data$.view_group <- NULL
      }
      return(sf::st_make_valid(sf_data))
    }
  }

  sf_data <- rmapshaper::ms_simplify(sf_data, keep = keep, keep_shapes = TRUE)
  sf::st_make_valid(sf_data)
}


#' Light buffer smoothing for polygon edges
#'
#' Applies a small positive then negative buffer to round off jagged edges
#' after simplification. The buffer distance is small enough that gaps
#' between adjacent regions remain negligible.
#'
#' @param sf_data An sf data.frame.
#' @param smoothness Buffer distance in geometry units. 0 skips smoothing.
#' @return Smoothed sf data.frame.
#' @noRd
#' @importFrom sf st_buffer st_make_valid
smooth_sf_light <- function(sf_data, smoothness = 0) {
  if (smoothness <= 0) {
    return(sf_data)
  }
  sf_data <- sf::st_buffer(sf_data, dist = smoothness, nQuadSegs = 8L)
  sf_data <- sf::st_buffer(sf_data, dist = -smoothness, nQuadSegs = 8L)
  sf::st_make_valid(sf_data)
}


#' Pass-through stub kept for backward compatibility
#'
#' Pipeline-time smoothing has been removed; callers should rely on
#' [atlas_smooth()] for any post-creation simplification. This helper
#' returns its input unchanged.
#'
#' @noRd
smooth_and_simplify_sf <- function(sf_data, smooth_refinements = 0, keep = 0) {
  sf_data
}


#' Build sf geometry from volumetric contours
#'
#' Shared by subcortical and tract pipelines. Loads reduced contours,
#' assigns view names, flips y-axis, adjusts coordinates, and extracts
#' labels from filenames.
#'
#' @param contours_file Path to `contours_reduced.rda`
#' @param views data.frame with `name` column of view names
#' @param cortex_slices Optional data.frame with `name` column for cortex
#'   slice view names (appended to `views$name`)
#' @return sf data.frame with `label`, `view`, `geometry` columns, sorted
#'   with cortex rows first
#' @noRd
#' @importFrom dplyr select arrange desc
#' @importFrom sf st_as_sf
build_contour_sf <- function(contours_file, views, cortex_slices = NULL) {
  conts <- make_multipolygon(contours_file)

  filenm_base <- sub("\\.png$", "", conts$filenm)

  all_view_names <- if (!is.null(cortex_slices)) {
    c(views$name, cortex_slices$name)
  } else {
    views$name
  }

  conts$view <- vapply(
    filenm_base,
    function(fn) {
      for (vn in all_view_names) {
        if (startsWith(fn, paste0(vn, "_"))) {
          return(vn)
        }
      }
      NA_character_
    },
    character(1)
  )

  # Flip y-axis: snapshot PNGs have origin top-left, sf expects bottom-left
  conts$geometry <- conts$geometry * matrix(c(1, 0, 0, -1), 2, 2)

  conts <- layout_volumetric_views(conts) # nolint: object_usage_linter.

  filenm_base <- sub("\\.png$", "", conts$filenm)
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
  # Ensure the cortex outline is the first row per view so it draws as
  # the bottom layer; structures get drawn on top. The outline can be
  # named `cortex_` (legacy single-slice path) or `cortex` (current
  # projection path, where sanitize_label strips the trailing
  # underscore). Match both — but exact equality, not a loose
  # `grepl("cortex", ...)` which would also catch `Cerebellar_Cortex_*`
  # and let cerebellum sort above the outline (HO2 regression).
  sf_data <- dplyr::arrange(
    sf_data,
    view,
    !label %in% c("cortex_", "cortex")
  )

  sf_data
}


#' @noRd
#' @importFrom dplyr group_by summarise ungroup
#' @importFrom sf st_combine st_coordinates st_geometry
make_multipolygon <- function(contourfile) {
  load_rda(contourfile)

  contours <- contours |>
    group_by(filenm) |>
    summarise(geometry = st_combine(geometry)) |>
    ungroup()

  bounds <- vapply(
    seq_len(nrow(contours)),
    function(i) {
      coords <- st_coordinates(contours[i, ])
      c(
        xmin = min(coords[, "X"]),
        ymin = min(coords[, "Y"]),
        xmax = max(coords[, "X"]),
        ymax = max(coords[, "Y"])
      )
    },
    numeric(4)
  )

  new_bb <- c(
    xmin = min(bounds["xmin", ]),
    ymin = min(bounds["ymin", ]),
    xmax = max(bounds["xmax", ]),
    ymax = max(bounds["ymax", ])
  )
  attr(new_bb, "class") <- "bbox"
  attr(sf::st_geometry(contours), "bbox") <- new_bb

  contours
}
