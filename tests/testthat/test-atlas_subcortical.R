.cap <- new.env()

describe("create_subcortical_from_volume decimate validation", {
  it("errors for values outside (0, 1)", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)

    for (val in list(-0.5, 0, 1, 1.5, 2)) {
      expect_error(
        create_subcortical_from_volume(
          vol_file,
          decimate = val,
          verbose = FALSE
        ),
        "decimate.*must be a single number between 0 and 1"
      )
    }
  })

  it("errors for non-numeric values", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)

    expect_error(
      create_subcortical_from_volume(
        vol_file,
        decimate = "half",
        verbose = FALSE
      ),
      "decimate.*must be a single number"
    )
  })

  it("errors for vectors of length > 1", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)

    expect_error(
      create_subcortical_from_volume(
        vol_file,
        decimate = c(0.3, 0.5),
        verbose = FALSE
      ),
      "decimate.*must be a single number"
    )
  })

  it("accepts NULL to skip decimation", {
    local_mocked_bindings(check_fs = function(...) TRUE)

    expect_error(
      create_subcortical_from_volume(
        "/nonexistent/volume.mgz",
        decimate = NULL,
        verbose = FALSE
      ),
      "not found"
    )
  })

  it("accepts valid values in (0, 1)", {
    local_mocked_bindings(check_fs = function(...) TRUE)

    for (val in c(0.1, 0.25, 0.5, 0.75, 0.99)) {
      expect_error(
        create_subcortical_from_volume(
          "/nonexistent/volume.mgz",
          decimate = val,
          verbose = FALSE
        ),
        "not found"
      )
    }
  })
})


describe("create_subcortical_from_volume", {
  it("requires FreeSurfer to be available", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) {
        if (abort) {
          cli::cli_abort("FreeSurfer not found")
        }
        FALSE
      }
    )

    expect_error(
      create_subcortical_from_volume(
        input_volume = "test.mgz",
        verbose = FALSE
      ),
      "FreeSurfer"
    )
  })

  it("warns about deprecated views argument and delegates to slabs", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) {
        if (abort) {
          cli::cli_abort("FreeSurfer not found")
        }
        FALSE
      }
    )

    lifecycle::expect_deprecated(
      expect_error(
        create_subcortical_from_volume(
          input_volume = "test.mgz",
          views = data.frame(
            name = "v",
            type = "coronal",
            start = 1L,
            end = 2L
          ),
          verbose = FALSE
        ),
        "FreeSurfer"
      )
    )
  })

  it("errors when volume file not found", {
    skip_if_no_freesurfer()

    expect_error(
      create_subcortical_from_volume(
        input_volume = "nonexistent_file.mgz",
        verbose = FALSE
      ),
      "not found"
    )
  })

  it("errors when specified color table not found", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")

    expect_error(
      create_subcortical_from_volume(
        input_volume = vol_file,
        input_lut = "nonexistent_lut.txt",
        verbose = FALSE
      ),
      "not found"
    )
  })

  it("generates colortable when input_lut is NULL", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")

    expect_warnings(
      {
        atlas <- create_subcortical_from_volume(
          input_volume = vol_file,
          input_lut = NULL,
          steps = 1:3,
          verbose = FALSE
        )
      },
      "No color lookup table"
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_gt(nrow(atlas$core), 0)
    expect_true(all(grepl("^region_", atlas$core$label)))
    expect_false(is.null(atlas$palette))
    expect_true(all(grepl("^#", atlas$palette)))
  })
})


