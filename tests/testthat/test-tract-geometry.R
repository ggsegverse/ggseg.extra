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

    expect_true(is.list(mesh))
    expect_true(all(c("vertices", "faces") %in% names(mesh)))
    expect_true(nrow(mesh$vertices) > 0)
    expect_true(nrow(mesh$faces) > 0)
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

    expected_vertices <- n_points * segments
    expect_equal(nrow(mesh$vertices), expected_vertices)
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

    expected_faces <- (n_points - 1) * segments * 2
    expect_equal(nrow(mesh$faces), expected_faces)
  })

  it("respects radius parameter", {
    centerline <- matrix(c(0, 0, 0, 10, 0, 0), ncol = 3, byrow = TRUE)
    colnames(centerline) <- c("x", "y", "z")

    mesh_small <- generate_tube_mesh(centerline, radius = 0.1, segments = 8)
    mesh_large <- generate_tube_mesh(centerline, radius = 1.0, segments = 8)

    small_range <- max(mesh_small$vertices$y) - min(mesh_small$vertices$y)
    large_range <- max(mesh_large$vertices$y) - min(mesh_large$vertices$y)

    expect_true(large_range > small_range * 5)
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

    expect_equal(nrow(centerline), 5)
    expect_true(all(c("x", "y", "z") %in% colnames(centerline)))
  })

  it("computes mean centerline from multiple streamlines", {
    streamlines <- list(
      matrix(c(1:5, rep(0, 10)), ncol = 3),
      matrix(c(1:5, rep(1, 10)), ncol = 3),
      matrix(c(1:5, rep(2, 10)), ncol = 3)
    )

    centerline <- extract_centerline(streamlines, method = "mean", n_points = 5)

    expect_equal(nrow(centerline), 5)
    expect_equal(mean(centerline[, 2]), 1, tolerance = 0.5)
  })

  it("resamples to specified number of points", {
    streamline <- matrix(c(1:100, rep(0, 200)), ncol = 3)
    colnames(streamline) <- c("x", "y", "z")

    centerline <- extract_centerline(streamline, n_points = 20)

    expect_equal(nrow(centerline), 20)
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
    expect_equal(nrow(frames$tangents), nrow(curve))
    expect_equal(nrow(frames$normals), nrow(curve))
    expect_equal(nrow(frames$binormals), nrow(curve))

    for (i in seq_len(nrow(curve))) {
      t <- frames$tangents[i, ]
      n <- frames$normals[i, ]
      b <- frames$binormals[i, ]

      expect_equal(sqrt(sum(n^2)), 1, tolerance = 1e-6)
      expect_equal(sqrt(sum(b^2)), 1, tolerance = 1e-6)
      expect_equal(sum(n * b), 0, tolerance = 1e-6)
    }
  })
})


describe("resample_streamline", {
  it("resamples to exact number of points", {
    streamline <- matrix(c(1:100, rep(0, 200)), ncol = 3)
    colnames(streamline) <- c("x", "y", "z")

    resampled <- resample_streamline(streamline, 20)

    expect_equal(nrow(resampled), 20)
  })

  it("preserves endpoints", {
    streamline <- matrix(c(0, 0, 0, 10, 0, 0), ncol = 3, byrow = TRUE)
    colnames(streamline) <- c("x", "y", "z")

    resampled <- resample_streamline(streamline, 5)

    expect_equal(as.numeric(resampled[1, 1]), 0, tolerance = 1e-6)
    expect_equal(as.numeric(resampled[5, 1]), 10, tolerance = 1e-6)
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

    expect_equal(result, c(0, 0, 1))
  })

  it("returns zero for parallel vectors", {
    a <- c(1, 0, 0)
    b <- c(2, 0, 0)

    result <- cross_product(a, b)

    expect_equal(result, c(0, 0, 0))
  })

  it("is anti-commutative", {
    a <- c(1, 2, 3)
    b <- c(4, 5, 6)

    result1 <- cross_product(a, b)
    result2 <- cross_product(b, a)

    expect_equal(result1, -result2)
  })
})


