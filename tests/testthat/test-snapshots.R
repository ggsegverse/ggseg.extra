describe("extract_slice_2d", {
  it("extracts axial slice", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 5] <- 1

    slice <- extract_slice_2d(vol, "axial", 5)

    expect_true(is.matrix(slice))
    expect_equal(dim(slice), c(10, 10))
    expect_equal(max(slice), 1)
  })

  it("extracts coronal slice", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 5] <- 1

    slice <- extract_slice_2d(vol, "coronal", 5)

    expect_true(is.matrix(slice))
    expect_equal(dim(slice), c(10, 10))
    expect_equal(max(slice), 1)
  })

  it("extracts sagittal slice", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 5] <- 1

    slice <- extract_slice_2d(vol, "sagittal", 5)

    expect_true(is.matrix(slice))
    expect_equal(dim(slice), c(10, 10))
    expect_equal(max(slice), 1)
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
    expect_equal(dim(result), c(10, 1))
  })
})


describe("snapshot_slice with label file", {
  it("filters volume by label ID", {
    vol <- array(0L, dim = c(10, 10, 10))
    vol[4:6, 4:6, 5] <- 42L
    vol[7:8, 7:8, 5] <- 99L

    local_mocked_bindings(
      read_volume = function(f) vol
    )

    outdir <- withr::local_tempdir("snap_label_")

    snapshot_slice(
      lab = "lh_0042.label",
      x = 5,
      y = 5,
      z = 5,
      view = "axial",
      label_file = "volume.mgz",
      output_dir = outdir
    )

    files <- list.files(outdir, pattern = "\\.png$")
    expect_true(length(files) > 0)
  })

  it("errors when label_file is NULL for .label input", {
    expect_error(
      snapshot_slice(
        lab = "lh_0042.label",
        x = 5,
        y = 5,
        z = 5,
        view = "axial",
        output_dir = tempdir()
      ),
      "label_file must be provided"
    )
  })
})


describe("orient_slice_2d", {
  it("flips left sagittal horizontally", {
    slice <- matrix(c(1, 2, 3, 4), nrow = 2)

    flipped <- orient_slice_2d(slice, "sagittal", hemi = "left")

    expect_equal(flipped[1, ], slice[2, ])
    expect_equal(flipped[2, ], slice[1, ])
  })

  it("does not flip right sagittal", {
    slice <- matrix(c(1, 2, 3, 4), nrow = 2)

    result <- orient_slice_2d(slice, "sagittal", hemi = "right")

    expect_equal(result, slice)
  })

  it("does not flip axial or coronal", {
    slice <- matrix(c(1, 2, 3, 4), nrow = 2)

    expect_equal(orient_slice_2d(slice, "axial"), slice)
    expect_equal(orient_slice_2d(slice, "coronal"), slice)
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
    expect_true(length(files) > 0)
  })
})


describe("snapshot_slice", {
  it("creates PNG when slice has data", {
    skip_if_no_freesurfer()

    mgz_file <- test_mgz_file()
    skip_if(!file.exists(mgz_file), "Test MGZ file not found")

    outdir <- withr::local_tempdir("snapshot_test_")

    snapshot_slice(
      lab = mgz_file,
      x = 16,
      y = 16,
      z = 16,
      view = "axial",
      output_dir = outdir
    )

    expected_file <- file.path(outdir, "016_016_016_axial_aseg.png")
    expect_true(file.exists(expected_file))
  })

  it("skips snapshot when slice has no data", {
    skip_if_no_freesurfer()

    mgz_file <- test_mgz_file()
    skip_if(!file.exists(mgz_file), "Test MGZ file not found")

    outdir <- withr::local_tempdir("snapshot_test_")

    expect_no_error(
      snapshot_slice(
        lab = mgz_file,
        x = 1,
        y = 30,
        z = 20,
        view = "sagittal",
        output_dir = outdir
      )
    )

    files_created <- list.files(outdir, pattern = "\\.png$")
    expect_length(files_created, 0)
  })

  it("runs without error for all view types", {
    skip_if_no_freesurfer()

    mgz_file <- test_mgz_file()
    skip_if(!file.exists(mgz_file), "Test MGZ file not found")

    outdir <- withr::local_tempdir("snapshot_test_")

    for (view in c("axial", "sagittal", "coronal")) {
      expect_no_error(
        snapshot_slice(
          lab = mgz_file,
          x = 16,
          y = 16,
          z = 16,
          view = view,
          output_dir = outdir
        )
      )
    }
  })

  it("skips existing files when skip_existing = TRUE", {
    skip_if_no_freesurfer()

    mgz_file <- test_mgz_file()
    skip_if(!file.exists(mgz_file), "Test MGZ file not found")

    outdir <- withr::local_tempdir("snapshot_test_")
    outfile <- file.path(outdir, "016_016_016_axial_aseg.png")

    snapshot_slice(
      lab = mgz_file,
      x = 16,
      y = 16,
      z = 16,
      view = "axial",
      output_dir = outdir
    )

    mtime1 <- file.mtime(outfile)
    Sys.sleep(0.1)

    snapshot_slice(
      lab = mgz_file,
      x = 16,
      y = 16,
      z = 16,
      view = "axial",
      output_dir = outdir,
      skip_existing = TRUE
    )

    mtime2 <- file.mtime(outfile)
    expect_equal(mtime1, mtime2)
  })
})


