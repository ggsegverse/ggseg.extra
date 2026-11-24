#' Smooth an outline over a window measured in world units
#'
#' The corner-rounding methods [atlas_smooth()] offers -- Chaikin, ksmooth,
#' spline -- all work between neighbouring vertices. That is the right scale
#' for a voxel staircase, where each step *is* one or two vertices. It is the
#' wrong scale for a small structure traced at high fidelity, where the
#' contour follows a coarse mask faithfully with many vertices per bump: the
#' filter's kernel sits far below the bump, so it redistributes points along
#' the same curve and the outline comes back looking unchanged.
#'
#' Measured on the `suit` atlas's deep nuclei: 45 x 22 units of extent against
#' a median edge of 0.026, which is four times finer, relative to the
#' structure, than the same atlas's flatmap. Chaikin, ksmooth and spline each
#' left it visually identical at every strength, and `vertex_budget = "free"`
#' added sixteen times the vertices without changing the shape.
#'
#' Windowing by arc length instead fixes the scale to the geometry rather than
#' to the sampling, so `span` means the same thing however finely the outline
#' happens to be traced.
#' @noRd
NULL

#' Moving average over a closed ring, windowed by arc length
#'
#' The ring is cyclic, so the window wraps rather than shrinking at the ends;
#' a ring smoothed with a one-sided window drifts.
#' @noRd
smooth_ring_arc <- function(x, y, span) {
  n <- length(x)
  if (n < 8L) {
    return(list(x = x, y = y))
  }
  perimeter <- sum(sqrt(diff(c(x, x[1]))^2 + diff(c(y, y[1]))^2))
  if (!is.finite(perimeter) || perimeter <= 0) {
    return(list(x = x, y = y))
  }

  # Half-window in vertices, from the span's share of the perimeter. Capped
  # below a third of the ring: a window approaching the whole ring collapses
  # it towards its centroid.
  k <- max(1L, round(n * (span / perimeter) / 2))
  k <- min(k, (n - 1L) %/% 3L)
  if (k < 1L) {
    return(list(x = x, y = y))
  }

  idx <- seq_len(n)
  offsets <- seq.int(-k, k)
  wrap <- function(v) ((v - 1L) %% n) + 1L
  taken <- vapply(offsets, function(o) wrap(idx + o), integer(n))
  list(
    x = rowMeans(matrix(x[taken], nrow = n)),
    y = rowMeans(matrix(y[taken], nrow = n))
  )
}


#' Smooth every ring of an sf layer over an arc-length window
#'
#' Rings are smoothed independently and then reconciled: a vertex two rings
#' shared before smoothing is moved to the mean of the positions they each
#' proposed, so a boundary two structures share stays shared. Without that,
#' smoothing opens a gap between neighbours exactly where they touch, which
#' is the most visible thing smoothing can do to an atlas.
#' @noRd
smooth_sf_arc <- function(sf_data, span) {
  rlang::check_installed("sfheaders", reason = "for arc-length smoothing")

  geom <- sf::st_geometry(sf_data)
  crs <- sf::st_crs(geom)
  multi <- sf::st_cast(geom, "MULTIPOLYGON")
  co <- as.data.frame(sf::st_coordinates(multi))

  ring_id <- interaction(co$L3, co$L2, co$L1, drop = TRUE, lex.order = TRUE)
  key <- shared_vertex_key(co$X, co$Y)

  moved <- lapply(split(seq_len(nrow(co)), ring_id), function(rows) {
    ring <- co[rows, , drop = FALSE]
    closed <- nrow(ring) > 1L &&
      ring$X[1] == ring$X[nrow(ring)] &&
      ring$Y[1] == ring$Y[nrow(ring)]
    open <- if (closed) ring[-nrow(ring), , drop = FALSE] else ring
    sm <- smooth_ring_arc(open$X, open$Y, span)
    data.frame(
      row = if (closed) c(rows[-length(rows)], rows[length(rows)]) else rows,
      x = if (closed) c(sm$x, sm$x[1]) else sm$x,
      y = if (closed) c(sm$y, sm$y[1]) else sm$y
    )
  })
  moved <- do.call(rbind, moved)
  moved <- moved[order(moved$row), , drop = FALSE]

  reconciled <- reconcile_shared_vertices(moved$x, moved$y, key)
  co$X <- reconciled$x
  co$Y <- reconciled$y

  # st_coordinates() on a MULTIPOLYGON names them L1 = ring, L2 = polygon,
  # L3 = feature; sfheaders names the same three linestring, polygon and
  # multipolygon.
  rebuilt <- sfheaders::sfc_multipolygon(
    co,
    x = "X",
    y = "Y",
    multipolygon_id = "L3",
    polygon_id = "L2",
    linestring_id = "L1",
    close = FALSE
  )
  sf::st_crs(rebuilt) <- crs
  sf::st_geometry(sf_data) <- sf::st_make_valid(rebuilt)
  sf_data
}


#' A key identifying vertices that sit on top of each other
#'
#' Rounded, because two rings tracing the same boundary store the same corner
#' as the same double but arrive at it from opposite directions; exact
#' equality is right here, and the rounding only guards against a boundary
#' that was already a hair apart.
#' @noRd
shared_vertex_key <- function(x, y) {
  paste(round(x, 9), round(y, 9), sep = "|")
}


#' Give every copy of a shared vertex the same new position
#' @noRd
reconcile_shared_vertices <- function(x, y, key) {
  dup <- key %in% key[duplicated(key)]
  if (!any(dup)) {
    return(list(x = x, y = y))
  }
  k <- key[dup]
  x[dup] <- stats::ave(x[dup], k, FUN = mean)
  y[dup] <- stats::ave(y[dup], k, FUN = mean)
  list(x = x, y = y)
}


#' Validate the arc-length window
#'
#' `span` is in the atlas's own units rather than normalised to 0-1 like
#' `smoothness`, because that is the whole point of the method: the window has
#' to mean a distance along the outline, not a share of the vertices.
#' @noRd
check_span <- function(span, call = rlang::caller_env()) {
  if (is.null(span)) {
    cli::cli_abort(
      c(
        "{.arg span} is required when {.code method = \"arc\"}.",
        "i" = "It is the smoothing window in the atlas's own units; try the
               width of the bumps you want gone."
      ),
      call = call
    )
  }
  if (!is.numeric(span) || length(span) != 1 || is.na(span) || span < 0) {
    cli::cli_abort(
      "{.arg span} must be a single, non-negative number.",
      call = call
    )
  }
  span
}
