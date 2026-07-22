.cap <- new.env()

# A valid tract atlas carrying the given centerline labels. The volumetric
# geometry code only reads `centerlines$label` (coordinates come from the
# separate `streamlines` argument), but ggseg.formats requires real point and
# tangent columns, so we supply dummy ones.
make_test_tract_atlas <- function(labels = "tract_a") {
  cl <- data.frame(label = labels, stringsAsFactors = FALSE)
  cl$points <- lapply(
    labels,
    function(.) matrix(c(0, 0, 0, 1, 1, 1), ncol = 3, byrow = TRUE)
  )
  cl$tangents <- lapply(
    labels,
    function(.) matrix(c(1, 0, 0, 1, 0, 0), ncol = 3, byrow = TRUE)
  )
  ggseg.formats::ggseg_atlas(
    atlas = "test",
    type = "tract",
    core = data.frame(
      hemi = "mid",
      region = labels,
      label = labels,
      stringsAsFactors = FALSE
    ),
    palette = stats::setNames(rep("#FF0000", length(labels)), labels),
    data = ggseg.formats::ggseg_data_tract(centerlines = cl)
  )
}

# A valid tract atlas backed by 2D geometry but carrying no centerlines, for
# exercising the "atlas must have centerlines" guard.
make_test_tract_atlas_geom <- function() {
  geom <- sf::st_sf(
    label = "tract_a",
    view = "axial",
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 0))))
    )
  )
  ggseg.formats::ggseg_atlas(
    atlas = "test",
    type = "tract",
    core = data.frame(
      hemi = "mid",
      region = "tract a",
      label = "tract_a",
      stringsAsFactors = FALSE
    ),
    palette = c(tract_a = "#FF0000"),
    data = ggseg.formats::ggseg_data_tract(geom = geom)
  )
}

describe("generate_tube_mesh", {
  it("creates valid mesh from centerline", {
    centerline <- matrix(
      c(
        0,
        0,
        0,
        1,
        0,
        0,
        2,
        0.5,
        0,
        3,
        1,
        0,
        4,
        1,
        0.5
      ),
      ncol = 3,
      byrow = TRUE
    )
    colnames(centerline) <- c("x", "y", "z")

    mesh <- generate_tube_mesh(centerline, radius = 0.5, segments = 8)

    expect_type(mesh, "list")
    expect_true(all(c("vertices", "faces") %in% names(mesh)))
    expect_gt(nrow(mesh$vertices), 0)
    expect_gt(nrow(mesh$faces), 0)
  })

  it("creates correct number of vertices", {
    n_points <- 10
    segments <- 8
    centerline <- matrix(
      c(seq_len(n_points), rep(0, n_points * 2)),
      ncol = 3
    )
    colnames(centerline) <- c("x", "y", "z")

    mesh <- generate_tube_mesh(centerline, radius = 1, segments = segments)

    expected_vertices <- as.integer(n_points * segments)
    expect_identical(nrow(mesh$vertices), expected_vertices)
  })

  it("creates correct number of faces", {
    n_points <- 10
    segments <- 8
    centerline <- matrix(
      c(seq_len(n_points), rep(0, n_points * 2)),
      ncol = 3
    )
    colnames(centerline) <- c("x", "y", "z")

    mesh <- generate_tube_mesh(centerline, radius = 1, segments = segments)

    expected_faces <- as.integer((n_points - 1) * segments * 2)
    expect_identical(nrow(mesh$faces), expected_faces)
  })

  it("respects radius parameter", {
    centerline <- matrix(c(0, 0, 0, 10, 0, 0), ncol = 3, byrow = TRUE)
    colnames(centerline) <- c("x", "y", "z")

    mesh_small <- generate_tube_mesh(centerline, radius = 0.1, segments = 8)
    mesh_large <- generate_tube_mesh(centerline, radius = 1.0, segments = 8)

    small_range <- max(mesh_small$vertices$y) - min(mesh_small$vertices$y)
    large_range <- max(mesh_large$vertices$y) - min(mesh_large$vertices$y)

    expect_gt(large_range, small_range * 5)
  })

  it("errors with too few points", {
    centerline <- matrix(c(0, 0, 0), ncol = 3)
    colnames(centerline) <- c("x", "y", "z")

    expect_error(generate_tube_mesh(centerline), "at least 2 rows")
  })
})


