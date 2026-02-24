describe("create_tract_from_tractography", {
  it("creates atlas from coordinate matrices", {
    tracts <- list(
      cst_left = matrix(c(1:20, rep(0, 40)), ncol = 3),
      cst_right = matrix(c(1:20, rep(1, 40)), ncol = 3)
    )

    atlas <- create_tract_from_tractography(
      input_tracts = tracts,
      steps = 1,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_equal(atlas$type, "tract")
    expect_false(is.null(atlas$data$centerlines))
    expect_equal(nrow(atlas$data$centerlines), 2)
  })

  it("assigns correct labels", {
    tracts <- list(
      cst_left = matrix(c(1:20, rep(0, 40)), ncol = 3),
      cst_right = matrix(c(1:20, rep(1, 40)), ncol = 3)
    )

    atlas <- create_tract_from_tractography(
      input_tracts = tracts,
      steps = 1,
      verbose = FALSE
    )

    expect_true("cst_left" %in% atlas$core$label)
    expect_true("cst_right" %in% atlas$core$label)
  })

  it("accepts custom names and colours via input_lut", {
    tracts <- list(
      matrix(c(1:20, rep(0, 40)), ncol = 3),
      matrix(c(1:20, rep(1, 40)), ncol = 3)
    )

    custom_lut <- data.frame(
      region = c("Tract A", "Tract B"),
      hex = c("#FF0000", "#00FF00")
    )

    atlas <- create_tract_from_tractography(
      input_tracts = tracts,
      input_lut = custom_lut,
      steps = 1,
      verbose = FALSE
    )

    expect_true("Tract_A" %in% atlas$core$label)
    expect_true("Tract_B" %in% atlas$core$label)
    expect_true("#FF0000" %in% atlas$palette)
    expect_true("#00FF00" %in% atlas$palette)
  })

  it("creates valid centerline structure for each tract", {
    tracts <- list(
      tract1 = matrix(c(1:20, rep(0, 40)), ncol = 3)
    )

    atlas <- create_tract_from_tractography(
      input_tracts = tracts,
      steps = 1,
      verbose = FALSE
    )

    expect_true(all(c("label", "points") %in% names(atlas$data$centerlines)))
    points <- atlas$data$centerlines$points[[1]]
    expect_true(all(c("x", "y", "z") %in% colnames(points)))
  })

  it("tube params are not stored on data object", {
    tract <- list(
      tract1 = matrix(c(1:10, rep(0, 20)), ncol = 3)
    )

    atlas <- create_tract_from_tractography(
      tract,
      tube_radius = 3.5,
      tube_segments = 12,
      steps = 1,
      verbose = FALSE
    )

    expect_null(atlas$data$tube_radius)
    expect_null(atlas$data$tube_segments)
  })

  it("can render with ggseg3d", {
    tracts <- list(
      cst_left = matrix(c(1:20, rep(0, 40)), ncol = 3),
      cst_right = matrix(c(1:20, rep(1, 40)), ncol = 3)
    )

    atlas <- create_tract_from_tractography(
      input_tracts = tracts,
      steps = 1,
      verbose = FALSE
    )

    expect_no_error({
      p <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = "subcort")
    })
  })
})


