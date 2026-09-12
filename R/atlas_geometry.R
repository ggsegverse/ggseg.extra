# Geometry processing functions for atlas creation ----
# These functions are shared across volumetric and cortical atlas pipelines

#' Smooth and simplify atlas 2D contours
#'
#' Topology-preserving simplification of atlas sf geometry via
#' [rmapshaper::ms_simplify()], with optional smoothing layered on top to
#' round off voxel-edge stair-steps into smooth curves. Shared boundaries
#' between adjacent regions are simplified together, preventing gaps.
#'
#' Note that the default `method = "close"` fills holes narrower than
#' `smoothness`; see `method` for alternatives that preserve them.
#'
#' By default all labels are smoothed equally. Use `labels` to smooth only
#' matching labels, or `exclude` to smooth everything except matching labels.
#' Only one of `labels` or `exclude` may be specified.
#'
#' @param atlas A `ggseg_atlas` object with sf data.
#' @param smoothness Smoothing strength between 0 and 1. The scale is shared by
#'   every `method`, so the same value means a comparable amount of smoothing
#'   whichever one you pick; each method's native parameter is derived from it.
#'   Around 0.4--0.6, the default, rounds off voxel-edge stair-steps on
#'   millimetre voxel grids without distorting shapes; 1 is the most smoothing
#'   a method applies before shapes stop resembling their input.
#' @param method Smoothing method. `"close"` (the default) is a
#'   morphological closing: a positive then negative [sf::st_buffer()].
#'   It rounds outlines but **fills holes narrower than the smoothing
#'   distance**,
#'   which erases the sulci of a thin cortical ribbon. The remaining
#'   methods come from [smoothr::smooth()] and move vertices rather than
#'   dilating the shape, so enclosed holes stay open: `"chaikin"` (corner
#'   cutting), `"ksmooth"` (kernel smoothing) and `"spline"`. Choose
#'   `"close"` to round solid shapes such as tract tubes, and one of the
#'   others when the geometry has holes worth keeping.
#' @param labels Optional regex pattern. Only labels matching this pattern
#'   are smoothed; others are left unchanged.
#' @param exclude Optional regex pattern. Labels matching this pattern are
#'   left unchanged; all others are smoothed.
#'
#' @return The `ggseg_atlas`, with its geometry rounded off.
#' @family atlas geometry
#' @seealso [atlas_simplify()] to reduce the vertex count, and
#'   [atlas_dilate()] to grow or shrink regions. Each does one thing: how
#'   round a shape is, how many vertices it costs, and how big it is, are
#'   separate questions and get tuned at separate times. Simplify before
#'   smoothing, not after - dropping vertices from a rounded outline replaces
#'   its curves with straight chords, putting the stair-step back.
#' @export
#' @importFrom sf st_make_valid
#'
#' @examples
#' \dontrun{
#' # Round off the voxel staircase.
#' atlas <- atlas_smooth(my_atlas, smoothness = 0.4)
#'
#' # Leave the brain outline alone.
#' atlas <- atlas_smooth(my_atlas, smoothness = 0.4, exclude = "^cortex")
#'
#' # Round a cortical ribbon without closing its sulci.
#' atlas <- atlas_smooth(
#'   my_atlas,
#'   smoothness = 0.4,
#'   method = "chaikin",
#'   labels = "^cortex"
#' )
#' }
atlas_smooth <- function(
  atlas,
  smoothness = 0.4,
  labels = NULL,
  exclude = NULL,
  method = c("close", "chaikin", "ksmooth", "spline")
) {
  method <- match.arg(method)
  check_smoothness(smoothness)
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

  if (!isTRUE(smoothness > 0)) {
    return(atlas)
  }

  # Smoothing is an sf/GEOS operation; work on the sf representation and
  # restore the atlas's original representation afterwards.
  was_polygon <- ggseg.formats::is_atlas_polygon(atlas)
  sf_data <- ggseg.formats::atlas_geom(ggseg.formats::as_sf_atlas(atlas))

  sf_data <- geometry_op_subset(
    sf_data,
    labels,
    exclude,
    function(d) smooth_sf_light(d, smoothness = smoothness, method = method),
    what = "smooth"
  )

  rehydrate_smoothed_atlas(atlas, sf_data, was_polygon)
}

