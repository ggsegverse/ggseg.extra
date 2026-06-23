# Mesh-to-polygon projection for cortical atlas creation ----
#
# Projects 3D inflated mesh triangles directly to 2D sf polygons,
# replacing the screenshot-based pipeline (steps 2-5).

#' @noRd
cross3 <- function(a, b) {
  c(
    a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1]
  )
}

#' Compute orthonormal view basis from camera position
#'
#' Replicates the Three.js OrthographicCamera look-at with up = (0,0,1).
#' @param camera_pos Numeric length-3 camera position vector.
#' @return Named list with `right` and `up` unit vectors (each length 3).
#' @noRd
compute_view_basis <- function(camera_pos) {
  forward <- -camera_pos / sqrt(sum(camera_pos^2))
  up <- c(0, 0, 1)

  right <- cross3(forward, up)
  right_len <- sqrt(sum(right^2))

  if (right_len < 1e-10) {
    up <- c(0, 1, 0)
    right <- cross3(forward, up)
    right_len <- sqrt(sum(right^2))
  }
  right <- right / right_len

  up_corrected <- cross3(right, forward)
  list(right = right, up = up_corrected)
}

#' Project 3D vertices to 2D using orthographic projection
#'
#' @param verts_3d N x 3 matrix of vertex positions.
#' @param basis View basis from `compute_view_basis()`.
#' @return N x 2 matrix of (x, y) screen coordinates.
#' @noRd
project_vertices_2d <- function(verts_3d, basis) {
  cbind(
    verts_3d %*% basis$right,
    verts_3d %*% basis$up
  )
}

#' Determine which mesh faces are front-facing for a given camera
#'
#' @param verts_3d N x 3 matrix of vertex positions.
#' @param faces F x 3 matrix of 1-indexed face vertex indices.
#' @param camera_pos Length-3 camera position vector.
#' @return Logical vector of length F.
#' @noRd
cull_backfaces <- function(verts_3d, faces, camera_pos) {
  v0 <- verts_3d[faces[, 1], , drop = FALSE]
  v1 <- verts_3d[faces[, 2], , drop = FALSE]
  v2 <- verts_3d[faces[, 3], , drop = FALSE]

  e1 <- v1 - v0
  e2 <- v2 - v0
  fn <- cbind(
    e1[, 2] * e2[, 3] - e1[, 3] * e2[, 2],
    e1[, 3] * e2[, 1] - e1[, 1] * e2[, 3],
    e1[, 1] * e2[, 2] - e1[, 2] * e2[, 1]
  )

  centers <- (v0 + v1 + v2) / 3
  to_cam <- matrix(camera_pos, nrow = nrow(fn), ncol = 3, byrow = TRUE) -
    centers

  rowSums(fn * to_cam) > 0
}

#' Build per-vertex label vector from vertices_df
#'
#' @param vertices_df Data frame with `label` and `vertices` (list-column of
#'   0-indexed integer vectors).
#' @param n_vertices Total number of vertices in the mesh.
#' @param hemi_short "lh" or "rh" — only labels starting with this prefix are
#'   included.
#' @return Character vector of length `n_vertices` (NA for unlabelled).
#' @noRd
build_vertex_label_vector <- function(vertices_df, n_vertices, hemi_short) {
  vertex_labels <- rep(NA_character_, n_vertices)
  prefix <- paste0(hemi_short, "_")

  for (i in seq_len(nrow(vertices_df))) {
    lbl <- vertices_df$label[i]
    if (!startsWith(lbl, prefix)) {
      next
    }
    idx <- vertices_df$vertices[[i]] + 1L
    idx <- idx[idx >= 1L & idx <= n_vertices]
    vertex_labels[idx] <- lbl
  }
  vertex_labels
}

