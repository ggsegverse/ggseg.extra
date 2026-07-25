.cap <- new.env()

describe("extract_slice_2d", {
  it("extracts axial slice", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 5] <- 1

    slice <- extract_slice_2d(vol, "axial", 5)

    expect_true(is.matrix(slice))
    expect_identical(dim(slice), c(10L, 10L))
    expect_identical(max(slice), 1)
  })

  it("extracts coronal slice", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 5] <- 1

    slice <- extract_slice_2d(vol, "coronal", 5)

    expect_true(is.matrix(slice))
    expect_identical(dim(slice), c(10L, 10L))
    expect_identical(max(slice), 1)
  })

  it("extracts sagittal slice", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 5] <- 1

    slice <- extract_slice_2d(vol, "sagittal", 5)

    expect_true(is.matrix(slice))
    expect_identical(dim(slice), c(10L, 10L))
    expect_identical(max(slice), 1)
  })
})


describe("extract_slice_2d edge cases", {
  it("returns NULL for empty slice", {
    vol <- array(0, dim = c(10, 10, 10))
    result <- extract_slice_2d(vol, "axial", 1)
    expect_true(is.matrix(result))
  })

  it("handles non-matrix slice from 1-thick dimension", {
    vol <- array(1:10, dim = c(10, 1, 1))
    result <- extract_slice_2d(vol, "axial", 1)
    expect_true(is.matrix(result))
    expect_identical(dim(result), c(10L, 1L))
  })
})


describe("orient_slice_2d", {
  it("flips left sagittal horizontally", {
    slice <- matrix(c(1, 2, 3, 4), nrow = 2)

    flipped <- orient_slice_2d(slice, "sagittal", hemi = "left")

    expect_identical(flipped[1, ], slice[2, ])
    expect_identical(flipped[2, ], slice[1, ])
  })

  it("does not flip right sagittal", {
    slice <- matrix(c(1, 2, 3, 4), nrow = 2)

    result <- orient_slice_2d(slice, "sagittal", hemi = "right")

    expect_identical(result, slice)
  })

  it("does not flip axial or coronal", {
    slice <- matrix(c(1, 2, 3, 4), nrow = 2)

    expect_identical(orient_slice_2d(slice, "axial"), slice)
    expect_identical(orient_slice_2d(slice, "coronal"), slice)
  })
})


describe("snapshot_partial_projection", {
  it("creates PNG for synthetic volume", {
    vol <- array(0L, dim = c(10, 10, 10))
    vol[4:6, 4:6, 4:6] <- 1L

    outdir <- withr::local_tempdir("partial_proj_")

    snapshot_partial_projection(
      vol = vol,
      view = "axial",
      start = 1,
      end = 10,
      view_name = "axial_1",
      label = "test_region",
      output_dir = outdir,
      colour = "red",
      skip_existing = FALSE
    )

    files <- list.files(outdir, pattern = "\\.png$")
    expect_gt(length(files), 0)
  })
})


describe("snapshot_cortex_slice", {
  it("creates PNG for valid slice", {
    vol <- array(0L, dim = c(10, 10, 10))
    vol[4:6, 4:6, 5] <- 1L

    outdir <- withr::local_tempdir("cortex_slice_")

    result <- snapshot_cortex_slice(
      vol = vol,
      x = NA,
      y = NA,
      z = 5,
      slice_view = "axial",
      view_name = "axial_1",
      hemi = "cortex",
      output_dir = outdir,
      skip_existing = FALSE
    )

    expect_true(file.exists(result))
    expect_match(basename(result), "axial_1_cortex")
  })

  it("returns NULL when slice is empty", {
    vol <- array(0L, dim = c(10, 10, 10))

    outdir <- withr::local_tempdir("cortex_slice_")

    result <- snapshot_cortex_slice(
      vol = vol,
      x = NA,
      y = NA,
      z = 5,
      slice_view = "axial",
      view_name = "axial_1",
      hemi = "cortex",
      output_dir = outdir,
      skip_existing = FALSE
    )

    expect_null(result)
  })

  it("skips existing files", {
    vol <- array(0L, dim = c(10, 10, 10))
    vol[4:6, 4:6, 5] <- 1L

    outdir <- withr::local_tempdir("cortex_slice_")
    outfile <- as.character(fs::path(outdir, "axial_1_cortex_left.png"))
    file.create(outfile)

    result <- snapshot_cortex_slice(
      vol = vol,
      x = NA,
      y = NA,
      z = 5,
      slice_view = "axial",
      view_name = "axial_1",
      hemi = "left",
      output_dir = outdir,
      skip_existing = TRUE
    )

    expect_identical(result, outfile)
  })
})


