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
#' Rounding a corner replaces it with an arc, which costs vertices: a
#' morphological close lays down eight segments per quarter turn. Those the
#' rounding added are dropped again before the atlas is returned, so a
#' preceding [atlas_simplify()] still counts rather than being undone.
#' Geometry that is already as sparse as its shapes allow - a raw voxel
#' tracing - keeps a little of the growth, since simplification cannot take
#' a ring below the vertices it needs.
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
#' @param vertex_budget What rounding is allowed to cost. Rounding a corner
#'   replaces it with an arc, and an arc costs vertices: a morphological
#'   close lays down eight segments per quarter turn, so smoothing an atlas
#'   can leave it several times larger than it found it and undo any
#'   simplification that came before.
#'
#'   `"preserve"`, the default, simplifies the rounded geometry back to
#'   roughly the vertex count it started with. It is a real simplification
#'   pass, so shapes move slightly beyond what the rounding alone did, and it
#'   stops once a pass buys nothing - geometry already at the floor that
#'   holds its shape, a raw voxel tracing say, cannot be brought all the way
#'   back. `"free"` rounds and stops there, and the vertex count grows.
#' @param close_gaps Whether to hand back the slivers rounding opens between
#'   neighbouring regions. Every method moves each region's boundary on its
#'   own, and a boundary shared with the region next door moves the other way
#'   for the neighbour, so a hairline gap opens along every shared edge. With
#'   `TRUE`, the default, area that no longer belongs to any region but
#'   borders two of them is given back to one of them, and the parcellation
#'   closes again. Set `FALSE` for geometry that is not a coverage - separate
#'   tract tubes, say - where there is nothing to close.
#'
#' @return The `ggseg_atlas`, with its geometry rounded off. Under the
#'   default `vertex_budget`, at close to the vertex count it arrived with.
#' @family atlas geometry
#' @seealso [atlas_polish()] to simplify and smooth in one call against a
#'   stated vertex budget, which is what most builds want.
#'   [atlas_simplify()] to reduce the vertex count, and [atlas_dilate()] to
#'   grow or shrink regions. Simplify before smoothing, not after - dropping
#'   vertices from a rounded outline replaces its curves with straight
#'   chords, putting the stair-step back.
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
  method = c("close", "chaikin", "ksmooth", "spline"),
  vertex_budget = c("preserve", "free"),
  close_gaps = TRUE
) {
  method <- match.arg(method)
  vertex_budget <- match.arg(vertex_budget)
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

  before <- sf_data
  sf_data <- geometry_op_subset(
    sf_data,
    labels,
    exclude,
    function(d) smooth_sf_light(d, smoothness = smoothness, method = method),
    what = "smooth"
  )
  if (!identical(sf_data, before)) {
    if (isTRUE(close_gaps)) {
      sf_data <- close_gaps_by_view(sf_data, before)
    }
    if (identical(vertex_budget, "preserve")) {
      sf_data <- trim_rounded_corners(
        sf_data,
        before,
        labels,
        exclude,
        close_gaps
      )
    }
  }

  rehydrate_smoothed_atlas(atlas, sf_data, was_polygon)
}