describe("create_subcortical_from_volume with meshes", {
  skip_if_no_freesurfer()

  vol_file <- test_mgz_file()
  skip_if(!file.exists(vol_file), "Test volume file not found")

  lut_file <- test_lut_file()
  skip_if(!file.exists(lut_file), "Test LUT file not found")

  atlas <- suppressWarnings(create_subcortical_from_volume(
    input_volume = vol_file,
    input_lut = lut_file,
    steps = 1:3,
    verbose = FALSE
  ))

  it("creates atlas with meshes component", {
    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(atlas$type, "subcortical")
    expect_false(is.null(atlas$data$meshes))
    expect_true("mesh" %in% names(atlas$data$meshes))
  })

  it("creates valid mesh structure", {
    for (i in seq_len(nrow(atlas$data$meshes))) {
      mesh <- atlas$data$meshes$mesh[[i]]
      if (!is.null(mesh)) {
        expect_true(all(c("vertices", "faces") %in% names(mesh)))
        expect_true(all(c("x", "y", "z") %in% names(mesh$vertices)))
        expect_true(all(c("i", "j", "k") %in% names(mesh$faces)))
      }
    }
  })

  it("assigns correct hemisphere", {
    left_labels <- atlas$core$label[grepl("Left|left|lh", atlas$core$label)]
    right_labels <- atlas$core$label[grepl("Right|right|rh", atlas$core$label)]

    left_hemis <- atlas$core$hemi[atlas$core$label %in% left_labels]
    right_hemis <- atlas$core$hemi[atlas$core$label %in% right_labels]

    if (length(left_hemis) > 0) {
      expect_true(all(left_hemis == "left" | is.na(left_hemis)))
    }
    if (length(right_hemis) > 0) {
      expect_true(all(right_hemis == "right" | is.na(right_hemis)))
    }
  })

  it("can render with ggseg3d", {
    skip_render_on_windows()
    expect_no_error({
      p <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = "subcort")
    })
  })
})


