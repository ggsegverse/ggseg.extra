describe("tract_read_input", {
  it("reads from named list", {
    tracts <- list(
      cst = matrix(1:9, ncol = 3),
      af = matrix(10:18, ncol = 3)
    )

    result <- tract_read_input(tracts, NULL)

    expect_equal(result$tract_names, c("cst", "af"))
    expect_equal(length(result$streamlines_data), 2)
  })

  it("generates default names for unnamed list", {
    tracts <- list(
      matrix(1:9, ncol = 3),
      matrix(10:18, ncol = 3)
    )

    result <- tract_read_input(tracts, NULL)

    expect_equal(result$tract_names, c("tract_1", "tract_2"))
  })

  it("errors when files not found", {
    expect_error(
      tract_read_input(c("nonexistent.trk"), NULL),
      "not found"
    )
  })

  it("errors when no data provided", {
    expect_error(
      tract_read_input(list(), NULL),
      "No tract data"
    )
  })
})


describe("tract_build_core", {
  it("builds core, palette, and centerlines", {
    meshes_list <- list(
      cst_left = list(
        metadata = list(
          centerline = matrix(
            1:9,
            ncol = 3,
            dimnames = list(NULL, c("x", "y", "z"))
          ),
          tangents = matrix(1:9, ncol = 3)
        )
      ),
      cst_right = list(
        metadata = list(
          centerline = matrix(
            10:18,
            ncol = 3,
            dimnames = list(NULL, c("x", "y", "z"))
          ),
          tangents = matrix(10:18, ncol = 3)
        )
      )
    )
    colours <- c(cst_left = "#FF0000", cst_right = "#00FF00")

    result <- tract_build_core(
      meshes_list,
      colours,
      c("cst_left", "cst_right")
    )

    expect_equal(nrow(result$core), 2)
    expect_equal(length(result$palette), 2)
    expect_equal(nrow(result$centerlines_df), 2)
    expect_equal(result$atlas_name, "tracts")
  })

  it("uses single tract name as atlas_name", {
    meshes_list <- list(
      cst = list(
        metadata = list(
          centerline = matrix(
            1:9,
            ncol = 3,
            dimnames = list(NULL, c("x", "y", "z"))
          ),
          tangents = matrix(1:9, ncol = 3)
        )
      )
    )

    result <- tract_build_core(meshes_list, c(cst = "#FF0000"), "cst")

    expect_equal(result$atlas_name, "cst")
  })
})


describe("tract_read_input file path branch", {
  it("reads from file paths and derives names from filenames", {
    local_mocked_bindings(
      read_tractography = function(f) list(matrix(1:9, ncol = 3)),
      future_map = function(.x, .f, ...) lapply(.x, .f)
    )

    tract_file <- withr::local_tempfile(fileext = ".trk")
    file.create(tract_file)

    result <- tract_read_input(tract_file, NULL)

    expect_equal(length(result$streamlines_data), 1)
    expect_equal(
      result$tract_names,
      tools::file_path_sans_ext(basename(tract_file))
    )
  })

  it("uses provided tract_names for files", {
    local_mocked_bindings(
      read_tractography = function(f) list(matrix(1:9, ncol = 3)),
      future_map = function(.x, .f, ...) lapply(.x, .f)
    )

    tract_file <- withr::local_tempfile(fileext = ".trk")
    file.create(tract_file)

    result <- tract_read_input(tract_file, "custom_name")

    expect_equal(result$tract_names, "custom_name")
  })
})