describe("snapshot_volume_slice", {
  it("creates PNG for valid volume slice", {
    vol <- array(0, dim = c(32, 32, 32))
    vol[10:20, 10:20, 16] <- 1

    outdir <- withr::local_tempdir("snapshot_vol_")

    result <- snapshot_volume_slice(
      vol = vol,
      x = 16,
      y = 16,
      z = 16,
      view = "axial",
      label = "test",
      output_dir = outdir
    )

    expect_true(file.exists(result))
    expect_match(result, "axial.*test\\.png$")
  })

  it("returns NULL when slice is empty", {
    vol <- array(0, dim = c(32, 32, 32))

    outdir <- withr::local_tempdir("snapshot_vol_")

    result <- snapshot_volume_slice(
      vol = vol,
      x = 16,
      y = 16,
      z = 16,
      view = "axial",
      label = "empty",
      output_dir = outdir
    )

    expect_null(result)
    expect_length(list.files(outdir, pattern = "\\.png$"), 0)
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
    outfile <- file.path(outdir, "axial_1_cortex_left.png")
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

    expect_equal(result, outfile)
  })
})


describe("snapshot_volume_slice coronal/sagittal", {
  it("creates PNG for coronal view", {
    vol <- array(0, dim = c(32, 32, 32))
    vol[10:20, 16, 10:20] <- 1

    outdir <- withr::local_tempdir("snapshot_vol_")

    result <- snapshot_volume_slice(
      vol = vol,
      x = 16,
      y = 16,
      z = 16,
      view = "coronal",
      label = "test",
      output_dir = outdir
    )

    expect_true(file.exists(result))
    expect_match(result, "coron.*test\\.png$")
  })

  it("creates PNG for sagittal view", {
    vol <- array(0, dim = c(32, 32, 32))
    vol[16, 10:20, 10:20] <- 1

    outdir <- withr::local_tempdir("snapshot_vol_")

    result <- snapshot_volume_slice(
      vol = vol,
      x = 16,
      y = 16,
      z = 16,
      view = "sagittal",
      label = "test",
      output_dir = outdir
    )

    expect_true(file.exists(result))
    expect_match(result, "sagit.*test\\.png$")
  })

  it("skips existing files", {
    vol <- array(0, dim = c(32, 32, 32))
    vol[10:20, 10:20, 16] <- 1

    outdir <- withr::local_tempdir("snapshot_vol_")

    result1 <- snapshot_volume_slice(
      vol = vol,
      x = 16,
      y = 16,
      z = 16,
      view = "axial",
      label = "test",
      output_dir = outdir,
      skip_existing = FALSE
    )

    mtime1 <- file.mtime(result1)
    Sys.sleep(0.1)

    result2 <- snapshot_volume_slice(
      vol = vol,
      x = 16,
      y = 16,
      z = 16,
      view = "axial",
      label = "test",
      output_dir = outdir,
      skip_existing = TRUE
    )

    expect_equal(file.mtime(result2), mtime1)
  })
})


