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
