.cap <- new.env()

describe("subcort_build_components", {
  it("builds components from colortable and meshes", {
    meshes_list <- list(
      "Left-Putamen" = list(
        vertices = list(x = 1:3, y = 1:3, z = 1:3),
        faces = list(i = 1, j = 2, k = 3)
      ),
      "Right-Putamen" = list(
        vertices = list(x = 4:6, y = 4:6, z = 4:6),
        faces = list(i = 1, j = 2, k = 3)
      )
    )
    colortable <- data.frame(
      idx = c(12, 51),
      label = c("Left-Putamen", "Right-Putamen"),
      color = c("#FF0000", "#00FF00"),
      stringsAsFactors = FALSE
    )

    result <- subcort_build_components(colortable, meshes_list)

    expect_type(result, "list")
    expect_true("core" %in% names(result))
    expect_true("palette" %in% names(result))
    expect_identical(nrow(result$core), 2L)
  })
})


describe("subcort_create_meshes", {
  it("errors when no meshes are created", {
    local_mocked_bindings(
      tessellate_label = function(...) NULL,
      progressor = function(...) function(...) NULL,
      center_meshes = function(x) x
    )

    colortable <- data.frame(
      idx = 10,
      label = "test",
      stringsAsFactors = FALSE
    )
    dirs <- list(meshes = withr::local_tempdir())

    expect_error(
      subcort_create_meshes(
        "fake.mgz",
        colortable,
        dirs,
        FALSE,
        FALSE
      ),
      "No meshes"
    )
  })

  it("warns and skips when tessellation fails with verbose", {
    local_mocked_bindings(
      tessellate_label = function(...) stop("mesh error"),
      progressor = function(...) function(...) NULL,
      future_map2 = mock_future_map2,
      furrr_options = function(...) list(),
      center_meshes = function(x) x
    )

    colortable <- data.frame(
      idx = c(10, 20),
      label = c("Left-Putamen", "Right-Putamen"),
      stringsAsFactors = FALSE
    )
    dirs <- list(meshes = withr::local_tempdir())

    expect_error(
      expect_warning(
        expect_warning(
          expect_messages(
            subcort_create_meshes("fake.mgz", colortable, dirs, FALSE, TRUE)
          ),
          "Failed to create mesh"
        ),
        "Failed to create mesh"
      ),
      "No meshes"
    )
  })

  it("returns meshes and logs success with verbose", {
    mock_mesh <- list(
      vertices = list(x = 1:3, y = 1:3, z = 1:3),
      faces = list(i = 1, j = 2, k = 3)
    )
    local_mocked_bindings(
      tessellate_label = function(...) mock_mesh,
      progressor = function(...) function(...) NULL,
      future_map2 = mock_future_map2,
      furrr_options = function(...) list(),
      center_meshes = function(x) x
    )

    colortable <- data.frame(
      idx = 10,
      label = "Left-Putamen",
      stringsAsFactors = FALSE
    )
    dirs <- list(meshes = withr::local_tempdir())

    result <- expect_messages(
      subcort_create_meshes(
        "fake.mgz",
        colortable,
        dirs,
        FALSE,
        TRUE,
        decimate = NULL
      )
    )

    expect_length(result, 1)
    expect_named(result, "Left-Putamen")
  })

  it("filters out NULL meshes from failed tessellations", {
    .cap$call_count <- 0L
    mock_mesh <- list(
      vertices = list(x = 1:3, y = 1:3, z = 1:3),
      faces = list(i = 1, j = 2, k = 3)
    )
    local_mocked_bindings(
      tessellate_label = function(...) {
        .cap$call_count <- .cap$call_count + 1L
        if (.cap$call_count == 1L) stop("fail") else mock_mesh
      },
      progressor = function(...) function(...) NULL,
      future_map2 = mock_future_map2,
      furrr_options = function(...) list(),
      center_meshes = function(x) x
    )

    colortable <- data.frame(
      idx = c(10, 20),
      label = c("Left-Putamen", "Right-Putamen"),
      stringsAsFactors = FALSE
    )
    dirs <- list(meshes = withr::local_tempdir())

    result <- subcort_create_meshes(
      "fake.mgz",
      colortable,
      dirs,
      FALSE,
      FALSE,
      decimate = NULL
    )

    expect_length(result, 1)
    expect_named(result, "Right-Putamen")
  })
})


