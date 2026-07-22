.cap <- new.env()

describe("wholebrain_classify_labels", {
  make_atlas_data <- function(labels, vertex_counts) {
    rows <- mapply(
      function(lbl, n) {
        tibble(
          hemi = "left",
          region = lbl,
          label = paste0("lh_", lbl),
          colour = "#FF0000",
          vertices = list(seq_len(n) - 1L),
          source_label = lbl,
          source_idx = match(lbl, labels)
        )
      },
      labels,
      vertex_counts,
      SIMPLIFY = FALSE
    )
    bind_rows(rows)
  }

  it("classifies labels above threshold as cortical", {
    ad <- make_atlas_data(
      c("region_a", "region_b"),
      c(100, 200)
    )
    result <- wholebrain_classify_labels(ad, min_vertices = 50L)
    expect_true("region_a" %in% result$cortical_labels)
    expect_true("region_b" %in% result$cortical_labels)
    expect_length(result$subcortical_labels, 0)
  })

  it("classifies labels below threshold as subcortical", {
    ad <- make_atlas_data(
      c("region_a", "region_b"),
      c(10, 20)
    )
    result <- wholebrain_classify_labels(ad, min_vertices = 50L)
    expect_length(result$cortical_labels, 0)
    expect_true("region_a" %in% result$subcortical_labels)
    expect_true("region_b" %in% result$subcortical_labels)
  })

  it("splits labels correctly at threshold boundary", {
    ad <- make_atlas_data(
      c("big", "small", "exact"),
      c(100, 10, 50)
    )
    result <- wholebrain_classify_labels(ad, min_vertices = 50L)
    expect_true("big" %in% result$cortical_labels)
    expect_true("exact" %in% result$cortical_labels)
    expect_true("small" %in% result$subcortical_labels)
  })

  it("respects manual cortical_labels override", {
    ad <- make_atlas_data(
      c("region_a", "region_b"),
      c(10, 200)
    )
    result <- wholebrain_classify_labels(
      ad,
      min_vertices = 50L,
      cortical_labels = "region_a"
    )
    expect_true("region_a" %in% result$cortical_labels)
    expect_true("region_b" %in% result$cortical_labels)
    expect_length(result$subcortical_labels, 0)
  })

  it("respects manual subcortical_labels override", {
    ad <- make_atlas_data(
      c("region_a", "region_b"),
      c(100, 200)
    )
    result <- wholebrain_classify_labels(
      ad,
      min_vertices = 50L,
      subcortical_labels = "region_a"
    )
    expect_true("region_a" %in% result$subcortical_labels)
    expect_true("region_b" %in% result$cortical_labels)
  })

  it("manual overrides take precedence over auto-classification", {
    ad <- make_atlas_data(
      c("region_a", "region_b", "region_c"),
      c(100, 200, 5)
    )
    result <- wholebrain_classify_labels(
      ad,
      min_vertices = 50L,
      cortical_labels = "region_c",
      subcortical_labels = "region_a"
    )
    expect_setequal(result$cortical_labels, c("region_b", "region_c"))
    expect_identical(result$subcortical_labels, "region_a")
  })

  it("sums vertex counts across hemispheres", {
    ad <- bind_rows(
      tibble(
        hemi = "left",
        region = "r",
        label = "lh_r",
        colour = "#FF0000",
        vertices = list(seq_len(30) - 1L),
        source_label = "r",
        source_idx = 1L
      ),
      tibble(
        hemi = "right",
        region = "r",
        label = "rh_r",
        colour = "#FF0000",
        vertices = list(seq_len(30) - 1L),
        source_label = "r",
        source_idx = 1L
      )
    )
    result <- wholebrain_classify_labels(ad, min_vertices = 50L)
    expect_true("r" %in% result$cortical_labels)
  })

  it("returns vertex_counts in result", {
    ad <- make_atlas_data(c("a", "b"), c(100, 10))
    result <- wholebrain_classify_labels(ad, min_vertices = 50L)
    expect_true("vertex_counts" %in% names(result))
    expect_identical(as.integer(result$vertex_counts["a"]), 100L)
    expect_identical(as.integer(result$vertex_counts["b"]), 10L)
  })

  it("handles empty atlas data", {
    ad <- tibble(
      hemi = character(),
      region = character(),
      label = character(),
      colour = character(),
      vertices = list(),
      source_label = character(),
      source_idx = integer()
    )
    result <- wholebrain_classify_labels(ad, min_vertices = 50L)
    expect_length(result$cortical_labels, 0)
    expect_length(result$subcortical_labels, 0)
    expect_length(result$cerebellar_labels, 0)
  })

  it("respects manual cerebellar_labels override", {
    ad <- make_atlas_data(
      c("cortex_a", "cerebellum_left", "cerebellum_right"),
      c(100, 80, 80)
    )
    result <- wholebrain_classify_labels(
      ad,
      min_vertices = 50L,
      cerebellar_labels = c("cerebellum_left", "cerebellum_right")
    )
    expect_true("cortex_a" %in% result$cortical_labels)
    expect_setequal(
      result$cerebellar_labels,
      c("cerebellum_left", "cerebellum_right")
    )
    expect_length(result$subcortical_labels, 0)
  })

  it("uses LUT type column for cerebellar classification", {
    ad <- make_atlas_data(
      c("cortex_a", "thalamus", "lobule_I"),
      c(100, 10, 60)
    )
    ct <- data.frame(
      idx = 1:3,
      label = c("cortex_a", "thalamus", "lobule_I"),
      type = c("cortical", "subcortical", "cerebellar"),
      stringsAsFactors = FALSE
    )
    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      min_vertices = 50L
    )
    expect_identical(result$cortical_labels, "cortex_a")
    expect_identical(result$subcortical_labels, "thalamus")
    expect_identical(result$cerebellar_labels, "lobule_I")
  })

  it("cerebellar_labels override takes precedence over LUT type", {
    ad <- make_atlas_data(c("lobule_I", "lobule_II"), c(100, 100))
    ct <- data.frame(
      idx = 1:2,
      label = c("lobule_I", "lobule_II"),
      type = c("cortical", "cortical"),
      stringsAsFactors = FALSE
    )
    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      min_vertices = 50L,
      cerebellar_labels = c("lobule_I", "lobule_II")
    )
    expect_length(result$cortical_labels, 0)
    expect_setequal(
      result$cerebellar_labels,
      c("lobule_I", "lobule_II")
    )
  })

  it("returns cerebellar_labels in result", {
    ad <- make_atlas_data(c("a", "b"), c(100, 10))
    result <- wholebrain_classify_labels(
      ad,
      min_vertices = 50L,
      cerebellar_labels = "b"
    )
    expect_true("cerebellar_labels" %in% names(result))
    expect_identical(result$cerebellar_labels, "b")
  })

  it("finds volume-only labels via LUT type column", {
    ad <- make_atlas_data("cortex_a", 100)
    ct <- data.frame(
      idx = 1:3,
      label = c("cortex_a", "thalamus", "lobule_I"),
      type = c("cortical", "subcortical", "cerebellar"),
      stringsAsFactors = FALSE
    )
    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      min_vertices = 50L
    )
    expect_identical(result$cortical_labels, "cortex_a")
    expect_identical(result$subcortical_labels, "thalamus")
    expect_identical(result$cerebellar_labels, "lobule_I")
  })

  it("defaults volume-only labels without type to subcortical", {
    ad <- make_atlas_data("cortex_a", 100)
    ct <- data.frame(
      idx = 1:2,
      label = c("cortex_a", "deep_nucleus"),
      stringsAsFactors = FALSE
    )
    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      min_vertices = 50L
    )
    expect_identical(result$cortical_labels, "cortex_a")
    expect_true("deep_nucleus" %in% result$subcortical_labels)
    expect_length(result$cerebellar_labels, 0)
  })

  it("manual cerebellar override works for volume-only labels", {
    ad <- make_atlas_data("cortex_a", 100)
    ct <- data.frame(
      idx = 1:3,
      label = c("cortex_a", "lobule_I", "lobule_II"),
      stringsAsFactors = FALSE
    )
    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      min_vertices = 50L,
      cerebellar_labels = c("lobule_I", "lobule_II")
    )
    expect_identical(result$cortical_labels, "cortex_a")
    expect_setequal(result$cerebellar_labels, c("lobule_I", "lobule_II"))
    expect_length(result$subcortical_labels, 0)
  })
})


