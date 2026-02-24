describe("tessellate_label", {
  it("creates mesh from volume label", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")

    vol <- read_volume(vol_file)
    labels <- unique(c(vol))
    labels <- labels[labels != 0]
    skip_if(length(labels) == 0, "No labels in test volume")

    output_dir <- tempdir()
    mesh <- tessellate_label(
      volume_file = vol_file,
      label_id = labels[1],
      output_dir = output_dir,
      verbose = FALSE
    )

    expect_true(is.list(mesh))
    expect_true(all(c("vertices", "faces") %in% names(mesh)))
    expect_true(nrow(mesh$vertices) > 0)
    expect_true(nrow(mesh$faces) > 0)
  })
})


describe("decimate_mesh", {
  it("reduces face count by specified percent", {
    mesh <- list(
      vertices = data.frame(
        x = c(0, 1, 0, 0, 1, 1, 0, 1),
        y = c(0, 0, 1, 0, 1, 0, 1, 1),
        z = c(0, 0, 0, 1, 0, 1, 1, 1)
      ),
      faces = data.frame(
        i = c(1, 1, 1, 2, 2, 3, 3, 5, 4, 4, 6, 7),
        j = c(2, 3, 4, 5, 6, 5, 7, 7, 6, 7, 8, 8),
        k = c(3, 4, 2, 3, 4, 7, 4, 8, 8, 8, 5, 6)
      )
    )

    result <- decimate_mesh(mesh, percent = 0.5)

    expect_true(nrow(result$faces) <= nrow(mesh$faces))
    expect_true(nrow(result$vertices) <= nrow(mesh$vertices))
  })

  it("returns correct data.frame structure", {
    mesh <- list(
      vertices = data.frame(
        x = c(0, 1, 0, 0, 1, 1, 0, 1),
        y = c(0, 0, 1, 0, 1, 0, 1, 1),
        z = c(0, 0, 0, 1, 0, 1, 1, 1)
      ),
      faces = data.frame(
        i = c(1, 1, 1, 2, 2, 3, 3, 5, 4, 4, 6, 7),
        j = c(2, 3, 4, 5, 6, 5, 7, 7, 6, 7, 8, 8),
        k = c(3, 4, 2, 3, 4, 7, 4, 8, 8, 8, 5, 6)
      )
    )

    result <- decimate_mesh(mesh, percent = 0.75)

    expect_named(result$vertices, c("x", "y", "z"))
    expect_named(result$faces, c("i", "j", "k"))
    expect_true(all(result$faces$i >= 1))
    expect_true(all(result$faces$j >= 1))
    expect_true(all(result$faces$k >= 1))
    expect_true(max(result$faces$i) <= nrow(result$vertices))
    expect_true(max(result$faces$j) <= nrow(result$vertices))
    expect_true(max(result$faces$k) <= nrow(result$vertices))
  })

  it("works on real aseg meshes", {
    skip_if_not_installed("Rvcg")

    mesh <- aseg()$data$meshes$mesh[[1]]

    result <- decimate_mesh(mesh, percent = 0.5)

    expect_true(nrow(result$faces) < nrow(mesh$faces))
    expect_true(nrow(result$vertices) < nrow(mesh$vertices))
  })
})


describe("generate_colortable_from_volume", {
  it("creates color table with correct structure", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")

    result <- generate_colortable_from_volume(vol_file)

    expect_s3_class(result, "data.frame")
    expect_true(all(
      c("idx", "label", "R", "G", "B", "A", "roi", "color") %in%
        names(result)
    ))
    expect_true(nrow(result) > 0)
    expect_true(all(result$idx > 0))
    expect_true(all(grepl("^region_", result$label)))
  })

  it("generates colortable from mocked volume", {
    local_mocked_bindings(
      read_volume = function(f) {
        vol <- array(0L, dim = c(3, 3, 3))
        vol[1, 1, 1] <- 10L
        vol[2, 2, 2] <- 20L
        vol
      }
    )

    result <- generate_colortable_from_volume("fake_file.mgz")

    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 2)
    expect_equal(result$idx, c(10, 20))
    expect_equal(result$label, c("region_0010", "region_0020"))
    expect_true(all(is.na(result$color)))
  })
})