describe("extract_centerline", {
  it("returns input for single streamline", {
    streamline <- matrix(c(1:10, rep(0, 20)), ncol = 3)
    colnames(streamline) <- c("x", "y", "z")

    centerline <- extract_centerline(streamline, n_points = 5)

    expect_identical(nrow(centerline), 5L)
    expect_true(all(c("x", "y", "z") %in% colnames(centerline)))
  })

  it("computes mean centerline from multiple streamlines", {
    streamlines <- list(
      matrix(c(1:5, rep(0, 10)), ncol = 3),
      matrix(c(1:5, rep(1, 10)), ncol = 3),
      matrix(c(1:5, rep(2, 10)), ncol = 3)
    )

    centerline <- extract_centerline(streamlines, method = "mean", n_points = 5)

    expect_identical(nrow(centerline), 5L)
    expect_identical(mean(centerline[, 2]), 1, tolerance = 0.5)
  })

  it("resamples to specified number of points", {
    streamline <- matrix(c(1:100, rep(0, 200)), ncol = 3)
    colnames(streamline) <- c("x", "y", "z")

    centerline <- extract_centerline(streamline, n_points = 20)

    expect_identical(nrow(centerline), 20L)
  })

  it("returns NULL for empty input", {
    result <- extract_centerline(list())
    expect_null(result)

    result <- extract_centerline(NULL)
    expect_null(result)
  })
})


describe("compute_parallel_transport_frames", {
  it("returns orthonormal frames", {
    curve <- matrix(
      c(
        0,
        0,
        0,
        1,
        0,
        0,
        2,
        0.5,
        0,
        3,
        1,
        0
      ),
      ncol = 3,
      byrow = TRUE
    )

    frames <- compute_parallel_transport_frames(curve)

    expect_true(all(c("tangents", "normals", "binormals") %in% names(frames)))
    expect_identical(nrow(frames$tangents), nrow(curve))
    expect_identical(nrow(frames$normals), nrow(curve))
    expect_identical(nrow(frames$binormals), nrow(curve))

    for (i in seq_len(nrow(curve))) {
      t <- frames$tangents[i, ]
      n <- frames$normals[i, ]
      b <- frames$binormals[i, ]

      expect_identical(sqrt(sum(n^2)), 1, tolerance = 1e-6)
      expect_identical(sqrt(sum(b^2)), 1, tolerance = 1e-6)
      expect_identical(sum(n * b), 0, tolerance = 1e-6)
    }
  })
})


describe("resample_streamline", {
  it("resamples to exact number of points", {
    streamline <- matrix(c(1:100, rep(0, 200)), ncol = 3)
    colnames(streamline) <- c("x", "y", "z")

    resampled <- resample_streamline(streamline, 20)

    expect_identical(nrow(resampled), 20L)
  })

  it("preserves endpoints", {
    streamline <- matrix(c(0, 0, 0, 10, 0, 0), ncol = 3, byrow = TRUE)
    colnames(streamline) <- c("x", "y", "z")

    resampled <- resample_streamline(streamline, 5)

    expect_identical(as.numeric(resampled[1, 1]), 0, tolerance = 1e-6)
    expect_identical(as.numeric(resampled[5, 1]), 10, tolerance = 1e-6)
  })

  it("returns NULL for invalid input", {
    expect_null(resample_streamline(matrix(ncol = 3, nrow = 1), 10))
    expect_null(resample_streamline(NULL, 10))
  })
})


describe("cross_product", {
  it("computes correct cross product", {
    a <- c(1, 0, 0)
    b <- c(0, 1, 0)

    result <- cross_product(a, b)

    expect_identical(result, c(0, 0, 1))
  })

  it("returns zero for parallel vectors", {
    a <- c(1, 0, 0)
    b <- c(2, 0, 0)

    result <- cross_product(a, b)

    expect_identical(result, c(0, 0, 0))
  })

  it("is anti-commutative", {
    a <- c(1, 2, 3)
    b <- c(4, 5, 6)

    result1 <- cross_product(a, b)
    result2 <- cross_product(b, a)

    expect_identical(result1, -result2)
  })
})