#' Grow or shrink an atlas's regions
#'
#' @description
#' Buffers region geometry outward, so structures too thin to read at
#' plotting size survive. This is the post-creation counterpart of the
#' snapshot-stage dilation the atlas pipelines used to apply: it works on the
#' finished atlas, so a build does not have to be repeated to retune it.
#'
#' @details
#' `amount` is a distance in the atlas's own geometry units, not voxels or
#' pixels. Start small and look: a value that reads well on one atlas will
#' not transfer to another built on a different grid.
#'
#' Dilate the structures, not the anatomical context. Grown by even a little,
#' a grey brain silhouette closes its sulci and flattens into a blob, so pass
#' `exclude` (or `labels`) to keep it out.
#'
#' @param atlas A `ggseg_atlas` object with 2D geometry.
#' @param amount Buffer distance in geometry units. Positive grows a region,
#'   negative shrinks it, `0` returns the atlas unchanged.
#' @param labels,exclude Regex selecting which labels to dilate, or which to
#'   leave alone. Give at most one.
#'
#' @return The `ggseg_atlas`, in the representation it arrived in.
#' @family atlas geometry
#' @seealso [atlas_smooth()] and [atlas_simplify()], the other post-creation
#'   geometry steps.
#' @export
#' @examples
#' \dontrun{
#' # Grow the structures and leave the grey brain alone
#' atlas <- atlas_dilate(atlas, 0.5, exclude = "^cortex")
#' }
atlas_dilate <- function(atlas, amount, labels = NULL, exclude = NULL) {
  check_dilate_args(amount, labels, exclude)

  if (is.null(ggseg.formats::atlas_geom(atlas))) {
    cli::cli_warn("Atlas has no 2D geometry, nothing to dilate")
    return(atlas)
  }
  if (amount == 0) {
    return(atlas)
  }

  was_polygon <- ggseg.formats::is_atlas_polygon(atlas)
  sf_data <- ggseg.formats::atlas_geom(ggseg.formats::as_sf_atlas(atlas))

  mask <- dilate_mask(sf_data$label, labels, exclude)
  if (!any(mask)) {
    cli::cli_warn("No labels matched, nothing to dilate")
    return(atlas)
  }

  sf_data$geometry[mask] <- sf::st_buffer(sf_data$geometry[mask], amount)
  sf_data <- sf_data[!sf::st_is_empty(sf_data$geometry), , drop = FALSE]

  rehydrate_smoothed_atlas(atlas, sf_data, was_polygon)
}


#' Reduce an atlas's vertex count
#'
#' @description
#' Drops vertices from region geometry while keeping its topology, so an
#' atlas costs less to store and to draw.
#'
#' @details
#' This is about size, not shape. The silhouette an atlas draws behind its
#' structures usually carries the bulk of the vertices, so it is the part
#' worth simplifying; tiny deep structures have few to spare. Use `labels` or
#' `exclude` to say which.
#'
#' @param atlas A `ggseg_atlas` object with 2D geometry.
#' @param keep Proportion of vertices to retain, between 0 and 1. Lower is
#'   smaller and blockier; near 1 is an effective no-op.
#' @param labels,exclude Regex selecting which labels to simplify, or which
#'   to leave alone. Give at most one.
#'
#' @return The `ggseg_atlas`, in the representation it arrived in.
#' @family atlas geometry
#' @seealso [atlas_smooth()] to round shapes off, and [atlas_dilate()] to
#'   grow or shrink them. Simplify first and smooth afterwards, so the
#'   smoothing has the last word on the outline.
#' @export
#' @examples
#' \dontrun{
#' # Halve the atlas, sparing the structures.
#' atlas <- atlas_simplify(my_atlas, keep = 0.5, labels = "^cortex")
#' }
atlas_simplify <- function(atlas, keep = 0.05, labels = NULL, exclude = NULL) {
  if (!is.numeric(keep) || length(keep) != 1L || is.na(keep)) {
    cli::cli_abort("{.arg keep} must be a single number between 0 and 1.")
  }
  if (keep <= 0 || keep > 1) {
    cli::cli_abort("{.arg keep} must be between 0 and 1, not {keep}.")
  }
  if (!is.null(labels) && !is.null(exclude)) {
    cli::cli_abort(
      "Specify only one of {.arg labels} or {.arg exclude}, not both."
    )
  }

  if (is.null(ggseg.formats::atlas_geom(atlas))) {
    cli::cli_warn("Atlas has no 2D geometry, nothing to simplify")
    return(atlas)
  }

  was_polygon <- ggseg.formats::is_atlas_polygon(atlas)
  sf_data <- ggseg.formats::atlas_geom(ggseg.formats::as_sf_atlas(atlas))

  sf_data <- geometry_op_subset(
    sf_data,
    labels,
    exclude,
    function(d) simplify_sf_topology(d, keep = keep),
    what = "simplify"
  )

  rehydrate_smoothed_atlas(atlas, sf_data, was_polygon)
}