describe("tessellate_label", {
  it("returns cached result when smooth file exists", {
    tmp_dir <- withr::local_tempdir()
    smooth_file <- file.path(tmp_dir, "0010_smooth")

    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      read_fs_surface = function(f, verbose = 0L) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 1, j = 2, k = 3)
        )
      }
    )
    writeLines("placeholder", smooth_file)

    result <- tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = TRUE)
    expect_true(is.list(result))
    expect_true("vertices" %in% names(result))
  })

  it("runs full pipeline when no cached files", {
    tmp_dir <- withr::local_tempdir()

    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_pretess.mgz"))
      },
      mri_tessellate = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_tess"))
      },
      mri_smooth = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_smooth"))
      },
      read_fs_surface = function(f, verbose = 0L) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 1, j = 2, k = 3)
        )
      }
    )

    result <- tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = FALSE)
    expect_true("vertices" %in% names(result))
  })

  it("errors when pretess fails", {
    tmp_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) NULL
    )

    expect_error(
      tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = FALSE),
      "Pre-tessellation failed"
    )
  })

  it("errors when tessellation fails", {
    tmp_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_pretess.mgz"))
      },
      mri_tessellate = function(...) NULL
    )

    expect_error(
      tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = FALSE),
      "Tessellation failed"
    )
  })

  it("errors when smoothing fails", {
    tmp_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_pretess.mgz"))
      },
      mri_tessellate = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_tess"))
      },
      mri_smooth = function(...) NULL
    )

    expect_error(
      tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = FALSE),
      "Smoothing failed"
    )
  })
})


describe("read_fs_surface", {
  it("uses surf2asc and read_dpv when available", {
    local_mocked_bindings(
      surf2asc = function(file, dpv_file, ...) NULL,
      read_dpv = function(f) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 0:2, j = 1:3, k = 2:4)
        )
      },
      get_verbose = function() FALSE
    )

    result <- read_fs_surface("test_surface")
    expect_equal(result$vertices$x, 1:3)
    expect_equal(result$faces$i, 1:3)
  })

  it("falls back to freesurferformats when surf2asc fails", {
    local_mocked_bindings(
      surf2asc = function(...) stop("conversion failed"),
      read_dpv = function(...) stop("no file"),
      get_verbose = function() FALSE
    )

    local_mocked_bindings(
      read.fs.surface = function(file) {
        list(
          vertices = matrix(c(1, 2, 3, 4, 5, 6, 7, 8, 9), ncol = 3),
          faces = matrix(c(1, 2, 3), ncol = 3)
        )
      },
      .package = "freesurferformats"
    )

    result <- read_fs_surface("test_surface")
    expect_equal(result$vertices$x, c(1, 2, 3))
    expect_equal(result$faces$i, 1)
  })

  it("errors when surf2asc fails and freesurferformats unavailable", {
    local_mocked_bindings(
      surf2asc = function(...) stop("conversion failed"),
      read_dpv = function(...) stop("no file"),
      get_verbose = function() FALSE
    )

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

    expect_error(
      read_fs_surface("test_surface"),
      "Failed to read surface file"
    )
  })
})


describe("generate_colortable_from_volume", {
  it("generates colortable from volume labels", {
    local_mocked_bindings(
      read_volume = function(f, ...) {
        vol <- array(0L, dim = c(5, 5, 5))
        vol[1:2, , ] <- 10L
        vol[3:4, , ] <- 20L
        vol
      }
    )

    result <- generate_colortable_from_volume("test.mgz")
    expect_s3_class(result, "data.frame")
    expect_equal(result$idx, c(10, 20))
    expect_equal(result$label, c("region_0010", "region_0020"))
    expect_true(all(is.na(result$R)))
  })
})