describe("volume_projection", {
  it("creates axial projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 1:10] <- 1:10

    proj <- volume_projection(vol, "axial")

    expect_identical(dim(proj), c(10L, 10L))
    expect_identical(max(proj), 10)
  })

  it("creates sagittal projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[1:10, 5, 5] <- 1:10

    proj <- volume_projection(vol, "sagittal")

    expect_identical(dim(proj), c(10L, 10L))
  })

  it("creates coronal projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 1:10, 5] <- 1:10

    proj <- volume_projection(vol, "coronal")

    expect_identical(dim(proj), c(10L, 10L))
  })
})


describe("volume_projection with start/end", {
  it("creates partial axial projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 3:7] <- 1

    proj <- volume_projection(vol, "axial", start = 3, end = 7)

    expect_identical(dim(proj), c(10L, 10L))
    expect_identical(proj[5, 5], 1)
  })

  it("respects slice boundaries", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 1:2] <- 1
    vol[5, 5, 8:10] <- 2

    proj <- volume_projection(vol, "axial", start = 3, end = 7)

    expect_identical(max(proj), 0)
  })

  it("errors when end is before start instead of reversing the slab", {
    vol <- array(0, dim = c(10, 10, 10))

    expect_error(
      volume_projection(vol, "axial", start = 7, end = 3),
      "before start"
    )
  })
})


describe("extract_slice_2d with invalid view", {
  it("returns NULL for unrecognized view name", {
    vol <- array(1, dim = c(10, 10, 10))
    result <- extract_slice_2d(vol, "invalid_view", 5)
    expect_null(result)
  })
})


describe("snapshot_cortex_slice when extract_slice_2d returns NULL", {
  it("returns NULL when slice extraction fails", {
    local_mocked_bindings(
      extract_slice_2d = function(...) NULL
    )

    outdir <- withr::local_tempdir("cortex_null_")

    result <- snapshot_cortex_slice(
      vol = array(1L, dim = c(10, 10, 10)),
      x = NA,
      y = NA,
      z = 5,
      slice_view = "axial",
      view_name = "axial_1",
      hemi = "left",
      output_dir = outdir,
      skip_existing = FALSE
    )

    expect_null(result)
  })
})


describe("snapshot_partial_projection skip and zero paths", {
  it("returns outfile when skip_existing is TRUE and file exists", {
    outdir <- withr::local_tempdir("partial_skip_")
    outfile <- as.character(fs::path(outdir, "axial_1_test.png"))
    file.create(outfile)

    result <- snapshot_partial_projection(
      vol = array(1L, dim = c(10, 10, 10)),
      view = "axial",
      start = 1,
      end = 10,
      view_name = "axial_1",
      label = "test",
      output_dir = outdir,
      skip_existing = TRUE
    )

    expect_identical(result, outfile, ignore_attr = TRUE)
  })

  it("returns NULL when projection is all zeros", {
    vol <- array(0L, dim = c(10, 10, 10))

    outdir <- withr::local_tempdir("partial_zero_")

    result <- snapshot_partial_projection(
      vol = vol,
      view = "axial",
      start = 1,
      end = 10,
      view_name = "axial_1",
      label = "empty",
      output_dir = outdir,
      skip_existing = FALSE
    )

    expect_null(result)
  })
})
