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

  it("skips NA labels without erroring", {
    vertices_df <- data.frame(
      label = c("lh_a", NA_character_),
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


describe("triangle_fragments", {
  region_sizes <- table(c("a", "a", "a", "b"))

  it("returns a single fragment for a uniform, fully-labelled triangle", {
    verts_2d <- matrix(c(0, 0, 1, 0, 0, 1), ncol = 2, byrow = TRUE)
    frags <- triangle_fragments(
      labs = c("a", "a", "a"),
      unique_non_na = "a",
      is_all_labeled = TRUE,
      vi = c(1L, 2L, 3L),
      verts_2d = verts_2d,
      region_sizes = region_sizes
    )

    expect_length(frags, 1L)
    expect_identical(frags[[1]]$label, "a")
    expect_identical(dim(frags[[1]]$coords), c(4L, 2L))
  })

  it("picks the smallest region for a partially-labelled mixed triangle", {
    verts_2d <- matrix(c(0, 0, 1, 0, 0, 1), ncol = 2, byrow = TRUE)
    frags <- triangle_fragments(
      labs = c("a", "b", NA_character_),
      unique_non_na = c("a", "b"),
      is_all_labeled = FALSE,
      vi = c(1L, 2L, 3L),
      verts_2d = verts_2d,
      region_sizes = region_sizes
    )

    expect_length(frags, 1L)
    expect_identical(frags[[1]]$label, "b")
  })

  it("delegates to split_boundary_triangle for a fully-labelled boundary", {
    verts_2d <- matrix(c(0, 0, 2, 0, 0, 2), ncol = 2, byrow = TRUE)
    frags <- triangle_fragments(
      labs = c("a", "b", "b"),
      unique_non_na = c("a", "b"),
      is_all_labeled = TRUE,
      vi = c(1L, 2L, 3L),
      verts_2d = verts_2d,
      region_sizes = region_sizes
    )

    labs_out <- vapply(frags, function(f) f$label, character(1))
    expect_setequal(labs_out, c("a", "b"))
  })
})


describe("build_view_polygons / assemble_region_sf / project_mesh_view", {
  # Unit square in the y-z plane at x = 0; winding chosen so both triangles
  # face a camera on the -x axis (verified via cull_backfaces()).
  verts_3d <- matrix(
    c(
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      0,
      0,
      1
    ),
    ncol = 3,
    byrow = TRUE
  )
  cam <- c(-350, 0, 0)
  faces_1idx <- matrix(c(3L, 2L, 1L, 4L, 3L, 1L), ncol = 3, byrow = TRUE)
  vertex_labels <- c("lh_a", "lh_a", "lh_b", "lh_b")

  it("build_view_polygons returns nothing when no vertex is labelled", {
    result <- build_view_polygons(
      visible = c(TRUE, TRUE),
      faces_1idx = faces_1idx,
      verts_2d = verts_3d[, 2:3],
      l1 = rep(NA_character_, 2),
      l2 = rep(NA_character_, 2),
      l3 = rep(NA_character_, 2),
      all_labeled = c(FALSE, FALSE),
      region_sizes = table(character(0))
    )

    expect_identical(result$n, 0L)
    expect_length(result$polys, 0L)
  })

  it("build_view_polygons skips backface-culled triangles", {
    l1 <- vertex_labels[faces_1idx[, 1]]
    l2 <- vertex_labels[faces_1idx[, 2]]
    l3 <- vertex_labels[faces_1idx[, 3]]

    result <- build_view_polygons(
      visible = c(FALSE, FALSE),
      faces_1idx = faces_1idx,
      verts_2d = verts_3d[, 2:3],
      l1 = l1,
      l2 = l2,
      l3 = l3,
      all_labeled = c(TRUE, TRUE),
      region_sizes = table(vertex_labels)
    )

    expect_identical(result$n, 0L)
  })

  it("build_view_polygons builds fragments for a labelled, visible mesh", {
    l1 <- vertex_labels[faces_1idx[, 1]]
    l2 <- vertex_labels[faces_1idx[, 2]]
    l3 <- vertex_labels[faces_1idx[, 3]]

    result <- build_view_polygons(
      visible = c(TRUE, TRUE),
      faces_1idx = faces_1idx,
      verts_2d = verts_3d[, 2:3],
      l1 = l1,
      l2 = l2,
      l3 = l3,
      all_labeled = c(TRUE, TRUE),
      region_sizes = table(vertex_labels)
    )

    expect_gt(result$n, 0L)
    expect_setequal(result$labels, c("lh_a", "lh_b"))
  })

  it("assemble_region_sf unions same-label fragments into one row each", {
    polys <- list(
      sf::st_polygon(list(rbind(
        c(0, 0),
        c(1, 0),
        c(0, 1),
        c(0, 0)
      ))),
      sf::st_polygon(list(rbind(
        c(1, 0),
        c(1, 1),
        c(0, 1),
        c(1, 0)
      ))),
      sf::st_polygon(list(rbind(
        c(2, 2),
        c(3, 2),
        c(2, 3),
        c(2, 2)
      )))
    )
    labels <- c("lh_a", "lh_a", "lh_b")

    result <- assemble_region_sf(polys, labels, "lh", "left", "lateral")

    expect_s3_class(result, "sf")
    expect_identical(nrow(result), 2L)
    expect_setequal(result$label, c("lh_a", "lh_b"))
    expect_identical(
      result$filenm[result$label == "lh_a"],
      "lh_lateral_lh_a"
    )
    expect_identical(result$hemi[result$label == "lh_a"], "left")
    expect_true(all(sf::st_is_valid(result)))
  })

  it("project_mesh_view returns NULL when nothing is visible or labelled", {
    mesh <- list(
      vertices = verts_3d,
      faces = faces_1idx - 1L
    )
    result <- project_mesh_view(
      mesh,
      vertex_labels = rep(NA_character_, 4),
      camera_pos = cam,
      hemi_short = "lh",
      view = "lateral"
    )

    expect_null(result)
  })

  it("project_mesh_view assembles a valid sf object end-to-end", {
    mesh <- list(
      vertices = verts_3d,
      faces = faces_1idx - 1L
    )
    result <- project_mesh_view(
      mesh,
      vertex_labels = vertex_labels,
      camera_pos = cam,
      hemi_short = "lh",
      view = "lateral"
    )

    expect_s3_class(result, "sf")
    expect_setequal(result$label, c("lh_a", "lh_b"))
    expect_identical(unique(result$hemi_short), "lh")
    expect_identical(unique(result$hemi), "left")
    expect_identical(unique(result$view), "lateral")
    expect_true(all(sf::st_is_valid(result)))
  })
})


describe("project_mesh_to_polygons", {
  verts_3d <- matrix(
    c(
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      0,
      0,
      1
    ),
    ncol = 3,
    byrow = TRUE
  )
  faces_0idx <- matrix(c(2L, 1L, 0L, 3L, 2L, 0L), ncol = 3, byrow = TRUE)
  mesh <- list(vertices = verts_3d, faces = faces_0idx)
  components <- list(
    vertices_df = data.frame(
      label = c("lh_a", "lh_b"),
      vertices = I(list(c(0L, 1L), c(2L, 3L))),
      stringsAsFactors = FALSE
    )
  )

  it("assembles polygons across hemispheres and views", {
    local_mocked_bindings(
      get_brain_mesh = function(hemi, surface) mesh,
      .package = "ggseg.formats"
    )

    result <- project_mesh_to_polygons(
      components,
      hemisphere = "lh",
      views = "lateral"
    )

    expect_s3_class(result, "sf")
    expect_setequal(result$label, c("lh_a", "lh_b"))
    expect_identical(unique(result$view), "lateral")
  })

  it("skips view/hemisphere combinations with no camera preset", {
    local_mocked_bindings(
      get_brain_mesh = function(hemi, surface) mesh,
      .package = "ggseg.formats"
    )

    result <- project_mesh_to_polygons(
      components,
      hemisphere = "lh",
      views = c("lateral", "bogus")
    )

    expect_s3_class(result, "sf")
    expect_identical(unique(result$view), "lateral")
    expect_false("bogus" %in% result$view)
  })

  it("aborts when no view/hemisphere combination yields polygons", {
    empty_mesh <- list(vertices = verts_3d, faces = faces_0idx)
    local_mocked_bindings(
      get_brain_mesh = function(hemi, surface) empty_mesh,
      .package = "ggseg.formats"
    )
    unlabelled <- list(
      vertices_df = data.frame(
        label = character(0),
        vertices = I(list()),
        stringsAsFactors = FALSE
      )
    )

    expect_error(
      project_mesh_to_polygons(
        unlabelled,
        hemisphere = "lh",
        views = "lateral"
      ),
      "No polygons generated"
    )
  })
})