describe("create_wholebrain_from_volume validation", {
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
      create_wholebrain_from_volume("test.nii.gz", verbose = FALSE),
      "FreeSurfer"
    )
  })

  it("errors when volume file not found", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    expect_error(
      create_wholebrain_from_volume(
        input_volume = "nonexistent.nii.gz",
        verbose = FALSE
      ),
      "not found"
    )
  })

  it("errors when LUT file not found", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)
    expect_error(
      create_wholebrain_from_volume(
        input_volume = vol_file,
        input_lut = "nonexistent_lut.txt",
        verbose = FALSE
      ),
      "not found"
    )
  })

  it("derives atlas_name from volume filename", {
    .cap$captured_name <- NULL
    test_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(output_dir, atlas_name, ...) {
        .cap$captured_name <- atlas_name
        list(
          base = test_dir,
          snapshots = test_dir,
          processed = test_dir,
          masks = test_dir,
          snapshots = test_dir # nolint
        )
      },
      load_or_run_step = function(step, steps, ...) {
        list(run = TRUE, data = list())
      },
      generate_colortable_from_volume = function(...) {
        data.frame(
          idx = 1L,
          label = "a",
          R = 255L,
          G = 0L,
          B = 0L,
          A = 0L,
          roi = "0001",
          color = "#FF0000",
          stringsAsFactors = FALSE
        )
      },
      wholebrain_project_to_surface = function(...) {
        tibble(
          hemi = character(),
          region = character(),
          label = character(),
          colour = character(),
          vertices = list(),
          source_label = character(),
          source_idx = integer()
        )
      },
      wholebrain_classify_labels = function(...) {
        list(
          cortical_labels = character(),
          subcortical_labels = character(),
          cerebellar_labels = character(),
          vertex_counts = integer()
        )
      }
    )

    vol_file <- file.path(withr::local_tempdir(), "test_vol.nii.gz")
    file.create(vol_file)

    expect_warning(
      {
        result <- create_wholebrain_from_volume(
          input_volume = vol_file,
          steps = 1:2,
          verbose = FALSE
        )
      },
      "No color lookup table"
    )
    expect_identical(.cap$captured_name, "test_vol")
  })
})


describe("create_wholebrain_from_volume pipeline flow", {
  it("returns split data for steps 1:2", {
    test_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = test_dir,
          snapshots = test_dir,
          processed = test_dir,
          masks = test_dir,
          snapshots = test_dir # nolint
        )
      },
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      },
      generate_colortable_from_volume = function(...) {
        data.frame(
          idx = c(1, 2),
          label = c("a", "b"),
          R = c(255, 0),
          G = c(0, 255),
          B = c(0, 0),
          A = c(0, 0),
          roi = c("0001", "0002"),
          color = c("#FF0000", "#00FF00"),
          stringsAsFactors = FALSE
        )
      },
      wholebrain_project_to_surface = function(...) {
        bind_rows(
          tibble(
            hemi = "left",
            region = "a",
            label = "lh_a",
            colour = "#FF0000",
            vertices = list(seq_len(100) - 1L),
            source_label = "a",
            source_idx = 1L
          ),
          tibble(
            hemi = "left",
            region = "b",
            label = "lh_b",
            colour = "#00FF00",
            vertices = list(seq_len(10) - 1L),
            source_label = "b",
            source_idx = 2L
          )
        )
      }
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    expect_warning(
      {
        result <- create_wholebrain_from_volume(
          input_volume = vol_file,
          steps = 1:2,
          verbose = FALSE
        )
      },
      "No color lookup table"
    )

    expect_true("cortical_labels" %in% names(result))
    expect_true("subcortical_labels" %in% names(result))
    expect_true("cerebellar_labels" %in% names(result))
    expect_true("a" %in% result$cortical_labels)
    expect_true("b" %in% result$subcortical_labels)
  })

  it("passes cortical labels to cortical pipeline for step 3", {
    test_dir <- withr::local_tempdir()
    .cap$captured_step1_args <- NULL

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = test_dir,
          snapshots = test_dir,
          processed = test_dir,
          masks = test_dir
        )
      },
      load_or_run_step = function(step, steps, ...) {
        if (step %in% steps) {
          list(run = TRUE, data = list())
        } else {
          list(
            run = FALSE,
            data = list(
              "atlas_data.rds" = tibble(
                hemi = "left",
                region = "a",
                label = "lh_a",
                colour = "#FF0000",
                vertices = list(seq_len(100) - 1L),
                source_label = "a",
                source_idx = 1L
              ),
              "colortable.rds" = data.frame(
                idx = 1,
                label = "a",
                color = "#FF0000",
                stringsAsFactors = FALSE
              ),
              "label_split.rds" = list(
                cortical_labels = "a",
                subcortical_labels = character(),
                vertex_counts = c(a = 100L)
              )
            )
          )
        }
      },
      validate_surface_config = function(...) {
        list(
          output_dir = test_dir,
          verbose = FALSE,
          cleanup = FALSE,
          skip_existing = FALSE,
          tolerance = 1
        )
      },
      cortical_read_data = function(...) {
        .cap$captured_step1_args <- list(...)
        list(
          atlas_3d = structure(
            list(
              core = data.frame(
                stringsAsFactors = FALSE,
                hemi = "left",
                region = "a",
                label = "lh_a"
              ),
              type = "cortical"
            ),
            class = "ggseg_atlas"
          ),
          components = list(
            core = data.frame(
              stringsAsFactors = FALSE,
              hemi = "left",
              region = "a",
              label = "lh_a"
            ),
            palette = c(lh_a = "#FF0000"),
            vertices_df = data.frame(stringsAsFactors = FALSE, label = "lh_a")
          )
        )
      },
      cortical_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    result <- create_wholebrain_from_volume(
      input_volume = vol_file,
      steps = 3,
      verbose = FALSE,
      cleanup = FALSE
    )

    expect_false(is.null(result$cortical))
    expect_null(result$subcortical)
    expect_false(is.null(.cap$captured_step1_args))
  })

  it("passes subcortical labels to subcortical pipeline for step 4", {
    test_dir <- withr::local_tempdir()
    .cap$captured_subcort_args <- NULL

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = test_dir,
          snapshots = test_dir,
          processed = test_dir,
          masks = test_dir
        )
      },
      load_or_run_step = function(step, steps, ...) {
        if (step %in% steps) {
          list(run = TRUE, data = list())
        } else {
          list(
            run = FALSE,
            data = list(
              "atlas_data.rds" = tibble(
                hemi = "left",
                region = "b",
                label = "lh_b",
                colour = "#00FF00",
                vertices = list(seq_len(10) - 1L),
                source_label = "b",
                source_idx = 2L
              ),
              "colortable.rds" = data.frame(
                idx = 2,
                label = "b",
                R = 0,
                G = 255,
                B = 0,
                A = 0,
                roi = "0002",
                color = "#00FF00",
                stringsAsFactors = FALSE
              ),
              "label_split.rds" = list(
                cortical_labels = character(),
                subcortical_labels = "b",
                vertex_counts = c(b = 10L)
              )
            )
          )
        }
      },
      write_lut = function(...) invisible(NULL),
      wholebrain_prepare_subcortical_volume = function(...) {
        invisible("filtered.nii.gz")
      },
      create_subcortical_from_volume = function(...) {
        .cap$captured_subcort_args <- list(...)
        structure(
          list(
            core = data.frame(
              stringsAsFactors = FALSE,
              hemi = NA,
              region = "b",
              label = "b"
            ),
            type = "subcortical"
          ),
          class = "ggseg_atlas"
        )
      }
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    result <- create_wholebrain_from_volume(
      input_volume = vol_file,
      steps = 4,
      verbose = FALSE,
      cleanup = FALSE
    )

    expect_null(result$cortical)
    expect_false(is.null(result$subcortical))
    expect_false(is.null(.cap$captured_subcort_args))
    expect_false(is.null(.cap$captured_subcort_args$input_volume))
  })

  it("skips cortical when no cortical labels", {
    test_dir <- withr::local_tempdir()

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = test_dir,
          snapshots = test_dir,
          processed = test_dir,
          masks = test_dir,
          snapshots = test_dir # nolint
        )
      },
      load_or_run_step = function(step, steps, ...) {
        list(
          run = FALSE,
          data = list(
            "atlas_data.rds" = tibble(
              hemi = "left",
              region = "b",
              label = "lh_b",
              colour = "#00FF00",
              vertices = list(seq_len(10) - 1L),
              source_label = "b",
              source_idx = 2L
            ),
            "colortable.rds" = data.frame(
              idx = 2,
              label = "b",
              R = 0,
              G = 255,
              B = 0,
              A = 0,
              roi = "0002",
              color = "#00FF00",
              stringsAsFactors = FALSE
            ),
            "label_split.rds" = list(
              cortical_labels = character(),
              subcortical_labels = "b",
              vertex_counts = c(b = 10L)
            )
          )
        )
      },
      write_lut = function(...) invisible(NULL),
      wholebrain_prepare_subcortical_volume = function(...) {
        invisible("filtered.nii.gz")
      },
      create_subcortical_from_volume = function(...) {
        structure(
          list(
            core = data.frame(
              stringsAsFactors = FALSE,
              hemi = NA,
              region = "b",
              label = "b"
            )
          ),
          class = "ggseg_atlas"
        )
      }
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    result <- create_wholebrain_from_volume(
      input_volume = vol_file,
      steps = 3:4,
      verbose = FALSE,
      cleanup = FALSE
    )

    expect_null(result$cortical)
    expect_false(is.null(result$subcortical))
  })
})


