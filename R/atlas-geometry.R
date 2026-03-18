# Geometry processing functions for atlas creation ----
# These functions are shared across volumetric and cortical atlas pipelines

#' @noRd
#' @importFrom dplyr bind_rows group_by summarise
#' @importFrom furrr future_map furrr_options
#' @importFrom progressr progressor
#' @importFrom terra rast global
#' @importFrom sf st_is_empty st_combine st_as_sf st_make_valid
#' @importFrom tools file_path_sans_ext
extract_contours <- function(
  input_dir,
  output_dir,
  verbose = get_verbose(), # nolint: object_usage_linter
  step = "",
  vertex_size_limits = NULL
) {
  if (verbose) {
    cli::cli_progress_step("{step} Extracting contours")
  }

  regions <- list.files(input_dir, full.names = TRUE)
  region_names <- file_path_sans_ext(basename(regions))

  max_val <- 0
  for (f in regions[seq_len(min(10, length(regions)))]) {
    r <- suppressWarnings(rast(f))
    m <- global(r, fun = "max", na.rm = TRUE)[1, 1]
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
      r <- suppressWarnings(rast(region_file))
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
#' @importFrom smoothr smooth
smooth_contours <- function(
  dir,
  smoothness,
  step,
  verbose = get_verbose() # nolint: object_usage_linter
) {
  load_rda(file.path(dir, "contours.rda"))

  if (verbose) {
    cli::cli_progress_step(
      "{step} Smoothing contours (smoothness = {.val {smoothness}})"
    )
  }
  contours <- filter_valid_geometries(contours)
  if (nrow(contours) == 0) {
    cli::cli_warn("No valid contours found after extraction")
    save(contours, file = file.path(dir, "contours_smoothed.rda"))
    return(invisible(contours))
  }

  contours <- smooth(contours, method = "ksmooth", smoothness = smoothness)
  contours <- filter_valid_geometries(contours)

  save(contours, file = file.path(dir, "contours_smoothed.rda"))
  if (verbose) {
    cli::cli_progress_done()
  }
  invisible(contours)
}


#' @noRd
#' @importFrom sf st_simplify
reduce_vertex <- function(
  dir,
  tolerance,
  step = "",
  verbose = get_verbose() # nolint: object_usage_linter
) {
  if (verbose) {
    cli::cli_progress_step(
      "{step} Reducing vertices (tolerance = {.val {tolerance}})"
    )
  }
  load_rda(file.path(dir, "contours_smoothed.rda"))

  contours <- filter_valid_geometries(contours)
  if (nrow(contours) == 0) {
    cli::cli_warn("No valid contours to simplify")
    save(contours, file = file.path(dir, "contours_reduced.rda"))
    return(invisible(contours))
  }

  contours <- st_simplify(
    contours,
    preserveTopology = TRUE,
    dTolerance = tolerance
  )
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

#' Smooth atlas 2D contours
#'
#' Apply kernel smoothing to the sf geometry of a `ggseg_atlas` object.
#' Higher `smoothness` values produce rounder region boundaries.
#' This avoids re-running the full atlas creation pipeline.
#'
#' @param atlas A `ggseg_atlas` object with sf data.
#' @param smoothness Smoothing bandwidth passed to
#'   [smoothr::smooth(method = "ksmooth")][smoothr::smooth]. Typical range
#'   3--15. Default 5.
#'
#' @return A modified `ggseg_atlas` with smoothed sf geometry.
#' @export
#' @importFrom smoothr smooth
#' @importFrom sf st_make_valid
#'
#' @examples
#' \dontrun{
#' atlas <- atlas_smooth(my_atlas, smoothness = 10)
#' plot(atlas)
#' }
atlas_smooth <- function(atlas, smoothness = 5) {
  if (is.null(atlas$data$sf)) {
    cli::cli_warn("Atlas has no sf data, nothing to smooth")
    return(atlas)
  }

  new_sf <- smoothr::smooth(atlas$data$sf, method = "ksmooth",
                            smoothness = smoothness)
  new_sf <- sf::st_make_valid(new_sf)

  atlas$data$sf <- new_sf
  atlas
}


#' Simplify atlas 2D contours
#'
#' Reduce vertex count in the sf geometry of a `ggseg_atlas` object using
#' Douglas-Peucker simplification. Higher `tolerance` values produce simpler
#' shapes with fewer vertices. This avoids re-running the full atlas creation
#' pipeline.
#'
#' @param atlas A `ggseg_atlas` object with sf data.
#' @param tolerance Simplification tolerance passed to
#'   [sf::st_simplify(dTolerance)][sf::st_simplify]. Typical range 0.1--2.
#'   Default 0.5.
#'
#' @return A modified `ggseg_atlas` with simplified sf geometry.
#' @export
#' @importFrom sf st_simplify st_make_valid
#'
#' @examples
#' \dontrun{
#' atlas <- atlas_simplify(my_atlas, tolerance = 1)
#' plot(atlas)
#' }
atlas_simplify <- function(atlas, tolerance = 0.5) {
  if (is.null(atlas$data$sf)) {
    cli::cli_warn("Atlas has no sf data, nothing to simplify")
    return(atlas)
  }

  new_sf <- sf::st_simplify(atlas$data$sf, preserveTopology = TRUE,
                            dTolerance = tolerance)
  new_sf <- sf::st_make_valid(new_sf)

  atlas$data$sf <- new_sf
  atlas
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