describe("create_subcortical_geometry_projection", {
  it("runs the full pipeline with default views and cortex slices", {
    tmp_dir <- withr::local_tempdir()

    fake_vol <- array(0L, dim = c(10, 10, 10))
    fake_vol[2:3, 2:3, 2:3] <- 5L
    fake_vol[5:6, 5:6, 5:6] <- 10L
    fake_vol[8:9, 8:9, 8:9] <- 3L

    fake_colortable <- data.frame(
      idx = c(5L, 10L),
      label = c("region_0005", "region_0010"),
      stringsAsFactors = FALSE
    )

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sfc <- sf::st_sfc(fake_geom, fake_geom)
    fake_sf <- sf::st_sf(
      filenm = c("axial_region_0005.png", "coronal_cortex_cortex.png"),
      geometry = fake_sfc
    )
    fake_sf$view <- c("axial", "coronal")

    local_mocked_bindings(
      is_verbose = function(...) TRUE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      mkdir = function(...) invisible(NULL),
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    result <- create_subcortical_geometry_projection(
      input_volume = "fake_aseg.mgz",
      colortable = fake_colortable,
      verbose = TRUE
    )

    expect_s3_class(result, "sf")
    expect_true("label" %in% names(result))
    expect_true("view" %in% names(result))
    expect_true("geometry" %in% names(result))
  })

  it("uses provided views and cortex_slices", {
    tmp_dir <- withr::local_tempdir()

    fake_vol <- array(0L, dim = c(10, 10, 10))
    fake_vol[2:3, 2:3, 2:3] <- 5L

    fake_colortable <- data.frame(
      idx = 5L,
      label = "region_0005",
      stringsAsFactors = FALSE
    )

    custom_views <- data.frame(
      name = "myview",
      type = "coronal",
      start = 1,
      end = 10,
      stringsAsFactors = FALSE
    )

    custom_cortex <- data.frame(
      x = NA,
      y = 5,
      z = NA,
      view = "coronal",
      name = "myview",
      stringsAsFactors = FALSE
    )

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "myview_region_0005.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "myview"

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      mkdir = function(...) invisible(NULL),
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    result <- create_subcortical_geometry_projection(
      input_volume = "fake.mgz",
      colortable = fake_colortable,
      views = custom_views,
      cortex_slices = custom_cortex
    )

    expect_s3_class(result, "sf")
    expect_true(all(result$view == "myview"))
  })

  it("cleans up when cleanup is TRUE", {
    tmp_dir <- withr::local_tempdir()

    fake_vol <- array(0L, dim = c(10, 10, 10))
    fake_vol[2, 2, 2] <- 5L

    fake_colortable <- data.frame(
      idx = 5L,
      label = "region_0005",
      stringsAsFactors = FALSE
    )

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_region_0005.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial"

    unlink_called_with <- NULL

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) TRUE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      mkdir = function(...) invisible(NULL),
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    result <- create_subcortical_geometry_projection(
      input_volume = "fake.mgz",
      colortable = fake_colortable
    )

    expect_s3_class(result, "sf")
  })

  it("extracts label from filename with NA view", {
    tmp_dir <- withr::local_tempdir()

    fake_vol <- array(0L, dim = c(10, 10, 10))
    fake_vol[2, 2, 2] <- 5L

    fake_colortable <- data.frame(
      idx = 5L,
      label = "region_0005",
      stringsAsFactors = FALSE
    )

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

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      mkdir = function(...) invisible(NULL),
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    custom_views <- data.frame(
      name = "special",
      type = "coronal",
      start = 1,
      end = 10,
      stringsAsFactors = FALSE
    )
    custom_cortex <- data.frame(
      x = NA,
      y = 5,
      z = NA,
      view = "coronal",
      name = "special",
      stringsAsFactors = FALSE
    )

    result <- create_subcortical_geometry_projection(
      input_volume = "fake.mgz",
      colortable = fake_colortable,
      views = custom_views,
      cortex_slices = custom_cortex
    )

    expect_equal(result$label, "unknown_thing")
  })

  it("handles structures with zero voxels in future_pmap callback", {
    tmp_dir <- withr::local_tempdir()

    fake_vol <- array(0L, dim = c(10, 10, 10))
    fake_vol[2, 2, 2] <- 5L

    fake_colortable <- data.frame(
      idx = c(5L, 99L),
      label = c("region_0005", "region_0099"),
      stringsAsFactors = FALSE
    )

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_region_0005.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial"

    snap_called <- 0L
    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      mkdir = function(...) invisible(NULL),
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) {
        snap_called <<- snap_called + 1L
        invisible(NULL)
      },
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(...) invisible(NULL),
      extract_alpha_mask = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    custom_views <- data.frame(
      name = "axial",
      type = "axial",
      start = 1,
      end = 10,
      stringsAsFactors = FALSE
    )
    custom_cortex <- data.frame(
      x = NA,
      y = NA,
      z = 5,
      view = "axial",
      name = "axial",
      stringsAsFactors = FALSE
    )

    result <- create_subcortical_geometry_projection(
      input_volume = "fake.mgz",
      colortable = fake_colortable,
      views = custom_views,
      cortex_slices = custom_cortex
    )

    expect_s3_class(result, "sf")
  })
})