describe("wholebrain_classify_labels verbose output", {
  make_atlas_data_v <- function(labels, vertex_counts) {
    rows <- mapply(
      function(lbl, n) {
        tibble(
          hemi = "left",
          region = lbl,
          label = paste0("lh_", lbl),
          colour = "#FF0000",
          vertices = list(seq_len(n) - 1L),
          source_label = lbl,
          source_idx = match(lbl, labels)
        )
      },
      labels,
      vertex_counts,
      SIMPLIFY = FALSE
    )
    bind_rows(rows)
  }

  it("prints classification summary when verbose", {
    ad <- make_atlas_data_v(c("big", "small"), c(100, 10))
    expect_messages(
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE),
      "cortical"
    )
  })

  it("prints subcortical detail when subcortical labels exist", {
    ad <- make_atlas_data_v(c("big", "tiny"), c(200, 5))
    expect_messages(
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE),
      "Subcortical"
    )
  })

  it("does not print subcortical detail when all cortical", {
    ad <- make_atlas_data_v(c("big", "bigger"), c(200, 300))
    expect_messages(
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE),
      "2 cortical, 0 subcortical"
    )
  })
})


describe("create_wholebrain_from_volume verbose and cleanup", {
  it("logs verbose output, cleans up temp files, and removes directory", {
    test_dir <- withr::local_tempdir()
    sub_dir <- file.path(test_dir, "wb_atlas")
    dir.create(sub_dir)

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = sub_dir,
          snapshots = sub_dir,
          processed = sub_dir,
          masks = sub_dir
        )
      },
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      },
      generate_colortable_from_volume = function(...) {
        data.frame(
          idx = 1L,
          label = "a",
          R = 255L,
          G = 0L,
          B = 0L,
          A = 0L,
          roi = "0001",
          color = "#FF0000",
          stringsAsFactors = FALSE
        )
      },
      wholebrain_project_to_surface = function(...) {
        tibble(
          hemi = "left",
          region = "a",
          label = "lh_a",
          colour = "#FF0000",
          vertices = list(seq_len(100) - 1L),
          source_label = "a",
          source_idx = 1L
        )
      },
      wholebrain_run_cortical = function(...) {
        structure(
          list(
            core = data.frame(
              stringsAsFactors = FALSE,
              hemi = "left",
              region = "a"
            )
          ),
          class = "ggseg_atlas"
        )
      },
      wholebrain_run_subcortical = function(...) NULL,
      log_elapsed = function(...) NULL
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    suppressWarnings(expect_messages(
      create_wholebrain_from_volume(
        input_volume = vol_file,
        steps = 1:4,
        verbose = TRUE,
        cleanup = TRUE
      ),
      "Creating whole-brain atlas"
    ))

    expect_false(dir.exists(sub_dir))
  })

  it("logs elapsed time for early return at step 2", {
    test_dir <- withr::local_tempdir()
    sub_dir <- file.path(test_dir, "wb_early")
    dir.create(sub_dir)

    .cap$elapsed_called <- FALSE

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = sub_dir,
          snapshots = sub_dir,
          processed = sub_dir,
          masks = sub_dir
        )
      },
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      },
      generate_colortable_from_volume = function(...) {
        data.frame(
          idx = 1L,
          label = "a",
          R = 255L,
          G = 0L,
          B = 0L,
          A = 0L,
          roi = "0001",
          color = "#FF0000",
          stringsAsFactors = FALSE
        )
      },
      wholebrain_project_to_surface = function(...) {
        tibble(
          hemi = "left",
          region = "a",
          label = "lh_a",
          colour = "#FF0000",
          vertices = list(seq_len(100) - 1L),
          source_label = "a",
          source_idx = 1L
        )
      },
      log_elapsed = function(...) {
        .cap$elapsed_called <- TRUE
      }
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    suppressWarnings(expect_messages(
      create_wholebrain_from_volume(
        input_volume = vol_file,
        steps = 1:2,
        verbose = TRUE,
        cleanup = FALSE
      )
    ))

    expect_true(.cap$elapsed_called)
  })
})