describe("tract_create_meshes", {
  it("creates meshes and filters out NULL results", {
    call_count <- 0L
    local_mocked_bindings(
      progressor = function(...) function(...) NULL,
      future_map2 = mock_future_map2,
      furrr_options = function(...) list(),
      extract_centerline = function(streamlines, ...) {
        matrix(1:9, ncol = 3, dimnames = list(NULL, c("x", "y", "z")))
      },
      resolve_tube_radius = function(...) rep(1, 3),
      generate_tube_mesh = function(...) {
        call_count <<- call_count + 1L
        if (call_count == 1L) {
          list(
            vertices = list(x = 1:3, y = 1:3, z = 1:3),
            faces = list(i = 1, j = 2, k = 3)
          )
        } else {
          NULL
        }
      },
      center_meshes = function(x) x
    )

    streamlines_data <- list(
      t1 = list(matrix(1:9, ncol = 3)),
      t2 = list(matrix(10:18, ncol = 3))
    )

    result <- tract_create_meshes(
      streamlines_data,
      c("t1", "t2"),
      "mean",
      50,
      5,
      8,
      c(0.2, 1.0)
    )

    expect_equal(length(result), 1)
    expect_equal(names(result), "t1")
  })

  it("skips tracts with NULL or too-short centerlines", {
    local_mocked_bindings(
      progressor = function(...) function(...) NULL,
      future_map2 = mock_future_map2,
      furrr_options = function(...) list(),
      extract_centerline = function(streamlines, ...) NULL,
      center_meshes = function(x) x
    )

    streamlines_data <- list(t1 = list(matrix(1:9, ncol = 3)))

    expect_error(
      tract_create_meshes(
        streamlines_data,
        "t1",
        "mean",
        50,
        5,
        8,
        c(0.2, 1.0)
      ),
      "No meshes"
    )
  })

  it("errors when all meshes fail", {
    local_mocked_bindings(
      progressor = function(...) function(...) NULL,
      future_map2 = mock_future_map2,
      furrr_options = function(...) list(),
      extract_centerline = function(streamlines, ...) {
        matrix(1:6, ncol = 3, dimnames = list(NULL, c("x", "y", "z")))
      },
      resolve_tube_radius = function(...) rep(1, 2),
      generate_tube_mesh = function(...) NULL,
      center_meshes = function(x) x
    )

    streamlines_data <- list(t1 = list(matrix(1:9, ncol = 3)))

    expect_error(
      tract_create_meshes(
        streamlines_data,
        "t1",
        "mean",
        50,
        5,
        8,
        c(0.2, 1.0)
      ),
      "No meshes"
    )
  })
})