describe("subcort_create_snapshots", {
  it("creates snapshots for structures and cortex slices", {
    .cap$snapshot_calls <- 0L
    .cap$cortex_calls <- 0L

    local_mocked_bindings(
      read_volume = function(f) {
        vol <- array(0L, dim = c(10, 10, 10))
        vol[2, 2, 2] <- 10L
        vol[5, 5, 5] <- 3L
        vol
      },
      default_subcortical_views = function(dims) {
        data.frame(
          name = "ax_1",
          type = "axial",
          start = 1,
          end = 10,
          stringsAsFactors = FALSE
        )
      },
      create_cortex_slices = function(views, dims) {
        data.frame(
          x = NA,
          y = NA,
          z = 5,
          view = "axial",
          name = "ax_1",
          stringsAsFactors = FALSE
        )
      },
      detect_cortex_labels = function(vol) {
        list(left = 3L, right = integer(0))
      },
      extract_hemi_from_view = function(...) "left",
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) {
        .cap$snapshot_calls <- .cap$snapshot_calls + 1L
        invisible(NULL)
      },
      snapshot_cortex_slice = function(...) {
        .cap$cortex_calls <- .cap$cortex_calls + 1L
        invisible(NULL)
      }
    )

    colortable <- data.frame(
      idx = 10,
      label = "Left-Putamen",
      stringsAsFactors = FALSE
    )
    dirs <- list(snapshots = withr::local_tempdir())

    result <- subcort_create_snapshots(
      "fake.mgz",
      colortable,
      NULL,
      dirs,
      FALSE
    )

    expect_type(result, "list")
    expect_true("views" %in% names(result))
    expect_true("cortex_slices" %in% names(result))
    # Both structures and the cortex outline now route through
    # snapshot_partial_projection for axial/coronal views (the cortex
    # outline must match the structures' slice-range projection so they
    # share the same brain extent). snapshot_cortex_slice is reserved for
    # sagittal cortex slices (hemisphere-specific, no slice range).
    expect_gt(.cap$snapshot_calls, 0)
    expect_identical(.cap$cortex_calls, 0L)
  })

  it("uses provided views instead of defaults", {
    custom_views <- data.frame(
      name = "custom_view",
      type = "coronal",
      start = 50,
      end = 60,
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      read_volume = function(f) {
        vol <- array(0L, dim = c(10, 10, 10))
        vol[2, 2, 2] <- 10L
        vol
      },
      create_cortex_slices = function(views, dims) {
        data.frame(
          x = NA,
          y = 5,
          z = NA,
          view = "coronal",
          name = "custom_view",
          stringsAsFactors = FALSE
        )
      },
      detect_cortex_labels = function(vol) {
        list(left = integer(0), right = integer(0))
      },
      extract_hemi_from_view = function(...) "left",
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      snapshot_cortex_slice = function(...) invisible(NULL)
    )

    colortable <- data.frame(
      idx = 10,
      label = "Left-Putamen",
      stringsAsFactors = FALSE
    )
    dirs <- list(snapshots = withr::local_tempdir())

    result <- subcort_create_snapshots(
      "fake.mgz",
      colortable,
      custom_views,
      dirs,
      FALSE
    )

    expect_identical(result$views$name, "custom_view")
    expect_identical(result$views$type, "coronal")
  })

  it("skips structures with zero voxels in volume", {
    .cap$snapshot_calls <- 0L

    local_mocked_bindings(
      read_volume = function(f) {
        vol <- array(0L, dim = c(10, 10, 10))
        vol
      },
      default_subcortical_views = function(dims) {
        data.frame(
          name = "ax_1",
          type = "axial",
          start = 1,
          end = 10,
          stringsAsFactors = FALSE
        )
      },
      create_cortex_slices = function(views, dims) {
        data.frame(
          x = NA,
          y = NA,
          z = 5,
          view = "axial",
          name = "ax_1",
          stringsAsFactors = FALSE
        )
      },
      detect_cortex_labels = function(vol) {
        list(left = integer(0), right = integer(0))
      },
      extract_hemi_from_view = function(...) "left",
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) {
        .cap$snapshot_calls <- .cap$snapshot_calls + 1L
        invisible(NULL)
      },
      snapshot_cortex_slice = function(...) invisible(NULL)
    )

    colortable <- data.frame(
      idx = 99,
      label = "Missing-Region",
      stringsAsFactors = FALSE
    )
    dirs <- list(snapshots = withr::local_tempdir())

    result <- subcort_create_snapshots(
      "fake.mgz",
      colortable,
      NULL,
      dirs,
      FALSE
    )

    expect_identical(.cap$snapshot_calls, 0L)
  })
})