#' Split a boundary triangle into per-region polygon fragments
#'
#' For triangles where vertices belong to different regions, interpolate
#' midpoints on edges that cross boundaries and return sub-polygons for
#' each region. This eliminates sawtooth artifacts at region borders.
#'
#' @param p1,p2,p3 Numeric length-2 vertex coordinates.
#' @param lab1,lab2,lab3 Character labels (must all be non-NA).
#' @return List of `list(label, coords)` where coords is a closed ring matrix.
#' @noRd
split_boundary_triangle <- function(p1, p2, p3, lab1, lab2, lab3) {
  labs <- c(lab1, lab2, lab3)
  unique_labs <- unique(labs)

  if (length(unique_labs) == 1) {
    return(list(list(label = lab1, coords = rbind(p1, p2, p3, p1))))
  }

  mid <- function(a, b) (a + b) / 2

  if (length(unique_labs) == 2) {
    pts <- rbind(p1, p2, p3)
    counts <- table(labs)
    odd_lab <- names(counts[counts == 1])
    maj_lab <- names(counts[counts == 2])
    odd_i <- which(labs == odd_lab)
    maj_i <- which(labs == maj_lab)

    po <- pts[odd_i, ]
    pm1 <- pts[maj_i[1], ]
    pm2 <- pts[maj_i[2], ]

    m1 <- mid(po, pm1)
    m2 <- mid(po, pm2)

    list(
      list(label = odd_lab, coords = rbind(po, m1, m2, po)),
      list(label = maj_lab, coords = rbind(pm1, pm2, m2, m1, pm1))
    )
  } else {
    ctr <- (p1 + p2 + p3) / 3
    m12 <- mid(p1, p2)
    m23 <- mid(p2, p3)
    m13 <- mid(p1, p3)

    list(
      list(label = lab1, coords = rbind(p1, m12, ctr, m13, p1)),
      list(label = lab2, coords = rbind(p2, m23, ctr, m12, p2)),
      list(label = lab3, coords = rbind(p3, m13, ctr, m23, p3))
    )
  }
}


#' Project one hemisphere + one view to sf polygons
#'
#' Boundary triangles (vertices with different region labels) are split into
#' sub-polygons along interpolated edge midpoints so that region borders are
#' smooth instead of jagged.
#'
#' @param mesh Brain mesh list with `vertices` and `faces` data frames.
#' @param vertex_labels Character vector from `build_vertex_label_vector()`.
#' @param camera_pos Length-3 camera position.
#' @param hemi_short "lh" or "rh".
#' @param view View name ("lateral", "medial", etc.).
#' @return sf data.frame with columns: filenm, hemi_short, hemi, view,
#'   label, geometry.
#' @noRd
#' @importFrom sf st_sf st_sfc st_polygon st_union st_make_valid
project_mesh_view <- function(
  mesh,
  vertex_labels,
  camera_pos,
  hemi_short,
  view
) {
  verts_3d <- as.matrix(mesh$vertices)
  faces_1idx <- as.matrix(mesh$faces) + 1L

  basis <- compute_view_basis(camera_pos)
  verts_2d <- project_vertices_2d(verts_3d, basis)

  visible <- cull_backfaces(verts_3d, faces_1idx, camera_pos)

  l1 <- vertex_labels[faces_1idx[, 1]]
  l2 <- vertex_labels[faces_1idx[, 2]]
  l3 <- vertex_labels[faces_1idx[, 3]]

  all_labeled <- !is.na(l1) & !is.na(l2) & !is.na(l3)

  region_sizes <- table(vertex_labels[!is.na(vertex_labels)])

  polys <- build_view_polygons(
    visible,
    faces_1idx,
    verts_2d,
    l1,
    l2,
    l3,
    all_labeled,
    region_sizes
  )

  if (polys$n == 0L) {
    return(NULL)
  }

  hemi_long <- if (hemi_short == "lh") "left" else "right"
  assemble_region_sf(polys$polys, polys$labels, hemi_short, hemi_long, view)
}

#' Build the per-triangle polygon list for one hemisphere/view
#'
#' @return List with `polys` (sfc-ready polygon list), `labels` (character),
#'   and `n` (number of polygons collected).
#' @noRd
build_view_polygons <- function(
  visible,
  faces_1idx,
  verts_2d,
  l1,
  l2,
  l3,
  all_labeled,
  region_sizes
) {
  vis_idx <- which(visible)
  max_polys <- length(vis_idx) * 3L
  all_polys <- vector("list", max_polys)
  all_labels <- character(max_polys)
  n <- 0L

  for (i in vis_idx) {
    labs <- c(l1[i], l2[i], l3[i])
    unique_non_na <- unique(labs[!is.na(labs)])
    if (length(unique_non_na) == 0) {
      next
    }

    vi <- faces_1idx[i, ]
    fragments <- triangle_fragments(
      labs,
      unique_non_na,
      all_labeled[i],
      vi,
      verts_2d,
      region_sizes
    )
    for (frag in fragments) {
      n <- n + 1L
      all_polys[[n]] <- sf::st_polygon(list(frag$coords))
      all_labels[n] <- frag$label
    }
  }

  list(
    polys = all_polys[seq_len(n)],
    labels = all_labels[seq_len(n)],
    n = n
  )
}

