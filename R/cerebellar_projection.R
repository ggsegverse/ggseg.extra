# SUIT flatmap projection for cerebellar atlas creation ----
#
# Projects cerebellar parcellations onto the SUIT flatmap surface.
# Unlike cortical projection, the flatmap coordinates are already 2D —
# no camera, backface culling, or orthographic projection needed.

#' Read SUIT flatmap surface from GIFTI
#'
#' Extracts 2D vertex coordinates and face connectivity from a SUIT
#' flatmap surface file (`.surf.gii`). The flatmap is already a 2D
#' representation, so only x and y coordinates are used.
#'
#' @param suit_surface Path to SUIT flatmap `.surf.gii` file.
#' @return Named list with:
#'   - `verts_2d`: N x 2 matrix of (x, y) flatmap coordinates
#'   - `faces`: F x 3 matrix of 0-indexed face vertex indices
#'   - `n_vertices`: integer vertex count
#' @noRd
read_suit_flatmap <- function(suit_surface) {
  rlang::check_installed("gifti", reason = "to read SUIT flatmap surfaces")

  if (!file.exists(suit_surface)) {
    cli::cli_abort("SUIT surface file not found: {.path {suit_surface}}")
  }

  gii <- gifti::readgii(suit_surface)

  pointset <- gii$data$pointset
  triangles <- gii$data$triangle

  if (is.null(pointset) || is.null(triangles)) {
    cli::cli_abort(c(
      "File does not appear to be a valid GIFTI surface",
      "i" = "Expected {.field pointset} and {.field triangle} data arrays",
      "i" = "File: {.path {suit_surface}}" # nolint
    ))
  }

  list(
    verts_2d = pointset[, 1:2, drop = FALSE],
    faces = triangles,
    n_vertices = nrow(pointset)
  )
}


#' Build per-vertex label vector for cerebellar flatmap
#'
#' Maps all labels in `vertices_df` to a character vector indexed by vertex.
#' Unlike the cortical version, there is no hemisphere prefix filtering —
#' all labels share a single flatmap mesh.
#'
#' @inheritParams build_vertex_label_vector
#' @param n_vertices Total number of vertices in the flatmap.
#' @return Character vector of length `n_vertices` (NA for unlabelled).
#' @noRd
# nolint next: object_length_linter.
build_vertex_label_vector_cerebellum <- function(vertices_df, n_vertices) {
  vertex_labels <- rep(NA_character_, n_vertices)

  for (i in seq_len(nrow(vertices_df))) {
    idx <- vertices_df$vertices[[i]] + 1L
    idx <- idx[idx >= 1L & idx <= n_vertices]
    vertex_labels[idx] <- vertices_df$label[i]
  }
  vertex_labels
}


#' Build sf polygons from SUIT flatmap triangles
#'
#' Iterates over all faces in the flatmap mesh, assigns each triangle to
#' its labelled region(s), and unions them into per-region sf polygons.
#' Boundary triangles (vertices with different labels) are split at edge
#' midpoints using `split_boundary_triangle()`.
#'
#' @param verts_2d N x 2 matrix of flatmap coordinates.
#' @param faces F x 3 matrix of 0-indexed face vertex indices.
#' @param vertex_labels Character vector from
#'   `build_vertex_label_vector_cerebellum()`.
#' @return sf data.frame with columns: label, geometry.
#' @noRd
#' @importFrom sf st_sf st_sfc st_polygon st_union st_make_valid
flatmap_triangles_to_polygons <- function(verts_2d, faces, vertex_labels) {
  faces_1idx <- faces + 1L

  l1 <- vertex_labels[faces_1idx[, 1]]
  l2 <- vertex_labels[faces_1idx[, 2]]
  l3 <- vertex_labels[faces_1idx[, 3]]

  all_labeled <- !is.na(l1) & !is.na(l2) & !is.na(l3)

  region_sizes <- table(vertex_labels[!is.na(vertex_labels)])

  n_faces <- nrow(faces_1idx)
  max_polys <- n_faces * 3L
  all_polys <- vector("list", max_polys)
  all_labels <- character(max_polys)
  n <- 0L

  for (i in seq_len(n_faces)) {
    face_polys <- triangle_to_region_polys(
      i,
      faces_1idx,
      verts_2d,
      c(l1[i], l2[i], l3[i]),
      all_labeled[i],
      region_sizes
    )
    for (poly in face_polys) {
      n <- n + 1L
      all_polys[[n]] <- poly$geometry
      all_labels[n] <- poly$label
    }
  }

  if (n == 0L) {
    cli::cli_abort("No labelled triangles found in flatmap")
  }

  all_polys <- all_polys[seq_len(n)]
  all_labels <- all_labels[seq_len(n)]
  sfc_all <- sf::st_sfc(all_polys)

  combined <- union_polys_by_region(sfc_all, all_labels)
  sf::st_as_sf(combined)
}