describe("default_subcortical_views", {
  it("creates views for standard 256 brain", {
    dims <- c(256, 256, 256)
    result <- default_subcortical_views(dims)

    expect_s3_class(result, "data.frame")
    expect_true(all(c("name", "type", "start", "end") %in% names(result)))
    expect_true("axial" %in% result$type)
    expect_true("coronal" %in% result$type)
    expect_true("sagittal" %in% result$type)
  })

  it("scales views for different volume sizes", {
    dims_256 <- c(256, 256, 256)
    dims_512 <- c(512, 512, 512)

    result_256 <- default_subcortical_views(dims_256)
    result_512 <- default_subcortical_views(dims_512)

    axial_256 <- result_256[result_256$type == "axial", ]
    axial_512 <- result_512[result_512$type == "axial", ]

    expect_identical(axial_512$start[1] / axial_256$start[1], 2)
  })

  it("creates single sagittal midline slice", {
    dims <- c(256, 256, 256)
    result <- default_subcortical_views(dims)

    sagittal <- result[result$type == "sagittal", ]
    expect_identical(nrow(sagittal), 1L)
    expect_identical(sagittal$start, 128)
    expect_identical(sagittal$end, 128)
  })
})


# Orchestration helper tests ----

describe("validate_subcort_config", {
  it("returns a list with all expected fields", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = tempdir())

    result <- validate_subcort_config(
      input_volume = vol_file,
      input_lut = lut_file,
      atlas_name = "test_atlas",
      output_dir = NULL,
      verbose = FALSE,
      cleanup = FALSE,
      skip_existing = FALSE,
      decimate = 0.5,
      steps = NULL,
      tolerance = NULL,
      smoothness = NULL
    )

    expect_type(result, "list")
    expected_fields <- c(
      "input_volume",
      "input_lut",
      "atlas_name",
      "output_dir",
      "verbose",
      "cleanup",
      "skip_existing",
      "decimate",
      "steps",
      "tolerance",
      "smoothness"
    )
    expect_true(all(expected_fields %in% names(result)))
    expect_identical(result$atlas_name, "test_atlas")
    expect_identical(result$decimate, 0.5)
  })

  it("aborts for invalid decimate values", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    withr::local_options(ggseg.extra.output_dir = tempdir())

    for (val in list(-0.5, 0, 1, 1.5, "half", c(0.3, 0.5))) {
      expect_error(
        validate_subcort_config(
          input_volume = vol_file,
          input_lut = NULL,
          atlas_name = NULL,
          output_dir = NULL,
          verbose = FALSE,
          cleanup = FALSE,
          skip_existing = FALSE,
          decimate = val,
          steps = NULL,
          tolerance = NULL,
          smoothness = NULL
        ),
        "decimate"
      )
    }
  })

  it("defaults steps to 1:9 when NULL", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    withr::local_options(ggseg.extra.output_dir = tempdir())

    result <- validate_subcort_config(
      input_volume = vol_file,
      input_lut = NULL,
      atlas_name = NULL,
      output_dir = NULL,
      verbose = FALSE,
      cleanup = FALSE,
      skip_existing = FALSE,
      decimate = 0.5,
      steps = NULL,
      tolerance = NULL,
      smoothness = NULL
    )

    expect_identical(result$steps, 1L:9L)
  })

  it("accepts a data.frame as input_lut", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    withr::local_options(ggseg.extra.output_dir = tempdir())

    lut_df <- data.frame(
      idx = c(10, 20),
      region = c("Region A", "Region B"),
      hex = c("#FF0000", "#00FF00"),
      stringsAsFactors = FALSE
    )

    result <- validate_subcort_config(
      input_volume = vol_file,
      input_lut = lut_df,
      atlas_name = NULL,
      output_dir = NULL,
      verbose = FALSE,
      cleanup = FALSE,
      skip_existing = FALSE,
      decimate = 0.5,
      steps = NULL,
      tolerance = NULL,
      smoothness = NULL
    )

    expect_s3_class(result$input_lut, "data.frame")
    expect_identical(nrow(result$input_lut), 2L)
  })
})