describe("tract_create_snapshots", {
  it("creates snapshots for tracts and cortex slices", {
    snapshot_calls <- 0L
    cortex_calls <- 0L

    local_mocked_bindings(
      read_volume = function(f) {
        vol <- array(0L, dim = c(10, 10, 10))
        vol[3, 3, 3] <- 3L
        vol
      },
      default_tract_views = function(dims) {
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
      detect_cortex_labels = function(vol) list(left = 3L, right = integer(0)),
      extract_hemi_from_view = function(...) "left",
      extract_centerline = function(streamlines, ...) {
        matrix(1:9, ncol = 3, dimnames = list(NULL, c("x", "y", "z")))
      },
      streamlines_to_volume = function(...) array(1L, dim = c(10, 10, 10)),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) {
        snapshot_calls <<- snapshot_calls + 1L
        invisible(NULL)
      },
      snapshot_cortex_slice = function(...) {
        cortex_calls <<- cortex_calls + 1L
        invisible(NULL)
      }
    )

    centerlines_df <- data.frame(label = "t1", stringsAsFactors = FALSE)
    streamlines_data <- list(t1 = list(matrix(1:9, ncol = 3)))
    dirs <- list(snapshots = withr::local_tempdir())

    result <- tract_create_snapshots(
      streamlines_data,
      centerlines_df,
      "fake_aseg.mgz",
      NULL,
      dirs,
      TRUE,
      FALSE,
      3,
      TRUE
    )

    expect_true(is.list(result))
    expect_true("views" %in% names(result))
    expect_true("cortex_slices" %in% names(result))
    expect_true(snapshot_calls > 0)
    expect_true(cortex_calls > 0)
  })

  it("uses provided views instead of defaults", {
    custom_views <- data.frame(
      name = "cor_1",
      type = "coronal",
      start = 50,
      end = 60,
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      read_volume = function(f) array(0L, dim = c(10, 10, 10)),
      create_cortex_slices = function(views, dims) {
        data.frame(
          x = NA,
          y = 5,
          z = NA,
          view = "coronal",
          name = "cor_1",
          stringsAsFactors = FALSE
        )
      },
      detect_cortex_labels = function(vol) {
        list(left = integer(0), right = integer(0))
      },
      extract_hemi_from_view = function(...) "left",
      extract_centerline = function(streamlines, ...) {
        matrix(1:9, ncol = 3, dimnames = list(NULL, c("x", "y", "z")))
      },
      streamlines_to_volume = function(...) array(0L, dim = c(10, 10, 10)),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      snapshot_cortex_slice = function(...) invisible(NULL)
    )

    centerlines_df <- data.frame(label = "t1", stringsAsFactors = FALSE)
    streamlines_data <- list(t1 = list(matrix(1:9, ncol = 3)))
    dirs <- list(snapshots = withr::local_tempdir())

    result <- tract_create_snapshots(
      streamlines_data,
      centerlines_df,
      "fake_aseg.mgz",
      custom_views,
      dirs,
      TRUE,
      FALSE,
      3,
      FALSE
    )

    expect_equal(result$views$name, "cor_1")
    expect_equal(result$views$type, "coronal")
  })

  it("handles streamlines as list of lists", {
    local_mocked_bindings(
      read_volume = function(f) array(0L, dim = c(10, 10, 10)),
      default_tract_views = function(dims) {
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
      extract_centerline = function(streamlines, ...) {
        matrix(1:9, ncol = 3, dimnames = list(NULL, c("x", "y", "z")))
      },
      streamlines_to_volume = function(...) array(0L, dim = c(10, 10, 10)),
      progressor = function(...) function(...) NULL,
      future_pmap = mock_future_pmap,
      furrr_options = function(...) list(),
      snapshot_partial_projection = function(...) invisible(NULL),
      snapshot_cortex_slice = function(...) invisible(NULL)
    )

    centerlines_df <- data.frame(label = "t1", stringsAsFactors = FALSE)
    streamlines_data <- list(
      t1 = list(matrix(1:9, ncol = 3), matrix(10:18, ncol = 3))
    )
    dirs <- list(snapshots = withr::local_tempdir())

    result <- tract_create_snapshots(
      streamlines_data,
      centerlines_df,
      "fake_aseg.mgz",
      NULL,
      dirs,
      TRUE,
      FALSE,
      3,
      FALSE
    )

    expect_true(is.list(result))
  })
})


describe("resolve_tube_radius", {
  it("returns uniform radius when given scalar", {
    centerline <- matrix(c(1:10, rep(0, 20)), ncol = 3)
    streamlines <- list(centerline)

    result <- resolve_tube_radius(0.5, streamlines, centerline, c(0.2, 1.0))

    expect_length(result, 10)
    expect_true(all(result == 0.5))
  })

  it("returns input when given vector of correct length", {
    centerline <- matrix(c(1:5, rep(0, 10)), ncol = 3)
    streamlines <- list(centerline)
    radii <- c(0.1, 0.2, 0.3, 0.4, 0.5)

    result <- resolve_tube_radius(radii, streamlines, centerline, c(0.2, 1.0))

    expect_equal(result, radii)
  })

  it("errors when vector has wrong length", {
    centerline <- matrix(c(1:10, rep(0, 20)), ncol = 3)
    streamlines <- list(centerline)

    expect_error(
      resolve_tube_radius(c(0.1, 0.2), streamlines, centerline, c(0.2, 1.0)),
      "length 1 or 10"
    )
  })

  it("computes density-based radius", {
    centerline <- matrix(c(1:5, rep(0, 10)), ncol = 3)
    streamlines <- list(
      matrix(c(1:5, rep(0, 10)), ncol = 3),
      matrix(c(1:5, rep(0.5, 10)), ncol = 3)
    )

    result <- resolve_tube_radius(
      "density",
      streamlines,
      centerline,
      c(0.2, 1.0)
    )

    expect_length(result, 5)
    expect_true(all(result >= 0.2))
    expect_true(all(result <= 1.0))
  })

  it("returns mean density_range when all density is zero", {
    centerline <- matrix(c(1:5, rep(0, 10)), ncol = 3)
    streamlines <- list(
      matrix(c(100:104, rep(100, 10)), ncol = 3)
    )

    result <- resolve_tube_radius(
      "density",
      streamlines,
      centerline,
      c(0.2, 1.0)
    )

    expect_length(result, 5)
    expect_true(all(result == 0.6))
  })

  it("errors for unknown string", {
    centerline <- matrix(c(1:5, rep(0, 10)), ncol = 3)
    streamlines <- list(centerline)

    expect_error(
      resolve_tube_radius("unknown", streamlines, centerline, c(0.2, 1.0)),
      "must be numeric"
    )
  })
})


describe("default_tract_views", {
  it("creates views for standard 256 brain", {
    dims <- c(256, 256, 256)
    result <- default_tract_views(dims)

    expect_s3_class(result, "data.frame")
    expect_true(all(c("name", "type", "start", "end") %in% names(result)))
    expect_true("axial" %in% result$type)
    expect_true("coronal" %in% result$type)
    expect_true("sagittal" %in% result$type)
  })

  it("creates wider projections than subcortical", {
    dims <- c(256, 256, 256)
    tract_views <- default_tract_views(dims)
    subcort_views <- default_subcortical_views(dims)

    tract_axial <- tract_views[tract_views$type == "axial", ]
    subcort_axial <- subcort_views[subcort_views$type == "axial", ]

    tract_range <- max(tract_axial$end) - min(tract_axial$start)
    subcort_range <- max(subcort_axial$end) - min(subcort_axial$start)

    expect_gt(tract_range, subcort_range)
  })

  it("creates midline, left, and right sagittal projections", {
    dims <- c(256, 256, 256)
    result <- default_tract_views(dims)

    sagittal <- result[result$type == "sagittal", ]
    expect_equal(nrow(sagittal), 3)
    expect_true(any(grepl("midline", sagittal$name)))
    expect_true(any(grepl("left", sagittal$name)))
    expect_true(any(grepl("right", sagittal$name)))
  })

  it("sagittal projections are lateralised around midline", {
    dims <- c(256, 256, 256)
    result <- default_tract_views(dims)

    sagittal <- result[result$type == "sagittal", ]
    left <- sagittal[grepl("left", sagittal$name), ]
    right <- sagittal[grepl("right", sagittal$name), ]
    midline <- sagittal[grepl("midline", sagittal$name), ]

    expect_gt(left$start, midline$end)
    expect_lt(right$end, midline$start)
  })

  it("scales for different volume sizes", {
    dims_256 <- c(256, 256, 256)
    dims_128 <- c(128, 128, 128)

    result_256 <- default_tract_views(dims_256)
    result_128 <- default_tract_views(dims_128)

    axial_256 <- result_256[result_256$type == "axial", ]
    axial_128 <- result_128[result_128$type == "axial", ]

    expect_equal(axial_128$start[1] / axial_256$start[1], 0.5)
  })
})


describe("validate_tract_config", {
  it("returns list with all expected fields", {
    withr::local_options(ggseg.extra.output_dir = tempdir())

    result <- validate_tract_config(
      output_dir = NULL, verbose = FALSE, cleanup = FALSE,
      skip_existing = FALSE, tolerance = NULL, smoothness = NULL,
      steps = NULL, centerline_method = "mean",
      tube_radius = 5, tube_segments = 8, n_points = 50
    )

    expected_fields <- c(
      "output_dir", "verbose", "cleanup", "skip_existing",
      "tolerance", "smoothness", "steps", "centerline_method",
      "tube_radius", "tube_segments", "n_points",
      "density_radius_range", "tract_radius"
    )
    expect_true(all(expected_fields %in% names(result)))
    expect_true(is.list(result))
  })

  it("defaults steps to 1:7", {
    withr::local_options(ggseg.extra.output_dir = tempdir())

    result <- validate_tract_config(
      output_dir = NULL, verbose = FALSE, cleanup = FALSE,
      skip_existing = FALSE, tolerance = NULL, smoothness = NULL,
      steps = NULL, centerline_method = "mean",
      tube_radius = 5, tube_segments = 8, n_points = 50
    )

    expect_equal(result$steps, 1L:7L)
  })

  it("validates centerline_method via match.arg", {
    withr::local_options(ggseg.extra.output_dir = tempdir())

    expect_no_error(
      validate_tract_config(
        output_dir = NULL, verbose = FALSE, cleanup = FALSE,
        skip_existing = FALSE, tolerance = NULL, smoothness = NULL,
        steps = NULL, centerline_method = "medoid",
        tube_radius = 5, tube_segments = 8, n_points = 50
      )
    )

    expect_error(
      validate_tract_config(
        output_dir = NULL, verbose = FALSE, cleanup = FALSE,
        skip_existing = FALSE, tolerance = NULL, smoothness = NULL,
        steps = NULL, centerline_method = "invalid",
        tube_radius = 5, tube_segments = 8, n_points = 50
      ),
      "arg"
    )
  })

  it("sets density_radius_range and tract_radius defaults", {
    withr::local_options(ggseg.extra.output_dir = tempdir())

    result <- validate_tract_config(
      output_dir = NULL, verbose = FALSE, cleanup = FALSE,
      skip_existing = FALSE, tolerance = NULL, smoothness = NULL,
      steps = NULL, centerline_method = "mean",
      tube_radius = 5, tube_segments = 8, n_points = 50
    )

    expect_equal(result$density_radius_range, c(0.2, 1.0))
    expect_equal(result$tract_radius, 3)
  })
})


describe("tract_log_header", {
  it("prints info when verbose", {
    config <- list(verbose = TRUE)

    expect_message(
      tract_log_header(config, "tract.trk", "aseg.mgz"),
      "tractography"
    )
  })

  it("is silent when verbose is FALSE", {
    config <- list(verbose = FALSE)

    expect_silent(
      tract_log_header(config, "tract.trk", "aseg.mgz")
    )
  })
})


describe("tract_resolve_step1", {
  it("returns cached data when skip_existing", {
    test_dir <- withr::local_tempdir()
    cached_step1 <- list(
      streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
      centerlines_df = data.frame(label = "t1"),
      core = data.frame(
        hemi = "midline", region = "t1", label = "t1",
        stringsAsFactors = FALSE
      ),
      palette = c(t1 = "#FF0000"),
      atlas_name = "t1",
      tube_radius = 5,
      tube_segments = 8,
      coords_are_voxels = TRUE
    )

    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(run = FALSE, data = list("step1_data.rds" = cached_step1))
      }
    )

    config <- list(
      steps = 2L:7L, skip_existing = TRUE, verbose = FALSE,
      centerline_method = "mean", n_points = 50,
      tube_radius = 5, tube_segments = 8,
      density_radius_range = c(0.2, 1.0)
    )
    dirs <- list(
      base = test_dir, snapshots = test_dir,
      processed = test_dir, masks = test_dir
    )

    result <- tract_resolve_step1(config, dirs, list(), NULL, NULL)

    expect_equal(result$atlas_name, "t1")
    expect_equal(result$tube_radius, 5)
    expect_true(result$coords_are_voxels)
  })

  it("returns structure with expected fields when run", {
    test_dir <- withr::local_tempdir()

    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(run = TRUE, data = list())
      },
      tract_read_input = function(input_tracts, tract_names) {
        list(
          streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
          tract_names = "t1"
        )
      },
      detect_coords_are_voxels = function(...) FALSE,
      tract_create_meshes = function(...) {
        list(
          t1 = list(
            metadata = list(
              centerline = matrix(
                1:9, ncol = 3,
                dimnames = list(NULL, c("x", "y", "z"))
              ),
              tangents = matrix(1:9, ncol = 3)
            )
          )
        )
      },
      tract_build_core = function(...) {
        list(
          core = data.frame(
            hemi = "midline", region = "t1", label = "t1",
            stringsAsFactors = FALSE
          ),
          palette = NULL,
          centerlines_df = data.frame(label = "t1"),
          atlas_name = "t1"
        )
      }
    )

    config <- list(
      steps = 1L:7L, skip_existing = FALSE, verbose = FALSE,
      centerline_method = "mean", n_points = 50,
      tube_radius = 5, tube_segments = 8,
      density_radius_range = c(0.2, 1.0)
    )
    dirs <- list(
      base = test_dir, snapshots = test_dir,
      processed = test_dir, masks = test_dir
    )

    result <- tract_resolve_step1(
      config, dirs, list(t1 = matrix(1:30, ncol = 3)), NULL, NULL
    )

    expected_fields <- c(
      "streamlines_data", "centerlines_df", "core", "palette",
      "atlas_name", "tube_radius", "tube_segments", "coords_are_voxels"
    )
    expect_true(all(expected_fields %in% names(result)))
  })
})