#' Convert one flatmap triangle into labelled sf polygon fragments
#'
#' Returns a list of `list(geometry = <POLYGON>, label = <chr>)` entries.
#' Degenerate or fully unlabelled triangles yield an empty list.
#' @noRd
triangle_to_region_polys <- function(
  i,
  faces_1idx,
  verts_2d,
  labs,
  face_all_labeled,
  region_sizes
) {
  non_na <- labs[!is.na(labs)]
  unique_non_na <- unique(non_na)
  if (length(unique_non_na) == 0) {
    return(list())
  }

  vi <- faces_1idx[i, ]
  coords <- verts_2d[vi, , drop = FALSE]

  e1 <- coords[2, ] - coords[1, ]
  e2 <- coords[3, ] - coords[1, ]
  area2 <- abs(e1[1] * e2[2] - e1[2] * e2[1])
  if (area2 < 1e-12) {
    return(list())
  }

  if (length(unique_non_na) == 1 || !face_all_labeled) {
    if (length(unique_non_na) == 1) {
      lbl <- unique_non_na
    } else {
      sizes <- region_sizes[unique_non_na]
      lbl <- names(which.min(sizes))
    }
    ring <- rbind(coords, coords[1, , drop = FALSE])
    return(list(list(geometry = sf::st_polygon(list(ring)), label = lbl)))
  }

  fragments <- split_boundary_triangle(
    verts_2d[vi[1], ],
    verts_2d[vi[2], ],
    verts_2d[vi[3], ],
    labs[1],
    labs[2],
    labs[3]
  )
  lapply(fragments, function(frag) {
    list(geometry = sf::st_polygon(list(frag$coords)), label = frag$label)
  })
}


#' Union triangle polygons into one row per region label
#' @noRd
union_polys_by_region <- function(sfc_all, all_labels) {
  region_labels <- unique(all_labels)
  results <- vector("list", length(region_labels))

  for (j in seq_along(region_labels)) {
    lbl <- region_labels[j]
    geom <- sf::st_make_valid(sf::st_union(sfc_all[all_labels == lbl]))
    results[[j]] <- data.frame(
      label = lbl,
      stringsAsFactors = FALSE
    )
    results[[j]]$geometry <- geom
  }

  do.call(rbind, results)
}


#' Build cerebellar sf data from SUIT flatmap projection
#'
#' Reads the SUIT flatmap surface, assigns region labels to vertices,
#' builds sf polygons from the mesh triangles, and applies smoothing
#' and simplification.
#'
#' @noRd
#' @importFrom sf st_make_valid st_as_sf
cerebellar_build_sf_flatmap <- function(
  components,
  suit_surface,
  tolerance = 0,
  smooth_refinements = 2,
  verbose = FALSE
) {
  if (verbose) {
    cli::cli_alert_info("Reading SUIT flatmap surface")
  }

  flatmap <- read_suit_flatmap(suit_surface)

  warn_flatmap_vertex_range(components, flatmap)

  vertex_labels <- build_vertex_label_vector_cerebellum(
    components$vertices_df,
    flatmap$n_vertices
  )

  check_flatmap_label_overlap(vertex_labels, components, flatmap)

  if (verbose) {
    n_v <- flatmap$n_vertices # nolint: object_usage_linter.
    n_f <- nrow(flatmap$faces) # nolint: object_usage_linter.
    cli::cli_alert_info(
      "Building polygons from {n_v} vertices, {n_f} faces"
    )
  }

  sf_data <- flatmap_triangles_to_polygons(
    flatmap$verts_2d,
    flatmap$faces,
    vertex_labels
  )

  sf_data <- fill_flatmap_holes(sf_data, verbose = verbose)

  sf_data$view <- "flatmap"
  sf::st_as_sf(sf_data)
}