describe("create_subcortical_from_volume pipeline flow", {
  it("passes correct volume path to generate_colortable_from_volume", {
    .cap$captured_gen_args <- NULL
    dirs <- mock_subcort_dirs()
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      generate_colortable_from_volume = function(vol) {
        .cap$captured_gen_args <- list(vol = vol)
        data.frame(
          idx = 10,
          label = "test_region",
          color = NA_character_,
          stringsAsFactors = FALSE
        )
      },
      read_volume = function(f) {
        vol <- array(0L, dim = c(3, 3, 3))
        vol[1, 1, 1] <- 10L
        vol
      },
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      },
      subcort_create_meshes = function(...) {
        list(
          test_region = list(
            vertices = list(x = 1, y = 1, z = 1),
            faces = list(i = 1, j = 1, k = 1)
          )
        )
      },
      subcort_build_components = function(...) {
        list(
          core = data.frame(
            hemi = NA,
            region = "test",
            label = "test_region",
            stringsAsFactors = FALSE
          ),
          palette = c(test_region = "#E78AC3"),
          meshes_df = data.frame(
            stringsAsFactors = FALSE,
            label = "test_region"
          )
        )
      },
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_subcortical = function(...) list(...)
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)

    expect_warning(
      {
        atlas <- create_subcortical_from_volume(
          input_volume = vol_file,
          input_lut = NULL,
          steps = 1:3,
          verbose = FALSE
        )
      },
      "No color lookup table"
    )

    expect_identical(.cap$captured_gen_args$vol, vol_file)
    expect_false(is.null(atlas$palette))
  })

  it("returns 3D-only atlas with correct structure count", {
    dirs <- mock_subcort_dirs()
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      get_lut = function(f) {
        data.frame(
          idx = c(10, 20),
          label = c("region_a", "region_b"),
          color = c("#FF0000", "#00FF00"),
          stringsAsFactors = FALSE
        )
      },
      read_volume = function(f) {
        vol <- array(0L, dim = c(3, 3, 3))
        vol[1, 1, 1] <- 10L
        vol[2, 2, 2] <- 20L
        vol
      },
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      },
      subcort_create_meshes = function(...) {
        list(
          region_a = list(
            vertices = list(x = 1, y = 1, z = 1),
            faces = list(i = 1, j = 1, k = 1)
          ),
          region_b = list(
            vertices = list(x = 2, y = 2, z = 2),
            faces = list(i = 1, j = 1, k = 1)
          )
        )
      },
      subcort_build_components = function(...) {
        list(
          core = data.frame(
            hemi = NA,
            region = c("a", "b"),
            label = c("region_a", "region_b"),
            stringsAsFactors = FALSE
          ),
          palette = c(region_a = "#FF0000", region_b = "#00FF00"),
          meshes_df = data.frame(
            stringsAsFactors = FALSE,
            label = c("region_a", "region_b")
          )
        )
      },
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_subcortical = function(...) list(...)
    )

    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_messages(
      {
        atlas <- create_subcortical_from_volume(
          input_volume = vol_file,
          input_lut = lut_file,
          steps = 1:3,
          verbose = TRUE
        )
      },
      "Creating subcortical atlas"
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(nrow(atlas$core), 2L)
  })

  it("errors when no matching labels found", {
    dirs <- mock_subcort_dirs()
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      get_lut = function(f) {
        data.frame(
          idx = 999,
          label = "nonexistent",
          color = "#FF0000",
          stringsAsFactors = FALSE
        )
      },
      read_volume = function(f) {
        vol <- array(0L, dim = c(3, 3, 3))
        vol[1, 1, 1] <- 10L
        vol
      },
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      }
    )

    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_error(
      create_subcortical_from_volume(
        input_volume = vol_file,
        input_lut = lut_file,
        steps = 1,
        verbose = FALSE
      ),
      "No matching labels"
    )
  })

  it("loads cached data for skipped steps and proceeds", {
    dirs <- mock_subcort_dirs()
    cached_colortable <- data.frame(
      idx = 10,
      label = "cached_r",
      color = "#AABBCC",
      stringsAsFactors = FALSE
    )
    cached_meshes <- list(
      cached_r = list(
        vertices = list(x = 1, y = 1, z = 1),
        faces = list(i = 1, j = 1, k = 1)
      )
    )
    cached_components <- list(
      core = data.frame(
        hemi = NA,
        region = "cached",
        label = "cached_r",
        stringsAsFactors = FALSE
      ),
      palette = c(cached_r = "#AABBCC"),
      meshes_df = data.frame(stringsAsFactors = FALSE, label = "cached_r")
    )
    cached_slabs <- data.frame(
      name = "ax_1",
      type = "axial",
      start = 1,
      end = 10,
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        if (step == 1L) {
          list(
            run = FALSE,
            data = list(
              "colortable.rds" = cached_colortable,
              "vol_labels.rds" = 10
            )
          )
        } else if (step == 2L) {
          list(run = FALSE, data = list("meshes_list.rds" = cached_meshes))
        } else if (step == 3L) {
          list(run = FALSE, data = list("components.rds" = cached_components))
        } else if (step == 4L) {
          list(
            run = FALSE,
            data = list(
              "slabs.rds" = cached_slabs,
              "cortex_slices.rds" = NULL
            )
          )
        } else {
          list(run = step %in% steps, data = list())
        }
      },
      process_and_mask_images = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL)
    )

    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_messages(
      {
        result <- create_subcortical_from_volume(
          input_volume = vol_file,
          input_lut = lut_file,
          steps = 5:8,
          verbose = TRUE
        )
      },
      "Creating subcortical atlas"
    )

    expect_null(result)
  })

  it("step 9 errors when contours_reduced.rda missing", {
    dirs <- mock_subcort_dirs()
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        if (step %in% steps) {
          list(run = TRUE, data = list())
        } else {
          list(
            run = FALSE,
            data = list(
              "colortable.rds" = data.frame(
                stringsAsFactors = FALSE,
                idx = 10,
                label = "r"
              ),
              "vol_labels.rds" = 10,
              "meshes_list.rds" = list(),
              "components.rds" = list(
                core = data.frame(
                  stringsAsFactors = FALSE,
                  hemi = NA,
                  region = "r",
                  label = "r"
                ),
                palette = c(r = "#FF0000"),
                meshes_df = data.frame(stringsAsFactors = FALSE, label = "r")
              ),
              "slabs.rds" = data.frame(
                stringsAsFactors = FALSE,
                name = "ax_1",
                type = "axial",
                start = 1,
                end = 10
              ),
              "cortex_slices.rds" = NULL
            )
          )
        }
      },
      subcort_create_snapshots = function(...) {
        list(
          slabs = data.frame(
            stringsAsFactors = FALSE,
            name = "ax_1",
            type = "axial",
            start = 1,
            end = 10
          ),
          cortex_slices = NULL
        )
      },
      process_and_mask_images = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL)
    )

    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_error(
      create_subcortical_from_volume(
        input_volume = vol_file,
        input_lut = lut_file,
        steps = 9,
        verbose = FALSE
      ),
      "contours_reduced"
    )
  })

  it("passes correct args to snapshot and image step functions", {
    dirs <- mock_subcort_dirs()
    .cap$captured_snapshot_args <- NULL

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        if (step %in% c(1L, 2L, 3L)) {
          list(
            run = FALSE,
            data = list(
              "colortable.rds" = data.frame(
                idx = 10,
                label = "region",
                color = "#FF0000",
                stringsAsFactors = FALSE
              ),
              "vol_labels.rds" = 10,
              "meshes_list.rds" = list(),
              "components.rds" = list(
                core = data.frame(
                  hemi = NA,
                  region = "r",
                  label = "region",
                  stringsAsFactors = FALSE
                ),
                palette = c(region = "#FF0000"),
                meshes_df = data.frame(
                  stringsAsFactors = FALSE,
                  label = "region"
                )
              )
            )
          )
        } else if (step == 4L) {
          list(run = TRUE, data = list())
        } else {
          list(run = step %in% steps, data = list())
        }
      },
      subcort_create_snapshots = function(...) {
        .cap$captured_snapshot_args <- list(...)
        list(
          slabs = data.frame(
            name = "ax_1",
            type = "axial",
            start = 1,
            end = 10,
            stringsAsFactors = FALSE
          ),
          cortex_slices = NULL
        )
      },
      process_and_mask_images = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL),
      smooth_contours = function(...) invisible(NULL),
      reduce_vertex = function(...) invisible(NULL)
    )

    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    result <- create_subcortical_from_volume(
      input_volume = vol_file,
      input_lut = lut_file,
      steps = 4:8,
      verbose = FALSE
    )

    expect_false(is.null(.cap$captured_snapshot_args))
    expect_null(result)
  })

  it("step 9 builds final atlas with cleanup", {
    dirs <- mock_subcort_dirs()
    cached_components <- list(
      core = data.frame(
        hemi = NA,
        region = "r",
        label = "region",
        stringsAsFactors = FALSE
      ),
      palette = c(region = "#FF0000"),
      meshes_df = data.frame(stringsAsFactors = FALSE, label = "region")
    )
    cached_slabs <- data.frame(
      name = "ax_1",
      type = "axial",
      start = 1,
      end = 10,
      stringsAsFactors = FALSE
    )

    contours_file <- file.path(dirs$base, "contours_reduced.rda")
    file.create(contours_file)

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        list(
          run = FALSE,
          data = list(
            "colortable.rds" = data.frame(
              stringsAsFactors = FALSE,
              idx = 10,
              label = "region"
            ),
            "vol_labels.rds" = 10,
            "meshes_list.rds" = list(),
            "components.rds" = cached_components,
            "slabs.rds" = cached_slabs,
            "cortex_slices.rds" = NULL
          )
        )
      },
      build_contour_sf = function(...) {
        data.frame(label = "region", stringsAsFactors = FALSE)
      },
      ggseg_atlas = function(...) {
        args <- list(...)
        structure(
          list(
            core = args$core,
            palette = args$palette,
            type = args$type,
            data = args$data
          ),
          class = "ggseg_atlas"
        )
      },
      ggseg_data_subcortical = function(...) list(...),
      warn_if_large_atlas = function(...) invisible(NULL),
      preview_atlas = function(...) invisible(NULL)
    )

    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_warnings(
      expect_messages(
        {
          atlas <- create_subcortical_from_volume(
            input_volume = vol_file,
            input_lut = lut_file,
            steps = 9,
            verbose = TRUE,
            cleanup = TRUE
          )
        },
        "Creating subcortical atlas"
      ),
      "no 2D geometry"
    )

    expect_s3_class(atlas, "ggseg_atlas")
  })

  it("returns invisible NULL for partial steps", {
    dirs <- mock_subcort_dirs()
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) dirs,
      load_or_run_step = function(step, steps, ...) {
        list(
          run = FALSE,
          data = list(
            "colortable.rds" = data.frame(
              stringsAsFactors = FALSE,
              idx = 10,
              label = "r"
            ),
            "vol_labels.rds" = 10,
            "meshes_list.rds" = list(),
            "components.rds" = list(
              core = data.frame(
                stringsAsFactors = FALSE,
                hemi = NA,
                region = "r",
                label = "r"
              ),
              palette = c(r = "#FF0000"),
              meshes_df = data.frame(stringsAsFactors = FALSE, label = "r")
            ),
            "slabs.rds" = data.frame(
              stringsAsFactors = FALSE,
              name = "ax_1",
              type = "axial",
              start = 1,
              end = 10
            ),
            "cortex_slices.rds" = NULL
          )
        )
      },
      process_and_mask_images = function(...) invisible(NULL),
      extract_contours = function(...) invisible(NULL)
    )

    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_messages(
      {
        result <- create_subcortical_from_volume(
          input_volume = vol_file,
          input_lut = lut_file,
          steps = 5:6,
          verbose = TRUE
        )
      },
      "Creating subcortical atlas"
    )

    expect_null(result)
  })
})