describe("create_tract_from_tractography pipeline flow", {
  it("passes correct args to tract_read_input and tract_create_meshes", {
    captured_read_args <- NULL
    captured_mesh_args <- NULL
    dirs <- mock_dirs()
    local_mocked_bindings(
      tract_read_input = function(input_tracts, tract_names) {
        captured_read_args <<- list(
          input_tracts = input_tracts, tract_names = tract_names
        )
        list(
          streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
          tract_names = "t1"
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      tract_create_meshes = function(...) {
        captured_mesh_args <<- list(...)
        list(t1 = list(metadata = list(
          centerline = matrix(
            1:9, ncol = 3, dimnames = list(NULL, c("x", "y", "z"))
          ),
          tangents = matrix(1:9, ncol = 3)
        )))
      },
      tract_build_core = function(...) {
        list(
          core = data.frame(
            hemi = "midline", region = "t1", label = "t1",
            stringsAsFactors = FALSE
          ),
          palette = c(t1 = "#FF0000"),
          centerlines_df = data.frame(label = "t1"),
          atlas_name = "t1"
        )
      },
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_tract = function(...) list(...),
      preview_atlas = function(...) invisible(NULL),
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())
    input <- list(t1 = matrix(1:30, ncol = 3))

    atlas <- create_tract_from_tractography(
      input_tracts = input,
      steps = 1,
      verbose = FALSE
    )

    expect_identical(captured_read_args$input_tracts, input)
    expect_false(is.null(captured_mesh_args))
  })

  it("errors when input_aseg is NULL for steps beyond 1", {
    dirs <- mock_dirs()
    cached <- list(
      streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
      centerlines_df = data.frame(label = "t1"),
      core = data.frame(
        hemi = "midline", region = "t1", label = "t1",
        stringsAsFactors = FALSE
      ),
      palette = c(t1 = "#FF0000"),
      atlas_name = "t1",
      tube_radius = 5,
      tube_segments = 8
    )

    local_mocked_bindings(
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        if (step == 1L) {
          list(run = FALSE, data = list("step1_data.rds" = cached))
        } else {
          list(run = step %in% steps, data = list())
        }
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_error(
      create_tract_from_tractography(
        input_tracts = list(t1 = matrix(1:30, ncol = 3)),
        input_aseg = NULL,
        steps = 2,
        verbose = FALSE
      ),
      "input_aseg.*required"
    )
  })

  it("reads LUT colours from RGB columns", {
    tracts <- list(
      matrix(c(1:20, rep(0, 40)), ncol = 3)
    )

    custom_lut <- data.frame(
      region = "Tract A",
      R = 255,
      G = 0,
      B = 128
    )

    atlas <- create_tract_from_tractography(
      input_tracts = tracts,
      input_lut = custom_lut,
      steps = 1,
      verbose = FALSE
    )

    expect_true(!is.na(atlas$palette[1]))
  })

  it("handles LUT without colour columns", {
    tracts <- list(
      matrix(c(1:20, rep(0, 40)), ncol = 3)
    )

    custom_lut <- data.frame(
      region = "Tract A"
    )

    atlas <- create_tract_from_tractography(
      input_tracts = tracts,
      input_lut = custom_lut,
      steps = 1,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_true("Tract_A" %in% atlas$core$label)
  })

  it("loads cached data for skipped steps and proceeds", {
    dirs <- mock_dirs()
    cached <- list(
      streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
      centerlines_df = data.frame(label = "t1"),
      core = data.frame(
        hemi = "midline", region = "t1", label = "t1",
        stringsAsFactors = FALSE
      ),
      palette = c(t1 = "#FF0000"),
      atlas_name = "t1",
      tube_radius = 5,
      tube_segments = 8
    )

    local_mocked_bindings(
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        if (step == 1L) {
          list(run = FALSE, data = list("step1_data.rds" = cached))
        } else if (step == 2L) {
          list(run = FALSE, data = list(
            "views.rds" = data.frame(
              name = "ax_1", type = "axial", start = 1, end = 10
            ),
            "cortex_slices.rds" = NULL
          ))
        } else {
          list(run = step %in% steps, data = list())
        }
      },
      process_and_mask_images = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL)
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())
    tract_file <- withr::local_tempfile(fileext = ".trk")
    file.create(tract_file)
    aseg_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(aseg_file)

    result <- create_tract_from_tractography(
      input_tracts = tract_file,
      input_aseg = aseg_file,
      steps = 3:6,
      verbose = TRUE
    )

    expect_null(result)
  })

  it("step 1 returns 3D-only atlas with verbose and cleanup", {
    dirs <- mock_dirs()
    tract_file <- withr::local_tempfile(fileext = ".trk")
    file.create(tract_file)

    local_mocked_bindings(
      tract_read_input = function(input_tracts, tract_names) {
        list(
          streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
          tract_names = "t1"
        )
      },
      detect_coords_are_voxels = function(...) TRUE,
      tract_create_meshes = function(...) {
        list(t1 = list(metadata = list(
          centerline = matrix(
            1:9, ncol = 3, dimnames = list(NULL, c("x", "y", "z"))
          ),
          tangents = matrix(1:9, ncol = 3)
        )))
      },
      tract_build_core = function(...) {
        list(
          core = data.frame(
            hemi = "midline", region = "t1", label = "t1",
            stringsAsFactors = FALSE
          ),
          palette = c(t1 = "#FF0000"),
          centerlines_df = data.frame(label = "t1"),
          atlas_name = "t1"
        )
      },
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_tract = function(...) list(...),
      preview_atlas = function(...) invisible(NULL),
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    atlas <- create_tract_from_tractography(
      input_tracts = tract_file,
      steps = 1,
      verbose = TRUE,
      cleanup = TRUE
    )

    expect_s3_class(atlas, "ggseg_atlas")
  })

  it("step 7 builds final atlas with cleanup", {
    dirs <- mock_dirs()
    tract_file <- withr::local_tempfile(fileext = ".trk")
    file.create(tract_file)

    cached <- list(
      streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
      centerlines_df = data.frame(label = "t1"),
      core = data.frame(
        hemi = "midline", region = "t1", label = "t1",
        stringsAsFactors = FALSE
      ),
      palette = c(t1 = "#FF0000"),
      atlas_name = "t1",
      tube_radius = 5,
      tube_segments = 8
    )

    contours_file <- file.path(dirs$base, "contours_reduced.rda")
    file.create(contours_file)

    local_mocked_bindings(
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        if (step == 1L) {
          list(run = FALSE, data = list("step1_data.rds" = cached))
        } else if (step == 2L) {
          list(run = FALSE, data = list(
            "views.rds" = data.frame(
              name = "ax_1", type = "axial", start = 1, end = 10
            ),
            "cortex_slices.rds" = NULL
          ))
        } else {
          list(run = step %in% steps, data = list())
        }
      },
      build_contour_sf = function(...) "mock_sf_data",
      ggseg_atlas = function(...) {
        args <- list(...)
        structure(
          list(
            core = args$core, palette = args$palette,
            type = args$type, data = args$data
          ),
          class = "ggseg_atlas"
        )
      },
      ggseg_data_tract = function(...) list(...),
      warn_if_large_atlas = function(...) invisible(NULL),
      preview_atlas = function(...) invisible(NULL)
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())
    aseg_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(aseg_file)

    atlas <- create_tract_from_tractography(
      input_tracts = tract_file,
      input_aseg = aseg_file,
      steps = 7,
      verbose = TRUE,
      cleanup = TRUE
    )

    expect_s3_class(atlas, "ggseg_atlas")
  })

  it("step 7 errors when contours_reduced.rda missing", {
    dirs <- mock_dirs()
    cached <- list(
      streamlines_data = list(t1 = matrix(1:30, ncol = 3)),
      centerlines_df = data.frame(label = "t1"),
      core = data.frame(
        hemi = "midline", region = "t1", label = "t1",
        stringsAsFactors = FALSE
      ),
      palette = c(t1 = "#FF0000"),
      atlas_name = "t1",
      tube_radius = 5,
      tube_segments = 8
    )

    local_mocked_bindings(
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        if (step == 1L) {
          list(run = FALSE, data = list("step1_data.rds" = cached))
        } else if (step == 2L) {
          list(run = FALSE, data = list(
            "views.rds" = data.frame(
              name = "ax_1", type = "axial", start = 1, end = 10
            ),
            "cortex_slices.rds" = NULL
          ))
        } else {
          list(run = step %in% steps, data = list())
        }
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())
    aseg_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(aseg_file)

    expect_error(
      create_tract_from_tractography(
        input_tracts = list(t1 = matrix(1:30, ncol = 3)),
        input_aseg = aseg_file,
        steps = 7,
        verbose = FALSE
      ),
      "contours_reduced"
    )
  })
})


describe("extract_centerline", {
  it("returns NULL when all resampled streamlines are invalid", {
    bad_streamlines <- list(
      matrix(c(0, 0, 0), nrow = 1, ncol = 3),
      matrix(c(1, 1, 1), nrow = 1, ncol = 3)
    )

    result <- extract_centerline(
      bad_streamlines, method = "mean", n_points = 50
    )
    expect_null(result)
  })

  it("returns NULL for empty list input", {
    result <- extract_centerline(list(), method = "mean", n_points = 50)
    expect_null(result)
  })
})


describe("tract_resolve_snapshots early-return NULL", {
  it("returns NULL views and cortex_slices when step skipped", {
    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(
          run = FALSE,
          data = list("views.rds" = NULL, "cortex_slices.rds" = NULL)
        )
      }
    )

    config <- list(steps = 1L, verbose = FALSE)
    dirs <- list(base = withr::local_tempdir())

    result <- tract_resolve_snapshots(
      config, dirs,
      step1 = list(), input_aseg = NULL, views = "axial"
    )
    expect_null(result$views)
    expect_null(result$cortex_slices)
  })
})