describe("detect_tract_coord_space", {
  it("detects voxel coordinates", {
    local_mocked_bindings(
      detect_coords_are_voxels = function(...) TRUE
    )

    streamlines_data <- list(t1 = list(matrix(1:9, ncol = 3)))

    result <- detect_tract_coord_space(streamlines_data, FALSE)

    expect_true(result)
  })

  it("detects RAS coordinates", {
    local_mocked_bindings(
      detect_coords_are_voxels = function(...) FALSE
    )

    streamlines_data <- list(t1 = list(matrix(1:9, ncol = 3)))

    result <- detect_tract_coord_space(streamlines_data, FALSE)

    expect_false(result)
  })
})


describe("tract_check_aseg", {
  it("aborts when aseg is NULL and steps include 2-7", {
    expect_error(
      tract_check_aseg(NULL, 2L:7L),
      "input_aseg.*required"
    )
  })

  it("passes when aseg is provided", {
    expect_no_error(
      tract_check_aseg("some_aseg.mgz", 2L:7L)
    )
  })

  it("passes when only step 1", {
    expect_no_error(
      tract_check_aseg(NULL, 1L)
    )
  })
})


describe("tract_resolve_snapshots", {
  it("returns cached data when not running", {
    test_dir <- withr::local_tempdir()
    cached_views <- data.frame(
      name = "ax_1", type = "axial", start = 1, end = 10,
      stringsAsFactors = FALSE
    )
    cached_cortex <- data.frame(
      x = NA, y = NA, z = 5, view = "axial", name = "ax_1",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(
          run = FALSE,
          data = list(
            "views.rds" = cached_views,
            "cortex_slices.rds" = cached_cortex
          )
        )
      }
    )

    config <- list(
      steps = 3L:7L, skip_existing = TRUE, verbose = FALSE,
      tract_radius = 3
    )
    dirs <- list(base = test_dir, snapshots = test_dir)
    step1 <- list(
      streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
      centerlines_df = data.frame(label = "t1"),
      coords_are_voxels = TRUE
    )

    result <- tract_resolve_snapshots(config, dirs, step1, "aseg.mgz", NULL)

    expect_equal(result$views$name, "ax_1")
    expect_equal(result$cortex_slices$name, "ax_1")
  })

  it("returns expected structure when run", {
    test_dir <- withr::local_tempdir()

    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(run = TRUE, data = list())
      },
      tract_create_snapshots = function(...) {
        list(
          views = data.frame(
            name = "ax_1", type = "axial", start = 1, end = 10,
            stringsAsFactors = FALSE
          ),
          cortex_slices = data.frame(
            x = NA, y = NA, z = 5, view = "axial", name = "ax_1",
            stringsAsFactors = FALSE
          )
        )
      }
    )

    config <- list(
      steps = 2L:7L, skip_existing = FALSE, verbose = FALSE,
      tract_radius = 3
    )
    dirs <- list(base = test_dir, snapshots = test_dir)
    step1 <- list(
      streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
      centerlines_df = data.frame(label = "t1"),
      coords_are_voxels = TRUE
    )

    result <- tract_resolve_snapshots(
      config, dirs, step1, "aseg.mgz", NULL
    )

    expect_true("views" %in% names(result))
    expect_true("cortex_slices" %in% names(result))
    expect_equal(result$views$type, "axial")
  })
})