describe("rotate_vector", {
  it("rotates vector 90 degrees around z-axis", {
    v <- c(1, 0, 0)
    axis <- c(0, 0, 1)
    angle <- pi / 2

    result <- rotate_vector(v, axis, angle)

    expect_equal(result[1], 0, tolerance = 1e-6)
    expect_equal(result[2], 1, tolerance = 1e-6)
    expect_equal(result[3], 0, tolerance = 1e-6)
  })

  it("does not change vector when angle is 0", {
    v <- c(1, 2, 3)
    axis <- c(0, 0, 1)

    result <- rotate_vector(v, axis, 0)

    expect_equal(result, v, tolerance = 1e-6)
  })

  it("returns original vector when rotating around itself", {
    v <- c(0, 0, 1)
    axis <- c(0, 0, 1)

    result <- rotate_vector(v, axis, pi / 4)

    expect_equal(result, v, tolerance = 1e-6)
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

    expect_equal(centroid[1], 0, tolerance = 1e-6)
    expect_equal(centroid[2], 0, tolerance = 1e-6)
    expect_equal(centroid[3], 0, tolerance = 1e-6)
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
    expect_equal(nrow(result$mesh1$vertices), 3)
    expect_equal(nrow(result$mesh1$faces), 1)
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
    expect_true(mean(cl[, 1]) < 5)
  })
})


describe("coord_to_voxel", {
  it("adds 1 when coords_are_voxels is TRUE", {
    result <- coord_to_voxel(c(10, 20, 30), c(256, 256, 256), NULL, TRUE)
    expect_equal(result, c(11, 21, 31))
  })

  it("uses vox2ras inverse when matrix provided", {
    vox2ras <- diag(4)
    vox2ras[1:3, 4] <- c(-128, -128, -128)
    result <- coord_to_voxel(c(0, 0, 0), c(256, 256, 256), vox2ras, FALSE)
    expect_equal(result, c(129, 129, 129))
  })

  it("uses fallback formula without vox2ras", {
    dims <- c(256, 256, 256)
    result <- coord_to_voxel(c(0, 0, 0), dims, NULL, FALSE)
    expect_equal(result, c(129, 129, 129))
  })
})


describe("voxel_in_bounds", {
  it("returns TRUE for valid coordinates", {
    expect_true(voxel_in_bounds(5, 5, 5, c(10, 10, 10)))
    expect_true(voxel_in_bounds(1, 1, 1, c(10, 10, 10)))
    expect_true(voxel_in_bounds(10, 10, 10, c(10, 10, 10)))
  })

  it("returns FALSE for out-of-bounds coordinates", {
    expect_false(voxel_in_bounds(0, 5, 5, c(10, 10, 10)))
    expect_false(voxel_in_bounds(5, 0, 5, c(10, 10, 10)))
    expect_false(voxel_in_bounds(5, 5, 11, c(10, 10, 10)))
  })
})