describe("subcort_log_header", {
  it("prints volume path when verbose", {
    config <- list(
      verbose = TRUE,
      atlas_name = "test_atlas",
      input_volume = "/path/to/volume.mgz",
      input_lut = "/path/to/lut.txt",
      output_dir = "/tmp/output"
    )

    expect_messages(subcort_log_header(config), "volume.mgz")
  })

  it("is silent when verbose is FALSE", {
    config <- list(
      verbose = FALSE,
      atlas_name = "test_atlas",
      input_volume = "/path/to/volume.mgz",
      input_lut = NULL,
      output_dir = "/tmp/output"
    )

    expect_silent(subcort_log_header(config))
  })
})


describe("subcort_resolve_labels", {
  it("loads cached labels when skip_existing", {
    cached_ct <- data.frame(
      idx = 10,
      label = "cached_label",
      color = "#FF0000",
      stringsAsFactors = FALSE
    )
    cached_vol <- 10L

    local_mocked_bindings(
      load_or_run_step = function(step, steps, files, skip_existing, ...) {
        list(
          run = FALSE,
          data = list(
            "colortable.rds" = cached_ct,
            "vol_labels.rds" = cached_vol
          )
        )
      }
    )

    config <- list(
      steps = 1L:3L,
      skip_existing = TRUE,
      verbose = FALSE,
      input_volume = "fake.mgz",
      input_lut = "fake.txt"
    )
    dirs <- list(base = withr::local_tempdir())

    result <- subcort_resolve_labels(config, dirs)

    expect_identical(result$colortable, cached_ct)
    expect_identical(result$vol_labels, cached_vol)
  })

  it("warns when no LUT provided", {
    local_mocked_bindings(
      load_or_run_step = function(...) list(run = TRUE, data = list()),
      generate_colortable_from_volume = function(vol) {
        data.frame(
          idx = 10,
          label = "region_0010",
          color = NA_character_,
          stringsAsFactors = FALSE
        )
      },
      read_volume = function(f) {
        vol <- array(0L, dim = c(3, 3, 3))
        vol[1, 1, 1] <- 10L
        vol
      }
    )

    config <- list(
      steps = 1L:3L,
      skip_existing = FALSE,
      verbose = FALSE,
      input_volume = "fake.mgz",
      input_lut = NULL
    )
    dirs <- list(base = withr::local_tempdir())

    expect_warning(
      subcort_resolve_labels(config, dirs),
      "No color lookup table"
    )
  })
})


describe("subcort_resolve_meshes", {
  it("loads cached meshes when skip_existing", {
    cached_meshes <- list(
      "Left-Putamen" = list(
        vertices = list(x = 1:3, y = 1:3, z = 1:3),
        faces = list(i = 1, j = 2, k = 3)
      )
    )

    local_mocked_bindings(
      load_or_run_step = function(step, steps, files, skip_existing, ...) {
        list(
          run = FALSE,
          data = list("meshes_list.rds" = cached_meshes)
        )
      }
    )

    config <- list(
      steps = 1L:3L,
      skip_existing = TRUE,
      verbose = FALSE,
      input_volume = "fake.mgz",
      decimate = 0.5
    )
    dirs <- list(base = withr::local_tempdir())
    colortable <- data.frame(
      idx = 12,
      label = "Left-Putamen",
      stringsAsFactors = FALSE
    )

    result <- subcort_resolve_meshes(config, dirs, colortable)

    expect_identical(result, cached_meshes)
  })
})