describe("run_image_steps (tract step_map)", {
  tract_step_map <- list(process = 3L, extract = 4L, smooth = 5L, reduce = 6L)

  it("calls process_and_mask_images for step 3", {
    process_called <- FALSE
    local_mocked_bindings(
      process_and_mask_images = function(...) {
        process_called <<- TRUE
        invisible(NULL)
      }
    )

    config <- list(steps = 3L, verbose = FALSE, skip_existing = FALSE)
    dirs <- list(snapshots = "s", processed = "p", masks = "m", base = "b")

    run_image_steps(config, dirs, tract_step_map, 7L)

    expect_true(process_called)
  })

  it("calls extract_contours for step 4", {
    extract_called <- FALSE
    local_mocked_bindings(
      extract_contours = function(...) {
        extract_called <<- TRUE
        invisible(NULL)
      }
    )

    config <- list(steps = 4L, verbose = FALSE)
    dirs <- list(snapshots = "s", processed = "p", masks = "m", base = "b")

    run_image_steps(config, dirs, tract_step_map, 7L)

    expect_true(extract_called)
  })

  it("calls smooth_contours for step 5", {
    smooth_called <- FALSE
    local_mocked_bindings(
      smooth_contours = function(...) {
        smooth_called <<- TRUE
        invisible(NULL)
      }
    )

    config <- list(steps = 5L, verbose = FALSE, smoothness = 1.0)
    dirs <- list(snapshots = "s", processed = "p", masks = "m", base = "b")

    run_image_steps(config, dirs, tract_step_map, 7L)

    expect_true(smooth_called)
  })

  it("calls reduce_vertex for step 6", {
    reduce_called <- FALSE
    local_mocked_bindings(
      reduce_vertex = function(...) {
        reduce_called <<- TRUE
        invisible(NULL)
      }
    )

    config <- list(steps = 6L, verbose = FALSE, tolerance = 0.01)
    dirs <- list(snapshots = "s", processed = "p", masks = "m", base = "b")

    run_image_steps(config, dirs, tract_step_map, 7L)

    expect_true(reduce_called)
  })

  it("calls all functions for steps 3-6", {
    calls <- character()
    local_mocked_bindings(
      process_and_mask_images = function(...) {
        calls <<- c(calls, "process")
        invisible(NULL)
      },
      extract_contours = function(...) {
        calls <<- c(calls, "extract")
        invisible(NULL)
      },
      smooth_contours = function(...) {
        calls <<- c(calls, "smooth")
        invisible(NULL)
      },
      reduce_vertex = function(...) {
        calls <<- c(calls, "reduce")
        invisible(NULL)
      }
    )

    config <- list(
      steps = 3L:6L, verbose = FALSE,
      skip_existing = FALSE, smoothness = 1.0, tolerance = 0.01
    )
    dirs <- list(snapshots = "s", processed = "p", masks = "m", base = "b")

    run_image_steps(config, dirs, tract_step_map, 7L)

    expect_equal(calls, c("process", "extract", "smooth", "reduce"))
  })
})