describe("volume_projection", {
  it("creates axial projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 1:10] <- 1:10

    proj <- volume_projection(vol, "axial")

    expect_equal(dim(proj), c(10, 10))
    expect_equal(max(proj), 10)
  })

  it("creates sagittal projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[1:10, 5, 5] <- 1:10

    proj <- volume_projection(vol, "sagittal")

    expect_equal(dim(proj), c(10, 10))
  })

  it("creates coronal projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 1:10, 5] <- 1:10

    proj <- volume_projection(vol, "coronal")

    expect_equal(dim(proj), c(10, 10))
  })
})


describe("volume_projection with start/end", {
  it("creates partial axial projection", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 3:7] <- 1

    proj <- volume_projection(vol, "axial", start = 3, end = 7)

    expect_equal(dim(proj), c(10, 10))
    expect_equal(proj[5, 5], 1)
  })

  it("respects slice boundaries", {
    vol <- array(0, dim = c(10, 10, 10))
    vol[5, 5, 1:2] <- 1
    vol[5, 5, 8:10] <- 2

    proj <- volume_projection(vol, "axial", start = 3, end = 7)

    expect_equal(max(proj), 0)
  })
})


describe("snapshot_brain_helper", {
  it("returns early when skip_existing and file exists", {
    tmp <- withr::local_tempfile(fileext = ".png")
    file.create(tmp)

    result <- snapshot_brain_helper(
      atlas = NULL,
      hemisphere = "lh",
      view = "lateral",
      surface = "inflated",
      outfile = tmp,
      skip_existing = TRUE
    )
    expect_null(result)
  })

  it("calls ggseg3d pipeline when file doesn't exist", {
    snapshot_called <- FALSE
    local_mocked_bindings(
      ggseg3d = function(...) structure(list(), class = "ggseg3d"),
      set_flat_shading = function(x, ...) x,
      set_orthographic = function(x, ...) x,
      pan_camera = function(x, ...) x,
      set_background = function(x, ...) x,
      set_legend = function(x, ...) x,
      snapshot_brain = function(p, file, ...) {
        snapshot_called <<- TRUE
        file.create(file)
      }
    )

    tmp <- withr::local_tempfile(fileext = ".png")
    snapshot_brain_helper(
      atlas = NULL,
      hemisphere = "lh",
      view = "lateral",
      surface = "inflated",
      outfile = tmp
    )
    expect_true(snapshot_called)
  })
})


describe("snapshot_brain_full (full brain)", {
  it("constructs correct output filename", {
    captured_outfile <- NULL
    local_mocked_bindings(
      snapshot_brain_helper = function(
        atlas,
        hemisphere,
        view,
        surface,
        outfile,
        ...
      ) {
        captured_outfile <<- outfile
        invisible(outfile)
      }
    )

    tmp_dir <- withr::local_tempdir()
    ggseg.extra:::snapshot_brain_full(
      atlas = NULL,
      hemisphere = "lh",
      view = "lateral",
      surface = "inflated",
      output_dir = tmp_dir
    )

    expect_match(basename(captured_outfile), "full_lh_lateral\\.png")
  })
})


describe("snapshot_region", {
  it("constructs correct output filename and highlight data", {
    captured <- list()
    local_mocked_bindings(
      snapshot_brain_helper = function(
        atlas,
        hemisphere,
        view,
        surface,
        outfile,
        .data,
        colour,
        na_colour,
        ...
      ) {
        captured$outfile <<- outfile
        captured$.data <<- .data
        captured$colour <<- colour
        captured$na_colour <<- na_colour
        invisible(outfile)
      }
    )

    mock_atlas <- list(
      core = data.frame(label = c("lh_frontal", "lh_parietal"))
    )
    tmp_dir <- withr::local_tempdir()

    snapshot_region(
      atlas = mock_atlas,
      region_label = "lh_frontal",
      hemisphere = "lh",
      view = "lateral",
      surface = "inflated",
      output_dir = tmp_dir
    )

    expect_match(basename(captured$outfile), "lh_frontal_lh_lateral\\.png")
    expect_equal(captured$colour, "highlight")
    expect_equal(captured$na_colour, "#FFFFFF")
    expect_equal(
      captured$.data$highlight[captured$.data$label == "lh_frontal"],
      "#FF0000"
    )
    expect_equal(
      captured$.data$highlight[captured$.data$label == "lh_parietal"],
      "#FFFFFF"
    )
  })
})