describe("subcort_resolve_components", {
  it("loads cached components when skip_existing", {
    cached_components <- list(
      core = data.frame(
        hemi = "left",
        region = "Putamen",
        label = "Left-Putamen",
        stringsAsFactors = FALSE
      ),
      palette = c("Left-Putamen" = "#FF0000"),
      meshes_df = data.frame(stringsAsFactors = FALSE, label = "Left-Putamen")
    )

    local_mocked_bindings(
      load_or_run_step = function(step, steps, files, skip_existing, ...) {
        list(
          run = FALSE,
          data = list("components.rds" = cached_components)
        )
      }
    )

    config <- list(
      steps = 1L:9L,
      skip_existing = TRUE,
      verbose = FALSE
    )
    dirs <- list(base = withr::local_tempdir())
    colortable <- data.frame(
      idx = 12,
      label = "Left-Putamen",
      stringsAsFactors = FALSE
    )
    meshes_list <- list()

    result <- subcort_resolve_components(
      config,
      dirs,
      colortable,
      meshes_list
    )

    expect_identical(result, cached_components)
  })
})


describe("subcort_assemble_3d", {
  it("returns a ggseg_atlas", {
    mock_atlas <- structure(
      list(type = "subcortical"),
      class = "ggseg_atlas"
    )
    local_mocked_bindings(
      ggseg_atlas = function(...) mock_atlas,
      ggseg_data_subcortical = function(...) list(...)
    )

    components <- list(
      palette = c(region = "#FF0000"),
      core = data.frame(
        hemi = NA,
        region = "r",
        label = "region",
        stringsAsFactors = FALSE
      ),
      meshes_df = data.frame(stringsAsFactors = FALSE, label = "region")
    )

    result <- subcort_assemble_3d("test_atlas", components)

    expect_s3_class(result, "ggseg_atlas")
  })
})


describe("finalize_atlas (subcort parameters)", {
  it("cleanup deletes directory", {
    test_dir <- withr::local_tempdir()
    sub_dir <- file.path(test_dir, "atlas_work")
    dir.create(sub_dir)
    file.create(file.path(sub_dir, "temp.rds"))

    config <- list(
      cleanup = TRUE,
      verbose = FALSE,
      steps = 1L:3L
    )
    dirs <- list(base = sub_dir)

    finalize_atlas(
      NULL,
      config,
      dirs,
      Sys.time(),
      type_label = "Subcortical",
      unit = "structures",
      early_step = 3L
    )

    expect_false(dir.exists(sub_dir))
  })

  it("logs messages when verbose", {
    local_mocked_bindings(
      log_elapsed = function(...) invisible(NULL)
    )

    config <- list(
      cleanup = FALSE,
      verbose = TRUE,
      steps = 1L:3L
    )
    dirs <- list(base = withr::local_tempdir())
    mock_atlas <- structure(
      list(
        core = data.frame(
          stringsAsFactors = FALSE,
          hemi = NA,
          region = "r",
          label = "r"
        )
      ),
      class = "ggseg_atlas"
    )

    expect_messages(
      finalize_atlas(
        mock_atlas,
        config,
        dirs,
        Sys.time(),
        type_label = "Subcortical",
        unit = "structures",
        early_step = 3L
      ),
      "atlas created"
    )
  })

  it("returns invisible NULL when atlas is NULL", {
    local_mocked_bindings(
      log_elapsed = function(...) invisible(NULL)
    )

    config <- list(
      cleanup = FALSE,
      verbose = FALSE,
      steps = 5L:8L
    )
    dirs <- list(base = withr::local_tempdir())

    result <- finalize_atlas(
      NULL,
      config,
      dirs,
      Sys.time(),
      type_label = "Subcortical",
      unit = "structures",
      early_step = 3L
    )

    expect_null(result)
  })
})


