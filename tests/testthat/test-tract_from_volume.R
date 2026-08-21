describe("tract_centerline_from_points", {
  it("returns NULL for too few points", {
    expect_null(
      tract_centerline_from_points(matrix(rnorm(30), ncol = 3), n_points = 10)
    )
  })

  it("orders a straight point cloud into a centerline along its length", {
    skip_if_not_installed("princurve")
    t <- seq(0, 1, length.out = 300)
    line <- cbind(x = t * 100, y = 0, z = 0)
    cl <- tract_centerline_from_points(line, n_points = 20L)

    expect_identical(dim(cl), c(20L, 3L))
    # endpoints sit at the ends of the line (order may be reversed)
    xends <- sort(c(cl[1, 1], cl[20, 1]))
    expect_lt(xends[1], 5) # one end near x = 0
    expect_gt(xends[2], 95) # other end near x = 100
  })

  it("resamples roughly uniformly along arc length", {
    skip_if_not_installed("princurve")
    t <- seq(0, 1, length.out = 300)
    line <- cbind(t * 100, 0, 0)
    cl <- tract_centerline_from_points(line, n_points = 20L)
    seg <- sqrt(rowSums(diff(cl)^2))
    expect_lt(stats::sd(seg) / mean(seg), 0.1)
  })

  it("follows a curved (quarter-circle) tract", {
    skip_if_not_installed("princurve")
    a <- seq(0, pi / 2, length.out = 300)
    arc <- cbind(x = cos(a) * 50, y = 0, z = sin(a) * 50)
    cl <- tract_centerline_from_points(arc, n_points = 30L)
    # both arc endpoints are matched by some centerline endpoint
    ends <- rbind(cl[1, ], cl[30, ])
    d0 <- min(sqrt(rowSums(sweep(ends, 2, arc[1, ])^2)))
    d1 <- min(sqrt(rowSums(sweep(ends, 2, arc[nrow(arc), ])^2)))
    expect_lt(d0, 8)
    expect_lt(d1, 8)
  })
})

describe("create_tract_from_volume", {
  it("builds a type=tract atlas from a label volume (3D)", {
    skip_if_not_installed("princurve")
    skip_if_not_installed("RNifti")

    # two diagonal "tracts" of voxels in a small volume
    arr <- array(0L, dim = c(40L, 40L, 40L))
    for (k in 5:35) {
      arr[k, k, 20] <- 1L # tract 1: x=y diagonal
      arr[k, 20, k] <- 2L # tract 2: x=z diagonal
    }
    vol <- RNifti::asNifti(arr)
    RNifti::pixdim(vol) <- c(1, 1, 1)
    vpath <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(vol, vpath)

    lut <- data.frame(
      idx = c(1L, 2L),
      label = c("tract_a", "tract_b"),
      R = c(255L, 0L),
      G = c(0L, 255L),
      B = c(0L, 0L)
    )

    atlas <- create_tract_from_volume(
      input_volume = vpath,
      input_lut = lut,
      min_voxels = 10L,
      atlas_name = "toy",
      output_dir = withr::local_tempdir(),
      steps = 1L,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(ggseg.formats::atlas_type(atlas), "tract")
    expect_identical(nrow(atlas$core), 2L)
  })
})


describe("thin_evenly", {
  it("leaves a vector at or under the cap untouched", {
    expect_identical(thin_evenly(1:10, 10L), 1:10)
    expect_identical(thin_evenly(1:3, 10L), 1:3)
  })

  it("thins to exactly the cap, keeping both ends", {
    out <- thin_evenly(1:1000, 50L)
    expect_length(out, 50L)
    expect_identical(out[1], 1L)
    expect_identical(out[50], 1000L)
  })

  it("is deterministic, so the build stays reproducible", {
    expect_identical(thin_evenly(1:1000, 50L), thin_evenly(1:1000, 50L))
  })
})


describe("voxels_to_world", {
  it("applies the affine to linear voxel indices", {
    dims <- c(4L, 5L, 6L)
    xf <- matrix(
      c(2, 0, 0, 10, 0, 3, 0, 20, 0, 0, 4, 30, 0, 0, 0, 1),
      nrow = 4,
      byrow = TRUE
    )
    # linear index 1 is voxel (1,1,1), i.e. zero-based (0,0,0)
    expect_equal(
      voxels_to_world(1L, dims, xf),
      matrix(c(10, 20, 30), nrow = 1),
      ignore_attr = TRUE
    )
  })

  it("matches a per-label which(arr.ind) scan", {
    dims <- c(7L, 8L, 9L)
    arr <- array(0L, dim = dims)
    arr[c(3L, 40L, 111L, 300L)] <- 5L
    xf <- matrix(
      c(-1, 0, 0, 4, 0, 2, 0, -6, 0, 0, 3, 1, 0, 0, 0, 1),
      nrow = 4,
      byrow = TRUE
    )

    ijk <- which(arr == 5L, arr.ind = TRUE) - 1L
    expected <- t(xf %*% rbind(t(ijk), 1))[, 1:3, drop = FALSE]

    expect_equal(
      voxels_to_world(which(arr == 5L), dims, xf),
      expected,
      ignore_attr = TRUE
    )
  })
})