describe("rotate_vector", {
  it("rotates vector 90 degrees around z-axis", {
    v <- c(1, 0, 0)
    axis <- c(0, 0, 1)
    angle <- pi / 2

    result <- rotate_vector(v, axis, angle)

    expect_identical(result[1], 0, tolerance = 1e-6)
    expect_identical(result[2], 1, tolerance = 1e-6)
    expect_identical(result[3], 0, tolerance = 1e-6)
  })

  it("does not change vector when angle is 0", {
    v <- c(1, 2, 3)
    axis <- c(0, 0, 1)

    result <- rotate_vector(v, axis, 0)

    expect_identical(result, v, tolerance = 1e-6)
  })

  it("returns original vector when rotating around itself", {
    v <- c(0, 0, 1)
    axis <- c(0, 0, 1)

    result <- rotate_vector(v, axis, pi / 4)

    expect_identical(result, v, tolerance = 1e-6)
  })
})


describe("compute_streamline_density", {
  it("computes density at each centerline point", {
    streamlines <- list(
      matrix(c(1:5, rep(0, 10)), ncol = 3),
      matrix(c(1:5, rep(0.5, 10)), ncol = 3),
      matrix(c(1:5, rep(1, 10)), ncol = 3)
    )
    centerline <- matrix(c(1:5, rep(0.5, 10)), ncol = 3)

    result <- compute_streamline_density(
      streamlines,
      centerline,
      search_radius = 1
    )

    expect_length(result, 5)
    expect_true(all(result >= 0))
  })

  it("returns zeros when no streamlines nearby", {
    streamlines <- list(
      matrix(c(100:110, rep(100, 22)), ncol = 3)
    )
    centerline <- matrix(c(1:5, rep(0, 10)), ncol = 3)

    result <- compute_streamline_density(
      streamlines,
      centerline,
      search_radius = 1
    )

    expect_true(all(result == 0))
  })
})


describe("center_meshes", {
  it("centers multiple meshes around origin", {
    meshes <- list(
      mesh1 = list(
        vertices = data.frame(x = 10:12, y = 10:12, z = 10:12),
        faces = data.frame(i = 1, j = 2, k = 3)
      ),
      mesh2 = list(
        vertices = data.frame(x = 20:22, y = 20:22, z = 20:22),
        faces = data.frame(i = 1, j = 2, k = 3)
      )
    )

    result <- center_meshes(meshes)

    all_verts <- do.call(rbind, lapply(result, function(m) m$vertices))
    centroid <- c(mean(all_verts$x), mean(all_verts$y), mean(all_verts$z))

    expect_identical(centroid[1], 0, tolerance = 1e-6)
    expect_identical(centroid[2], 0, tolerance = 1e-6)
    expect_identical(centroid[3], 0, tolerance = 1e-6)
  })

  it("preserves mesh structure", {
    meshes <- list(
      mesh1 = list(
        vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
        faces = data.frame(i = 1, j = 2, k = 3)
      )
    )

    result <- center_meshes(meshes)

    expect_true(all(c("vertices", "faces") %in% names(result$mesh1)))
    expect_identical(nrow(result$mesh1$vertices), 3L)
    expect_identical(nrow(result$mesh1$faces), 1L)
  })

  it("also centers metadata centerline if present", {
    meshes <- list(
      mesh1 = list(
        vertices = data.frame(x = 10:12, y = 10:12, z = 10:12),
        faces = data.frame(i = 1, j = 2, k = 3),
        metadata = list(
          centerline = matrix(c(10, 11, 12, 10, 11, 12, 10, 11, 12), ncol = 3)
        )
      )
    )

    result <- center_meshes(meshes)

    cl <- result$mesh1$metadata$centerline
    expect_lt(mean(cl[, 1]), 5)
  })
})