describe("wholebrain_resolve_projection cached path", {
  it("returns cached data and logs when verbose", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )

    cached_atlas <- tibble(
      hemi = "left",
      region = "a",
      label = "lh_a",
      colour = "#FF0000",
      vertices = list(seq_len(50) - 1L),
      source_label = "a",
      source_idx = 1L
    )
    cached_ct <- data.frame(
      idx = 1L,
      label = "a",
      R = 255L,
      G = 0L,
      B = 0L,
      A = 0L,
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      load_or_run_step = function(...) {
        list(
          run = FALSE,
          data = list(
            "atlas_data.rds" = cached_atlas,
            "colortable.rds" = cached_ct
          )
        )
      }
    )

    config <- list(steps = 1L, skip_existing = TRUE, verbose = TRUE)

    expect_messages(
      {
        result <- wholebrain_resolve_projection(config, dirs)
      },
      "Loaded existing"
    )

    expect_identical(result$atlas_data, cached_atlas)
    expect_identical(result$colortable, cached_ct)
  })
})


describe("wholebrain_resolve_split cached path", {
  it("returns cached split and logs when verbose", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )

    cached_split <- list(
      cortical_labels = "a",
      subcortical_labels = "b",
      vertex_counts = c(a = 100L, b = 10L)
    )

    local_mocked_bindings(
      load_or_run_step = function(...) {
        list(
          run = FALSE,
          data = list("label_split.rds" = cached_split)
        )
      }
    )

    config <- list(
      steps = 2L,
      skip_existing = TRUE,
      verbose = TRUE,
      min_vertices = 50L
    )
    projection <- list(
      atlas_data = tibble(),
      colortable = data.frame()
    )

    expect_messages(
      {
        result <- wholebrain_resolve_split(config, dirs, projection)
      },
      "Loaded existing"
    )

    expect_identical(result, cached_split)
  })
})


describe("wholebrain_run_cortical verbose logging", {
  it("logs progress step and validates cortical config", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )

    cortical_data <- tibble(
      hemi = "left",
      region = "a",
      label = "lh_a",
      colour = "#FF0000",
      vertices = list(seq_len(100) - 1L),
      source_label = "a",
      source_idx = 1L
    )

    local_mocked_bindings(
      setup_atlas_dirs = function(...) dirs,
      validate_surface_config = function(...) {
        list(
          output_dir = test_dir,
          verbose = TRUE,
          cleanup = FALSE,
          skip_existing = FALSE,
          tolerance = 1
        )
      },
      cortical_read_data = function(...) {
        list(
          atlas_3d = structure(
            list(
              core = data.frame(
                stringsAsFactors = FALSE,
                hemi = "left",
                region = "a"
              )
            ),
            class = "ggseg_atlas"
          ),
          components = list()
        )
      },
      cortical_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    config <- list(
      atlas_name = "test",
      verbose = TRUE,
      output_dir = test_dir,
      skip_existing = FALSE,
      tolerance = 1,
      smoothness = 5
    )
    projection <- list(atlas_data = cortical_data)
    split <- list(cortical_labels = "a")

    expect_messages(
      wholebrain_run_cortical(config, dirs, projection, split),
      "Cortical pipeline"
    )
  })
})


describe("wholebrain_run_subcortical verbose logging", {
  it("logs progress step and filters subcortical data", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )

    colortable <- data.frame(
      idx = c(1L, 2L),
      label = c("a", "b"),
      R = c(255L, 0L),
      G = c(0L, 255L),
      B = c(0L, 0L),
      A = c(0L, 0L),
      roi = c("0001", "0002"),
      color = c("#FF0000", "#00FF00"),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      write_lut = function(...) invisible(NULL),
      wholebrain_prepare_subcortical_volume = function(...) {
        invisible("filtered.nii.gz")
      },
      create_subcortical_from_volume = function(...) {
        structure(
          list(
            core = data.frame(stringsAsFactors = FALSE, hemi = NA, region = "b")
          ),
          class = "ggseg_atlas"
        )
      }
    )

    config <- list(
      atlas_name = "test",
      verbose = TRUE,
      input_volume = "fake.nii.gz",
      output_dir = test_dir,
      skip_existing = FALSE,
      tolerance = 1,
      smoothness = 5
    )
    split <- list(subcortical_labels = "b")

    expect_messages(
      wholebrain_run_subcortical(
        config,
        dirs,
        split,
        colortable = colortable
      ),
      "Subcortical pipeline"
    )
  })

  it("filters colortable to subcortical labels only", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )

    .cap$captured_lut <- NULL
    colortable <- data.frame(
      idx = c(1L, 2L, 3L),
      label = c("cortical_a", "subcort_b", "subcort_c"),
      R = c(255L, 0L, 0L),
      G = c(0L, 255L, 0L),
      B = c(0L, 0L, 255L),
      A = c(0L, 0L, 0L),
      roi = c("0001", "0002", "0003"),
      color = c("#FF0000", "#00FF00", "#0000FF"),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      write_lut = function(ct, ...) {
        .cap$captured_lut <- ct
        invisible(NULL)
      },
      wholebrain_prepare_subcortical_volume = function(...) {
        invisible("filtered.nii.gz")
      },
      create_subcortical_from_volume = function(...) {
        structure(
          list(
            core = data.frame(
              stringsAsFactors = FALSE,
              hemi = NA,
              region = "subcort_b"
            )
          ),
          class = "ggseg_atlas"
        )
      }
    )

    config <- list(
      atlas_name = "test",
      verbose = FALSE,
      input_volume = "fake.nii.gz",
      output_dir = test_dir,
      skip_existing = FALSE,
      tolerance = 1,
      smoothness = 5
    )
    split <- list(subcortical_labels = c("subcort_b", "subcort_c"))

    wholebrain_run_subcortical(
      config,
      dirs,
      split,
      colortable = colortable
    )

    expect_identical(
      sort(.cap$captured_lut$label),
      sort(c("subcort_b", "subcort_c"))
    )
    expect_false("cortical_a" %in% .cap$captured_lut$label)
  })
})


describe("create_wholebrain_from_volume integration", {
  it("projects native-space volume and classifies labels", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    result <- create_wholebrain_from_volume(
      input_volume = vol_file,
      input_lut = lut_file,
      regheader = TRUE,
      steps = 1:2,
      verbose = FALSE
    )

    expect_true("cortical_labels" %in% names(result))
    expect_true("subcortical_labels" %in% names(result))
    expect_true("cerebellar_labels" %in% names(result))
    expect_gt(
      length(result$cortical_labels) +
        length(result$subcortical_labels) +
        length(result$cerebellar_labels),
      0
    )
  })
})


