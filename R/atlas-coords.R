# Coordinate transformation functions for atlas geometry ----

#' @importFrom dplyr mutate
#' @importFrom sf st_geometry st_bbox st_transform
correct_coords_sf <- function(data, by) {
  geom <- st_geometry(data)
  ymin <- st_bbox(geom)["ymin"]

  mutate(data, geometry = geom + c(by, 0) - c(0, ymin))
}


#' @importFrom dplyr group_by group_split group_keys ungroup
#' @importFrom sf st_bbox
layout_cortical_views <- function(atlas_df) {
  atlas_grouped <- group_by(atlas_df, hemi, view)
  keys <- group_keys(atlas_grouped)
  splits <- group_split(atlas_grouped)

  find_group <- function(h_vals, s) {
    idx <- which(keys$hemi %in% h_vals & keys$view == s)
    if (length(idx) == 1) splits[[idx]] else NULL
  }

  view_order <- c(
    "left inferior",
    "left lateral",
    "left medial",
    "left superior",
    "right inferior",
    "right lateral",
    "right medial",
    "right superior"
  )

  atlas_list <- lapply(view_order, function(v) {
    parts <- strsplit(v, " ")[[1]]
    hemi <- parts[1]
    vw <- parts[2]
    find_group(c(hemi, substr(hemi, 1, 1)), vw)
  })
  names(atlas_list) <- view_order

  present <- !vapply(atlas_list, is.null, logical(1))
  atlas_list <- atlas_list[present]

  if (length(atlas_list) == 0) {
    cli::cli_abort("No valid hemi/view combinations found")
  }

  widths <- vapply(
    atlas_list,
    function(df) {
      bbox <- st_bbox(df$geometry)
      unname(bbox["xmax"] - bbox["xmin"])
    },
    numeric(1)
  )

  gap <- max(widths) * 0.05
  offsets <- cumsum(c(0, widths[-length(widths)] + gap))

  atlas_list <- lapply(seq_along(atlas_list), function(i) {
    correct_coords_sf(atlas_list[[i]], offsets[i])
  })

  atlas_df_r <- do.call(rbind, atlas_list)
  ungroup(atlas_df_r)
}


#' @importFrom dplyr group_by group_split
layout_volumetric_views <- function(atlas_df) {
  atlas <- group_by(atlas_df, view)
  atlas <- group_split(atlas)

  atlas <- lapply(atlas, gather_geometry)

  atlas2 <- restack(atlas)

  atlas2$df
}


#' @importFrom sf st_coordinates
count_vertices <- function(x) {
  vapply(x$geometry, function(i) nrow(st_coordinates(i)), integer(1))
}


#' @importFrom dplyr as_tibble group_by mutate row_number ungroup
#' @importFrom sf st_combine st_coordinates
to_coords <- function(x, n) {
  if (nrow(x) == 0) {
    coords <- data.frame(matrix(nrow = 0, ncol = 6))
    names(coords) <- c(".long", ".lat", ".subid", ".id", ".poly", ".order")
    return(coords)
  }

  coords <- x |>
    sf::st_geometry() |>
    st_combine() |>
    st_coordinates() |>
    as_tibble()

  coords$L2 <- n * 10000 + coords$L2

  coords <- coords |>
    group_by(L2) |>
    mutate(.order = row_number()) |>
    ungroup()

  names(coords) <- c(".long", ".lat", ".subid", ".id", ".poly", ".order")
  coords
}


#' @importFrom dplyr group_by group_split
#' @importFrom sf st_polygon st_sfc st_sf st_zm st_cast st_crs
coords2sf <- function(x, vertex_size_limits = NULL) {
  dt <- group_by(x, .subid, .id)
  dt_split <- group_split(dt)

  if (!is.null(vertex_size_limits)) {
    if (!is.na(vertex_size_limits[1])) {
      dt_split <- dt_split[vapply(
        dt_split,
        function(d) nrow(d) > vertex_size_limits[1],
        logical(1)
      )]
    }

    if (!is.na(vertex_size_limits[2])) {
      dt_split <- dt_split[vapply(
        dt_split,
        function(d) nrow(d) < vertex_size_limits[2],
        logical(1)
      )]
    }
  }

  polygon_list <- lapply(dt_split, function(d) {
    coords_matrix <- as.matrix(d[, c(".long", ".lat")])
    if (!identical(coords_matrix[1, ], utils::tail(coords_matrix, 1)[1, ])) {
      coords_matrix <- rbind(coords_matrix, coords_matrix[1, ])
    }
    st_polygon(list(coords_matrix))
  })

  if (length(polygon_list) > 0) {
    dt_sf <- st_sfc(polygon_list)
    dt_sf <- st_sf(geometry = dt_sf)
    dt_sf <- st_zm(dt_sf)
    dt_sf <- st_cast(dt_sf, "MULTIPOLYGON")
    return(dt_sf)
  }
  st_sf(geometry = st_sfc(crs = st_crs(NA)))
}


#' @importFrom sf st_bbox
gather_geometry <- function(df) {
  cent <- center_coord(df)
  df$geometry <- df$geometry - cent[1:2]
  df
}


center_coord <- function(x) {
  apply(range_coord(x), 2, mean)
}


#' @importFrom sf st_coordinates
range_coord <- function(x) {
  coords <- st_coordinates(x)
  apply(coords, 2, range)[, 1:2]
}


#' @importFrom sf st_bbox
#' @importFrom stats sd
restack <- function(views) {
  ranges <- lapply(views, range_coord)

  max_extent <- max(vapply(ranges, function(r) max(abs(r[, 2])), numeric(1)))
  widths <- vapply(ranges, function(r) diff(r[, 1]), numeric(1))
  half_widths <- vapply(ranges, function(r) max(abs(r[, 1])), numeric(1))
  gap <- max(widths) * 0.15

  positioned <- list()
  x_pos <- 0

  for (idx in seq_along(views)) {
    x_offset <- x_pos + half_widths[idx]
    positioned[[idx]] <- views[[idx]]
    positioned[[idx]]$geometry <-
      views[[idx]]$geometry + c(x_offset, max_extent)
    x_pos <- x_pos + widths[idx] + gap
  }

  bboxes <- do.call(rbind, lapply(positioned, function(v) st_bbox(v$geometry)))
  combined_bbox <- c(
    xmin = min(bboxes[, "xmin"]), ymin = min(bboxes[, "ymin"]),
    xmax = max(bboxes[, "xmax"]), ymax = max(bboxes[, "ymax"])
  )

  list(
    df = do.call(rbind, positioned),
    box = combined_bbox
  )
}