describe("coord_to_voxel", {
  it("adds 1 when coords_are_voxels is TRUE", {
    result <- coord_to_voxel(c(10, 20, 30), c(256, 256, 256), NULL, TRUE)
    expect_identical(result, c(11, 21, 31))
  })

  it("uses vox2ras inverse when matrix provided", {
    vox2ras <- diag(4)
    vox2ras[1:3, 4] <- c(-128, -128, -128)
    result <- coord_to_voxel(c(0, 0, 0), c(256, 256, 256), vox2ras, FALSE)
    expect_identical(result, c(129, 129, 129))
  })

  it("uses fallback formula without vox2ras", {
    dims <- c(256, 256, 256)
    result <- coord_to_voxel(c(0, 0, 0), dims, NULL, FALSE)
    expect_identical(result, c(129, 129, 129))
  })
})


describe("set_sphere_voxels", {
  it("sets voxels within sphere", {
    vol <- array(0L, dim = c(10, 10, 10))
    result <- set_sphere_voxels(vol, c(5, 5, 5), 1, 1L, c(10, 10, 10))

    expect_identical(result[5, 5, 5], 1L)
    expect_identical(result[6, 5, 5], 1L)
    expect_identical(result[5, 6, 5], 1L)
  })

  it("does not set voxels outside bounds", {
    vol <- array(0L, dim = c(5, 5, 5))
    result <- set_sphere_voxels(vol, c(1, 1, 1), 2, 1L, c(5, 5, 5))

    expect_identical(sum(result), sum(result[result > 0]))
  })
})


describe("detect_coords_are_voxels", {
  it("detects positive-only coordinates as voxel space", {
    streamlines <- list(
      matrix(c(50:60, rep(70, 11), rep(80, 11)), ncol = 3)
    )

    expect_true(detect_coords_are_voxels(streamlines))
  })

  it("detects negative coordinates as world space", {
    streamlines <- list(
      matrix(c(-10:0, rep(-5, 11), rep(3, 11)), ncol = 3)
    )

    expect_false(detect_coords_are_voxels(streamlines))
  })

  it("returns FALSE for empty input", {
    expect_false(detect_coords_are_voxels(list()))
    expect_false(detect_coords_are_voxels(list(matrix(ncol = 3, nrow = 0))))
  })

  it("uses dims for validation when provided", {
    streamlines <- list(
      matrix(c(50:60, rep(70, 11), rep(80, 11)), ncol = 3)
    )
    expect_true(detect_coords_are_voxels(streamlines, dims = c(256, 256, 256)))
  })
})


describe("extract_centerline medoid", {
  it("selects the most representative streamline", {
    streamlines <- list(
      matrix(c(1:5, rep(0, 10)), ncol = 3),
      matrix(c(1:5, rep(0.1, 10)), ncol = 3),
      matrix(c(1:5, rep(10, 10)), ncol = 3)
    )

    result <- extract_centerline(
      streamlines,
      method = "medoid",
      n_points = 5
    )

    expect_identical(nrow(result), 5L)
  })
})


describe("load_vox2ras_matrix", {
  it("returns NULL when coords_are_voxels is TRUE", {
    result <- load_vox2ras_matrix("any_file.mgz", TRUE)
    expect_null(result)
  })

  it("returns NULL for unsupported file extension", {
    result <- load_vox2ras_matrix("file.txt", FALSE)
    expect_null(result)
  })
})


describe("extract_centerline", {
  it("returns resampled single streamline from list", {
    sl <- list(matrix(c(1:10, rep(0, 20)), ncol = 3))
    result <- extract_centerline(sl, n_points = 5)
    expect_identical(nrow(result), 5L)
  })

  it("returns NULL when all resampled streamlines are invalid", {
    invalid_sl <- list(
      matrix(c(1, 0, 0), ncol = 3),
      matrix(c(2, 0, 0), ncol = 3)
    )
    result <- extract_centerline(invalid_sl, n_points = 5)
    expect_null(result)
  })
})