describe("fill_surface_labels", {
  it("warns and returns overlay when surface file not found", {
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent/subjects",
      .package = "freesurfer"
    )

    overlay <- c(1L, 0L, 2L, 0L)
    expect_warning(
      {
        result <- fill_surface_labels(overlay, "lh", "fsaverage5")
      },
      "skipping dilation"
    )
    expect_identical(result, overlay)
  })

  it("breaks when no newly_labeled vertices remain", {
    tmp_dir <- withr::local_tempdir()
    subj_dir <- file.path(tmp_dir, "fsaverage5")
    surf_dir <- file.path(subj_dir, "surf")
    label_dir <- file.path(subj_dir, "label")
    dir.create(surf_dir, recursive = TRUE)
    dir.create(label_dir, recursive = TRUE)
    writeLines("placeholder", file.path(surf_dir, "lh.white"))
    file.create(file.path(label_dir, "lh.cortex.label"))

    local_mocked_bindings(
      fs_subj_dir = function() tmp_dir,
      .package = "freesurfer"
    )

    local_mocked_bindings(
      read.fs.surface = function(f) {
        list(
          vertices = matrix(0, nrow = 5, ncol = 3),
          faces = matrix(c(1L, 2L, 3L), nrow = 1, byrow = TRUE)
        )
      },
      .package = "freesurferformats"
    )

    local_mocked_bindings(
      read_label_vertices = function(...) c(0L, 1L, 2L)
    )

    overlay <- c(1L, 0L, 2L, 0L, 0L)
    result <- fill_surface_labels(overlay, "lh", "fsaverage5")
    expect_identical(result[1], 1L)
    expect_identical(result[3], 2L)
    expect_true(result[2] != 0L)
    expect_identical(result[4], 0L)
    expect_identical(result[5], 0L)
  })
})


describe("load_cortex_mask", {
  it("returns logical vector from cortex label file", {
    tmp_dir <- withr::local_tempdir()
    label_dir <- file.path(tmp_dir, "fsaverage5", "label")
    dir.create(label_dir, recursive = TRUE)
    label_file <- file.path(label_dir, "lh.cortex.label")
    file.create(label_file)

    local_mocked_bindings(
      fs_subj_dir = function() tmp_dir,
      .package = "freesurfer"
    )
    local_mocked_bindings(
      read_label_vertices = function(...) c(0L, 2L, 4L)
    )

    mask <- load_cortex_mask("lh", "fsaverage5", n_vertices = 6L)
    expect_type(mask, "logical")
    expect_length(mask, 6L)
    expect_identical(mask, c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE))
  })

  it("errors when cortex label file missing", {
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent/subjects",
      .package = "freesurfer"
    )

    expect_error(
      load_cortex_mask("lh", "fsaverage5", n_vertices = 10L),
      "Cortex label not found"
    )
  })
})


describe("fill_surface_labels with cortex mask", {
  it("does not dilate into medial wall vertices", {
    tmp_dir <- withr::local_tempdir()
    subj_dir <- file.path(tmp_dir, "fsaverage5")
    surf_dir <- file.path(subj_dir, "surf")
    label_dir <- file.path(subj_dir, "label")
    dir.create(surf_dir, recursive = TRUE)
    dir.create(label_dir, recursive = TRUE)
    surf_file <- file.path(surf_dir, "lh.white")
    writeLines("placeholder", surf_file)
    label_file <- file.path(label_dir, "lh.cortex.label")
    file.create(label_file)

    local_mocked_bindings(
      fs_subj_dir = function() tmp_dir,
      .package = "freesurfer"
    )

    local_mocked_bindings(
      read.fs.surface = function(f) {
        list(
          vertices = matrix(0, nrow = 6, ncol = 3),
          faces = matrix(
            c(1L, 2L, 3L, 3L, 4L, 5L, 5L, 6L, 1L),
            nrow = 3,
            byrow = TRUE
          )
        )
      },
      .package = "freesurferformats"
    )

    local_mocked_bindings(
      read_label_vertices = function(...) c(0L, 1L, 2L)
    )

    overlay <- c(1L, 0L, 0L, 0L, 0L, 0L)
    result <- fill_surface_labels(overlay, "lh", "fsaverage5")

    expect_identical(result[1], 1L)
    expect_true(result[2] != 0L)
    expect_true(result[3] != 0L)
    expect_identical(result[4], 0L)
    expect_identical(result[5], 0L)
    expect_identical(result[6], 0L)
  })
})


describe("create_wholebrain_from_volume oversight warning", {
  it("warns about manual validation when verbose", {
    test_dir <- withr::local_tempdir()
    sub_dir <- file.path(test_dir, "wb_warn")
    dir.create(sub_dir)

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = sub_dir,
          snapshots = sub_dir,
          processed = sub_dir,
          masks = sub_dir
        )
      },
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      },
      generate_colortable_from_volume = function(...) {
        data.frame(
          idx = 1L,
          label = "a",
          R = 255L,
          G = 0L,
          B = 0L,
          A = 0L,
          roi = "0001",
          color = "#FF0000",
          stringsAsFactors = FALSE
        )
      },
      wholebrain_project_to_surface = function(...) {
        tibble(
          hemi = "left",
          region = "a",
          label = "lh_a",
          colour = "#FF0000",
          vertices = list(seq_len(100) - 1L),
          source_label = "a",
          source_idx = 1L
        )
      },
      log_elapsed = function(...) NULL
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    expect_messages(
      suppressWarnings(
        create_wholebrain_from_volume(
          input_volume = vol_file,
          steps = 1:2,
          verbose = TRUE
        )
      ),
      "manual validation"
    )
  })
})


describe("create_wholebrain_from_volume verbose LUT path", {
  it("prints LUT path when verbose and input_lut is not NULL", {
    test_dir <- withr::local_tempdir()
    sub_dir <- file.path(test_dir, "wb_lut_verbose")
    dir.create(sub_dir)

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)
    lut_file <- withr::local_tempfile(fileext = ".txt")
    file.create(lut_file)

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = sub_dir,
          snapshots = sub_dir,
          processed = sub_dir,
          masks = sub_dir
        )
      },
      load_or_run_step = function(step, steps, ...) {
        list(run = step %in% steps, data = list())
      },
      get_lut = function(...) {
        data.frame(
          idx = 1L,
          label = "a",
          R = 255L,
          G = 0L,
          B = 0L,
          A = 0L,
          roi = "0001",
          color = "#FF0000",
          stringsAsFactors = FALSE
        )
      },
      wholebrain_project_to_surface = function(...) {
        tibble(
          hemi = "left",
          region = "a",
          label = "lh_a",
          colour = "#FF0000",
          vertices = list(seq_len(100) - 1L),
          source_label = "a",
          source_idx = 1L
        )
      },
      log_elapsed = function(...) NULL
    )

    expect_messages(
      create_wholebrain_from_volume(
        input_volume = vol_file,
        input_lut = lut_file,
        steps = 1:2,
        verbose = TRUE
      ),
      "Color LUT"
    )
  })
})