describe("run_image_steps (subcort step_map)", {
  subcort_step_map <- list(process = 5L, extract = 6L, smooth = 7L, reduce = 8L)

  it("calls the right functions for the right steps", {
    .cap$step5_called <- FALSE
    .cap$step6_called <- FALSE
    .cap$step7_called <- FALSE
    .cap$step8_called <- FALSE

    local_mocked_bindings(
      process_and_mask_images = function(...) {
        .cap$step5_called <- TRUE
        invisible(NULL)
      },
      extract_contours = function(...) {
        .cap$step6_called <- TRUE
        invisible(NULL)
      },
      smooth_contours = function(...) {
        .cap$step7_called <- TRUE
        invisible(NULL)
      },
      reduce_vertex = function(...) {
        .cap$step8_called <- TRUE
        invisible(NULL)
      }
    )

    config <- list(
      steps = 5L:8L,
      verbose = FALSE,
      skip_existing = FALSE,
      smoothness = 3,
      tolerance = 0.5
    )
    dirs <- list(
      snapshots = withr::local_tempdir(),
      processed = withr::local_tempdir(),
      masks = withr::local_tempdir(),
      base = withr::local_tempdir()
    )

    run_image_steps(config, dirs, subcort_step_map, 9L)

    expect_true(.cap$step5_called)
    expect_true(.cap$step6_called)
    expect_true(.cap$step7_called)
    expect_true(.cap$step8_called)
  })

  it("skips steps not in config$steps", {
    .cap$step5_called <- FALSE
    .cap$step6_called <- FALSE
    .cap$step7_called <- FALSE
    .cap$step8_called <- FALSE

    local_mocked_bindings(
      process_and_mask_images = function(...) {
        .cap$step5_called <- TRUE
        invisible(NULL)
      },
      extract_contours = function(...) {
        .cap$step6_called <- TRUE
        invisible(NULL)
      },
      smooth_contours = function(...) {
        .cap$step7_called <- TRUE
        invisible(NULL)
      },
      reduce_vertex = function(...) {
        .cap$step8_called <- TRUE
        invisible(NULL)
      }
    )

    config <- list(
      steps = c(6L, 8L),
      verbose = FALSE,
      skip_existing = FALSE,
      smoothness = 3,
      tolerance = 0.5
    )
    dirs <- list(
      snapshots = withr::local_tempdir(),
      processed = withr::local_tempdir(),
      masks = withr::local_tempdir(),
      base = withr::local_tempdir()
    )

    run_image_steps(config, dirs, subcort_step_map, 9L)

    expect_false(.cap$step5_called)
    expect_true(.cap$step6_called)
    expect_false(.cap$step7_called)
    expect_true(.cap$step8_called)
  })
})


describe("subcort_create_meshes", {
  it("logs decimation stats when verbose and decimate < 1", {
    mock_mesh <- list(
      vertices = data.frame(x = 1:10, y = 1:10, z = 1:10),
      faces = data.frame(i = 1:5, j = 2:6, k = 3:7)
    )
    local_mocked_bindings(
      tessellate_label = function(...) mock_mesh,
      progressor = function(...) function(...) NULL,
      future_map2 = mock_future_map2,
      furrr_options = function(...) list(),
      center_meshes = function(x) x,
      decimate_mesh = function(mesh, ...) {
        list(
          vertices = data.frame(x = 1:8, y = 1:8, z = 1:8),
          faces = data.frame(i = 1:3, j = 2:4, k = 3:5)
        )
      }
    )

    colortable <- data.frame(
      idx = 10,
      label = "Left-Putamen",
      stringsAsFactors = FALSE
    )
    dirs <- list(meshes = withr::local_tempdir())

    expect_messages(
      subcort_create_meshes(
        "fake.mgz",
        colortable,
        dirs,
        skip_existing = FALSE,
        verbose = TRUE,
        decimate = 0.5
      ),
      "Decimating"
    )
  })
})