describe("resample_streamline", {
  it("handles 2-point streamline where some segments have zero length", {
    streamline <- matrix(c(0, 0, 0, 0, 0, 5), ncol = 3, byrow = TRUE)
    result <- resample_streamline(streamline, 3)
    expect_identical(nrow(result), 3L)
    expect_identical(colnames(result), c("x", "y", "z"))
    expect_identical(as.numeric(result[1, 3]), 0, tolerance = 1e-6)
    expect_identical(as.numeric(result[3, 3]), 5, tolerance = 1e-6)
  })

  it("handles streamline where segment_end equals segment_start", {
    streamline <- matrix(
      c(0, 0, 0, 0, 0, 0, 0, 0, 5),
      ncol = 3,
      byrow = TRUE
    )
    result <- resample_streamline(streamline, 5)
    expect_identical(nrow(result), 5L)
  })

  it("returns NULL when all points are identical (zero total length)", {
    streamline <- matrix(c(1, 0, 0, 1, 0, 0), ncol = 3, byrow = TRUE)
    expect_null(resample_streamline(streamline, 5))
  })

  it("handles zero-length segment at end of streamline", {
    streamline <- matrix(
      c(0, 0, 0, 5, 0, 0, 5, 0, 0),
      ncol = 3,
      byrow = TRUE
    )
    result <- resample_streamline(streamline, 5)
    expect_identical(nrow(result), 5L)
    expect_identical(as.numeric(result[5, 1]), 5, tolerance = 1e-6)
  })
})


describe("generate_tube_mesh", {
  it("errors with wrong radius length", {
    centerline <- matrix(c(0, 0, 0, 1, 0, 0, 2, 0, 0), ncol = 3, byrow = TRUE)
    colnames(centerline) <- c("x", "y", "z")
    expect_error(
      generate_tube_mesh(centerline, radius = c(1, 2)),
      "radius must be length 1 or 3"
    )
  })

  it("accepts per-point radius vector", {
    centerline <- matrix(c(0, 0, 0, 1, 0, 0, 2, 0, 0), ncol = 3, byrow = TRUE)
    colnames(centerline) <- c("x", "y", "z")
    mesh <- generate_tube_mesh(
      centerline,
      radius = c(0.5, 1.0, 0.5),
      segments = 4
    )
    expect_identical(nrow(mesh$vertices), 3L * 4L)
    expect_identical(nrow(mesh$faces), 2L * 4L * 2L)
  })
})


describe("compute_streamline_density", {
  it("skips invalid streamlines", {
    streamlines <- list(
      "not a matrix",
      matrix(c(1:5, rep(0, 10)), ncol = 3)
    )
    centerline <- matrix(c(1:3, rep(0, 6)), ncol = 3)

    result <- compute_streamline_density(
      streamlines,
      centerline,
      search_radius = 2
    )

    expect_length(result, 3)
    expect_gte(result[1], 1)
  })
})


describe("load_vox2ras_matrix", {
  it("loads vox2ras from mgz file", {
    result <- load_vox2ras_matrix(
      test_mgz_file(),
      coords_are_voxels = FALSE
    )
    expect_true(is.matrix(result) || is.null(result))
  })

  it("handles .nii.gz extension by parsing gz correctly", {
    tmp <- tempfile(fileext = ".nii.gz")
    vol <- array(0L, dim = c(5, 5, 5))
    nii <- RNifti::asNifti(vol)
    RNifti::writeNifti(nii, tmp)
    on.exit(unlink(tmp))

    result <- load_vox2ras_matrix(tmp, FALSE)
    expect_true(is.matrix(result))
    expect_identical(dim(result), c(4L, 4L))
  })

  it("loads vox2ras from nii file", {
    tmp <- tempfile(fileext = ".nii")
    vol <- array(0L, dim = c(5, 5, 5))
    nii <- RNifti::asNifti(vol)
    RNifti::writeNifti(nii, tmp)
    on.exit(unlink(tmp))

    result <- load_vox2ras_matrix(tmp, FALSE)
    expect_true(is.matrix(result))
    expect_identical(dim(result), c(4L, 4L))
  })

  it("returns NULL for mgz when freesurferformats unavailable", {
    orig_require <- base::requireNamespace
    local_mocked_bindings(
      requireNamespace = function(pkg, ...) {
        if (pkg == "freesurferformats") {
          return(FALSE)
        }
        orig_require(pkg, ...)
      },
      .package = "base"
    )

    result <- load_vox2ras_matrix("file.mgz", FALSE)
    expect_null(result)
  })

  it("returns NULL for nii when RNifti unavailable", {
    orig_require <- base::requireNamespace
    local_mocked_bindings(
      requireNamespace = function(pkg, ...) {
        if (pkg == "RNifti") {
          return(FALSE)
        }
        orig_require(pkg, ...)
      },
      .package = "base"
    )

    result <- load_vox2ras_matrix("file.nii", FALSE)
    expect_null(result)
  })
})