describe("wholebrain_project_to_surface", {
  it("errors when mri_vol2surf output file does not exist", {
    tmp_dir <- withr::local_tempdir()
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    colortable <- data.frame(
      idx = 1L,
      label = "a",
      R = 255L,
      G = 0L,
      B = 0L,
      A = 0L,
      roi = "0001",
      color = "#FF0000",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      mri_vol2surf = function(...) invisible(NULL),
      fill_surface_labels = function(overlay, ...) overlay
    )

    expect_error(
      wholebrain_project_to_surface(
        input_volume = vol_file,
        colortable = colortable,
        subject = "fsaverage5",
        projfrac = 0.5,
        projfrac_range = NULL,
        regheader = TRUE,
        output_dir = tmp_dir,
        verbose = FALSE
      ),
      "mri_vol2surf failed"
    )
  })

  it("prints verbose fill_surface_labels message", {
    skip_if_not_installed("RNifti")

    tmp_dir <- withr::local_tempdir()
    surf_dir <- file.path(tmp_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    colortable <- data.frame(
      idx = 1L,
      label = "a",
      R = 255L,
      G = 0L,
      B = 0L,
      A = 0L,
      roi = "0001",
      color = "#FF0000",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(1L, 5), rep(0L, 5))
        RNifti::writeNifti(array(values, dim = c(10, 1, 1)), output_file)
      },
      fill_surface_labels = function(overlay, ...) {
        overlay[overlay == 0L] <- 1L
        overlay
      }
    )

    expect_messages(
      wholebrain_project_to_surface(
        input_volume = "fake.nii.gz",
        colortable = colortable,
        subject = "fsaverage5",
        projfrac = 0.5,
        projfrac_range = NULL,
        regheader = TRUE,
        output_dir = tmp_dir,
        verbose = TRUE
      ),
      "labeled vertices"
    )
  })

  it("skips label not in colortable", {
    skip_if_not_installed("RNifti")

    tmp_dir <- withr::local_tempdir()
    surf_dir <- file.path(tmp_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    colortable <- data.frame(
      idx = 1L,
      label = "a",
      R = 255L,
      G = 0L,
      B = 0L,
      A = 0L,
      roi = "0001",
      color = "#FF0000",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(1L, 3), rep(99L, 2), rep(0L, 5))
        RNifti::writeNifti(array(values, dim = c(10, 1, 1)), output_file)
      },
      fill_surface_labels = function(overlay, ...) overlay
    )

    result <- wholebrain_project_to_surface(
      input_volume = "fake.nii.gz",
      colortable = colortable,
      subject = "fsaverage5",
      projfrac = 0.5,
      projfrac_range = NULL,
      regheader = TRUE,
      output_dir = tmp_dir,
      verbose = FALSE
    )

    expect_false(any(result$source_idx == 99L))
    labeled <- result[result$source_idx != 0L, ]
    expect_true(all(labeled$source_idx == 1L))
  })

  it("uses RGB columns for colour when color column missing", {
    skip_if_not_installed("RNifti")

    tmp_dir <- withr::local_tempdir()
    surf_dir <- file.path(tmp_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    colortable <- data.frame(
      idx = 1L,
      label = "a",
      R = 255L,
      G = 0L,
      B = 0L,
      A = 0L,
      roi = "0001",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(1L, 5), rep(0L, 5))
        RNifti::writeNifti(array(values, dim = c(10, 1, 1)), output_file)
      },
      fill_surface_labels = function(overlay, ...) overlay
    )

    result <- wholebrain_project_to_surface(
      input_volume = "fake.nii.gz",
      colortable = colortable,
      subject = "fsaverage5",
      projfrac = 0.5,
      projfrac_range = NULL,
      regheader = TRUE,
      output_dir = tmp_dir,
      verbose = FALSE
    )

    expect_true(all(grepl("^#", result$colour)))
    expect_identical(result$colour[1], "#FF0000")
  })
})


describe("wholebrain_run_cortical verbose progress_done", {
  it("calls cli_progress_done when verbose", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )

    cortical_data <- tibble(
      hemi = "left",
      region = "a",
      label = "lh_a",
      colour = "#FF0000",
      vertices = list(seq_len(100) - 1L),
      source_label = "a",
      source_idx = 1L
    )

    mock_atlas <- structure(
      list(
        core = data.frame(
          stringsAsFactors = FALSE,
          hemi = "left",
          region = "a",
          label = "lh_a"
        )
      ),
      class = "ggseg_atlas"
    )

    local_mocked_bindings(
      setup_atlas_dirs = function(...) dirs,
      validate_surface_config = function(...) {
        list(
          output_dir = test_dir,
          verbose = TRUE,
          cleanup = FALSE,
          skip_existing = FALSE,
          tolerance = 1
        )
      },
      cortical_read_data = function(...) {
        list(
          atlas_3d = mock_atlas,
          components = list(
            core = data.frame(
              stringsAsFactors = FALSE,
              hemi = "left",
              region = "a",
              label = "lh_a"
            ),
            palette = c(lh_a = "#FF0000"),
            vertices_df = data.frame(stringsAsFactors = FALSE, label = "lh_a")
          )
        )
      },
      cortical_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    config <- list(
      atlas_name = "test",
      verbose = TRUE,
      output_dir = test_dir,
      skip_existing = FALSE,
      tolerance = 1,
      smoothness = 5
    )
    projection <- list(atlas_data = cortical_data)
    split <- list(cortical_labels = "a")

    expect_messages(
      {
        result <- wholebrain_run_cortical(config, dirs, projection, split)
      },
      "Cortical"
    )

    expect_s3_class(result, "ggseg_atlas")
  })
})


describe("validate_pipeline_opts", {
  it("returns empty list for NULL opts", {
    expect_identical(validate_pipeline_opts(NULL, "cortical", "views"), list())
  })

  it("returns empty list for empty list opts", {
    expect_identical(
      validate_pipeline_opts(list(), "cortical", "views"),
      list()
    )
  })

  it("errors when opts is not a list", {
    expect_error(
      validate_pipeline_opts("bad", "cortical", "views"),
      "must be a named list"
    )
  })

  it("errors on unnamed entries", {
    expect_error(
      validate_pipeline_opts(list(1, 2), "cortical", "views"),
      "must be named"
    )
  })

  it("errors on partially unnamed entries", {
    expect_error(
      validate_pipeline_opts(
        list(views = "lat", 2),
        "cortical",
        "views"
      ),
      "must be named"
    )
  })

  it("errors on duplicate names", {
    expect_error(
      validate_pipeline_opts(
        list(views = "lat", views = "med"), # nolint
        "cortical",
        "views"
      ),
      "Duplicate"
    )
  })

  it("errors on unknown option names", {
    expect_error(
      validate_pipeline_opts(
        list(unknown_opt = TRUE),
        "cortical",
        c("views", "tolerance")
      ),
      "Unknown cortical option"
    )
  })

  it("returns validated list for valid named opts", {
    result <- validate_pipeline_opts(
      list(views = c("lateral", "medial")),
      "cortical",
      c("views", "tolerance")
    )
    expect_identical(result$views, c("lateral", "medial"))
  })
})


