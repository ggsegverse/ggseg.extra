square_ring <- function(side, offset = c(0, 0)) {
  m <- matrix(
    c(
      0,
      0,
      side,
      0,
      side,
      side,
      0,
      side,
      0,
      0
    ),
    ncol = 2,
    byrow = TRUE
  )
  m[, 1] <- m[, 1] + offset[1]
  m[, 2] <- m[, 2] + offset[2]
  m
}


describe("build_vertex_label_vector_cerebellum", {
  it("maps 0-indexed vertices onto 1-indexed positions", {
    vertices_df <- data.frame(
      label = "region_a",
      vertices = I(list(c(0L, 3L))),
      stringsAsFactors = FALSE
    )

    labels <- build_vertex_label_vector_cerebellum(vertices_df, 4L)

    expect_length(labels, 4L)
    expect_identical(
      labels,
      c("region_a", NA_character_, NA_character_, "region_a")
    )
  })

  it("keeps all labels regardless of prefix and drops out-of-range indices", {
    vertices_df <- data.frame(
      label = c("lh_a", "rh_b"),
      vertices = I(list(0L, c(1L, 20L))),
      stringsAsFactors = FALSE
    )

    labels <- build_vertex_label_vector_cerebellum(vertices_df, 3L)

    expect_identical(labels, c("lh_a", "rh_b", NA_character_))
  })
})


describe("drop_small_rings_poly", {
  it("keeps the outer ring and drops small internal holes", {
    outer <- square_ring(10)
    small_hole <- square_ring(1, offset = c(2, 2))

    kept <- drop_small_rings_poly(list(outer, small_hole), threshold = 5)

    expect_length(kept, 1L)
    expect_identical(kept[[1]], outer)
  })

  it("keeps internal holes larger than the threshold", {
    outer <- square_ring(10)
    big_hole <- square_ring(4, offset = c(2, 2))

    kept <- drop_small_rings_poly(list(outer, big_hole), threshold = 5)

    expect_length(kept, 2L)
    expect_identical(kept[[2]], big_hole)
  })

  it("returns input unchanged when there are no inner rings", {
    outer <- square_ring(10)

    kept <- drop_small_rings_poly(list(outer), threshold = 5)

    expect_length(kept, 1L)
    expect_identical(kept, list(outer))
  })
})


describe("remove_small_internal_holes", {
  it("removes small holes from polygon geometries", {
    outer <- square_ring(10)
    small_hole <- square_ring(1, offset = c(2, 2))
    poly <- sf::st_polygon(list(outer, small_hole))
    sf_data <- sf::st_sf(
      label = "a",
      geometry = sf::st_sfc(poly)
    )

    result <- remove_small_internal_holes(sf_data, threshold = 5)
    geom <- sf::st_geometry(result)[[1]]

    expect_length(geom, 1L)
    expect_s3_class(geom, "POLYGON")
  })

  it("preserves large holes", {
    outer <- square_ring(10)
    big_hole <- square_ring(4, offset = c(3, 3))
    poly <- sf::st_polygon(list(outer, big_hole))
    sf_data <- sf::st_sf(
      label = "a",
      geometry = sf::st_sfc(poly)
    )

    result <- remove_small_internal_holes(sf_data, threshold = 5)
    geom <- sf::st_geometry(result)[[1]]

    expect_length(geom, 2L)
  })
})


describe("drop_small_rings", {
  it("passes through geometries that are neither POLYGON nor MULTIPOLYGON", {
    pt <- sf::st_point(c(0, 0))

    expect_identical(drop_small_rings(pt, threshold = 5), pt)
  })

  it("drops small holes on a POLYGON geometry", {
    outer <- square_ring(10)
    small_hole <- square_ring(1, offset = c(2, 2))
    poly <- sf::st_polygon(list(outer, small_hole))

    result <- drop_small_rings(poly, threshold = 5)

    expect_s3_class(result, "POLYGON")
    expect_length(result, 1L)
  })
})


describe("read_suit_flatmap invalid surface", {
  it("errors when the GIFTI lacks pointset or triangle arrays", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    local_mocked_bindings(
      readgii = function(file) {
        list(data = list(pointset = NULL, triangle = NULL))
      },
      .package = "gifti"
    )
    tmp <- withr::local_tempfile(fileext = ".surf.gii")
    writeLines("x", tmp)
    expect_error(read_suit_flatmap(tmp), "valid GIFTI surface")
  })
})


describe("fill_inter_region_gaps", {
  it("leaves gaps larger than the threshold unfilled", {
    a <- sf::st_polygon(list(matrix(
      c(0, 0, 4, 0, 4, 4, 0, 4, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    b <- sf::st_polygon(list(matrix(
      c(5, 0, 9, 0, 9, 4, 5, 4, 5, 0),
      ncol = 2,
      byrow = TRUE
    )))
    sf_data <- sf::st_sf(
      label = c("a", "b"),
      view = c("flatmap", "flatmap"),
      geometry = sf::st_sfc(a, b)
    )
    result <- fill_inter_region_gaps(sf_data, threshold = 1, verbose = FALSE)
    expect_identical(nrow(result), 2L)
  })
})
