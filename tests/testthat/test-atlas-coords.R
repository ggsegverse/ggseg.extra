describe("to_coords", {
  it("converts sf geometry to coordinate tibble", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- to_coords(sf_obj, 1)

    expect_s3_class(result, "data.frame")
    expect_true(all(
      c(".long", ".lat", ".subid", ".id", ".poly", ".order") %in%
        names(result)
    ))
    expect_gt(nrow(result), 0)
  })

  it("returns empty data.frame for empty sf", {
    sf_obj <- sf::st_sf(
      id = character(0),
      geometry = sf::st_sfc()
    )

    result <- to_coords(sf_obj, 1)

    expect_identical(nrow(result), 0L)
  })
})


describe("coords2sf", {
  it("converts coordinates back to sf polygons", {
    coords <- data.frame(
      .long = c(0, 1, 1, 0, 0),
      .lat = c(0, 0, 1, 1, 0),
      .subid = rep(1, 5),
      .id = rep(1, 5),
      .poly = rep(1, 5),
      .order = 1:5
    )

    result <- coords2sf(coords)

    expect_s3_class(result, "sf")
    expect_gt(nrow(result), 0)
  })

  it("respects vertex_size_limits minimum", {
    coords <- data.frame(
      .long = c(0, 1, 0, 0),
      .lat = c(0, 0, 1, 0),
      .subid = rep(1, 4),
      .id = rep(1, 4),
      .poly = rep(1, 4),
      .order = 1:4
    )

    result <- coords2sf(coords, vertex_size_limits = c(10, NA))

    expect_identical(nrow(result), 0L)
  })

  it("respects vertex_size_limits maximum", {
    coords <- data.frame(
      .long = c(0, 1, 1, 0, 0),
      .lat = c(0, 0, 1, 1, 0),
      .subid = rep(1, 5),
      .id = rep(1, 5),
      .poly = rep(1, 5),
      .order = 1:5
    )

    result <- coords2sf(coords, vertex_size_limits = c(NA, 3))

    expect_identical(nrow(result), 0L)
  })
})


describe("center_coord", {
  it("returns center of coordinates", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 10, 0, 10, 10, 0, 10, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- center_coord(sf_obj)

    expect_identical(unname(result[1]), 5, tolerance = 0.1)
    expect_identical(unname(result[2]), 5, tolerance = 0.1)
  })
})


describe("range_coord", {
  it("returns coordinate ranges", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 10, 0, 10, 10, 0, 10, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- range_coord(sf_obj)

    expect_identical(unname(result[1, 1]), 0)
    expect_identical(unname(result[2, 1]), 10)
    expect_identical(unname(result[1, 2]), 0)
    expect_identical(unname(result[2, 2]), 10)
  })
})


describe("gather_geometry", {
  it("centers geometry around origin", {
    df <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(10, 10, 20, 10, 20, 20, 10, 20, 10, 10),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- gather_geometry(df)

    centered <- center_coord(result)
    expect_identical(unname(centered[1]), 0, tolerance = 0.1)
    expect_identical(unname(centered[2]), 0, tolerance = 0.1)
  })
})


describe("restack", {
  it("arranges geometries horizontally", {
    df1 <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    df2 <- sf::st_sf(
      id = "b",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    df1 <- gather_geometry(df1)
    df2 <- gather_geometry(df2)

    result <- restack(list(df1, df2))

    expect_type(result, "list")
    expect_true("df" %in% names(result))
    expect_true("box" %in% names(result))
    expect_identical(nrow(result$df), 2L)
  })
})


describe("correct_coords_sf", {
  it("applies horizontal offset", {
    df <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- correct_coords_sf(df, by = 100)

    coords <- sf::st_coordinates(result)[, 1:2]
    expect_true(all(coords[, 1] >= 100))
  })

  it("adjusts vertical position based on ymin", {
    df <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 10, 1, 10, 1, 11, 0, 11, 0, 10),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- correct_coords_sf(df, by = 0)

    coords <- sf::st_coordinates(result)[, 1:2]
    expect_identical(min(coords[, 2]), 0, tolerance = 1e-6)
  })
})


describe("count_vertices", {
  it("counts vertices in each geometry", {
    sf_obj <- sf::st_sf(
      id = c("a", "b"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(0, 0, 2, 0, 2, 2, 0, 2, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- count_vertices(sf_obj)

    expect_length(result, 2)
    expect_identical(result[1], 5L)
    expect_identical(result[2], 5L)
  })
})


describe("coords2sf", {
  it("handles empty result when all filtered out", {
    coords <- data.frame(
      .long = c(0, 1, 0, 0),
      .lat = c(0, 0, 1, 0),
      .subid = rep(1, 4),
      .id = rep(1, 4),
      .poly = rep(1, 4),
      .order = 1:4
    )

    result <- coords2sf(coords, vertex_size_limits = c(NA, 2))

    expect_s3_class(result, "sf")
    expect_identical(nrow(result), 0L)
  })

  it("creates valid sf from coordinates", {
    coords <- data.frame(
      .long = c(0, 1, 1, 0, 0, 2, 3, 3, 2, 2),
      .lat = c(0, 0, 1, 1, 0, 0, 0, 1, 1, 0),
      .subid = c(rep(1, 5), rep(2, 5)),
      .id = c(rep(1, 5), rep(2, 5)),
      .poly = c(rep(1, 5), rep(2, 5)),
      .order = c(1:5, 1:5)
    )

    result <- coords2sf(coords)

    expect_s3_class(result, "sf")
    expect_gt(nrow(result), 0)
  })
})


describe("layout_cortical_views", {
  it("arranges hemi/view combinations horizontally", {
    make_view_df <- function(hemi_val, view_val, x_offset) {
      sf::st_sf(
        hemi = hemi_val,
        view = view_val,
        geometry = sf::st_sfc(
          sf::st_polygon(list(matrix(
            c(
              x_offset,
              0,
              x_offset + 1,
              0,
              x_offset + 1,
              1,
              x_offset,
              1,
              x_offset,
              0
            ),
            ncol = 2,
            byrow = TRUE
          )))
        )
      )
    }

    atlas_df <- rbind(
      make_view_df("left", "lateral", 0),
      make_view_df("left", "medial", 0),
      make_view_df("right", "lateral", 0),
      make_view_df("right", "medial", 0)
    )

    result <- layout_cortical_views(atlas_df)

    expect_s3_class(result, "data.frame")
    expect_identical(nrow(result), 4L)
    expect_true("hemi" %in% names(result))
    expect_true("view" %in% names(result))
  })

  it("errors when no valid combinations found", {
    atlas_df <- sf::st_sf(
      hemi = "unknown",
      view = "unknown",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    expect_error(layout_cortical_views(atlas_df), "No valid")
  })
})


describe("layout_volumetric_views", {
  it("arranges views horizontally", {
    df <- sf::st_sf(
      view = c("axial", "coronal"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- layout_volumetric_views(df)

    expect_s3_class(result, "data.frame")
    expect_identical(nrow(result), 2L)
  })
})


describe("coords2sf polygon closing", {
  it("closes unclosed polygon by appending first point", {
    coords <- data.frame(
      .long = c(0, 1, 1, 0),
      .lat = c(0, 0, 1, 1),
      .subid = rep(1, 4),
      .id = rep(1, 4),
      .poly = rep(1, 4),
      .order = 1:4
    )

    result <- coords2sf(coords)

    expect_s3_class(result, "sf")
    expect_gt(nrow(result), 0)
  })
})