describe("tract_assemble_3d", {
  it("returns ggseg_atlas", {
    local_mocked_bindings(
      ggseg_atlas = function(...) {
        args <- list(...)
        structure(
          list(
            type = args$type,
            core = args$core,
            palette = args$palette,
            data = args$data
          ),
          class = "ggseg_atlas"
        )
      },
      ggseg_data_tract = function(...) list(...)
    )

    step1 <- list(
      atlas_name = "test_tract",
      core = data.frame(
        hemi = "midline", region = "t1", label = "t1",
        stringsAsFactors = FALSE
      ),
      palette = c(t1 = "#FF0000"),
      centerlines_df = data.frame(label = "t1"),
      tube_radius = 5,
      tube_segments = 8
    )

    result <- tract_assemble_3d(step1)

    expect_s3_class(result, "ggseg_atlas")
    expect_equal(result$type, "tract")
  })
})


describe("tract_assemble_full", {
  it("errors when contours_reduced.rda missing", {
    test_dir <- withr::local_tempdir()
    dirs <- list(base = test_dir)
    step1 <- list(
      atlas_name = "t1",
      core = data.frame(
        hemi = "midline", region = "t1", label = "t1",
        stringsAsFactors = FALSE
      ),
      palette = c(t1 = "#FF0000"),
      centerlines_df = data.frame(label = "t1"),
      tube_radius = 5,
      tube_segments = 8
    )

    expect_error(
      tract_assemble_full(step1, dirs, NULL, NULL),
      "contours_reduced"
    )
  })
})