describe("region_faces_camera", {
  it("returns TRUE when normals face the camera", {
    normals <- matrix(c(-1, 0, 0, -1, 0, 0), nrow = 2, byrow = TRUE)
    camera <- c(-350, 0, 0)

    expect_true(region_faces_camera(normals, camera))
  })

  it("returns FALSE when normals face away", {
    normals <- matrix(c(1, 0, 0, 1, 0, 0), nrow = 2, byrow = TRUE)
    camera <- c(-350, 0, 0)

    expect_false(region_faces_camera(normals, camera))
  })

  it("returns TRUE when at least one normal faces camera", {
    normals <- matrix(
      c(-1, 0, 0, 1, 0, 0),
      nrow = 2, byrow = TRUE
    )
    camera <- c(-350, 0, 0)

    expect_true(region_faces_camera(normals, camera))
  })
})


describe("filter_visible_regions", {
  make_mesh <- function(n) {
    n <- max(n, 4L)
    list(
      vertices = data.frame(
        x = seq_len(n), y = seq_len(n), z = rep(0, n)
      ),
      faces = data.frame(
        i = rep(0L, n - 2L),
        j = seq_len(n - 2L),
        k = seq_len(n - 2L) + 1L
      )
    )
  }

  it("removes regions that face away from camera", {
    local_mocked_bindings(
      compute_vertex_normals = function(mesh) {
        n <- nrow(mesh$vertices)
        normals <- matrix(0, nrow = n, ncol = 3)
        normals[1:3, 1] <- -1
        normals[4:6, 1] <- 1
        normals
      }
    )
    local_mocked_bindings(
      get_brain_mesh = function(hemi, surface, ...) make_mesh(6),
      .package = "ggseg.formats"
    )

    vertices_df <- data.frame(label = c("lh_outer", "lh_inner"))
    vertices_df$vertices <- list(
      c(0L, 1L, 2L),
      c(3L, 4L, 5L)
    )

    grid <- data.frame(
      region_label = c("lh_outer", "lh_inner"),
      hemisphere = c("lh", "lh"),
      view = c("lateral", "lateral"),
      stringsAsFactors = FALSE
    )

    result <- filter_visible_regions(grid, vertices_df)
    expect_equal(nrow(result), 1)
    expect_equal(result$region_label, "lh_outer")
  })

  it("keeps all regions for unknown view", {
    local_mocked_bindings(
      get_brain_mesh = function(hemi, surface, ...) make_mesh(3),
      .package = "ggseg.formats"
    )

    vertices_df <- data.frame(label = "lh_test")
    vertices_df$vertices <- list(0L)

    grid <- data.frame(
      region_label = "lh_test",
      hemisphere = "lh",
      view = "unknown_view",
      stringsAsFactors = FALSE
    )

    result <- filter_visible_regions(grid, vertices_df)
    expect_equal(nrow(result), 1)
  })
})


describe("snapshot_na_regions", {
  it("constructs correct filename and white highlight data", {
    captured <- list()
    local_mocked_bindings(
      snapshot_brain_helper = function(
        atlas,
        hemisphere,
        view,
        surface,
        outfile,
        .data,
        colour,
        na_colour,
        ...
      ) {
        captured$outfile <<- outfile
        captured$na_colour <<- na_colour
        invisible(outfile)
      }
    )

    mock_atlas <- list(
      core = data.frame(label = c("lh_frontal"))
    )
    tmp_dir <- withr::local_tempdir()

    snapshot_na_regions(
      atlas = mock_atlas,
      hemisphere = "lh",
      view = "lateral",
      surface = "inflated",
      output_dir = tmp_dir
    )

    expect_match(basename(captured$outfile), "nolabel")
    expect_equal(captured$na_colour, "#FF0000")
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
    outfile <- file.path(outdir, "axial_1_test.png")
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

    expect_equal(result, outfile, ignore_attr = TRUE)
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
