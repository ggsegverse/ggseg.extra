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
  rlang::check_installed("terra",
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


#' @noRd
smooth_contours <- function(
  dir,
  smoothness, # nolint: object_usage_linter.
  step,
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


#' @noRd
reduce_vertex <- function(
  dir,
  tolerance,
  step = "",
  verbose = get_verbose() # nolint: object_usage_linter
) {
  if (verbose) {
    cli::cli_progress_step(
      "{step} Simplifying contours (keep = {.val {tolerance}})"
    )
  }
  load_rda(file.path(dir, "contours_smoothed.rda"))

  contours <- filter_valid_geometries(contours)
  if (nrow(contours) == 0) {
    cli::cli_warn("No valid contours to simplify")
    save(contours, file = file.path(dir, "contours_reduced.rda"))
    return(invisible(contours))
  }

  contours <- simplify_sf_topology(contours, keep = tolerance)
  contours <- filter_valid_geometries(contours)
  save(contours, file = file.path(dir, "contours_reduced.rda"))
  if (verbose) {
    cli::cli_progress_done()
  }
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
#' [rmapshaper::ms_simplify()]. Shared boundaries between adjacent regions
#' are simplified together, preventing gaps between regions.
#'
#' @param atlas A `ggseg_atlas` object with sf data.
#' @param keep Proportion of vertices to retain (0--1). Lower values produce
#'   simpler, smoother shapes. Default 0.05.
#'
#' @return A modified `ggseg_atlas` with simplified sf geometry.
#' @export
#' @importFrom sf st_make_valid
#'
#' @examples
#' \dontrun{
#' atlas <- atlas_smooth(my_atlas, keep = 0.05)
#' plot(atlas)
#' }
atlas_smooth <- function(atlas, keep = 0.05) {
  if (is.null(atlas$data$sf)) {
    cli::cli_warn("Atlas has no sf data, nothing to smooth")
    return(atlas)
  }

  atlas$data$sf <- simplify_sf_topology(atlas$data$sf, keep = keep)
  atlas
}


#' @rdname atlas_smooth
#' @export
atlas_simplify <- function(atlas, keep = 0.05) {
  lifecycle::deprecate_warn(
    "2.0.0", "atlas_simplify()", "atlas_smooth()"
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
        rmapshaper::ms_simplify(group_sf, keep = keep,
                                keep_shapes = TRUE)
      })
      sf_data <- do.call(rbind, parts)
      if (".view_group" %in% names(sf_data)) {
        sf_data$.view_group <- NULL
      }
      return(sf::st_make_valid(sf_data))
    }
  }

  sf_data <- rmapshaper::ms_simplify(sf_data, keep = keep,
                                     keep_shapes = TRUE)
  sf::st_make_valid(sf_data)
}


#' Topology-preserving simplification for atlas pipelines
#'
#' Central post-processing called by cortical, cerebellar, and other
#' mesh-based pipelines.
#'
#' @param sf_data An sf data.frame.
#' @param smooth_refinements Ignored (kept for API compatibility during
#'   transition). Smoothing is handled by topology-preserving simplification.
#' @param keep Proportion of vertices to retain (0--1). 0 skips
#'   simplification.
#' @return Processed sf data.frame.
#' @noRd
smooth_and_simplify_sf <- function(sf_data, smooth_refinements = 0,
                                   keep = 0) {
  if (keep > 0 && keep < 1) {
    sf_data <- simplify_sf_topology(sf_data, keep = keep)
  }

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
  sf_data <- dplyr::arrange(
    sf_data,
    dplyr::desc(grepl("cortex", label, ignore.case = TRUE))
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

  bounds <- vapply(seq_len(nrow(contours)), function(i) {
    coords <- st_coordinates(contours[i, ])
    c(
      xmin = min(coords[, "X"]),
      ymin = min(coords[, "Y"]),
      xmax = max(coords[, "X"]),
      ymax = max(coords[, "Y"])
    )
  }, numeric(4))

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