describe("validate_wholebrain_opts", {
  it("derives cortical allowed names from create_cortical_from_annotation()", {
    result <- validate_wholebrain_opts(
      cortical_opts = list(views = c("lateral", "medial")),
      subcortical_opts = list(),
      cerebellar_opts = list()
    )
    expect_identical(result$cortical$views, c("lateral", "medial"))
  })

  it("rejects cortical_opts entries managed by the wholebrain pipeline", {
    expect_error(
      validate_wholebrain_opts(
        cortical_opts = list(atlas_name = "custom"),
        subcortical_opts = list(),
        cerebellar_opts = list()
      ),
      "Unknown cortical option"
    )
  })

  it("rejects unknown cortical_opts entries", {
    expect_error(
      validate_wholebrain_opts(
        cortical_opts = list(bogus = TRUE),
        subcortical_opts = list(),
        cerebellar_opts = list()
      ),
      "Unknown cortical option"
    )
  })

  it("still validates subcortical and cerebellar opts", {
    result <- validate_wholebrain_opts(
      cortical_opts = list(),
      subcortical_opts = list(dilate = 2),
      cerebellar_opts = list(decimate = 0.3)
    )
    expect_identical(result$subcortical$dilate, 2)
    expect_identical(result$cerebellar$decimate, 0.3)
  })
})


describe("wholebrain_classify_labels additional verbose branches", {
  make_atlas_data_v <- function(labels, vertex_counts) {
    rows <- mapply(
      function(lbl, n) {
        tibble(
          hemi = "left",
          region = lbl,
          label = paste0("lh_", lbl),
          colour = "#FF0000",
          vertices = list(seq_len(n) - 1L),
          source_label = lbl,
          source_idx = match(lbl, labels)
        )
      },
      labels,
      vertex_counts,
      SIMPLIFY = FALSE
    )
    bind_rows(rows)
  }

  it("warns for subcortical_labels not found in data", {
    ad <- make_atlas_data_v("region_a", 10)
    expect_warning(
      wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        subcortical_labels = c("region_a", "nonexistent")
      ),
      "not found in data"
    )
  })

  it("prints cerebellar detail when cerebellar labels exist and verbose", {
    ad <- make_atlas_data_v(c("cortex_a", "lobule_I"), c(100, 80))
    expect_messages(
      wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        cerebellar_labels = "lobule_I",
        verbose = TRUE
      ),
      "Cerebellar"
    )
  })

  it("prints vertex count info when no type column", {
    ad <- make_atlas_data_v(c("big", "small"), c(100, 10))
    expect_messages(
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE),
      "classifying.*labels by vertex count"
    )
  })
})


describe("wholebrain_refine_cortical_projection", {
  it("returns projection unchanged when no non-cortical labels", {
    config <- list(verbose = FALSE, subject = "fsaverage5")
    dirs <- list(base = withr::local_tempdir())
    projection <- list(
      atlas_data = tibble(),
      colortable = data.frame(stringsAsFactors = FALSE, idx = 1L, label = "a")
    )
    split <- list(
      subcortical_labels = character(),
      cerebellar_labels = character(),
      cortical_labels = "a"
    )
    result <- wholebrain_refine_cortical_projection(
      config,
      dirs,
      projection,
      split
    )
    expect_identical(result, projection)
  })

  it("returns projection unchanged when no idx matches non-cortical", {
    config <- list(verbose = FALSE, subject = "fsaverage5")
    dirs <- list(base = withr::local_tempdir())
    projection <- list(
      atlas_data = tibble(),
      colortable = data.frame(
        idx = 1L,
        label = "cortical_only",
        stringsAsFactors = FALSE
      )
    )
    split <- list(
      subcortical_labels = "nonexistent",
      cerebellar_labels = character(),
      cortical_labels = "cortical_only"
    )
    result <- wholebrain_refine_cortical_projection(
      config,
      dirs,
      projection,
      split
    )
    expect_identical(result, projection)
  })

  it("errors when overlay file is missing", {
    skip_if_not_installed("RNifti")
    config <- list(verbose = FALSE, subject = "fsaverage5")
    tmp <- withr::local_tempdir()
    dirs <- list(base = tmp)
    projection <- list(
      atlas_data = tibble(),
      colortable = data.frame(
        idx = c(1L, 2L),
        label = c("cort", "subcort"),
        stringsAsFactors = FALSE
      )
    )
    split <- list(
      subcortical_labels = "subcort",
      cerebellar_labels = character(),
      cortical_labels = "cort"
    )
    expect_error(
      wholebrain_refine_cortical_projection(
        config,
        dirs,
        projection,
        split
      ),
      "Overlay file missing"
    )
  })

  it("removes subcortical labels and refills surface", {
    skip_if_not_installed("RNifti")
    tmp <- withr::local_tempdir()
    surf_dir <- file.path(tmp, "surface_overlays")
    dir.create(surf_dir)
    for (h in c("lh", "rh")) {
      vals <- c(rep(1L, 3), rep(2L, 2), rep(0L, 5))
      RNifti::writeNifti(
        array(vals, dim = c(10, 1, 1)),
        file.path(surf_dir, paste0(h, "_overlay.nii.gz"))
      )
    }
    config <- list(verbose = FALSE, subject = "fsaverage5")
    dirs <- list(base = tmp)
    projection <- list(
      atlas_data = tibble(),
      colortable = data.frame(
        idx = c(1L, 2L),
        label = c("cortex", "thalamus"),
        stringsAsFactors = FALSE
      )
    )
    split <- list(
      subcortical_labels = "thalamus",
      cerebellar_labels = character(),
      cortical_labels = "cortex"
    )
    local_mocked_bindings(
      fill_surface_labels = function(overlay, ...) overlay,
      overlay_to_atlas_data = function(overlay, hemi_short, ct, ...) {
        tibble(
          hemi = "left",
          region = "cortex",
          label = "lh_cortex",
          colour = "#FF0000",
          vertices = list(which(overlay == 1L) - 1L),
          source_label = "cortex",
          source_idx = 1L
        )
      }
    )
    result <- wholebrain_refine_cortical_projection(
      config,
      dirs,
      projection,
      split
    )
    expect_true(all(result$atlas_data$source_label == "cortex"))
    expect_false("thalamus" %in% result$colortable$label)
  })
})


describe("fill_missing_rgb", {
  it("adds missing R/G/B/A columns and fills them", {
    ct <- data.frame(
      idx = 1:2,
      label = c("a", "b"),
      stringsAsFactors = FALSE
    )
    expect_messages(
      {
        result <- fill_missing_rgb(ct, "test")
      },
      "Auto-generating colours"
    )
    expect_true(all(c("R", "G", "B", "A") %in% names(result)))
    expect_false(anyNA(result$R))
    expect_false(anyNA(result$G))
    expect_false(anyNA(result$B))
    expect_identical(result$A, c(0L, 0L))
  })

  it("preserves existing colours and only fills NAs", {
    ct <- data.frame(
      idx = 1:3,
      label = c("a", "b", "c"),
      R = c(255L, NA_integer_, NA_integer_),
      G = c(0L, NA_integer_, NA_integer_),
      B = c(0L, NA_integer_, NA_integer_),
      A = c(0L, NA_integer_, NA_integer_),
      stringsAsFactors = FALSE
    )
    result <- fill_missing_rgb(ct, "test")
    expect_identical(result$R[1], 255L)
    expect_false(is.na(result$R[2]))
    expect_identical(result$A, c(0L, 0L, 0L))
  })

  it("returns unchanged when no missing RGB", {
    ct <- data.frame(
      idx = 1L,
      label = "a",
      R = 100L,
      G = 150L,
      B = 200L,
      A = 0L,
      stringsAsFactors = FALSE
    )
    result <- fill_missing_rgb(ct, "test")
    expect_identical(result$R, 100L)
    expect_identical(result$G, 150L)
    expect_identical(result$B, 200L)
  })
})