#' Warn when the parcellation references vertices outside the flatmap
#' @noRd
warn_flatmap_vertex_range <- function(components, flatmap) {
  max_vertex <- max(vapply(
    components$vertices_df$vertices,
    function(v) if (length(v) == 0) 0L else max(v),
    integer(1)
  ))
  if (max_vertex >= flatmap$n_vertices) {
    cli::cli_warn(c(
      "Parcellation references vertex {max_vertex} but flatmap has only
      {flatmap$n_vertices} vertices",
      "i" = "Out-of-range vertices will be ignored"
    ))
  }
}


#' Abort when no parcellation vertices map onto the flatmap
#' @noRd
check_flatmap_label_overlap <- function(vertex_labels, components, flatmap) {
  n_labelled <- sum(!is.na(vertex_labels))
  if (n_labelled == 0) {
    cli::cli_abort(c(
      "No vertices matched between parcellation and flatmap",
      "i" = "The parcellation has {nrow(components$vertices_df)} regions but
      none map to the {flatmap$n_vertices}-vertex flatmap"
    ))
  }
}


#' Fill holes in cerebellar flatmap polygons
#'
#' Two-pass hole filling:
#' 1. Remove small internal rings (holes inside a region polygon)
#' 2. Fill small gaps between regions by assigning to the nearest region
#'
#' @noRd
fill_flatmap_holes <- function(
  sf_data,
  hole_threshold = 100,
  gap_threshold = 200,
  verbose = FALSE
) {
  sf_data <- remove_small_internal_holes(sf_data, hole_threshold)
  sf_data <- fill_inter_region_gaps(sf_data, gap_threshold, verbose)
  sf_data
}


#' @noRd
remove_small_internal_holes <- function(sf_data, threshold) {
  for (i in seq_len(nrow(sf_data))) {
    geom <- sf::st_geometry(sf_data)[[i]]
    sf::st_geometry(sf_data)[[i]] <- drop_small_rings(geom, threshold)
  }
  sf::st_make_valid(sf_data)
}


#' @noRd
drop_small_rings <- function(geom, threshold) {
  if (inherits(geom, "MULTIPOLYGON")) {
    polys <- lapply(geom, drop_small_rings_poly, threshold)
    sf::st_multipolygon(polys)
  } else if (inherits(geom, "POLYGON")) {
    sf::st_polygon(drop_small_rings_poly(geom, threshold))
  } else {
    geom
  }
}


#' @noRd
drop_small_rings_poly <- function(poly_coords, threshold) {
  if (length(poly_coords) <= 1) {
    return(poly_coords)
  }

  keep <- list(poly_coords[[1]])
  for (j in seq_along(poly_coords)[-1]) {
    ring <- poly_coords[[j]]
    ring_area <- abs(sum(
      ring[-nrow(ring), 1] * ring[-1, 2] - ring[-1, 1] * ring[-nrow(ring), 2]
    )) /
      2
    if (ring_area > threshold) keep[[length(keep) + 1]] <- ring
  }
  keep
}


#' @noRd
fill_inter_region_gaps <- function(sf_data, threshold, verbose) {
  all_union <- sf::st_union(sf_data)
  hull <- sf::st_convex_hull(all_union)
  uncovered <- sf::st_difference(hull, all_union)

  if (sf::st_is_empty(uncovered)) {
    # nocov start
    return(sf_data)
    # nocov end
  }

  gap_polys <- sf::st_cast(sf::st_make_valid(uncovered), "POLYGON")
  gap_areas <- sf::st_area(gap_polys)
  small_gaps <- gap_polys[as.numeric(gap_areas) <= threshold]

  if (length(small_gaps) == 0) {
    return(sf_data)
  }

  if (verbose) {
    cli::cli_alert_info("Filling {length(small_gaps)} small inter-region gaps")
  }

  sf_data <- sf::st_cast(sf_data, "MULTIPOLYGON")

  for (gap in small_gaps) {
    dists <- sf::st_distance(gap, sf_data)
    nearest_idx <- which.min(dists)
    merged <- sf::st_make_valid(
      sf::st_union(sf::st_geometry(sf_data)[[nearest_idx]], gap)
    )
    if (!inherits(merged, "MULTIPOLYGON")) {
      merged <- sf::st_cast(merged, "MULTIPOLYGON")
    }
    sf::st_geometry(sf_data)[[nearest_idx]] <- merged
  }

  sf::st_make_valid(sf_data)
}