describe("subcort_resolve_meshes early-return NULL", {
  it("returns NULL when step not run and no future steps", {
    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(run = FALSE, data = list("meshes_list.rds" = list()))
      }
    )

    config <- list(steps = 1L, verbose = FALSE)
    dirs <- list(base = withr::local_tempdir())
    colortable <- data.frame(stringsAsFactors = FALSE, idx = 10, label = "r")

    result <- subcort_resolve_meshes(config, dirs, colortable)
    expect_null(result)
  })
})


describe("subcort_resolve_components early-return NULL", {
  it("returns NULL when step not run and no future steps", {
    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(run = FALSE, data = list("components.rds" = list()))
      }
    )

    config <- list(steps = 1:2, verbose = FALSE)
    dirs <- list(base = withr::local_tempdir())
    colortable <- data.frame(stringsAsFactors = FALSE, idx = 10, label = "r")
    meshes_list <- list()

    result <- subcort_resolve_components(config, dirs, colortable, meshes_list)
    expect_null(result)
  })
})


describe("subcort_assemble_full sf_data as data.frame", {
  it("extracts labels from sf_data when build_contour_sf returns a df", {
    test_dir <- withr::local_tempdir()
    save(
      list = character(0),
      file = file.path(test_dir, "contours_reduced.rda")
    )

    sf_df <- data.frame(
      stringsAsFactors = FALSE,
      label = c("lh_region1", "rh_region2", NA)
    )

    local_mocked_bindings(
      build_contour_sf = function(...) sf_df,
      ggseg_atlas = function(...) {
        args <- list(...)
        structure(
          list(
            core = args$core,
            palette = args$palette,
            type = args$type,
            data = args$data
          ),
          class = "ggseg_atlas"
        )
      },
      ggseg_data_subcortical = function(...) list(...),
      warn_if_large_atlas = function(...) invisible(NULL),
      preview_atlas = function(...) invisible(NULL)
    )

    components <- list(
      core = dplyr::tibble(
        hemi = "left",
        region = "region1",
        label = "lh_region1",
        colour = "#FF0000"
      ),
      palette = c(lh_region1 = "#FF0000"),
      meshes_df = dplyr::tibble(label = "lh_region1", mesh = list(NULL))
    )

    result <- expect_warnings(
      subcort_assemble_full(
        "test",
        components,
        list(base = test_dir),
        "axial",
        NULL
      ),
      "no 2D geometry"
    )
    expect_s3_class(result, "ggseg_atlas")
  })
})