describe("finalize_atlas (tract parameters)", {
  it("deletes dir when cleanup is TRUE", {
    test_dir <- withr::local_tempdir()
    sub_dir <- file.path(test_dir, "atlas_work")
    dir.create(sub_dir)
    file.create(file.path(sub_dir, "temp.rds"))

    config <- list(verbose = FALSE, cleanup = TRUE, steps = 1L)
    dirs <- list(base = sub_dir)

    finalize_atlas(
      NULL, config, dirs, Sys.time(),
      type_label = "Tract", unit = "tracts", early_step = 1L
    )

    expect_false(dir.exists(sub_dir))
  })

  it("logs when verbose is TRUE", {
    test_dir <- withr::local_tempdir()
    config <- list(verbose = TRUE, cleanup = FALSE, steps = 3L:5L)
    dirs <- list(base = test_dir)

    local_mocked_bindings(
      log_elapsed = function(...) invisible(NULL)
    )

    expect_message(
      finalize_atlas(
        NULL, config, dirs, Sys.time(),
        type_label = "Tract", unit = "tracts", early_step = 1L
      ),
      "Completed steps"
    )
  })

  it("returns invisible NULL when atlas is NULL", {
    test_dir <- withr::local_tempdir()
    config <- list(verbose = FALSE, cleanup = FALSE, steps = 3L:5L)
    dirs <- list(base = test_dir)

    result <- finalize_atlas(
      NULL, config, dirs, Sys.time(),
      type_label = "Tract", unit = "tracts", early_step = 1L
    )

    expect_null(result)
  })

  it("returns atlas when atlas is not NULL", {
    test_dir <- withr::local_tempdir()
    mock_atlas <- structure(
      list(
        core = data.frame(
          hemi = "midline", region = "t1", label = "t1",
          stringsAsFactors = FALSE
        )
      ),
      class = "ggseg_atlas"
    )
    config <- list(verbose = FALSE, cleanup = FALSE, steps = 1L)
    dirs <- list(base = test_dir)

    result <- finalize_atlas(
      mock_atlas, config, dirs, Sys.time(),
      type_label = "Tract", unit = "tracts", early_step = 1L
    )

    expect_s3_class(result, "ggseg_atlas")
  })
})