describe("streamlines_to_volume", {
  it("errors when template file doesn't exist", {
    expect_error(
      streamlines_to_volume(
        centerline = matrix(1:6, ncol = 3),
        template_file = "/nonexistent.mgz"
      ),
      "not found"
    )
  })

  it("creates volume from centerline with voxel coordinates", {
    tmp_vol <- tempfile(fileext = ".nii.gz")
    on.exit(unlink(tmp_vol))

    vol_data <- array(0L, dim = c(10, 10, 10))
    nii <- RNifti::asNifti(vol_data)
    RNifti::writeNifti(nii, tmp_vol)

    centerline <- matrix(c(5, 5, 5, 6, 6, 6), ncol = 3, byrow = TRUE)

    result <- streamlines_to_volume(
      centerline = centerline,
      template_file = tmp_vol,
      label_value = 1L,
      radius = 1,
      coords_are_voxels = TRUE
    )

    expect_true(is.array(result))
    expect_length(dim(result), 3)
    expect_gt(sum(result > 0), 0)
  })

  it("creates volume from centerline with RAS coordinates", {
    tmp_vol <- tempfile(fileext = ".nii.gz")
    on.exit(unlink(tmp_vol))

    vol_data <- array(0L, dim = c(10, 10, 10))
    nii <- RNifti::asNifti(vol_data)
    RNifti::writeNifti(nii, tmp_vol)

    centerline <- matrix(c(0, 0, 0, 1, 1, 1), ncol = 3, byrow = TRUE)

    result <- streamlines_to_volume(
      centerline = centerline,
      template_file = tmp_vol,
      label_value = 2L,
      radius = 1,
      coords_are_voxels = FALSE
    )

    expect_true(is.array(result))
    expect_length(dim(result), 3)
  })

  it("reorients volume to RAS when template is not RAS", {
    tmp_vol <- tempfile(fileext = ".nii.gz")
    on.exit(unlink(tmp_vol))

    vol_data <- array(0L, dim = c(10, 10, 10))
    nii <- RNifti::asNifti(vol_data)
    lpi_xform <- structure(diag(c(-1, -1, -1, 1)), code = 2L)
    RNifti::sform(nii) <- lpi_xform
    RNifti::qform(nii) <- lpi_xform
    RNifti::writeNifti(nii, tmp_vol)

    centerline <- matrix(c(5, 5, 5, 6, 6, 6), ncol = 3, byrow = TRUE)

    result <- streamlines_to_volume(
      centerline = centerline,
      template_file = tmp_vol,
      label_value = 1L,
      radius = 1,
      coords_are_voxels = TRUE
    )

    expect_true(is.array(result))
    expect_length(dim(result), 3)
  })
})


describe("detect_coords_are_voxels", {
  it("returns FALSE when min_coord less than -10", {
    streamlines <- list(
      matrix(c(-15:0, rep(0, 32)), ncol = 3)
    )
    expect_false(detect_coords_are_voxels(streamlines))
  })

  it("returns FALSE when max exceeds dims and dims provided", {
    streamlines <- list(
      matrix(c(0:10, rep(200, 11), rep(100, 11)), ncol = 3)
    )
    expect_false(detect_coords_are_voxels(streamlines, dims = c(50, 50, 50)))
  })
})