#' Simplify and smooth an atlas against a vertex budget
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The two things a finished atlas usually needs at once: fewer vertices, and
#' its voxel staircase rounded off. Doing them separately means deciding which
#' order they go in, and the answer is not obvious - rounding *adds* vertices,
#' so smoothing after simplifying undoes some of the reduction, while
#' simplifying after smoothing replaces the new curves with straight chords
#' and puts the staircase back.
#'
#' `atlas_polish()` owns that order so a build does not have to rediscover it.
#'
#' @details
#' `keep` is a budget on the result, not on an intermediate: the atlas is
#' simplified to `keep` of the vertices it arrived with, then rounded under
#' [atlas_smooth()]'s `"preserve"` budget, which simplifies the rounding back
#' towards that same count.
#'
#' It is a dial rather than a guarantee, and the low end is the loose end.
#' Simplification will not take a ring below the handful of vertices that
#' holds its shape, so an atlas of many small rings lands well above what was
#' asked. On `ggsegJHU`'s tract atlas (14,667 vertices):
#'
#' | `keep` | asked | [atlas_simplify()] alone | `atlas_polish()` |
#' |---|---|---|---|
#' | 0.05 | 733 | 2,636 | 3,989 |
#' | 0.10 | 1,467 | 3,341 | 4,890 |
#' | 0.20 | 2,933 | 4,729 | 6,437 |
#' | 0.50 | 7,334 | 8,570 | 10,417 |
#'
#' Most of that gap is the floor, not the rounding: [atlas_simplify()] on its
#' own misses the same target the same way. Rounding then adds roughly a third
#' more, which the `"preserve"` budget takes back only as far as the floor
#' allows. Ask for what you want, then look at what you got.
#'
#' @param atlas A `ggseg_atlas`.
#' @param keep Proportion of the original vertices to aim for. See details.
#' @param smoothness Smoothing strength between 0 and 1, passed to
#'   [atlas_smooth()].
#' @param method Smoothing method, passed to [atlas_smooth()]. `"close"`
#'   rounds solid shapes; the others keep holes open.
#' @param labels Optional regex. Only matching labels are polished.
#' @param exclude Optional regex. Matching labels are left alone.
#' @param close_gaps Whether to hand back the slivers the operations open
#'   between neighbouring regions. See [atlas_smooth()].
#'
#' @return The `ggseg_atlas`, simplified and rounded.
#' @family atlas geometry
#' @seealso [atlas_simplify()] and [atlas_smooth()] for the separate steps,
#'   when a build needs to interleave them differently.
#' @export
#'
#' @examples
#' \dontrun{
#' # The usual shape of a build: the context silhouette and the structures
#' # want different budgets, so they get a call each.
#' atlas <- my_atlas |>
#'   atlas_polish(
#'     keep = 0.4,
#'     smoothness = 0.4,
#'     method = "chaikin",
#'     labels = "^cortex"
#'   ) |>
#'   atlas_polish(keep = 0.1, smoothness = 0.4, exclude = "^cortex")
#' }
atlas_polish <- function(
  atlas,
  keep = 0.1,
  smoothness = 0.4,
  method = c("close", "chaikin", "ksmooth", "spline"),
  labels = NULL,
  exclude = NULL,
  close_gaps = TRUE
) {
  method <- match.arg(method)

  atlas <- atlas_simplify(
    atlas,
    keep = keep,
    labels = labels,
    exclude = exclude,
    close_gaps = close_gaps
  )
  atlas_smooth(
    atlas,
    smoothness = smoothness,
    labels = labels,
    exclude = exclude,
    method = method,
    vertex_budget = "preserve",
    close_gaps = close_gaps
  )
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
#'   smaller and blockier; near 1 is an effective no-op. A target rather than
#'   a promise: a ring is never taken below the handful of vertices that holds
#'   its shape, so an atlas of many small rings lands above what was asked -
#'   `keep = 0.05` on a tract atlas came back at 0.18. [atlas_polish()] has
#'   measured figures.
#' @param labels,exclude Regex selecting which labels to simplify, or which
#'   to leave alone. Give at most one.
#' @param close_gaps Whether to hand back any sliver the simplification
#'   opens between neighbouring regions. Simplification is topology-aware,
#'   so on geometry straight out of a pipeline, whose neighbours share their
#'   boundary vertex for vertex, it opens none and this does nothing. It
#'   earns its keep on geometry that has been reshaped since - rounded off by
#'   [atlas_smooth()], or traced region by region from separate masks - where
#'   the rings no longer agree and the shared edge comes apart. With `TRUE`,
#'   the default, area that no longer belongs to any region but borders two
#'   of them is given back to one of them.
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
atlas_simplify <- function(
  atlas,
  keep = 0.05,
  labels = NULL,
  exclude = NULL,
  close_gaps = TRUE
) {
  check_simplify_args(keep, labels, exclude)

  if (is.null(ggseg.formats::atlas_geom(atlas))) {
    cli::cli_warn("Atlas has no 2D geometry, nothing to simplify")
    return(atlas)
  }

  was_polygon <- ggseg.formats::is_atlas_polygon(atlas)
  sf_data <- ggseg.formats::atlas_geom(ggseg.formats::as_sf_atlas(atlas))

  before <- sf_data
  sf_data <- geometry_op_subset(
    sf_data,
    labels,
    exclude,
    function(d) simplify_sf_topology(d, keep = keep),
    what = "simplify"
  )
  if (isTRUE(close_gaps) && !identical(sf_data, before)) {
    sf_data <- close_gaps_by_view(sf_data, before)
  }

  rehydrate_smoothed_atlas(atlas, sf_data, was_polygon)
}


#' Take the rounded corners back down to the vertex count they started at
#'
#' Rounding a corner replaces it with an arc, and an arc costs vertices: a
#' morphological close lays down eight segments per quarter turn, so
#' smoothing used to leave an atlas several times larger than it found it and
#' silently undo any simplification that came before. An arc of two or three
#' segments reads the same at plotting size, so the extra ones are dropped
#' again here.
#'
#' Simplification will not take a ring below the handful of vertices that
#' keeps its shape, so one pass lands above what it was asked for and the
#' trim asks again. Geometry already at that floor when it arrived - a raw
#' voxel tracing, say - cannot be brought all the way back, so the trim also
#' stops once a pass has stopped buying anything, and backs a pass out
#' entirely if closing its gaps cost more than it saved.
#' @noRd
trim_rounded_corners <- function(
  sf_data,
  before,
  labels,
  exclude,
  close_gaps,
  passes = 4L
) {
  rows <- dilate_mask(before$label, labels, exclude)
  target <- sum(count_vertices(before[rows, , drop = FALSE]))
  if (target == 0) {
    return(sf_data)
  }

  grown <- sum(count_vertices(sf_data[rows, , drop = FALSE]))
  for (pass in seq_len(passes)) {
    if (grown <= target * 1.1) {
      break
    }
    previous <- sf_data
    sf_data <- geometry_op_subset(
      sf_data,
      labels,
      exclude,
      function(d) simplify_sf_topology(d, keep = target / grown),
      what = "simplify"
    )
    if (isTRUE(close_gaps)) {
      sf_data <- close_gaps_by_view(sf_data, previous)
    }
    # Closing the gaps the simplification opened can cost more vertices than
    # the simplification saved, so a pass is kept only if it came out ahead.
    trimmed <- sum(count_vertices(sf_data[rows, , drop = FALSE]))
    if (trimmed >= grown) {
      return(previous)
    }
    if (trimmed > grown * 0.95) {
      break
    }
    grown <- trimmed
  }
  sf_data
}


#' Validate what atlas_simplify() was handed
#' @noRd
check_simplify_args <- function(keep, labels, exclude) {
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
  invisible(NULL)
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
  rlang::check_installed("terra", reason = "for contour extraction")
  if (verbose) {
    cli::cli_progress_step("{step} Extracting contours")
  }

  regions <- list.files(input_dir, full.names = TRUE, pattern = "\\.rda$")
  region_names <- file_path_sans_ext(basename(regions))

  contourobjs <- map_region_contours(
    regions = regions,
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


#' Extract contours from each region raster in parallel
#' @noRd
#' @importFrom furrr furrr_options
#' @importFrom progressr progressor
map_region_contours <- function(regions, vertex_size_limits, step) {
  p <- progressor(
    steps = length(regions),
    label = paste(step, "Extracting contours")
  )
  safe_future_map(
    regions,
    function(region_file) {
      r <- projection_raster(read_projection(region_file))
      result <- get_contours(r, vertex_size_limits = vertex_size_limits)
      p()
      result
    },
    .options = furrr::furrr_options(
      packages = c("terra", "ggseg.extra"),
      globals = c("vertex_size_limits", "p")
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
    # Each view is a separate picture, so shared boundaries are only shared
    # within one. Row order is draw order, so the groups are put back in the
    # order they arrived in rather than the order they were simplified in.
    groups <- split(seq_len(nrow(sf_data)), sf_data[[group_col]])
    parts <- lapply(groups, function(rows) {
      group_sf <- sf_data[rows, , drop = FALSE]
      rmapshaper::ms_simplify(group_sf, keep = keep, keep_shapes = TRUE)
    })
    sf_data <- do.call(rbind, parts)
    sf_data <- sf_data[
      order(unlist(groups, use.names = FALSE)),
      ,
      drop = FALSE
    ]
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

  all_view_names <- if (!is.null(cortex_slices)) {
    c(slabs$name, cortex_slices$name)
  } else {
    slabs$name
  }

  conts$view <- match_contour_views(conts$filenm, all_view_names)
  validate_contour_views(conts$view, conts$filenm, all_view_names)

  conts <- layout_volumetric_views(conts) # nolint: object_usage_linter.

  conts$label <- strip_view_prefix(conts$filenm, conts$view)

  arrange_contour_sf(conts)
}


#' Abort when a contour belongs to no view the atlas is being built from
#'
#' Contours are read from the output directory rather than from the slab table,
#' so a directory carrying files from an earlier run with a different slab
#' layout contributes contours that match no current view. Left alone they
#' travel through the atlas with `view = NA` and fail far downstream, in the
#' view packing, with an error that says nothing about stale files.
#' @noRd
validate_contour_views <- function(views, filenm_base, all_view_names) {
  unmatched <- unique(filenm_base[is.na(views)])
  n <- length(unmatched)
  if (n == 0L) {
    return(invisible(NULL))
  }
  cli::cli_abort(c(
    "{n} contour{?s} match{?es/} none of the atlas's views.",
    "i" = "View{?s}: {.val {all_view_names}}.",
    "x" = "Unmatched: {.val {utils::head(unmatched, 10L)}}.",
    "i" = "Contours left from an earlier slab layout are the usual cause; \\
           rebuild into a clean output directory."
  ))
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
#'
#' Every contour has a view by this point: `validate_contour_views()` has
#' already rejected the ones that matched none.
#' @noRd
strip_view_prefix <- function(filenm_base, views) {
  vapply(
    seq_along(filenm_base),
    function(i) sub(paste0("^", views[i], "_"), "", filenm_base[i]),
    character(1)
  )
}


#' Whether a contour label names the brain silhouette rather than a structure
#'
#' The silhouette arrives under several names: `cortex_` from the legacy
#' single-slice path, `cortex` from the projection path where sanitize_label
#' strips the trailing underscore, and `cortex_left` / `cortex_right` from
#' sagittal views, which cortex_slice_file() names per hemisphere.
#'
#' Anchoring is what makes this safe. A loose `grepl("cortex", ...)` also
#' catches `Cerebellar_Cortex_*` and lets cerebellum sort above the outline
#' (HO2 regression); anchored and case-sensitive, it cannot.
#' @noRd
is_cortex_outline <- function(label) {
  grepl(context_pattern(), label)
}


#' Select the atlas columns and sort the cortex outline to the bottom layer
#' @noRd
#' @importFrom dplyr arrange select
#' @importFrom sf st_as_sf
arrange_contour_sf <- function(conts) {
  sf_data <- dplyr::select(conts, label, view, geometry)
  sf_data <- sf::st_as_sf(sf_data)
  sf_data <- dplyr::arrange(
    sf_data,
    view,
    !is_cortex_outline(label)
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


# Coverage repair ----

#' Give back the slivers a per-region operation opened between neighbours
#'
#' Reshaping a region moves its boundary, and a boundary shared with the
#' region next door moves the other way for the neighbour, so a hairline
#' sliver opens along every shared edge. The area is not lost, it is simply
#' unclaimed: this finds the holes the reshaping left in the parcellation and
#' hands each one to a region that borders it, so the coverage closes again.
#'
#' Only area that *was* covered is handed back. Space that was already open
#' between separate structures is anatomy, not damage, and stays open; so
#' does a shaving along the outside of the coverage, which is what the
#' reshaping was asked for.
#'
#' @param new_sf The sf data.frame after the operation.
#' @param old_sf The same rows before it.
#' @return `new_sf`, with the slivers merged back in.
#' @noRd
close_coverage_gaps <- function(new_sf, old_sf, passes = 3L) {
  if (nrow(new_sf) < 2L || nrow(new_sf) != nrow(old_sf)) {
    return(new_sf)
  }
  parcels <- which(!is_backdrop_row(old_sf))
  if (length(parcels) < 2L) {
    return(new_sf)
  }
  covered <- sf::st_union(
    sf::st_make_valid(sf::st_geometry(old_sf)[parcels])
  )
  for (pass in seq_len(passes)) {
    filled <- fill_reopened_area(new_sf, parcels, covered)
    if (is.null(filled)) {
      break
    }
    new_sf <- filled
  }
  new_sf
}


#' Which rows are the picture behind the parcellation, not part of it
#'
#' An atlas often draws a grey brain silhouette under its regions as
#' anatomical context. It covers the parcels rather than abutting them, so it
#' would hide every gap between them: a hole in the parcellation is not a
#' hole in a coverage the backdrop is part of. A row covering most of what
#' the group covers is taken to be one.
#' @noRd
is_backdrop_row <- function(sf_data) {
  geom <- sf::st_make_valid(sf::st_geometry(sf_data))
  total <- as.numeric(sf::st_area(sf::st_union(geom)))
  if (length(total) != 1L || !is.finite(total) || total <= 0) {
    return(rep(FALSE, length(geom)))
  }
  as.numeric(sf::st_area(geom)) / total > 0.5
}


#' One pass of the repair, or `NULL` when there is nothing left to close
#'
#' Merging a sliver back in lands its edge on the neighbour's to within
#' floating-point, which can leave a thinner one behind, so the repair is run
#' again until it finds nothing.
#' @noRd
fill_reopened_area <- function(new_sf, parcels, covered) {
  parcel_geom <- sf::st_make_valid(sf::st_geometry(new_sf)[parcels])
  pieces <- reopened_area(sf::st_union(parcel_geom), covered)
  if (length(pieces) == 0L) {
    return(NULL)
  }
  owner <- parcels[claim_pieces(pieces, parcel_geom)]
  merge_pieces_into(new_sf, pieces, owner)
}


#' The holes a reshaping punched in ground the regions used to cover
#' @noRd
reopened_area <- function(new_union, old_union) {
  holes <- union_holes(new_union)
  if (length(holes) == 0L) {
    return(holes)
  }
  reopened <- suppressWarnings(sf::st_intersection(holes, old_union))
  reopened <- polygonal_parts(reopened)
  reopened[as.numeric(sf::st_area(reopened)) > 0]
}


#' Every interior ring of a unioned coverage, as a polygon
#' @noRd
union_holes <- function(geom) {
  polys <- suppressWarnings(
    sf::st_cast(sf::st_cast(geom, "MULTIPOLYGON"), "POLYGON")
  )
  rings <- list()
  for (poly in polys) {
    if (length(poly) < 2L) {
      next
    }
    for (ring in poly[-1L]) {
      rings[[length(rings) + 1L]] <- sf::st_polygon(list(ring))
    }
  }
  sf::st_sfc(rings, crs = sf::st_crs(geom))
}


#' Keep only the polygonal parts of a geometry set
#'
#' Differencing and intersecting coverages returns whatever falls out -
#' polygons, but also the lines and points where two boundaries only touch.
#' Only the polygons carry area worth handing back.
#' @noRd
polygonal_parts <- function(geom) {
  geom <- geom[!sf::st_is_empty(geom)]
  if (length(geom) == 0L) {
    return(geom)
  }
  parts <- list()
  for (g in geom) {
    for (part in polygons_within(g)) {
      parts[[length(parts) + 1L]] <- part
    }
  }
  sf::st_sfc(parts, crs = sf::st_crs(geom))
}


#' Every POLYGON inside one geometry, however it is nested
#' @noRd
polygons_within <- function(g) {
  switch(
    class(g)[[2L]],
    POLYGON = list(g),
    MULTIPOLYGON = lapply(unclass(g), sf::st_polygon),
    GEOMETRYCOLLECTION = unlist(
      lapply(unclass(g), polygons_within),
      recursive = FALSE
    ),
    list()
  )
}


#' Which row each sliver belongs to
#'
#' A sliver borders the regions it was taken from, so the first of those
#' claims it. One that borders nothing - a rounding artefact adrift inside a
#' single region - goes to whichever region is nearest.
#' @noRd
claim_pieces <- function(pieces, geom) {
  bordering <- sf::st_intersects(pieces, sf::st_boundary(geom))
  owner <- vapply(
    bordering,
    function(hit) if (length(hit) > 0L) hit[[1L]] else NA_integer_,
    integer(1)
  )
  adrift <- is.na(owner)
  if (any(adrift)) {
    owner[adrift] <- sf::st_nearest_feature(pieces[adrift], geom)
  }
  owner
}


#' Union each sliver into the row that claimed it
#' @noRd
merge_pieces_into <- function(sf_data, pieces, owner) {
  geom <- sf::st_geometry(sf_data)
  for (row in unique(owner)) {
    addition <- sf::st_union(pieces[owner == row])
    merged <- sf::st_make_valid(sf::st_union(geom[row], addition))
    merged <- polygonal_parts(merged)
    if (length(merged) == 0L) {
      next
    }
    geom[row] <- sf::st_cast(sf::st_union(merged), "MULTIPOLYGON")
  }
  sf::st_geometry(sf_data) <- sf::st_make_valid(geom)
  sf_data
}


#' Repair the coverage one view at a time
#'
#' Views are laid out side by side in one set of coordinates but are separate
#' pictures, so a sliver may only ever be handed to a region in its own view.
#' @noRd
close_gaps_by_view <- function(new_sf, old_sf) {
  if (!"view" %in% names(new_sf)) {
    return(close_coverage_gaps(new_sf, old_sf))
  }
  for (v in unique(new_sf$view)) {
    rows <- which(new_sf$view == v)
    repaired <- close_coverage_gaps(
      new_sf[rows, , drop = FALSE],
      old_sf[rows, , drop = FALSE]
    )
    sf::st_geometry(new_sf)[rows] <- sf::st_geometry(repaired)
  }
  sf::st_make_valid(new_sf)
}