describe("subcort_resolve_snapshots early-return NULL", {
  it("returns NULL slabs and cortex_slices when step skipped", {
    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(
          run = FALSE,
          data = list("slabs.rds" = NULL, "cortex_slices.rds" = NULL)
        )
      }
    )

    config <- list(steps = 1:3, verbose = FALSE)
    dirs <- list(base = withr::local_tempdir())
    colortable <- data.frame(stringsAsFactors = FALSE, idx = 10, label = "r")
    slabs <- c("axial", "coronal", "sagittal")

    result <- subcort_resolve_snapshots(config, dirs, colortable, slabs)
    expect_null(result$slabs)
    expect_null(result$cortex_slices)
  })

  it("returns cached slabs when the step is skipped but later steps run", {
    cached_slabs <- data.frame(
      name = "ax_1",
      type = "axial",
      start = 1,
      end = 10,
      stringsAsFactors = FALSE
    )
    cached_cortex <- data.frame(
      x = NA,
      y = NA,
      z = 5,
      view = "axial",
      name = "ax_1",
      stringsAsFactors = FALSE
    )
    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(
          run = FALSE,
          data = list(
            "slabs.rds" = cached_slabs,
            "cortex_slices.rds" = cached_cortex
          )
        )
      }
    )

    config <- list(steps = 4L:9L, verbose = TRUE)
    dirs <- list(base = withr::local_tempdir())
    colortable <- data.frame(stringsAsFactors = FALSE, idx = 10, label = "r")

    result <- expect_messages(
      subcort_resolve_snapshots(config, dirs, colortable, NULL),
      "Loaded existing slabs"
    )
    expect_identical(result$slabs, cached_slabs)
    expect_identical(result$cortex_slices, cached_cortex)
  })

  it("runs snapshots and logs progress when the step executes with verbose", {
    local_mocked_bindings(
      load_or_run_step = function(step, steps, ...) {
        list(run = TRUE, data = list())
      },
      subcort_create_snapshots = function(...) {
        list(
          slabs = data.frame(
            name = "ax_1",
            type = "axial",
            start = 1,
            end = 10,
            stringsAsFactors = FALSE
          ),
          cortex_slices = NULL
        )
      }
    )

    config <- list(
      steps = 4L:9L,
      verbose = TRUE,
      input_volume = "fake.mgz",
      skip_existing = FALSE
    )
    dirs <- list(base = withr::local_tempdir())
    colortable <- data.frame(stringsAsFactors = FALSE, idx = 10, label = "r")

    result <- expect_messages(
      subcort_resolve_snapshots(config, dirs, colortable, NULL),
      "Creating projection snapshots"
    )
    expect_identical(result$slabs$name, "ax_1")
  })
})


