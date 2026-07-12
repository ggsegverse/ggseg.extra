describe("compute_view_basis", {
  it("returns orthonormal right and up unit vectors", {
    basis <- compute_view_basis(c(10, 0, 0))

    expect_equal(sqrt(sum(basis$right^2)), 1, tolerance = 1e-8)
    expect_equal(sqrt(sum(basis$up^2)), 1, tolerance = 1e-8)
    expect_equal(sum(basis$right * basis$up), 0, tolerance = 1e-8)
  })

  it("produces the expected basis for a camera on the x-axis", {
    basis <- compute_view_basis(c(10, 0, 0))

    expect_equal(basis$right, c(0, 1, 0), tolerance = 1e-8)
    expect_equal(basis$up, c(0, 0, 1), tolerance = 1e-8)
  })

  it("falls back to a valid basis for a camera on the z-axis", {
    basis <- compute_view_basis(c(0, 0, 10))

    expect_equal(sqrt(sum(basis$right^2)), 1, tolerance = 1e-8)
    expect_equal(sqrt(sum(basis$up^2)), 1, tolerance = 1e-8)
    expect_equal(sum(basis$right * basis$up), 0, tolerance = 1e-8)
  })
})


describe("project_vertices_2d", {
  it("projects vertices onto the view basis axes", {
    basis <- list(right = c(1, 0, 0), up = c(0, 1, 0))
    verts <- matrix(
      c(
        0,
        0,
        0,
        2,
        3,
        5,
        -1,
        4,
        9
      ),
      ncol = 3,
      byrow = TRUE
    )

    projected <- project_vertices_2d(verts, basis)

    expect_identical(dim(projected), c(3L, 2L))
    expect_equal(projected[, 1], c(0, 2, -1), tolerance = 1e-8)
    expect_equal(projected[, 2], c(0, 3, 4), tolerance = 1e-8)
  })
})


describe("cull_backfaces", {
  it("marks a triangle facing the camera as visible", {
    verts <- matrix(
      c(
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        0
      ),
      ncol = 3,
      byrow = TRUE
    )
    faces <- matrix(c(1L, 2L, 3L), ncol = 3)

    expect_true(cull_backfaces(verts, faces, c(0, 0, 10)))
  })

  it("marks a triangle facing away from the camera as hidden", {
    verts <- matrix(
      c(
        0,
        0,
        0,
        0,
        1,
        0,
        1,
        0,
        0
      ),
      ncol = 3,
      byrow = TRUE
    )
    faces <- matrix(c(1L, 2L, 3L), ncol = 3)

    expect_false(cull_backfaces(verts, faces, c(0, 0, 10)))
  })
})


describe("build_vertex_label_vector", {
  it("maps 0-indexed vertices onto 1-indexed positions", {
    vertices_df <- data.frame(
      label = "lh_a",
      vertices = I(list(c(0L, 2L))),
      stringsAsFactors = FALSE
    )

    labels <- build_vertex_label_vector(vertices_df, 4L, "lh")

    expect_length(labels, 4L)
    expect_identical(labels, c("lh_a", NA_character_, "lh_a", NA_character_))
  })

  it("keeps only labels matching the hemisphere prefix", {
    vertices_df <- data.frame(
      label = c("lh_a", "rh_b"),
      vertices = I(list(0L, 1L)),
      stringsAsFactors = FALSE
    )

    labels <- build_vertex_label_vector(vertices_df, 3L, "lh")

    expect_identical(labels, c("lh_a", NA_character_, NA_character_))
  })

  it("drops out-of-range vertex indices", {
    vertices_df <- data.frame(
      label = "lh_a",
      vertices = I(list(c(0L, 9L))),
      stringsAsFactors = FALSE
    )

    labels <- build_vertex_label_vector(vertices_df, 3L, "lh")

    expect_identical(labels, c("lh_a", NA_character_, NA_character_))
  })
})


describe("split_boundary_triangle", {
  it("returns a single closed ring when all labels match", {
    p1 <- c(0, 0)
    p2 <- c(1, 0)
    p3 <- c(0, 1)

    frags <- split_boundary_triangle(p1, p2, p3, "a", "a", "a")

    expect_length(frags, 1L)
    expect_identical(frags[[1]]$label, "a")
    expect_identical(frags[[1]]$coords[1, ], frags[[1]]$coords[4, ])
  })

  it("splits two-label triangles into two labelled fragments", {
    p1 <- c(0, 0)
    p2 <- c(2, 0)
    p3 <- c(0, 2)

    frags <- split_boundary_triangle(p1, p2, p3, "a", "b", "b")

    labs <- vapply(frags, function(f) f$label, character(1))
    expect_setequal(labs, c("a", "b"))
  })

  it("splits three-label triangles into three fragments", {
    p1 <- c(0, 0)
    p2 <- c(3, 0)
    p3 <- c(0, 3)

    frags <- split_boundary_triangle(p1, p2, p3, "a", "b", "c")

    labs <- vapply(frags, function(f) f$label, character(1))
    expect_setequal(labs, c("a", "b", "c"))
  })
})