#' Which rows a dilation applies to
#'
#' Mirrors [atlas_smooth()]'s selection: `labels` opts in, `exclude` opts out,
#' neither means everything. Unlabelled rows are never selected.
#' @noRd
dilate_mask <- function(sf_labels, labels, exclude) {
  mask <- if (!is.null(labels)) {
    grepl(labels, sf_labels, ignore.case = TRUE)
  } else if (!is.null(exclude)) {
    !grepl(exclude, sf_labels, ignore.case = TRUE)
  } else {
    rep(TRUE, length(sf_labels))
  }
  mask[is.na(sf_labels)] <- FALSE
  mask
}

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
    c("magick", "terra"),
    reason = "for contour extraction from snapshot masks"
  )
  if (verbose) {
    cli::cli_progress_step("{step} Extracting contours")
  }

  regions <- list.files(input_dir, full.names = TRUE, pattern = "\\.png$")
  region_names <- file_path_sans_ext(basename(regions))

  max_val <- probe_raster_max(regions)

  contourobjs <- map_region_contours(
    regions = regions,
    max_val = max_val,
    vertex_size_limits = vertex_size_limits,
    step = step
  )
  names(contourobjs) <- region_names

  contours <- combine_region_contours(contourobjs)
  contours$y_axis <- "up"

  save_cache_rda(contours, output_dir, "contours.rda")

  if (verbose) {
    cli::cli_progress_done()
  }

  invisible(contours)
}


#' Read a snapshot mask PNG as a raster with y increasing upward
#'
#' The raster is built from the decoded pixels with an explicit extent, so
#' the top image row always spans the largest y. `terra::rast()` on the PNG
#' itself is avoided because terra's orientation of non-georeferenced files
#' is not stable across versions. Masks are single-channel greyscale, as
#' written by `extract_alpha_mask()`; any alpha channel is ignored.
#'
#' @param file Path to a PNG mask.
#' @return Single-layer SpatRaster spanning `0..ncol` by `0..nrow`, with
#'   grey values 0-255.
#' @keywords internal
#' @noRd
read_mask_raster <- function(file) {
  # Workaround: masks can carry the RGB colour profile of their snapshot on
  # greyscale pixels; libpng only warns about it, but the magick R package
  # turns that warning into an error unless the profile is skipped.
  pixels <- magick::image_read(file, defines = c("profile:skip" = "ICC")) |>
    magick::image_data(channels = "gray") |>
    as.integer()
  values <- matrix(pixels, nrow = nrow(pixels))
  terra::rast(values, extent = terra::ext(0, ncol(values), 0, nrow(values)))
}


#' Stop when cached contours predate the y-up coordinate convention
#'
#' Kept alongside the manifest check: this asserts the property the
#' downstream code depends on, not the provenance of the file carrying it.
#' @noRd
check_contour_y_axis <- function(contours, contourfile) {
  if (identical(unique(contours$y_axis), "up")) {
    return(invisible(contours))
  }
  cli::cli_abort(c(
    "{.path {contourfile}} was extracted by an older ggseg.extra.",
    "i" = "Its y coordinates may run downward, which draws the atlas upside
      down.",
    "i" = "Rerun the contour extraction steps; cached snapshots and masks
      are reused."
  ))
}


#' Find the maximum raster value across the first regions with data
#' @noRd
probe_raster_max <- function(regions) {
  max_val <- 0
  for (f in regions[seq_len(min(10, length(regions)))]) {
    r <- read_mask_raster(f)
    m <- terra::global(r, fun = "max", na.rm = TRUE)[1, 1]
    if (m > max_val) {
      max_val <- m
    }
    if (max_val > 0) break
  }
  if (max_val == 0) {
    max_val <- 1
  }
  max_val
}


#' Extract contours from each region raster in parallel
#' @noRd
#' @importFrom furrr furrr_options
#' @importFrom progressr progressor
map_region_contours <- function(regions, max_val, vertex_size_limits, step) {
  p <- progressor(
    steps = length(regions),
    label = paste(step, "Extracting contours")
  )
  safe_future_map(
    regions,
    function(region_file) {
      r <- read_mask_raster(region_file)
      result <- get_contours(
        r,
        max_val = max_val,
        vertex_size_limits = vertex_size_limits
      )
      p()
      result
    },
    .options = furrr::furrr_options(
      packages = c("magick", "terra", "ggseg.extra"),
      globals = c("max_val", "vertex_size_limits", "p")
    )
  )
}