describe("validate_subcort_inputs", {
  it("errors when the volume file does not exist", {
    expect_error(
      validate_subcort_inputs("/no/such/volume.mgz", NULL),
      "Volume file not found"
    )
  })

  it("errors when a character LUT path does not exist", {
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    expect_error(
      validate_subcort_inputs(vol_file, "/no/such/lut.txt"),
      "Color lookup table not found"
    )
  })

  it("is silent for an existing volume and a NULL or data.frame LUT", {
    vol_file <- withr::local_tempfile(fileext = ".mgz")
    file.create(vol_file)
    expect_null(validate_subcort_inputs(vol_file, NULL))
    expect_null(validate_subcort_inputs(vol_file, data.frame(idx = 1)))
  })
})


describe("subcort_drop_missing_labels", {
  make_components <- function() {
    list(
      core = data.frame(
        hemi = c("left", "right"),
        region = c("a", "b"),
        label = c("region_a", "region_b"),
        stringsAsFactors = FALSE
      ),
      palette = c(region_a = "#FF0000", region_b = "#00FF00"),
      meshes_df = dplyr::tibble(
        label = c("region_a", "region_b"),
        mesh = list(NULL, NULL)
      )
    )
  }

  it("drops labels absent from the contour geometry and warns", {
    result <- expect_warnings(
      subcort_drop_missing_labels(
        make_components(),
        data.frame(stringsAsFactors = FALSE, label = c("region_a", NA))
      ),
      "no valid contour data"
    )
    expect_identical(result$core$label, "region_a")
    expect_named(result$palette, "region_a")
    expect_identical(result$meshes_df$label, "region_a")
  })

  it("keeps every label and does not warn when all have geometry", {
    expect_no_warning(
      result <- subcort_drop_missing_labels(
        make_components(),
        data.frame(stringsAsFactors = FALSE, label = c("region_a", "region_b"))
      )
    )
    expect_setequal(result$core$label, c("region_a", "region_b"))
  })

  it("treats non-data.frame sf_data as having no labels and aborts", {
    expect_error(
      suppressWarnings(subcort_drop_missing_labels(make_components(), NULL)),
      "No labels with valid contour data"
    )
  })
})