describe("wholebrain_prepare_cerebellar_volume", {
  it("keeps only cerebellar indices in output", {
    skip_if_not_installed("RNifti")
    vol <- array(0L, dim = c(5, 5, 5))
    vol[1, 1, 1] <- 1L
    vol[2, 2, 2] <- 2L
    vol[3, 3, 3] <- 3L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_cerebellar_volume(
      input_volume = vol_file,
      cerebellar_idx = c(1L, 3L),
      output_file = out_file
    )

    result <- drop(as.array(RNifti::readNifti(out_file)))
    expect_identical(result[1, 1, 1], 1L)
    expect_identical(result[2, 2, 2], 0L)
    expect_identical(result[3, 3, 3], 3L)
  })

  it("returns output_file invisibly", {
    skip_if_not_installed("RNifti")
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(
      RNifti::asNifti(array(0L, dim = c(3, 3, 3))),
      vol_file
    )
    out_file <- withr::local_tempfile(fileext = ".nii.gz")
    result <- wholebrain_prepare_cerebellar_volume(
      input_volume = vol_file,
      cerebellar_idx = integer(0),
      output_file = out_file
    )
    expect_identical(result, out_file)
  })
})


describe("wholebrain_prepare_subcortical_volume", {
  it("zeros non-subcortical non-cortical voxels", {
    skip_if_not_installed("RNifti")
    vol <- array(0L, dim = c(6, 3, 3))
    vol[1, 1, 1] <- 10L
    vol[3, 1, 1] <- 20L
    vol[5, 1, 1] <- 99L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = 20L,
      output_file = out_file
    )

    result <- drop(as.array(RNifti::readNifti(out_file)))
    expect_identical(result[1, 1, 1], 10L)
    expect_identical(result[5, 1, 1], 0L)
    expect_true(result[3, 1, 1] %in% c(3, 42))
  })
})


describe("wholebrain_run_cerebellar", {
  it("calls create_cerebellar_from_volume with filtered colortable", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )
    colortable <- data.frame(
      idx = c(1L, 2L, 3L),
      label = c("cortex_a", "lobule_I", "lobule_II"),
      R = c(255L, 128L, 64L),
      G = c(0L, 200L, 100L),
      B = c(0L, 50L, 25L),
      A = c(0L, 0L, 0L),
      stringsAsFactors = FALSE
    )
    split <- list(cerebellar_labels = c("lobule_I", "lobule_II"))
    config <- list(
      atlas_name = "test",
      verbose = FALSE,
      input_volume = "fake.nii.gz",
      skip_existing = FALSE,
      cleanup = FALSE
    )
    .cap$captured <- NULL
    local_mocked_bindings(
      wholebrain_prepare_cerebellar_volume = function(...) {
        invisible("cer_vol.nii.gz")
      },
      create_cerebellar_from_volume = function(...) {
        .cap$captured <- list(...)
        structure(list(), class = "ggseg_atlas")
      }
    )
    wholebrain_run_cerebellar(config, dirs, split, colortable)
    expect_false(is.null(.cap$captured))
    expect_identical(
      sort(.cap$captured$input_lut$label),
      c("lobule_I", "lobule_II")
    )
    expect_null(.cap$captured$smooth_refinements)
  })

  it("passes opts overriding defaults", {
    test_dir <- withr::local_tempdir()
    dirs <- list(base = test_dir)
    colortable <- data.frame(
      idx = 1L,
      label = "lobule_I",
      R = 128L,
      G = 200L,
      B = 50L,
      A = 0L,
      stringsAsFactors = FALSE
    )
    split <- list(cerebellar_labels = "lobule_I")
    config <- list(
      atlas_name = "test",
      verbose = FALSE,
      input_volume = "fake.nii.gz",
      skip_existing = FALSE,
      cleanup = FALSE
    )
    .cap$captured <- NULL
    local_mocked_bindings(
      wholebrain_prepare_cerebellar_volume = function(...) {
        invisible("cer_vol.nii.gz")
      },
      create_cerebellar_from_volume = function(...) {
        .cap$captured <- list(...)
        structure(list(), class = "ggseg_atlas")
      }
    )
    wholebrain_run_cerebellar(
      config,
      dirs,
      split,
      colortable,
      opts = list(smooth_refinements = 5L)
    )
    expect_identical(.cap$captured$smooth_refinements, 5L)
  })

  it("prints verbose header", {
    test_dir <- withr::local_tempdir()
    dirs <- list(base = test_dir)
    colortable <- data.frame(
      idx = 1L,
      label = "lobule_I",
      R = 128L,
      G = 200L,
      B = 50L,
      A = 0L,
      stringsAsFactors = FALSE
    )
    split <- list(cerebellar_labels = "lobule_I")
    config <- list(
      atlas_name = "test",
      verbose = TRUE,
      input_volume = "fake.nii.gz",
      skip_existing = FALSE,
      cleanup = FALSE
    )
    local_mocked_bindings(
      wholebrain_prepare_cerebellar_volume = function(...) {
        invisible("cer_vol.nii.gz")
      },
      create_cerebellar_from_volume = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )
    expect_messages(
      wholebrain_run_cerebellar(config, dirs, split, colortable),
      "Cerebellar pipeline"
    )
  })
})


describe("create_wholebrain_from_volume step 5 cerebellar", {
  it("runs cerebellar pipeline for step 5", {
    test_dir <- withr::local_tempdir()

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      setup_atlas_dirs = function(...) {
        list(
          base = test_dir,
          snapshots = test_dir,
          processed = test_dir,
          masks = test_dir
        )
      },
      load_or_run_step = function(step, steps, ...) {
        if (step %in% steps) {
          list(run = TRUE, data = list())
        } else {
          list(
            run = FALSE,
            data = list(
              "atlas_data.rds" = tibble(
                hemi = "left",
                region = "lobule_I",
                label = "lh_lobule_I",
                colour = "#00FF00",
                vertices = list(seq_len(10) - 1L),
                source_label = "lobule_I",
                source_idx = 1L
              ),
              "colortable.rds" = data.frame(
                idx = 1L,
                label = "lobule_I",
                R = 0L,
                G = 255L,
                B = 0L,
                A = 0L,
                roi = "0001",
                color = "#00FF00",
                stringsAsFactors = FALSE
              ),
              "label_split.rds" = list(
                cortical_labels = character(),
                subcortical_labels = character(),
                cerebellar_labels = "lobule_I",
                vertex_counts = c(lobule_I = 10L)
              )
            )
          )
        }
      },
      wholebrain_run_cerebellar = function(...) {
        structure(
          list(
            core = data.frame(
              stringsAsFactors = FALSE,
              hemi = NA,
              region = "lobule_I",
              label = "lobule_I"
            )
          ),
          class = "ggseg_atlas"
        )
      },
      log_elapsed = function(...) NULL
    )

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    result <- create_wholebrain_from_volume(
      input_volume = vol_file,
      steps = 5,
      verbose = FALSE,
      cleanup = FALSE
    )

    expect_null(result$cortical)
    expect_null(result$subcortical)
    expect_false(is.null(result$cerebellar))
  })
})