#' Combine per-region contours into a single valid sf data.frame
#' @noRd
#' @importFrom dplyr bind_rows group_by summarise
#' @importFrom sf st_as_sf st_combine st_make_valid
combine_region_contours <- function(contourobjs) {
  kp <- !vapply(contourobjs, is.null, logical(1))
  contourobjs2 <- contourobjs[kp]

  if (length(contourobjs2) == 0) {
    cli::cli_abort(c(
      "No contours were extracted from any region",
      "i" = "Every region raster was empty or below the contour threshold"
    ))
  }

  contours <- bind_rows(contourobjs2, .id = "filenm")
  contours <- group_by(contours, filenm)
  contours <- summarise(contours, geometry = st_combine(geometry))
  contours <- st_as_sf(contours)
  st_make_valid(contours)
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
  load_cached_rda(
    as.character(fs::path(dir, "contours.rda")),
    contour_rerun_remedy
  )

  contours <- filter_valid_geometries(contours)
  if (nrow(contours) == 0) {
    cli::cli_warn("No valid contours found after extraction")
  }

  save_cache_rda(contours, dir, "contours_smoothed.rda")
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
  load_cached_rda(
    as.character(fs::path(dir, "contours_smoothed.rda")),
    contour_rerun_remedy
  )

  contours <- filter_valid_geometries(contours)
  if (nrow(contours) == 0) {
    cli::cli_warn("No valid contours to simplify")
  }
  save_cache_rda(contours, dir, "contours_reduced.rda")
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

#' Apply a geometry operation to some rows, leaving the rest alone
#'
#' Shared by [atlas_smooth()] and [atlas_simplify()], which rebuild whole
#' rows and so have to put them back in order. [atlas_dilate()] assigns into
#' the geometry column instead and keeps row order for free; the three still
#' share `dilate_mask()`, so `labels` and `exclude` select the same way.
#'
#' Row order is draw order, so an operation that reshuffled it would change
#' which region is painted over which.
#' @noRd
geometry_op_subset <- function(sf_data, labels, exclude, op, what) {
  if (is.null(labels) && is.null(exclude)) {
    return(sf::st_make_valid(op(sf_data)))
  }

  mask <- dilate_mask(sf_data$label, labels, exclude)
  if (!any(mask)) {
    cli::cli_warn("No labels matched, nothing to {what}")
    return(sf_data)
  }

  sf_data$.op_order <- seq_len(nrow(sf_data))
  target <- op(sf_data[mask, , drop = FALSE])
  rest <- sf_data[!mask, , drop = FALSE]

  out <- rbind(target, rest)
  out <- out[order(out$.op_order), , drop = FALSE]
  out$.op_order <- NULL
  sf::st_make_valid(out)
}


#' Write smoothed geometry back and restore the atlas representation
#' @noRd
rehydrate_smoothed_atlas <- function(atlas, sf_data, was_polygon) {
  atlas$data$geom <- sf_data
  if (was_polygon) {
    ggseg.formats::as_polygon_atlas(atlas)
  } else {
    ggseg.formats::as_sf_atlas(atlas)
  }
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

  multi_group <- !is.null(group_col) &&
    length(unique(sf_data[[group_col]])) > 1

  if (multi_group) {
    parts <- lapply(unique(sf_data[[group_col]]), function(g) {
      group_sf <- sf_data[sf_data[[group_col]] == g, , drop = FALSE]
      rmapshaper::ms_simplify(group_sf, keep = keep, keep_shapes = TRUE)
    })
    sf_data <- do.call(rbind, parts)
  } else {
    sf_data <- rmapshaper::ms_simplify(sf_data, keep = keep, keep_shapes = TRUE)
  }

  # Drop the temporary grouping column in both paths so it never leaks into
  # the returned atlas (a stray column breaks rbind() in smooth_sf_subset()).
  if (".view_group" %in% names(sf_data)) {
    sf_data$.view_group <- NULL
  }
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
smooth_sf_light <- function(sf_data, smoothness = 0, method = "close") {
  if (smoothness <= 0) {
    return(sf_data)
  }
  if (identical(method, "close")) {
    dist <- native_smoothness(smoothness, "close")
    sf_data <- sf::st_buffer(sf_data, dist = dist, nQuadSegs = 8L)
    sf_data <- sf::st_buffer(sf_data, dist = -dist, nQuadSegs = 8L)
    return(sf::st_make_valid(sf_data))
  }

  rlang::check_installed(
    "smoothr",
    reason = paste0("for the \"", method, "\" smoothing method")
  )
  # Corner-rounding methods move vertices rather than dilating the shape, so
  # every ring survives and enclosed holes stay open.
  native <- native_smoothness(smoothness, method)
  args <- switch(
    method,
    chaikin = list(refinements = native),
    ksmooth = list(smoothness = native),
    spline = list(vertex_factor = native)
  )
  sf::st_geometry(sf_data) <- do.call(
    smoothr::smooth,
    c(list(sf::st_geometry(sf_data), method = method), args)
  )
  sf::st_make_valid(sf_data)
}


#' Validate the normalised smoothness strength
#' @noRd
check_smoothness <- function(smoothness) {
  if (is.null(smoothness) || is.na(smoothness)) {
    return(invisible(NULL))
  }
  if (smoothness < 0 || smoothness > 1) {
    cli::cli_abort(c(
      "{.arg smoothness} must be between 0 and 1, not {smoothness}.",
      "i" = "It is a relative strength shared by every {.arg method}, so the
             same value means the same amount of smoothing whichever one you
             pick.",
      "i" = "It previously took each method's native units (a buffer distance,
             a refinement count). Divide an old {.code method = \"close\"}
             distance by {smoothness_scale$close} to convert."
    ))
  }
  invisible(NULL)
}


# Native parameter reached at smoothness = 1, per method. `spline` takes a
# vertex multiplier that is only meaningful from 2 upwards, so it is scaled
# between that floor and its maximum rather than from zero.
smoothness_scale <- list(
  close = 5,
  chaikin = 5,
  ksmooth = 5,
  spline = 10
)


#' Map the normalised 0-1 strength onto a method's native parameter
#' @noRd
native_smoothness <- function(smoothness, method) {
  switch(
    method,
    close = smoothness * smoothness_scale$close,
    chaikin = max(1L, as.integer(round(smoothness * smoothness_scale$chaikin))),
    ksmooth = smoothness * smoothness_scale$ksmooth,
    spline = 2 + smoothness * (smoothness_scale$spline - 2)
  )
}


#' Build sf geometry from volumetric contours
#'
#' Shared by subcortical and tract pipelines. Loads reduced contours,
#' assigns view names, adjusts coordinates, and extracts labels from
#' filenames.
#'
#' @param contours_file Path to `contours_reduced.rda`
#' @param slabs data.frame with `name` column of slab names
#' @param cortex_slices Optional data.frame with `name` column for cortex
#'   slice view names (appended to `slabs$name`)
#' @return sf data.frame with `label`, `view`, `geometry` columns, sorted
#'   with cortex rows first
#' @noRd
#' @importFrom dplyr select arrange desc
#' @importFrom sf st_as_sf
build_contour_sf <- function(contours_file, slabs, cortex_slices = NULL) {
  conts <- make_multipolygon(contours_file)

  filenm_base <- sub("\\.png$", "", conts$filenm)

  all_view_names <- if (!is.null(cortex_slices)) {
    c(slabs$name, cortex_slices$name)
  } else {
    slabs$name
  }

  conts$view <- match_contour_views(filenm_base, all_view_names)

  conts <- layout_volumetric_views(conts) # nolint: object_usage_linter.

  filenm_base <- sub("\\.png$", "", conts$filenm)
  conts$label <- strip_view_prefix(filenm_base, conts$view)

  arrange_contour_sf(conts)
}


#' Match each contour filename to the view name it starts with
#' @noRd
match_contour_views <- function(filenm_base, all_view_names) {
  vapply(
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
}


#' Strip the leading view name from each contour filename
#' @noRd
strip_view_prefix <- function(filenm_base, views) {
  vapply(
    seq_along(filenm_base),
    function(i) {
      fn <- filenm_base[i]
      vn <- views[i]
      if (is.na(vn)) {
        return(fn)
      }
      sub(paste0("^", vn, "_"), "", fn)
    },
    character(1)
  )
}


#' Select the atlas columns and sort the cortex outline to the bottom layer
#' @noRd
#' @importFrom dplyr arrange select
#' @importFrom sf st_as_sf
arrange_contour_sf <- function(conts) {
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
  load_cached_rda(contourfile, contour_rerun_remedy)
  check_contour_y_axis(contours, contourfile)

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


#' Validate what atlas_dilate() was handed
#' @noRd
check_dilate_args <- function(amount, labels, exclude) {
  if (!is.numeric(amount) || length(amount) != 1L || is.na(amount)) {
    cli::cli_abort("{.arg amount} must be a single number.")
  }
  if (!is.null(labels) && !is.null(exclude)) {
    cli::cli_abort(
      "Specify only one of {.arg labels} or {.arg exclude}, not both."
    )
  }
  invisible(NULL)
}