#' Compute polygon fragments for a single visible triangle
#'
#' @return List of `list(label, coords)` fragments.
#' @noRd
triangle_fragments <- function(
  labs,
  unique_non_na,
  is_all_labeled,
  vi,
  verts_2d,
  region_sizes
) {
  if (length(unique_non_na) == 1 || !is_all_labeled) {
    if (length(unique_non_na) == 1) {
      lbl <- unique_non_na
    } else {
      sizes <- region_sizes[unique_non_na]
      lbl <- names(which.min(sizes))
    }
    coords <- verts_2d[vi, , drop = FALSE]
    coords <- rbind(coords, coords[1, , drop = FALSE])
    return(list(list(label = lbl, coords = coords)))
  }

  split_boundary_triangle(
    verts_2d[vi[1], ],
    verts_2d[vi[2], ],
    verts_2d[vi[3], ],
    labs[1],
    labs[2],
    labs[3]
  )
}

#' Union per-triangle polygons into one sf row per region
#'
#' @return sf data.frame with one row per unique label.
#' @noRd
assemble_region_sf <- function(
  all_polys,
  all_labels,
  hemi_short,
  hemi_long,
  view
) {
  sfc_all <- sf::st_sfc(all_polys)
  region_labels <- unique(all_labels)

  results <- vector("list", length(region_labels))
  for (j in seq_along(region_labels)) {
    lbl <- region_labels[j]
    geom <- sf::st_make_valid(sf::st_union(sfc_all[all_labels == lbl]))
    results[[j]] <- data.frame(
      filenm = paste0(hemi_short, "_", view, "_", lbl),
      hemi_short = hemi_short,
      hemi = hemi_long,
      view = view,
      label = lbl,
      stringsAsFactors = FALSE
    )
    results[[j]]$geometry <- geom
  }

  combined <- do.call(rbind, results)
  sf::st_as_sf(combined)
}


#' Project mesh to 2D polygons for all hemispheres and views
#'
#' Replaces the screenshot pipeline (steps 2-5) with direct geometric
#' projection of mesh triangles.
#'
#' @param components Atlas components list with `vertices_df`.
#' @param hemisphere Character vector of hemisphere codes ("lh", "rh").
#' @noRd
#' @importFrom sf st_make_valid
project_mesh_to_polygons <- function(
  components,
  hemisphere,
  views,
  tolerance = 0,
  smooth_refinements = 2,
  verbose = FALSE
) {
  hemi_data <- lapply(stats::setNames(hemisphere, hemisphere), function(hemi) {
    mesh <- ggseg.formats::get_brain_mesh(hemi, "inflated")
    n_verts <- nrow(mesh$vertices)
    vertex_labels <- build_vertex_label_vector(
      components$vertices_df,
      n_verts,
      hemi
    )
    list(mesh = mesh, vertex_labels = vertex_labels)
  })

  combos <- expand.grid(
    view = views,
    hemi = hemisphere,
    stringsAsFactors = FALSE
  )

  all_results <- lapply(seq_len(nrow(combos)), function(idx) {
    hemi <- combos$hemi[idx]
    view <- combos$view[idx]
    key <- paste(hemi, view, sep = "_")
    cam <- camera_presets[[key]]
    if (is.null(cam)) {
      return(NULL)
    }

    if (verbose) {
      cli::cli_alert_info("Projecting {.val {hemi}} {.val {view}}")
    }

    hd <- hemi_data[[hemi]]
    project_mesh_view(hd$mesh, hd$vertex_labels, cam, hemi, view)
  })
  all_results <- Filter(Negate(is.null), all_results)

  if (length(all_results) == 0) {
    cli::cli_abort("No polygons generated from mesh projection")
  }

  sf_data <- do.call(rbind, all_results)
  sf_data
}


#' @noRd
#' @importFrom dplyr group_by mutate ungroup select
#' @importFrom sf st_combine st_as_sf
cortical_build_sf_projected <- function(
  components,
  hemisphere,
  views,
  tolerance = 0,
  smooth_refinements = 2,
  verbose = FALSE
) {
  projected <- project_mesh_to_polygons(
    components,
    hemisphere,
    views,
    tolerance = tolerance,
    smooth_refinements = smooth_refinements,
    verbose = verbose
  )

  projected |>
    layout_cortical_views() |>
    dplyr::group_by(view, label) |>
    dplyr::mutate(geometry = sf::st_combine(geometry)) |>
    dplyr::ungroup() |>
    dplyr::select(label, view, geometry) |>
    sf::st_as_sf()
}