describe("set_sphere_voxels", {
  it("sets voxels within sphere", {
    vol <- array(0L, dim = c(10, 10, 10))
    result <- set_sphere_voxels(vol, c(5, 5, 5), 1, 1L, c(10, 10, 10))

    expect_equal(result[5, 5, 5], 1L)
    expect_equal(result[6, 5, 5], 1L)
    expect_equal(result[5, 6, 5], 1L)
  })

  it("does not set voxels outside bounds", {
    vol <- array(0L, dim = c(5, 5, 5))
    result <- set_sphere_voxels(vol, c(1, 1, 1), 2, 1L, c(5, 5, 5))

    expect_equal(sum(result), sum(result[result > 0]))
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

    expect_equal(nrow(result), 5)
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
    expect_equal(nrow(result), 5)
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
    expect_equal(nrow(result), 3)
    expect_equal(colnames(result), c("x", "y", "z"))
    expect_equal(as.numeric(result[1, 3]), 0, tolerance = 1e-6)
    expect_equal(as.numeric(result[3, 3]), 5, tolerance = 1e-6)
  })

  it("handles streamline where segment_end equals segment_start", {
    streamline <- matrix(
      c(0, 0, 0, 0, 0, 0, 0, 0, 5),
      ncol = 3,
      byrow = TRUE
    )
    result <- resample_streamline(streamline, 5)
    expect_equal(nrow(result), 5)
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
    expect_equal(nrow(result), 5)
    expect_equal(as.numeric(result[5, 1]), 5, tolerance = 1e-6)
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
    expect_equal(nrow(mesh$vertices), 3 * 4)
    expect_equal(nrow(mesh$faces), 2 * 4 * 2)
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
    expect_true(result[1] >= 1)
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
    expect_equal(dim(result), c(4, 4))
  })

  it("loads vox2ras from nii file", {
    tmp <- tempfile(fileext = ".nii")
    vol <- array(0L, dim = c(5, 5, 5))
    nii <- RNifti::asNifti(vol)
    RNifti::writeNifti(nii, tmp)
    on.exit(unlink(tmp))

    result <- load_vox2ras_matrix(tmp, FALSE)
    expect_true(is.matrix(result))
    expect_equal(dim(result), c(4, 4))
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
    expect_equal(length(dim(result)), 3)
    expect_true(sum(result > 0) > 0)
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
    expect_equal(length(dim(result)), 3)
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
    expect_equal(length(dim(result)), 3)
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


describe("create_tract_geometry_volumetric", {
  it("runs the full pipeline with mocked dependencies", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas(c("tract_a", "tract_b"))

    fake_streamlines <- list(
      tract_a = matrix(c(1:10, rep(0, 20)), ncol = 3),
      tract_b = matrix(c(1:10, rep(5, 20)), ncol = 3)
    )

    fake_vol <- array(0L, dim = c(20, 20, 20))
    fake_vol[5:10, 5:10, 5:10] <- 3L
    fake_vol[12:16, 12:16, 12:16] <- 42L

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(fake_vol)
    RNifti::writeNifti(nii, aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sfc <- sf::st_sfc(fake_geom, fake_geom, fake_geom)
    fake_sf <- sf::st_sf(
      filenm = c(
        "axial_1_tract_a.png",
        "axial_1_tract_b.png",
        "axial_1_cortex_cortex.png"
      ),
      geometry = fake_sfc
    )
    fake_sf$view <- c("axial_1", "axial_1", "axial_1")

    local_mocked_bindings(
      is_verbose = function(...) TRUE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        dirs <- list(
          base = file.path(tmp_dir, "tract_geom"),
          snapshots = file.path(tmp_dir, "tract_geom", "snapshots"),
          processed = file.path(tmp_dir, "tract_geom", "processed"),
          masks = file.path(tmp_dir, "tract_geom", "masks"),
          volumes = file.path(tmp_dir, "tract_geom", "volumes")
        )
        lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE)
        dirs
      },
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      default_tract_views = function(dims) {
        data.frame(
          name = "axial_1",
          type = "axial",
          start = 1,
          end = 20,
          stringsAsFactors = FALSE
        )
      },
      create_cortex_slices = function(views, dims, ...) {
        data.frame(
          x = NA,
          y = NA,
          z = 10,
          view = "axial",
          name = "axial_1",
          stringsAsFactors = FALSE
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      extract_centerline = function(sl, ...) {
        if (is.list(sl) && !is.matrix(sl)) {
          sl[[1]]
        } else {
          sl
        }
      },
      streamlines_to_volume = function(...) fake_vol,
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      extract_hemi_from_view = function(...) NULL,
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    expect_messages(
      result <- create_tract_geometry_volumetric(
        atlas = fake_atlas,
        aseg_file = aseg_tmp,
        streamlines = fake_streamlines,
        verbose = TRUE
      )
    )

    expect_s3_class(result, "sf")
    expect_true("label" %in% names(result))
    expect_true("view" %in% names(result))
    expect_true("geometry" %in% names(result))
  })

  it("errors when atlas is not tract type", {
    expect_error(
      create_tract_geometry_volumetric(
        atlas = list(type = "cortical"),
        aseg_file = "fake.mgz",
        streamlines = list()
      ),
      "must be of type 'tract'"
    )
  })

  it("errors when aseg file doesn't exist", {
    expect_error(
      create_tract_geometry_volumetric(
        atlas = make_test_tract_atlas(),
        aseg_file = "/nonexistent.mgz",
        streamlines = list()
      ),
      "not found"
    )
  })

  it("errors when streamlines are missing", {
    aseg_tmp <- tempfile(fileext = ".nii.gz")
    writeLines("fake", aseg_tmp)
    on.exit(unlink(aseg_tmp))

    expect_error(
      create_tract_geometry_volumetric(
        atlas = make_test_tract_atlas(),
        aseg_file = aseg_tmp
      ),
      "streamlines.*required"
    )
  })

  it("errors when atlas has no centerlines data", {
    tmp_dir <- withr::local_tempdir()
    aseg_tmp <- tempfile(fileext = ".nii.gz")
    writeLines("fake", aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = tmp_dir,
          snapshots = tmp_dir,
          processed = tmp_dir,
          masks = tmp_dir,
          volumes = tmp_dir
        )
      },
      detect_coords_are_voxels = function(...) TRUE
    )

    expect_error(
      create_tract_geometry_volumetric(
        atlas = make_test_tract_atlas_geom(),
        aseg_file = aseg_tmp,
        streamlines = list(a = matrix(1:6, ncol = 3))
      ),
      "must have centerlines"
    )
  })

  it("errors when streamlines are missing labels", {
    tmp_dir <- withr::local_tempdir()
    aseg_tmp <- tempfile(fileext = ".nii.gz")
    writeLines("fake", aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = tmp_dir,
          snapshots = tmp_dir,
          processed = tmp_dir,
          masks = tmp_dir,
          volumes = tmp_dir
        )
      },
      detect_coords_are_voxels = function(...) TRUE
    )

    expect_error(
      create_tract_geometry_volumetric(
        atlas = make_test_tract_atlas(c("a", "b")),
        aseg_file = aseg_tmp,
        streamlines = list(a = matrix(1:6, ncol = 3))
      ),
      "Streamlines missing"
    )
  })

  it("uses cached contours when skip_existing is TRUE", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas("tract_a")

    base_dir <- file.path(tmp_dir, "tract_geom")
    dir.create(base_dir, recursive = TRUE)

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_1_tract_a.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial_1"

    contours_file <- file.path(base_dir, "contours_reduced.rda")
    file.create(contours_file)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 1,
      end = 20,
      stringsAsFactors = FALSE
    )
    views_file <- file.path(base_dir, "views.rds")
    saveRDS(views, views_file)

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    writeLines("fake", aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    local_mocked_bindings(
      is_verbose = function(...) TRUE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) TRUE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = base_dir,
          snapshots = file.path(base_dir, "snapshots"),
          processed = file.path(base_dir, "processed"),
          masks = file.path(base_dir, "masks"),
          volumes = file.path(base_dir, "volumes")
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    expect_messages(
      result <- create_tract_geometry_volumetric(
        atlas = fake_atlas,
        aseg_file = aseg_tmp,
        streamlines = list(tract_a = matrix(1:6, ncol = 3)),
        verbose = TRUE
      )
    )

    expect_s3_class(result, "sf")
  })

  it("uses cached contours without views file", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas("tract_a")

    base_dir <- file.path(tmp_dir, "tract_geom")
    dir.create(base_dir, recursive = TRUE)

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_1_tract_a.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial_1"

    contours_file <- file.path(base_dir, "contours_reduced.rda")
    file.create(contours_file)

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    writeLines("fake", aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) TRUE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = base_dir,
          snapshots = file.path(base_dir, "snapshots"),
          processed = file.path(base_dir, "processed"),
          masks = file.path(base_dir, "masks"),
          volumes = file.path(base_dir, "volumes")
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      read_volume = function(f, ...) array(0L, dim = c(20, 20, 20)),
      default_tract_views = function(dims) {
        data.frame(
          name = "axial_1",
          type = "axial",
          start = 1,
          end = 20,
          stringsAsFactors = FALSE
        )
      },
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    result <- create_tract_geometry_volumetric(
      atlas = fake_atlas,
      aseg_file = aseg_tmp,
      streamlines = list(tract_a = matrix(1:6, ncol = 3))
    )

    expect_s3_class(result, "sf")
  })

  it("cleans up when cleanup is TRUE", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas("tract_a")

    base_dir <- file.path(tmp_dir, "tract_geom")
    dir.create(base_dir, recursive = TRUE)

    contours_file <- file.path(base_dir, "contours_reduced.rda")
    file.create(contours_file)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 1,
      end = 20,
      stringsAsFactors = FALSE
    )
    saveRDS(views, file.path(base_dir, "views.rds"))

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_1_tract_a.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial_1"

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    writeLines("fake", aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) TRUE,
      get_skip_existing = function(...) TRUE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = base_dir,
          snapshots = file.path(base_dir, "snapshots"),
          processed = file.path(base_dir, "processed"),
          masks = file.path(base_dir, "masks"),
          volumes = file.path(base_dir, "volumes")
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    result <- create_tract_geometry_volumetric(
      atlas = fake_atlas,
      aseg_file = aseg_tmp,
      streamlines = list(tract_a = matrix(1:6, ncol = 3))
    )

    expect_s3_class(result, "sf")
  })

  it("handles NA view in filename extraction", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas("tract_a")

    base_dir <- file.path(tmp_dir, "tract_geom")
    dir.create(base_dir, recursive = TRUE)

    contours_file <- file.path(base_dir, "contours_reduced.rda")
    file.create(contours_file)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 1,
      end = 20,
      stringsAsFactors = FALSE
    )
    saveRDS(views, file.path(base_dir, "views.rds"))

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "unknown_thing.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- NA_character_

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    writeLines("fake", aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) TRUE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = base_dir,
          snapshots = file.path(base_dir, "snapshots"),
          processed = file.path(base_dir, "processed"),
          masks = file.path(base_dir, "masks"),
          volumes = file.path(base_dir, "volumes")
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    result <- create_tract_geometry_volumetric(
      atlas = fake_atlas,
      aseg_file = aseg_tmp,
      streamlines = list(tract_a = matrix(1:6, ncol = 3))
    )

    expect_equal(result$label, "unknown_thing")
  })

  it("skips existing snapshots when enough exist", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas("tract_a")

    fake_vol <- array(0L, dim = c(20, 20, 20))
    fake_vol[5:10, 5:10, 5:10] <- 3L

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(fake_vol)
    RNifti::writeNifti(nii, aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    base_dir <- file.path(tmp_dir, "tract_geom")
    snaps_dir <- file.path(base_dir, "snapshots")
    processed_dir <- file.path(base_dir, "processed")
    masks_dir <- file.path(base_dir, "masks")
    dir.create(snaps_dir, recursive = TRUE)
    dir.create(processed_dir, recursive = TRUE)
    dir.create(masks_dir, recursive = TRUE)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 1,
      end = 20,
      stringsAsFactors = FALSE
    )
    cortex_slices <- data.frame(
      x = NA,
      y = NA,
      z = 10,
      view = "axial",
      name = "axial_1",
      stringsAsFactors = FALSE
    )

    n_snapshots <- nrow(views) * 1 + nrow(cortex_slices)
    for (i in seq_len(n_snapshots)) {
      file.create(file.path(snaps_dir, paste0("snap_", i, ".png")))
    }

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_1_tract_a.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial_1"

    local_mocked_bindings(
      is_verbose = function(...) TRUE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) TRUE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = base_dir,
          snapshots = snaps_dir,
          processed = processed_dir,
          masks = masks_dir,
          volumes = file.path(base_dir, "volumes")
        )
      },
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      default_tract_views = function(dims) views,
      create_cortex_slices = function(...) cortex_slices,
      detect_coords_are_voxels = function(...) TRUE,
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    expect_messages(
      result <- create_tract_geometry_volumetric(
        atlas = fake_atlas,
        aseg_file = aseg_tmp,
        streamlines = list(tract_a = matrix(1:6, ncol = 3)),
        verbose = TRUE
      )
    )

    expect_s3_class(result, "sf")
  })

  it("handles list-of-lists streamlines in the tract volume creation", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas("tract_a")

    fake_vol <- array(0L, dim = c(20, 20, 20))
    fake_vol[5:10, 5:10, 5:10] <- 3L

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(fake_vol)
    RNifti::writeNifti(nii, aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_1_tract_a.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial_1"

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        dirs <- list(
          base = file.path(tmp_dir, "tg"),
          snapshots = file.path(tmp_dir, "tg", "snapshots"),
          processed = file.path(tmp_dir, "tg", "processed"),
          masks = file.path(tmp_dir, "tg", "masks"),
          volumes = file.path(tmp_dir, "tg", "volumes")
        )
        lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE)
        dirs
      },
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      default_tract_views = function(dims) {
        data.frame(
          name = "axial_1",
          type = "axial",
          start = 1,
          end = 20,
          stringsAsFactors = FALSE
        )
      },
      create_cortex_slices = function(...) {
        data.frame(
          x = NA,
          y = NA,
          z = 10,
          view = "axial",
          name = "axial_1",
          stringsAsFactors = FALSE
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      extract_centerline = function(sl, ...) {
        matrix(c(5, 5, 5, 6, 6, 6), ncol = 3, byrow = TRUE)
      },
      streamlines_to_volume = function(...) fake_vol,
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      extract_hemi_from_view = function(...) NULL,
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    list_streamlines <- list(
      tract_a = list(
        matrix(c(5, 5, 5, 6, 6, 6), ncol = 3, byrow = TRUE),
        matrix(c(5, 5, 5, 7, 7, 7), ncol = 3, byrow = TRUE)
      )
    )

    result <- create_tract_geometry_volumetric(
      atlas = fake_atlas,
      aseg_file = aseg_tmp,
      streamlines = list_streamlines
    )

    expect_s3_class(result, "sf")
  })

  it("auto-detects coordinate space when coords_are_voxels is NULL", {
    tmp_dir <- withr::local_tempdir()

    fake_atlas <- make_test_tract_atlas("tract_a")

    fake_vol <- array(0L, dim = c(20, 20, 20))
    fake_vol[5:10, 5:10, 5:10] <- 3L

    aseg_tmp <- tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(fake_vol)
    RNifti::writeNifti(nii, aseg_tmp)
    withr::defer(unlink(aseg_tmp))

    base_dir <- file.path(tmp_dir, "tract_geom")
    dir.create(base_dir, recursive = TRUE)
    contours_file <- file.path(base_dir, "contours_reduced.rda")
    file.create(contours_file)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 1,
      end = 20,
      stringsAsFactors = FALSE
    )
    saveRDS(views, file.path(base_dir, "views.rds"))

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_1_tract_a.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial_1"

    detected_space <- NULL
    local_mocked_bindings(
      is_verbose = function(...) TRUE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) TRUE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      setup_atlas_dirs = function(...) {
        list(
          base = base_dir,
          snapshots = file.path(base_dir, "snapshots"),
          processed = file.path(base_dir, "processed"),
          masks = file.path(base_dir, "masks"),
          volumes = file.path(base_dir, "volumes")
        )
      },
      detect_coords_are_voxels = function(...) {
        detected_space <<- TRUE
        TRUE
      },
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    expect_messages(
      result <- create_tract_geometry_volumetric(
        atlas = fake_atlas,
        aseg_file = aseg_tmp,
        streamlines = list(tract_a = matrix(c(5:14, rep(0, 20)), ncol = 3)),
        coords_are_voxels = NULL,
        verbose = TRUE
      )
    )

    expect_s3_class(result, "sf")
    expect_true(detected_space)
  })
})