describe("create_subcortical_geometry_projection image processing loop", {
  it("calls process_snapshot_image and extract_alpha_mask for each file", {
    tmp_dir <- withr::local_tempdir()

    fake_vol <- array(0L, dim = c(10, 10, 10))
    fake_vol[2:3, 2:3, 2:3] <- 5L

    fake_colortable <- data.frame(
      idx = 5L,
      label = "region_0005",
      stringsAsFactors = FALSE
    )

    snap_dir <- file.path(tmp_dir, "subcort_proj_geom", "snapshots")
    proc_dir <- file.path(tmp_dir, "subcort_proj_geom", "processed")

    process_files <- character(0)
    mask_files <- character(0)

    fake_geom <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
    )))
    fake_sf <- sf::st_sf(
      filenm = "axial_region_0005.png",
      geometry = sf::st_sfc(fake_geom)
    )
    fake_sf$view <- "axial"

    local_mocked_bindings(
      is_verbose = function(...) FALSE,
      get_cleanup = function(...) FALSE,
      get_skip_existing = function(...) FALSE,
      get_tolerance = function(...) 0.01,
      get_smoothness = function(...) 1,
      get_output_dir = function(...) tmp_dir,
      mkdir = function(d) {
        dir.create(d, recursive = TRUE, showWarnings = FALSE)
        invisible(NULL)
      },
      read_volume = function(f, ...) fake_vol,
      detect_cortex_labels = function(vol) list(left = 3L, right = 42L),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function( # nolint: line_length_linter.
        ..., output_dir, label, view_name
      ) {
        f <- file.path(output_dir, paste0(view_name, "_", label, ".png"))
        file.create(f)
        invisible(NULL)
      },
      snapshot_cortex_slice = function(...) invisible(NULL),
      process_snapshot_image = function(input_file, output_file, ...) {
        process_files <<- c(process_files, basename(input_file))
        file.create(output_file)
        invisible(NULL)
      },
      extract_alpha_mask = function(input, output, ...) {
        mask_files <<- c(mask_files, basename(input))
        invisible(NULL)
      },
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL),
      make_multipolygon = function(...) fake_sf,
      layout_volumetric_views = function(df) df
    )

    custom_views <- data.frame(
      name = "axial",
      type = "axial",
      start = 1,
      end = 10,
      stringsAsFactors = FALSE
    )
    custom_cortex <- data.frame(
      x = NA, y = NA, z = 5,
      view = "axial", name = "axial",
      stringsAsFactors = FALSE
    )

    result <- create_subcortical_geometry_projection(
      input_volume = "fake.mgz",
      colortable = fake_colortable,
      views = custom_views,
      cortex_slices = custom_cortex
    )

    expect_true(length(process_files) > 0)
    expect_true(length(mask_files) > 0)
    expect_s3_class(result, "sf")
  })
})
