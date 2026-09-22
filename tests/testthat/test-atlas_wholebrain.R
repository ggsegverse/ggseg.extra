.cap <- new.env()

local_fake_fsaverage <- function(
  n_vertices,
  faces,
  cortex,
  env = parent.frame()
) {
  tmp_dir <- withr::local_tempdir(.local_envir = env)
  subj_dir <- file.path(tmp_dir, "fsaverage5")
  dir.create(file.path(subj_dir, "surf"), recursive = TRUE)
  dir.create(file.path(subj_dir, "label"), recursive = TRUE)
  for (hemi in c("lh", "rh")) {
    writeLines(
      "placeholder",
      file.path(subj_dir, "surf", paste0(hemi, ".white"))
    )
    file.create(file.path(subj_dir, "label", paste0(hemi, ".cortex.label")))
  }
  local_mocked_bindings(
    fs_subj_dir = function() tmp_dir,
    .package = "freesurfer",
    .env = env
  )
  local_mocked_bindings(
    read.fs.surface = function(f) {
      list(vertices = matrix(0, nrow = n_vertices, ncol = 3), faces = faces)
    },
    .package = "freesurferformats",
    .env = env
  )
  local_mocked_bindings(
    read_label_vertices = function(...) cortex,
    .env = env
  )
  tmp_dir
}

# Capture the arguments the pipeline passes to mri_vol2surf, writing a
# stand-in overlay so the caller can read it back. Returns an environment
# whose `args` holds the arguments after `output_file`.
local_mock_mri_vol2surf <- function(overlay = c(1L, 2L), env = parent.frame()) {
  cap <- new.env()
  local_mocked_bindings(
    mri_vol2surf = function(input_file, output_file, ...) {
      cap$args <- list(...)
      RNifti::writeNifti(
        array(overlay, dim = c(length(overlay), 1, 1)),
        output_file
      )
    },
    .env = env
  )
  cap
}


# Pretend no FreeSurfer aseg is available, so the cortical context falls back
# to the solid silhouette without shelling out or warning.
local_no_aseg_ribbon <- function(env = parent.frame()) {
  local_mocked_bindings(
    aseg_context_volume = function(...) NULL,
    .env = env
  )
}

# A context volume in the shape aseg_context_volume() returns: left cortex
# where `left` is TRUE, right cortex where `right` is TRUE, 0 elsewhere.
mock_cortex_ribbon <- function(left, right) {
  ribbon <- array(0L, dim = dim(left))
  ribbon[left] <- 3L
  ribbon[right] <- 42L
  ribbon
}

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
    expect_warning(
      result <- wholebrain_classify_labels(ad, min_vertices = 50L),
      "by surface vertex count"
    )
    expect_true("region_a" %in% result$cortical_labels)
    expect_true("region_b" %in% result$cortical_labels)
    expect_length(result$subcortical_labels, 0)
  })

  it("classifies labels below threshold as subcortical", {
    ad <- make_atlas_data(
      c("region_a", "region_b"),
      c(10, 20)
    )
    expect_warning(
      result <- wholebrain_classify_labels(ad, min_vertices = 50L),
      "by surface vertex count"
    )
    expect_length(result$cortical_labels, 0)
    expect_true("region_a" %in% result$subcortical_labels)
    expect_true("region_b" %in% result$subcortical_labels)
  })

  it("splits labels correctly at threshold boundary", {
    ad <- make_atlas_data(
      c("big", "small", "exact"),
      c(100, 10, 50)
    )
    expect_warning(
      result <- wholebrain_classify_labels(ad, min_vertices = 50L),
      "by surface vertex count"
    )
    expect_true("big" %in% result$cortical_labels)
    expect_true("exact" %in% result$cortical_labels)
    expect_true("small" %in% result$subcortical_labels)
  })

  it("respects manual cortical_labels override", {
    ad <- make_atlas_data(
      c("region_a", "region_b"),
      c(10, 200)
    )
    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        cortical_labels = "region_a"
      ),
      "by surface vertex count"
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
    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        subcortical_labels = "region_a"
      ),
      "by surface vertex count"
    )
    expect_true("region_a" %in% result$subcortical_labels)
    expect_true("region_b" %in% result$cortical_labels)
  })

  it("manual overrides take precedence over auto-classification", {
    ad <- make_atlas_data(
      c("region_a", "region_b", "region_c"),
      c(100, 200, 5)
    )
    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        cortical_labels = "region_c",
        subcortical_labels = "region_a"
      ),
      "by surface vertex count"
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
    expect_warning(
      result <- wholebrain_classify_labels(ad, min_vertices = 50L),
      "by surface vertex count"
    )
    expect_true("r" %in% result$cortical_labels)
  })

  it("returns vertex_counts in result", {
    ad <- make_atlas_data(c("a", "b"), c(100, 10))
    expect_warning(
      result <- wholebrain_classify_labels(ad, min_vertices = 50L),
      "by surface vertex count"
    )
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
    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        cerebellar_labels = c("cerebellum_left", "cerebellum_right")
      ),
      "by surface vertex count"
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
    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        cerebellar_labels = "b"
      ),
      "by surface vertex count"
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
    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        colortable = ct,
        min_vertices = 50L
      ),
      "by surface vertex count"
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
    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        colortable = ct,
        min_vertices = 50L,
        cerebellar_labels = c("lobule_I", "lobule_II")
      ),
      "by surface vertex count"
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
      expect_warning(
        {
          result <- create_wholebrain_from_volume(
            input_volume = vol_file,
            steps = 1:2,
            verbose = FALSE
          )
        },
        "No color lookup table"
      ),
      "by surface vertex count"
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
    expect_snapshot(
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE)
    )
  })

  it("prints subcortical detail when subcortical labels exist", {
    ad <- make_atlas_data_v(c("big", "tiny"), c(200, 5))
    expect_snapshot(
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE)
    )
  })

  it("does not print subcortical detail when all cortical", {
    ad <- make_atlas_data_v(c("big", "bigger"), c(200, 300))
    expect_snapshot(
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE)
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

    vol_file <- file.path(test_dir, "wb.nii.gz")
    file.create(vol_file)

    expect_snapshot(
      invisible(create_wholebrain_from_volume(
        input_volume = vol_file,
        steps = 1:4,
        verbose = TRUE,
        cleanup = TRUE
      )),
      transform = scrub_volatile
    )

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

    vol_file <- file.path(test_dir, "wb.nii.gz")
    file.create(vol_file)

    expect_snapshot(
      invisible(create_wholebrain_from_volume(
        input_volume = vol_file,
        steps = 1:2,
        verbose = TRUE,
        cleanup = FALSE
      )),
      transform = scrub_volatile
    )

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

    expect_snapshot(
      result <- wholebrain_resolve_projection(config, dirs)
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

    expect_snapshot(
      result <- wholebrain_resolve_split(config, dirs, projection)
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

    expect_snapshot(
      result <- wholebrain_run_cortical(config, dirs, projection, split)
    )
    expect_s3_class(result, "ggseg_atlas")
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

    expect_snapshot(
      result <- wholebrain_run_subcortical(
        config,
        dirs,
        split,
        colortable = colortable
      )
    )
    expect_s3_class(result, "ggseg_atlas")
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

  it("keeps subcortical labels off the brain-outline indices", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )

    .cap$captured_lut <- NULL
    .cap$captured <- NULL
    colortable <- data.frame(
      idx = c(3L, 42L, 60L),
      label = c("amygdala", "pallidum", "cortical_a"),
      R = c(255L, 0L, 0L),
      G = c(0L, 255L, 0L),
      B = c(0L, 0L, 255L),
      A = c(0L, 0L, 0L),
      roi = c("0003", "0042", "0060"),
      color = c("#FF0000", "#00FF00", "#0000FF"),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      write_lut = function(ct, ...) {
        .cap$captured_lut <- ct
        invisible(NULL)
      },
      wholebrain_prepare_subcortical_volume = function(...) {
        .cap$captured <- list(...)
        invisible("filtered.nii.gz")
      },
      create_subcortical_from_volume = function(...) {
        structure(
          list(
            core = data.frame(stringsAsFactors = FALSE, region = "amygdala")
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
    split <- list(subcortical_labels = c("amygdala", "pallidum"))

    wholebrain_run_subcortical(config, dirs, split, colortable = colortable)

    expect_false(any(.cap$captured_lut$idx %in% SUBCORT_RESERVED_IDX))
    expect_identical(.cap$captured$subcortical_idx, c(3L, 42L))
    expect_identical(.cap$captured$target_idx, .cap$captured_lut$idx)
  })
})


describe("create_wholebrain_from_volume integration", {
  it("projects native-space volume and classifies labels", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    expect_warning(
      result <- create_wholebrain_from_volume(
        input_volume = vol_file,
        input_lut = lut_file,
        projection_opts = list(registration = "header"),
        steps = 1:2,
        verbose = FALSE
      ),
      "by surface vertex count"
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
    local_fake_fsaverage(
      n_vertices = 5L,
      faces = matrix(c(1L, 2L, 3L), nrow = 1),
      cortex = 0:2
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
    local_fake_fsaverage(
      n_vertices = 6L,
      faces = matrix(c(1L, 2L, 3L), nrow = 1),
      cortex = c(0L, 2L, 4L)
    )

    mask <- load_cortex_mask("lh", n_vertices = 6L, subject = "fsaverage5")
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
      load_cortex_mask("lh", n_vertices = 10L, subject = "fsaverage5"),
      "Cortex label not found"
    )
  })
})


describe("fill_surface_labels with cortex mask", {
  it("does not dilate into medial wall vertices", {
    local_fake_fsaverage(
      n_vertices = 6L,
      faces = matrix(
        c(1L, 2L, 3L, 3L, 4L, 5L, 5L, 6L, 1L),
        nrow = 3,
        byrow = TRUE
      ),
      cortex = 0:2
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

    vol_file <- file.path(test_dir, "wb.nii.gz")
    file.create(vol_file)

    expect_snapshot(
      invisible(create_wholebrain_from_volume(
        input_volume = vol_file,
        steps = 1:2,
        verbose = TRUE
      )),
      transform = scrub_volatile
    )
  })
})


describe("create_wholebrain_from_volume verbose LUT path", {
  it("prints LUT path when verbose and input_lut is not NULL", {
    test_dir <- withr::local_tempdir()
    sub_dir <- file.path(test_dir, "wb_lut_verbose")
    dir.create(sub_dir)

    vol_file <- file.path(test_dir, "wb.nii.gz")
    file.create(vol_file)
    lut_file <- file.path(test_dir, "lut.txt")
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
      volume_label_ids = function(...) 1L,
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

    expect_snapshot(
      invisible(create_wholebrain_from_volume(
        input_volume = vol_file,
        input_lut = lut_file,
        steps = 1:2,
        verbose = TRUE
      )),
      transform = scrub_volatile
    )
  })
})


describe("keep_labels_in_volume", {
  lut <- data.frame(
    idx = c(10L, 17L, 49L, 2000L),
    label = c("Left-Thalamus", "Left-Hippocampus", "Right-Thalamus", "Absent"),
    stringsAsFactors = FALSE
  )

  it("drops colour table entries the volume never carries", {
    kept <- keep_labels_in_volume(lut, c(10L, 49L))

    expect_identical(kept$idx, c(10L, 49L))
  })

  it("reports how many entries were dropped when verbose", {
    expect_message(
      keep_labels_in_volume(lut, c(10L, 49L), verbose = TRUE),
      "Dropped 2 colour table entries"
    )
  })

  it("errors when no colour table entry matches the volume", {
    expect_error(
      keep_labels_in_volume(lut, 3L),
      "No matching labels"
    )
  })
})


describe("load_volume_colortable", {
  it("reads the volume once and returns its labels with the filtered table", {
    local_mocked_bindings(
      read_volume = function(...) array(c(0L, 49L, 10L, 49L), dim = c(2, 2, 1))
    )
    lut <- data.frame(
      idx = c(10L, 49L, 2000L),
      label = c("a", "b", "absent"),
      R = 0L,
      G = 0L,
      B = 0L,
      A = 0L,
      stringsAsFactors = FALSE
    )

    loaded <- load_volume_colortable(lut, "vol.mgz")

    expect_identical(loaded$vol_labels, c(10L, 49L))
    expect_identical(loaded$colortable$idx, c(10L, 49L))
  })

  it("generates a colour table from the volume when none is given", {
    local_mocked_bindings(
      read_volume = function(...) array(c(0L, 49L, 10L, 49L), dim = c(2, 2, 1))
    )

    expect_warning(
      loaded <- load_volume_colortable(NULL, "vol.mgz"),
      "No color lookup table"
    )

    expect_identical(loaded$vol_labels, c(10L, 49L))
    expect_identical(loaded$colortable$label, c("region_0010", "region_0049"))
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
      write_projection_volume = function(input_volume, ...) input_volume,
      mri_vol2surf = function(...) invisible(NULL),
      mask_to_cortex = function(overlay, ...) overlay,
      fill_surface_labels = function(overlay, ...) overlay
    )

    expect_error(
      wholebrain_project_to_surface(
        input_volume = vol_file,
        colortable = colortable,
        subject = "fsaverage5",
        projfrac = 0.5,
        projfrac_range = NULL,
        registration = "header",
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
      write_projection_volume = function(input_volume, ...) input_volume,
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(1L, 5), rep(0L, 5))
        RNifti::writeNifti(array(values, dim = c(10, 1, 1)), output_file)
      },
      mask_to_cortex = function(overlay, ...) overlay,
      fill_surface_labels = function(overlay, ...) {
        overlay[overlay == 0L] <- 1L
        overlay
      }
    )

    expect_snapshot(
      result <- wholebrain_project_to_surface(
        input_volume = "fake.nii.gz",
        colortable = colortable,
        subject = "fsaverage5",
        projfrac = 0.5,
        projfrac_range = NULL,
        registration = "header",
        output_dir = tmp_dir,
        verbose = TRUE
      )
    )
    expect_identical(result$hemi, c("left", "right"))
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
      write_projection_volume = function(input_volume, ...) input_volume,
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(1L, 3), rep(99L, 2), rep(0L, 5))
        RNifti::writeNifti(array(values, dim = c(10, 1, 1)), output_file)
      },
      mask_to_cortex = function(overlay, ...) overlay,
      fill_surface_labels = function(overlay, ...) overlay
    )

    result <- wholebrain_project_to_surface(
      input_volume = "fake.nii.gz",
      colortable = colortable,
      subject = "fsaverage5",
      projfrac = 0.5,
      projfrac_range = NULL,
      registration = "header",
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
      write_projection_volume = function(input_volume, ...) input_volume,
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(1L, 5), rep(0L, 5))
        RNifti::writeNifti(array(values, dim = c(10, 1, 1)), output_file)
      },
      mask_to_cortex = function(overlay, ...) overlay,
      fill_surface_labels = function(overlay, ...) overlay
    )

    result <- wholebrain_project_to_surface(
      input_volume = "fake.nii.gz",
      colortable = colortable,
      subject = "fsaverage5",
      projfrac = 0.5,
      projfrac_range = NULL,
      registration = "header",
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

    expect_snapshot(
      result <- wholebrain_run_cortical(config, dirs, projection, split)
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
        "cortical_opts",
        c("views", "tolerance")
      ),
      "Unknown .*cortical_opts.* entr"
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
      "Unknown .*cortical_opts.* entr"
    )
  })

  it("rejects unknown cortical_opts entries", {
    expect_error(
      validate_wholebrain_opts(
        cortical_opts = list(bogus = TRUE),
        subcortical_opts = list(),
        cerebellar_opts = list()
      ),
      "Unknown .*cortical_opts.* entr"
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
    expect_snapshot(
      wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        cerebellar_labels = "lobule_I",
        verbose = TRUE
      )
    )
  })

  it("warns loudly when it falls back to the vertex count", {
    ad <- make_atlas_data_v(c("big", "small"), c(100, 10))
    expect_warning(
      wholebrain_classify_labels(ad, min_vertices = 50L),
      "Classified 2 labels by surface vertex count"
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
      mask_to_cortex = function(overlay, ...) overlay,
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
    expect_message(
      result <- fill_missing_rgb(ct, "test"),
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
    expect_message(
      result <- fill_missing_rgb(ct, "test"),
      "Auto-generating colours for 2 test regions"
    )
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
    local_no_aseg_ribbon()
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

  it("writes subcortical voxels under their target index", {
    skip_if_not_installed("RNifti")
    local_no_aseg_ribbon()
    vol <- array(0L, dim = c(6, 3, 3))
    vol[1, 1, 1] <- 3L
    vol[3, 1, 1] <- 20L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 3L,
      cortical_idx = 20L,
      output_file = out_file,
      target_idx = 101L
    )

    result <- drop(as.array(RNifti::readNifti(out_file)))
    expect_identical(result[1, 1, 1], 101L)
    expect_true(result[3, 1, 1] %in% c(3L, 42L))
  })
})


describe("reindex_reserved_subcort_idx", {
  it("leaves a colliding-free colortable untouched", {
    ct <- data.frame(
      idx = c(10L, 20L, 30L),
      label = c("a", "b", "c"),
      stringsAsFactors = FALSE
    )
    result <- reindex_reserved_subcort_idx(ct, verbose = FALSE)
    expect_identical(result$idx, ct$idx)
    expect_identical(result$source_idx, ct$idx)
  })

  it("moves indices reserved for the brain outline", {
    ct <- data.frame(
      idx = c(3L, 10L, 42L, 16L),
      label = c("amygdala", "putamen", "pallidum", "thalamus"),
      stringsAsFactors = FALSE
    )
    result <- reindex_reserved_subcort_idx(ct, verbose = FALSE)
    expect_false(any(result$idx %in% SUBCORT_RESERVED_IDX))
    expect_identical(result$source_idx, ct$idx)
    expect_identical(result$idx[2], 10L)
    expect_identical(anyDuplicated(result$idx), 0L)
    expect_identical(result$label, ct$label)
  })

  it("never reuses an index the colortable already holds", {
    ct <- data.frame(
      idx = c(3L, 1L, 2L, 4L, 5L),
      label = letters[1:5],
      stringsAsFactors = FALSE
    )
    result <- reindex_reserved_subcort_idx(ct, verbose = FALSE)
    expect_identical(anyDuplicated(result$idx), 0L)
    expect_false(result$idx[1] %in% SUBCORT_RESERVED_IDX)
    expect_identical(result$idx[-1], ct$idx[-1])
  })

  it("reports the reindexed labels when verbose", {
    ct <- data.frame(
      idx = c(3L, 10L),
      label = c("amygdala", "putamen"),
      stringsAsFactors = FALSE
    )
    expect_message(
      reindex_reserved_subcort_idx(ct, verbose = TRUE),
      "amygdala"
    )
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
    expect_snapshot(
      result <- wholebrain_run_cerebellar(config, dirs, split, colortable)
    )
    expect_s3_class(result, "ggseg_atlas")
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


describe("wholebrain_log_summary", {
  it("counts present atlases and reports absent ones as zero", {
    withr::local_options(width = 200)
    subcortical <- structure(
      list(
        core = data.frame(
          region = c("thalamus", "putamen"),
          stringsAsFactors = FALSE
        )
      ),
      class = "ggseg_atlas"
    )
    cerebellar <- structure(
      list(core = data.frame(region = "lobule_I", stringsAsFactors = FALSE)),
      class = "ggseg_atlas"
    )

    expect_snapshot(
      result <- wholebrain_log_summary(
        cortical_atlas = NULL,
        subcortical_atlas = subcortical,
        cerebellar_atlas = cerebellar,
        start_time = Sys.time()
      ),
      transform = scrub_volatile
    )
    expect_null(result)
  })
})


describe("wholebrain_refine_cortical_projection verbose", {
  it("logs progress steps when verbose is enabled", {
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
    config <- list(verbose = TRUE, subject = "fsaverage5")
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
      mask_to_cortex = function(overlay, ...) overlay,
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
    expect_snapshot(
      result <- wholebrain_refine_cortical_projection(
        config,
        dirs,
        projection,
        split
      ),
      transform = scrub_volatile
    )
    expect_true(all(result$atlas_data$source_label == "cortex"))
  })
})


describe("wholebrain_cerebellar_to_suit", {
  cer_config <- function(space) {
    list(verbose = FALSE, cerebellar_space = space)
  }

  it("leaves a volume already in SUIT space alone", {
    dirs <- list(base = withr::local_tempdir())

    expect_identical(
      wholebrain_cerebellar_to_suit("cer.nii.gz", cer_config("suit"), dirs),
      "cer.nii.gz"
    )
  })

  it("does not transform when the config never set a space", {
    dirs <- list(base = withr::local_tempdir())

    expect_identical(
      wholebrain_cerebellar_to_suit("cer.nii.gz", list(verbose = FALSE), dirs),
      "cer.nii.gz"
    )
  })

  it("transforms an MNI volume with the matching deformation field", {
    dirs <- list(base = withr::local_tempdir())
    .cap$captured <- NULL
    .cap$template <- NULL
    # Separate slots on purpose: transform_mni_to_suit() forces its own
    # arguments, so the deformation-field call runs partway through the
    # capture and one shared slot would overwrite the other.
    local_mocked_bindings(
      suit_deformation_field = function(template, ...) {
        .cap$template <- template
        "xfm.nii"
      },
      transform_mni_to_suit = function(...) {
        .cap$captured <- list(...)
        invisible(list(...)$output_file)
      }
    )

    out <- wholebrain_cerebellar_to_suit(
      "cer.nii.gz",
      cer_config("MNI152NLin6AsymC"),
      dirs
    )

    expect_identical(.cap$template, "MNI152NLin6AsymC")
    expect_identical(.cap$captured$deformation_field, "xfm.nii")
    expect_identical(.cap$captured$input_volume, "cer.nii.gz")
    expect_identical(out, .cap$captured$output_file)
    expect_match(out, "cerebellar_volume_suit\\.nii\\.gz$")
  })

  it("resamples a label volume by nearest neighbour, never by blending", {
    dirs <- list(base = withr::local_tempdir())
    .cap$captured <- NULL
    local_mocked_bindings(
      suit_deformation_field = function(...) "xfm.nii",
      transform_mni_to_suit = function(...) {
        .cap$captured <- list(...)
        invisible(list(...)$output_file)
      }
    )

    wholebrain_cerebellar_to_suit(
      "cer.nii.gz",
      cer_config("MNI152NLin2009cSymC"),
      dirs
    )

    expect_identical(.cap$captured$interpolation, "nearest")
  })

  it("says which space it is assuming when verbose", {
    dirs <- list(base = withr::local_tempdir())

    expect_message(
      wholebrain_cerebellar_to_suit(
        "cer.nii.gz",
        list(verbose = TRUE, cerebellar_space = "suit"),
        dirs
      ),
      "already in SUIT space"
    )
  })
})

describe("wholebrain_run_cerebellar space handling", {
  it("hands the transformed volume to create_cerebellar_from_volume", {
    test_dir <- withr::local_tempdir()
    dirs <- list(
      base = test_dir,
      snapshots = test_dir,
      processed = test_dir,
      masks = test_dir
    )
    colortable <- data.frame(
      idx = 2L,
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
      cleanup = FALSE,
      cerebellar_space = "MNI152NLin6AsymC"
    )
    .cap$captured <- NULL
    local_mocked_bindings(
      wholebrain_prepare_cerebellar_volume = function(...) {
        invisible("cer_vol.nii.gz")
      },
      wholebrain_cerebellar_to_suit = function(...) "cer_vol_suit.nii.gz",
      create_cerebellar_from_volume = function(...) {
        .cap$captured <- list(...)
        structure(list(), class = "ggseg_atlas")
      }
    )

    wholebrain_run_cerebellar(config, dirs, split, colortable)

    expect_identical(.cap$captured$input_volume, "cer_vol_suit.nii.gz")
  })
})

describe("wholebrain_prepare_cerebellar_volume orientation", {
  it("reorients non-RAS output to RAS", {
    skip_if_not_installed("RNifti")
    vol <- array(0L, dim = c(5, 5, 5))
    vol[1, 1, 1] <- 1L
    nii <- RNifti::asNifti(vol)
    m <- diag(c(-1, 1, 1, 1))
    m[1, 4] <- 4
    RNifti::sform(nii) <- structure(m, code = 2L)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(nii, vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_cerebellar_volume(
      input_volume = vol_file,
      cerebellar_idx = 1L,
      output_file = out_file
    )

    out <- RNifti::readNifti(out_file)
    expect_identical(RNifti::orientation(out), "RAS")
    expect_true(1L %in% as.array(out))
  })
})


describe("wholebrain_prepare_subcortical_volume left-high", {
  it("handles a negative x-axis xform and reorients output to RAS", {
    skip_if_not_installed("RNifti")
    local_no_aseg_ribbon()
    vol <- array(0L, dim = c(6, 3, 3))
    vol[1, 1, 1] <- 10L
    vol[6, 1, 1] <- 20L
    nii <- RNifti::asNifti(vol)
    m <- diag(c(-1, 1, 1, 1))
    m[1, 4] <- 5
    RNifti::sform(nii) <- structure(m, code = 2L)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(nii, vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = 20L,
      output_file = out_file
    )

    out <- RNifti::readNifti(out_file)
    expect_identical(RNifti::orientation(out), "RAS")
    arr <- as.array(out)
    expect_true(10L %in% arr)
    expect_true(any(arr %in% c(3L, 42L)))
  })

  it("splits cortex at the 1-based midline voxel", {
    skip_if_not_installed("RNifti")
    local_no_aseg_ribbon()
    # 5 cortical voxels along x (3x3 in y/z so read_volume keeps it 3D);
    # world_x = voxel_x - 2, so the world origin sits at 0-based voxel 2
    # (1-based voxel 3).
    arr <- array(1000L, dim = c(5, 3, 3))
    nii <- RNifti::asNifti(arr)
    m <- diag(4)
    m[1, 4] <- -2
    RNifti::sform(nii) <- structure(m, code = 2L)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(nii, vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    arr_out <- as.array(RNifti::readNifti(out_file))
    # Midline is 1-based voxel 3: x-slices 1-3 left (3L), 4-5 right (42L),
    # each slice holding 3x3 = 9 voxels. The pre-fix 0-based midline (2)
    # would have given 18 left / 27 right.
    expect_identical(sum(arr_out == 3L), 27L)
    expect_identical(sum(arr_out == 42L), 18L)
  })
})


describe("fill_surface_labels stalled dilation", {
  it("breaks when no unlabeled vertex has a labeled neighbor", {
    local_fake_fsaverage(
      n_vertices = 4L,
      faces = matrix(c(1L, 2L, 3L, 3L, 4L, 1L), nrow = 2, byrow = TRUE),
      cortex = 0:3
    )

    overlay <- c(0L, 0L, 0L, 0L)
    result <- fill_surface_labels(overlay, "lh", "fsaverage5")
    expect_identical(result, overlay)
  })
})


describe("zero_unlisted_labels", {
  it("zeros ids missing from the lookup table and keeps listed ones", {
    expect_identical(
      zero_unlisted_labels(c(0L, 1L, 45L, 2L), 1:2),
      c(0L, 1L, 0L, 2L)
    )
  })

  it("keeps array dimensions", {
    labels <- array(c(1L, 45L, 2L, 45L), dim = c(2, 2, 1))
    result <- zero_unlisted_labels(labels, 1:2)
    expect_identical(dim(result), c(2L, 2L, 1L))
    expect_identical(sum(result == 0L), 2L)
  })
})


describe("write_projection_volume", {
  labels <- array(c(1L, 45L, 2L, 0L, 45L, 1L, 2L, 2L), dim = c(2, 2, 2))
  expected <- c(1L, 0L, 2L, 0L, 0L, 1L, 2L, 2L)

  it("returns the input and writes nothing when every id is listed", {
    skip_if_not_installed("RNifti")
    skip_if_not_installed("freesurferformats")
    source_dir <- withr::local_tempdir()
    output_dir <- withr::local_tempdir()
    listed <- zero_unlisted_labels(labels, 1:2)
    nifti_file <- file.path(source_dir, "labels.nii.gz")
    RNifti::writeNifti(RNifti::asNifti(listed), nifti_file)
    mgz_file <- file.path(source_dir, "labels.mgz")
    freesurferformats::write.fs.mgh(mgz_file, listed)

    expect_identical(
      write_projection_volume(nifti_file, 1:2, output_dir),
      nifti_file
    )
    expect_identical(
      write_projection_volume(mgz_file, 1:2, output_dir),
      mgz_file
    )
    expect_length(list.files(output_dir), 0L)
  })

  it("writes a NIfTI copy with unlisted ids zeroed and the transform kept", {
    skip_if_not_installed("RNifti")
    tmp <- withr::local_tempdir()
    source_image <- RNifti::asNifti(labels)
    RNifti::pixdim(source_image) <- c(1.5, 1.5, 1.5)
    source_file <- file.path(tmp, "labels.nii.gz")
    RNifti::writeNifti(source_image, source_file)

    output <- write_projection_volume(source_file, 1:2, tmp)
    result <- RNifti::readNifti(output)

    expect_identical(basename(output), "projection_volume.nii")
    expect_identical(as.integer(result), expected)
    expect_equal(
      RNifti::xform(result),
      RNifti::xform(RNifti::readNifti(source_file)),
      ignore_attr = TRUE
    )
  })

  it("writes an MGZ copy with the voxel-to-world transform kept", {
    skip_if_not_installed("freesurferformats")
    tmp <- withr::local_tempdir()
    vox2ras <- matrix(
      c(-1.5, 0, 0, 0, 0, 1.5, 0, 0, 0, 0, 1.5, 0, 90, -126, -72, 1),
      nrow = 4
    )
    source_file <- file.path(tmp, "labels.mgz")
    freesurferformats::write.fs.mgh(
      source_file,
      labels,
      vox2ras_matrix = vox2ras
    )

    output <- write_projection_volume(source_file, 1:2, tmp)
    result <- freesurferformats::read.fs.mgh(output, with_header = TRUE)

    expect_identical(basename(output), "projection_volume.mgh")
    expect_identical(as.integer(result$data), expected)
    expect_equal(
      freesurferformats::mghheader.vox2ras(result$header),
      vox2ras,
      ignore_attr = TRUE
    )
  })

  it("leaves an MGZ without RAS information without it", {
    skip_if_not_installed("freesurferformats")
    tmp <- withr::local_tempdir()
    source_file <- file.path(tmp, "labels.mgz")
    freesurferformats::write.fs.mgh(source_file, labels)

    output <- write_projection_volume(source_file, 1:2, tmp)
    result <- freesurferformats::read.fs.mgh(output, with_header = TRUE)

    expect_identical(as.integer(result$data), expected)
    expect_false(freesurferformats::mghheader.is.ras.valid(result$header))
  })

  it("keeps a non-RAS NIfTI orientation and its header codes", {
    skip_if_not_installed("RNifti")
    tmp <- withr::local_tempdir()
    xform <- structure(
      matrix(
        c(-1.5, 0, 0, 0, 0, 1.5, 0, 0, 0, 0, 1.5, 0, 90, -126, -72, 1),
        nrow = 4
      ),
      code = 4L
    )
    source_image <- RNifti::asNifti(labels)
    RNifti::qform(source_image) <- xform
    RNifti::sform(source_image) <- xform
    source_file <- file.path(tmp, "labels.nii.gz")
    RNifti::writeNifti(source_image, source_file)

    output <- write_projection_volume(source_file, 1:2, tmp)
    source_header <- RNifti::niftiHeader(RNifti::readNifti(source_file))
    result <- RNifti::readNifti(output)
    result_header <- RNifti::niftiHeader(result)

    expect_identical(RNifti::orientation(result), "LAS")
    expect_identical(as.integer(result), expected)
    for (field in c("qform_code", "sform_code", "srow_x", "srow_y", "srow_z")) {
      expect_identical(result_header[[field]], source_header[[field]])
    }
  })
})


describe("mask_to_cortex", {
  it("clears labelled vertices outside the cortex label", {
    local_fake_fsaverage(
      n_vertices = 6L,
      faces = matrix(c(1L, 2L, 3L), nrow = 1),
      cortex = 0:2
    )

    expect_identical(
      mask_to_cortex(c(1L, 0L, 2L, 5L, 5L, 5L), "lh", "fsaverage5"),
      c(1L, 0L, 2L, 0L, 0L, 0L)
    )
  })
})


describe("wholebrain_project_to_surface unlisted labels", {
  colortable <- data.frame(
    idx = 1:2,
    label = c("a", "b"),
    color = c("#FF0000", "#00FF00"),
    stringsAsFactors = FALSE
  )

  it("projects the lookup-table-only copy of the volume", {
    skip_if_not_installed("RNifti")
    tmp_dir <- withr::local_tempdir()
    .cap$kept_idx <- NULL
    .cap$projected <- NULL

    local_mocked_bindings(
      write_projection_volume = function(input_volume, keep_idx, output_dir) {
        .cap$kept_idx <- keep_idx
        file.path(output_dir, "projection_volume.nii")
      },
      mri_vol2surf = function(input_file, output_file, ...) {
        .cap$projected <- c(.cap$projected, input_file)
        RNifti::writeNifti(array(c(1L, 2L), dim = c(2, 1, 1)), output_file)
      },
      mask_to_cortex = function(overlay, ...) overlay,
      fill_surface_labels = function(overlay, ...) overlay
    )

    wholebrain_project_to_surface(
      input_volume = "labels.nii.gz",
      colortable = colortable,
      subject = "fsaverage5",
      projfrac = 0.5,
      projfrac_range = NULL,
      registration = "header",
      output_dir = tmp_dir,
      verbose = FALSE
    )

    expect_identical(.cap$kept_idx, 1:2)
    expect_identical(
      unique(basename(.cap$projected)),
      "projection_volume.nii"
    )
  })

  it("fills vertices carrying unlisted ids from their neighbours", {
    skip_if_not_installed("RNifti")
    output_dir <- withr::local_tempdir()
    local_fake_fsaverage(
      n_vertices = 4L,
      faces = matrix(c(1L, 2L, 3L, 2L, 3L, 4L), nrow = 2, byrow = TRUE),
      cortex = 0:3
    )
    local_mocked_bindings(
      write_projection_volume = function(input_volume, ...) input_volume
    )
    local_mock_mri_vol2surf(overlay = c(1L, 45L, 1L, 2L))

    result <- wholebrain_project_to_surface(
      input_volume = "labels.nii.gz",
      colortable = colortable,
      subject = "fsaverage5",
      projfrac = 0.5,
      projfrac_range = NULL,
      registration = "header",
      output_dir = output_dir,
      verbose = FALSE
    )

    left <- result[result$hemi == "left", ]
    expect_setequal(unlist(left$vertices), 0:3)
    expect_identical(left$vertices[[which(left$label == "lh_a")]], 0:2)
    expect_false("lh_unknown" %in% left$label)
  })
})


describe("refine_cortical_overlays unlisted labels", {
  it("zeros ids outside the cortical lookup table before refilling", {
    skip_if_not_installed("RNifti")
    tmp <- withr::local_tempdir()
    surf_dir <- file.path(tmp, "surface_overlays")
    dir.create(surf_dir)
    for (hemi in c("lh", "rh")) {
      RNifti::writeNifti(
        array(c(1L, 2L, 45L, 0L), dim = c(4, 1, 1)),
        file.path(surf_dir, paste0(hemi, "_overlay.nii.gz"))
      )
    }
    .cap$fill_input <- list()
    local_mocked_bindings(
      mask_to_cortex = function(overlay, ...) overlay,
      fill_surface_labels = function(overlay, ...) {
        .cap$fill_input <- c(.cap$fill_input, list(overlay))
        overlay
      }
    )

    wholebrain_refine_cortical_projection(
      config = list(verbose = FALSE, subject = "fsaverage5"),
      dirs = list(base = tmp),
      projection = list(
        atlas_data = tibble(),
        colortable = data.frame(
          idx = 1:2,
          label = c("cortex", "thalamus"),
          stringsAsFactors = FALSE
        )
      ),
      split = list(
        subcortical_labels = "thalamus",
        cerebellar_labels = character(),
        cortical_labels = "cortex"
      )
    )

    expect_length(.cap$fill_input, 2L)
    expect_identical(.cap$fill_input[[1]], c(1L, 0L, 0L, 0L))
  })
})


describe("unknown context through the wholebrain split", {
  atlas_data <- tibble(
    hemi = "left",
    region = c("a", "unknown"),
    label = c("lh_a", "lh_unknown"),
    colour = c("#FF0000", "#BEBEBE"),
    vertices = list(0:99, 100:109),
    source_label = c("a", "unknown"),
    source_idx = c(1L, 0L)
  )
  colortable <- data.frame(
    idx = 1:2,
    label = c("a", "thalamus"),
    type = c("cortical", "subcortical"),
    color = c("#FF0000", "#0000FF"),
    stringsAsFactors = FALSE
  )

  it("is not classified as a region", {
    expect_warning(
      split <- wholebrain_classify_labels(atlas_data, min_vertices = 50L),
      "by surface vertex count"
    )

    expect_false(
      "unknown" %in%
        c(
          split$cortical_labels,
          split$subcortical_labels,
          split$cerebellar_labels
        )
    )
    expect_false("unknown" %in% names(split$vertex_counts))
  })

  it("reaches the cortical inputs when the LUT has a type column", {
    split <- wholebrain_classify_labels(
      atlas_data,
      colortable = colortable,
      min_vertices = 50L
    )

    prep <- wholebrain_cortical_inputs(
      config = list(
        atlas_name = "test",
        verbose = FALSE,
        skip_existing = FALSE
      ),
      dirs = list(base = withr::local_tempdir()),
      projection = list(atlas_data = atlas_data),
      split = split,
      opts = list()
    )

    expect_setequal(prep$data$label, c("lh_a", "lh_unknown"))
  })

  it("ends up as context geometry in the cortical atlas", {
    local_mocked_bindings(
      cortical_build_sf_projected = function(components, ...) {
        mock_context_sf(components$vertices_df$label)
      },
      warn_if_large_atlas = function(...) NULL,
      preview_atlas = function(...) NULL
    )

    atlas <- wholebrain_run_cortical(
      config = list(
        atlas_name = "test",
        verbose = FALSE,
        skip_existing = FALSE
      ),
      dirs = list(base = withr::local_tempdir()),
      projection = list(atlas_data = atlas_data),
      split = list(cortical_labels = "a")
    )

    expect_unknown_is_context(atlas, "lh_unknown")
    expect_identical(atlas$core$label, "lh_a")
  })
})


describe("wholebrain_vol2surf_overlay", {
  forward_to_vol2surf <- function(registration_args) {
    caller <- parent.frame()
    cap <- local_mock_mri_vol2surf(env = caller)

    wholebrain_vol2surf_overlay(
      input_volume = "labels.nii.gz",
      hemi_short = "lh",
      subject = "fsaverage5",
      projfrac = 0.5,
      projfrac_range = NULL,
      registration_args = registration_args,
      surf_dir = withr::local_tempdir(.local_envir = caller),
      verbose = FALSE
    )
    cap
  }

  it("passes a registration through with its source subject", {
    reg_file <- withr::local_tempfile(fileext = ".dat")
    file.create(reg_file)

    cap <- forward_to_vol2surf(resolve_vol2surf_registration(
      reg_file,
      "fsaverage5"
    ))

    expect_identical(cap$args$reg, reg_file)
    expect_identical(cap$args$srcsubject, "fsaverage5")
    expect_null(cap$args$regheader)
  })

  it("passes a header registration through", {
    cap <- forward_to_vol2surf(resolve_vol2surf_registration(
      "header",
      "fsaverage5"
    ))

    expect_null(cap$args$reg)
    expect_null(cap$args$srcsubject)
    expect_identical(cap$args$regheader, "fsaverage5")
  })

  it("keeps labels integer and listed when registering a real volume", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")
    colortable <- get_lut(lut_file)

    project <- function(registration) {
      wholebrain_vol2surf_overlay(
        input_volume = vol_file,
        hemi_short = "lh",
        subject = "fsaverage5",
        projfrac = 0.5,
        projfrac_range = c(0, 1, 0.1),
        registration_args = resolve_vol2surf_registration(
          registration,
          "fsaverage5"
        ),
        surf_dir = withr::local_tempdir(),
        verbose = FALSE
      )
    }

    overlay <- project("mni152")

    expect_true(all(setdiff(unique(overlay), 0L) %in% colortable$idx))
    expect_false(identical(overlay, project("header")))
  })
})


describe("write_registration_record", {
  it("records the registration the overlays were built with", {
    dir <- withr::local_tempdir()

    write_registration_record(
      dir,
      registration = "mni152",
      subject = "fsaverage5",
      args = list(
        reg = "/opt/freesurfer/average/mni152.register.dat",
        srcsubject = "fsaverage5",
        regheader = NULL
      )
    )
    record <- readLines(file.path(dir, "registration.txt"))

    expect_true(any(grepl("^registration: mni152$", record)))
    expect_true(any(grepl("^srcsubject: fsaverage5$", record)))
    expect_true(any(grepl("mni152.register.dat", record, fixed = TRUE)))
    expect_false(any(grepl("^regheader:", record)))
  })

  it("records a header registration without a source subject", {
    dir <- withr::local_tempdir()

    write_registration_record(
      dir,
      registration = "header",
      subject = "fsaverage5",
      args = list(reg = NULL, srcsubject = NULL, regheader = "fsaverage5")
    )
    record <- readLines(file.path(dir, "registration.txt"))

    expect_true(any(grepl("^registration: header$", record)))
    expect_true(any(grepl("^regheader: fsaverage5$", record)))
    expect_false(any(grepl("^reg:", record)))
  })
})


describe("registration_from_regheader", {
  it("maps TRUE to the header registration", {
    withr::local_options(lifecycle_verbosity = "quiet")

    expect_identical(
      registration_from_regheader(TRUE, registration_missing = TRUE),
      "header"
    )
  })

  it("maps FALSE to the MNI152 registration", {
    withr::local_options(lifecycle_verbosity = "quiet")

    expect_identical(
      registration_from_regheader(FALSE, registration_missing = TRUE),
      "mni152"
    )
  })

  it("warns that regheader is deprecated", {
    withr::local_options(lifecycle_verbosity = "warning")

    expect_warning(
      registration_from_regheader(TRUE, registration_missing = TRUE),
      class = "lifecycle_warning_deprecated"
    )
  })

  it("refuses to override an explicit registration", {
    expect_error(
      registration_from_regheader(TRUE, registration_missing = FALSE),
      "Cannot use both"
    )
  })

  it("refuses anything that is not a single TRUE or FALSE", {
    expect_error(
      registration_from_regheader(NA, registration_missing = TRUE),
      "must be"
    )
    expect_error(
      registration_from_regheader("yes", registration_missing = TRUE),
      "must be"
    )
    expect_error(
      registration_from_regheader(c(TRUE, FALSE), registration_missing = TRUE),
      "must be"
    )
  })
})


describe("create_wholebrain_from_volume(regheader = )", {
  it("errors when given alongside registration", {
    local_mocked_bindings(check_fs = function(abort = FALSE) invisible(TRUE))

    expect_error(
      create_wholebrain_from_volume(
        input_volume = "missing-volume.nii.gz",
        output_dir = withr::local_tempdir(),
        projection_opts = list(registration = "header"),
        regheader = FALSE,
        verbose = FALSE
      ),
      "Cannot use both"
    )
  })

  it("is deprecated in favour of registration", {
    # Deprecation *errors*, not warnings. lifecycle throttles an indirect
    # warning - one raised from inside the package rather than by the caller -
    # to once per session, and `lifecycle_verbosity = "warning"` does not lift
    # that. The direct call in the registration_from_regheader block above
    # spends it, so asserting a warning here passes or fails according to what
    # ran first. Errors carry no such budget.
    withr::local_options(lifecycle_verbosity = "error")
    local_mocked_bindings(check_fs = function(abort = FALSE) invisible(TRUE))

    expect_error(
      create_wholebrain_from_volume(
        input_volume = "missing-volume.nii.gz",
        output_dir = withr::local_tempdir(),
        regheader = TRUE,
        verbose = FALSE
      ),
      class = "lifecycle_error_deprecated"
    )
  })
})


describe("create_wholebrain_from_volume without FreeSurfer", {
  it("does not need FreeSurfer's transform when it never projects", {
    captured <- new.env()
    local_mocked_bindings(
      fs_dir = function(...) NA_character_,
      have_fs = function(...) FALSE,
      .package = "freesurfer"
    )
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      wholebrain_project_to_surface = function(...) {
        captured$projected <- TRUE
        dplyr::tibble(
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

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    vol <- RNifti::asNifti(array(1L, dim = c(2, 2, 2)))
    RNifti::qform(vol) <- structure(diag(c(-1, 1, 1, 1)), code = 4L)
    RNifti::writeNifti(vol, vol_file)

    expect_warning(
      result <- create_wholebrain_from_volume(
        input_volume = vol_file,
        output_dir = withr::local_tempdir(),
        steps = 1:2,
        verbose = FALSE
      ),
      "No color lookup table"
    )

    expect_true(captured$projected)
    expect_true("cortical_labels" %in% names(result))
  })
})


describe("wholebrain cortex context from the aseg ribbon", {
  it("keeps only the voxels the ribbon covers when the mantle is solid", {
    skip_if_not_installed("RNifti")
    arr <- array(1000L, dim = c(12, 5, 5))
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    # 300 cortical voxels against a 150-voxel ribbon: a solid mantle. The
    # ribbon is three voxels thick, so the grid can carry it.
    left <- right <- array(FALSE, dim = dim(arr))
    left[1:3, , ] <- TRUE
    right[10:12, , ] <- TRUE
    local_mocked_bindings(
      aseg_context_volume = function(...) mock_cortex_ribbon(left, right)
    )

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result == 3L), 75L)
    expect_identical(sum(result == 42L), 75L)
    # The six middle x-slices are cortex the ribbon does not cover: the
    # sulcal space that makes the silhouette read as a brain.
    expect_identical(sum(result == 0L), 150L)
  })

  it("never writes context over a structure", {
    skip_if_not_installed("RNifti")
    arr <- array(1000L, dim = c(8, 5, 5))
    arr[2, 2, 2] <- 10L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    ribbon <- array(0L, dim = dim(arr))
    ribbon[1:3, , ] <- 3L
    local_mocked_bindings(aseg_context_volume = function(...) ribbon)

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = 1000L,
      output_file = out_file,
      target_idx = 101L
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(result[2, 2, 2], 101L)
    expect_identical(sum(result == 3L), 74L)
  })

  it("keeps a cortical mask that is already a ribbon", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(6, 3, 3))
    arr[1:2, , ] <- 1000L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    ribbon <- array(3L, dim = dim(arr))
    local_mocked_bindings(aseg_context_volume = function(...) ribbon)

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    # Every cortical voxel is context and nothing else is, which is the
    # midline split this has always done.
    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result %in% c(3L, 42L)), 18L)
  })

  it("does not look for an aseg when the atlas has no cortex", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(4, 3, 3))
    arr[1, 1, 1] <- 10L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    seen <- new.env()
    seen$called <- FALSE
    local_mocked_bindings(
      aseg_context_volume = function(...) {
        seen$called <- TRUE
        NULL
      }
    )

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = integer(0),
      output_file = out_file
    )

    expect_false(seen$called)
    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result %in% c(3L, 42L)), 0L)
  })
})


describe("cortex_mask_is_solid", {
  it("calls a mantle several ribbons thick solid", {
    mask <- array(TRUE, dim = c(4, 4, 4))
    ribbon <- array(0L, dim = c(4, 4, 4))
    ribbon[1, , ] <- 3L
    expect_true(cortex_mask_is_solid(mask, ribbon, verbose = FALSE))
  })

  it("calls a mask no thicker than the ribbon a ribbon", {
    mask <- array(FALSE, dim = c(4, 4, 4))
    mask[1, , ] <- TRUE
    ribbon <- array(3L, dim = c(4, 4, 4))
    expect_false(cortex_mask_is_solid(mask, ribbon, verbose = FALSE))
  })

  it("says which way it decided when verbose", {
    mask <- array(FALSE, dim = c(4, 4, 4))
    mask[1, , ] <- TRUE
    ribbon <- array(3L, dim = c(4, 4, 4))
    expect_message(
      cortex_mask_is_solid(mask, ribbon, verbose = TRUE),
      "already a ribbon"
    )
  })

  it("survives an empty ribbon", {
    mask <- array(TRUE, dim = c(2, 2, 2))
    expect_true(
      cortex_mask_is_solid(mask, array(0L, dim = c(2, 2, 2)), verbose = FALSE)
    )
  })

  it("compares the ratio it measured, not a rounded one", {
    # 1.4951 ribbons' worth of voxels is not 1.5, however it prints.
    ribbon <- array(0L, dim = c(30, 30, 30))
    ribbon[1:10000] <- 3L
    mask <- array(FALSE, dim = dim(ribbon))
    mask[1:14951] <- TRUE
    expect_false(cortex_mask_is_solid(mask, ribbon, verbose = FALSE))
  })

  it("says so when the mantle is solid", {
    mask <- array(TRUE, dim = c(4, 4, 4))
    ribbon <- array(0L, dim = c(4, 4, 4))
    ribbon[1, , ] <- 3L
    expect_message(
      cortex_mask_is_solid(mask, ribbon, verbose = TRUE),
      "solid mantle"
    )
  })
})


describe("ribbon_interior_fraction", {
  it("is zero for a ribbon one voxel thick", {
    ribbon <- array(FALSE, dim = c(12, 5, 5))
    ribbon[1, , ] <- TRUE
    expect_identical(ribbon_interior_fraction(ribbon), 0)
  })

  it("counts the voxels with a full neighbourhood", {
    ribbon <- array(FALSE, dim = c(12, 5, 5))
    ribbon[1:3, , ] <- TRUE
    # Only x = 2 has ribbon either side of it, and only the 3 x 3 core of
    # the slice has ribbon above, below and beside it.
    expect_identical(ribbon_interior_fraction(ribbon), 9 / 75)
  })

  it("is zero for an empty ribbon", {
    expect_identical(
      ribbon_interior_fraction(array(FALSE, dim = c(4, 4, 4))),
      0
    )
  })

  it("is zero when an axis is too short to have an interior", {
    ribbon <- array(TRUE, dim = c(4, 4, 1))
    expect_identical(ribbon_interior_fraction(ribbon), 0)
  })
})


describe("ribbon_is_resolved", {
  it("accepts a ribbon that is a voxel thick through itself", {
    aseg <- array(0L, dim = c(12, 5, 5))
    aseg[1:3, , ] <- 3L
    expect_true(ribbon_is_resolved(aseg, verbose = FALSE))
  })

  it("declines a ribbon the grid has flattened to a sheet", {
    aseg <- array(0L, dim = c(12, 5, 5))
    aseg[1, , ] <- 3L
    aseg[12, , ] <- 42L
    expect_false(ribbon_is_resolved(aseg, verbose = FALSE))
  })

  it("takes the threshold itself as resolved", {
    aseg <- array(0L, dim = c(12, 5, 5))
    aseg[1:3, , ] <- 3L
    expect_true(ribbon_is_resolved(aseg, verbose = FALSE, min_interior = 0.12))
    expect_false(ribbon_is_resolved(aseg, verbose = FALSE, min_interior = 0.13))
  })

  it("ignores the posterior fossa labels, which are not cortex", {
    aseg <- array(8L, dim = c(12, 5, 5))
    aseg[1, , ] <- 3L
    expect_false(ribbon_is_resolved(aseg, verbose = FALSE))
  })

  it("says which way it decided when verbose", {
    coarse <- array(0L, dim = c(12, 5, 5))
    coarse[1, , ] <- 3L
    expect_message(
      ribbon_is_resolved(coarse, verbose = TRUE),
      "too coarse"
    )

    fine <- array(0L, dim = c(12, 5, 5))
    fine[1:3, , ] <- 3L
    expect_message(
      ribbon_is_resolved(fine, verbose = TRUE),
      "Taking the silhouette from the resampled"
    )
  })
})


describe("wholebrain cortex context on a coarse grid", {
  it("keeps the atlas's own labels when the ribbon is a sheet", {
    skip_if_not_installed("RNifti")
    arr <- array(1000L, dim = c(12, 5, 5))
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    # A solid mantle six times the ribbon, but a ribbon one voxel thick:
    # what a 4 mm parcellation resamples the aseg into.
    left <- right <- array(FALSE, dim = dim(arr))
    left[1, , ] <- TRUE
    right[12, , ] <- TRUE
    local_mocked_bindings(
      aseg_context_volume = function(...) mock_cortex_ribbon(left, right)
    )

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result %in% c(3L, 42L)), 300L)
    expect_identical(sum(result == 0L), 0L)
  })
})


describe("aseg_volume_path", {
  it("warns and returns NULL without FreeSurfer", {
    local_mocked_bindings(have_fs_quietly = function() FALSE)
    expect_warning(
      expect_null(aseg_volume_path("cvs_avg35_inMNI152")),
      "FreeSurfer is not available"
    )
  })

  it("warns and returns NULL when the subject has no aseg", {
    subj_dir <- withr::local_tempdir()
    local_mocked_bindings(have_fs_quietly = function() TRUE)
    local_mocked_bindings(
      fs_subj_dir = function() subj_dir,
      .package = "freesurfer"
    )
    expect_warning(
      expect_null(aseg_volume_path("nosuchsubject")),
      "does not exist"
    )
  })

  it("returns the path when the aseg is there", {
    subj_dir <- withr::local_tempdir()
    mri <- file.path(subj_dir, "subj", "mri")
    dir.create(mri, recursive = TRUE)
    file.create(file.path(mri, "aseg.mgz"))
    local_mocked_bindings(have_fs_quietly = function() TRUE)
    local_mocked_bindings(
      fs_subj_dir = function() subj_dir,
      .package = "freesurfer"
    )
    expect_identical(
      aseg_volume_path("subj"),
      as.character(fs::path(mri, "aseg.mgz"))
    )
  })
})


describe("aseg_context_volume resampling", {
  it("warns and falls back when the resampling fails", {
    local_mocked_bindings(
      run_cmd = function(cmd, ...) cli::cli_abort("boom")
    )
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")

    expect_warning(
      expect_null(aseg_context_volume(
        "a.nii.gz",
        "subj",
        c(2L, 2L, 2L),
        array(TRUE, c(2, 2, 2))
      )),
      "mri_vol2vol"
    )
  })
})


describe("aseg_context_volume", {
  it("returns NULL when there is no aseg to resample", {
    local_mocked_bindings(aseg_volume_path = function(...) NULL)
    expect_null(
      aseg_context_volume(
        "a.nii.gz",
        "subj",
        c(2L, 2L, 2L),
        array(TRUE, c(2, 2, 2))
      )
    )
  })

  it("warns and returns NULL when the resampled grid differs", {
    skip_if_not_installed("RNifti")
    resampled <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(array(3L, dim = c(2, 2, 2))), resampled)
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")
    local_mocked_bindings(resample_volume_to_grid = function(...) resampled)

    expect_warning(
      expect_null(aseg_context_volume(
        "a.nii.gz",
        "subj",
        c(3L, 3L, 3L),
        array(TRUE, c(3, 3, 3))
      )),
      "does not share the volume's grid"
    )
  })

  it("keeps the cortex and posterior fossa indices and nothing else", {
    skip_if_not_installed("RNifti")
    aseg <- array(0L, dim = c(2, 2, 2))
    aseg[1, 1, 1] <- 3L
    aseg[2, 1, 1] <- 42L
    aseg[1, 2, 1] <- 8L
    aseg[2, 2, 1] <- 16L
    # Cerebellar white matter and an unrelated structure are dropped.
    aseg[1, 1, 2] <- 7L
    aseg[2, 1, 2] <- 17L
    resampled <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(aseg), resampled)
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")
    local_mocked_bindings(resample_volume_to_grid = function(...) resampled)

    context <- aseg_context_volume(
      "a.nii.gz",
      "subj",
      c(2L, 2L, 2L),
      array(TRUE, c(2, 2, 2))
    )
    expect_identical(
      sort(unique(as.vector(context))),
      c(0L, 3L, 8L, 16L, 42L)
    )
    expect_identical(context[1, 1, 2], 0L)
    expect_identical(context[2, 1, 2], 0L)
  })

  it("judges the space on the cortical ribbon, not the posterior fossa", {
    skip_if_not_installed("RNifti")
    # The fossa is wanted exactly where the atlas has nothing, so an atlas
    # labelling grey matter only - MarsAtlas - fails the overlap gate if the
    # fossa counts towards it, and loses its context entirely.
    aseg <- array(0L, dim = c(4, 4, 4))
    # nolint next: commas_linter. air formats empty subscripts without spaces.
    aseg[,, 1] <- 3L
    # nolint next: commas_linter. air formats empty subscripts without spaces.
    aseg[,, 2:4] <- 8L
    brain_mask <- array(FALSE, dim = c(4, 4, 4))
    # nolint next: commas_linter. air formats empty subscripts without spaces.
    brain_mask[,, 1] <- TRUE
    resampled <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(aseg), resampled)
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")
    local_mocked_bindings(resample_volume_to_grid = function(...) resampled)

    context <- aseg_context_volume(
      "a.nii.gz",
      "subj",
      c(4L, 4L, 4L),
      brain_mask
    )

    expect_false(is.null(context))
    expect_true(any(context == 8L))
  })
})


describe("aseg_fossa_idx", {
  it("is cerebellar cortex and brain stem, not cerebellar white matter", {
    expect_identical(
      aseg_fossa_idx(),
      c(cerebellum_left = 8L, cerebellum_right = 47L, brainstem = 16L)
    )
    # 7 and 46 fill the cerebellum into a solid lump that merges with the
    # occipital lobe; without them it stays a foliated shell.
    expect_false(any(c(7L, 46L) %in% aseg_fossa_idx()))
  })

  it("is part of the context volume alongside the cortical ribbon", {
    expect_identical(
      aseg_context_idx(),
      c(aseg_cortex_idx(), aseg_fossa_idx())
    )
  })
})


describe("posterior fossa context", {
  fossa_volume <- function(structure_slice = NULL) {
    arr <- array(1000L, dim = c(12, 5, 5))
    if (!is.null(structure_slice)) {
      arr[structure_slice, , ] <- 10L
    }
    arr
  }

  # Cortex three voxels thick on the outer x-slices, so the grid can carry
  # it, with cerebellum and brain stem in the middle.
  fossa_aseg <- function(dims = c(12, 5, 5)) {
    aseg <- array(0L, dim = dims)
    aseg[1:3, , ] <- 3L
    aseg[10:12, , ] <- 42L
    aseg[5, , ] <- 8L
    aseg[6, , ] <- 16L
    aseg
  }

  write_context <- function(arr, aseg, env = parent.frame()) {
    vol_file <- withr::local_tempfile(fileext = ".nii.gz", .local_envir = env)
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz", .local_envir = env)
    local_mocked_bindings(
      aseg_context_volume = function(...) aseg,
      .env = env
    )
    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = 1000L,
      output_file = out_file,
      target_idx = 101L
    )
    as.array(RNifti::readNifti(out_file))
  }

  it("fills the fossa behind a solid mantle", {
    skip_if_not_installed("RNifti")
    result <- write_context(fossa_volume(), fossa_aseg())

    expect_identical(sum(result == 8L), 25L)
    expect_identical(sum(result == 16L), 25L)
    expect_identical(sum(result == 3L), 75L)
    expect_identical(sum(result == 42L), 75L)
  })

  it("fills the fossa even when the atlas keeps its own cortical ribbon", {
    skip_if_not_installed("RNifti")
    # Cortex on three x-slices only: a ribbon, not a mantle, so the cerebral
    # context stays the atlas's own. The fossa is empty either way, so it is
    # filled regardless.
    arr <- array(0L, dim = c(12, 5, 5))
    arr[1:3, , ] <- 1000L
    result <- write_context(arr, fossa_aseg())

    expect_identical(sum(result == 8L), 25L)
    expect_identical(sum(result == 16L), 25L)
    # The atlas's own cortical slices, split at the midline.
    expect_identical(sum(result %in% c(3L, 42L)), 75L)
  })

  it("never writes fossa context over a structure", {
    skip_if_not_installed("RNifti")
    result <- write_context(fossa_volume(structure_slice = 5), fossa_aseg())

    # The whole x = 5 slice is a structure, so the cerebellum there is not
    # drawn over it.
    expect_identical(sum(result == 101L), 25L)
    expect_identical(sum(result == 8L), 0L)
    expect_identical(sum(result == 16L), 25L)
  })

  it("is skipped entirely when no aseg can be had", {
    skip_if_not_installed("RNifti")
    arr <- fossa_volume()
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")
    local_no_aseg_ribbon()

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result %in% aseg_fossa_idx()), 0L)
  })
})


describe("ribbon_lands_on_volume", {
  it("rejects an empty ribbon", {
    ribbon <- array(0L, dim = c(2, 2, 2))
    expect_warning(
      expect_false(ribbon_lands_on_volume(ribbon, array(TRUE, c(2, 2, 2)))),
      "no cortex"
    )
  })

  it("reports the overlap it measured", {
    ribbon <- array(3L, dim = c(4, 1, 1))
    brain <- array(c(TRUE, FALSE, FALSE, FALSE), dim = c(4, 1, 1))
    expect_warning(
      ribbon_lands_on_volume(ribbon, brain),
      "25%"
    )
  })

  it("rejects a ribbon that lands outside the volume", {
    ribbon <- array(3L, dim = c(4, 1, 1))
    brain <- array(c(TRUE, FALSE, FALSE, FALSE), dim = c(4, 1, 1))
    expect_warning(
      expect_false(ribbon_lands_on_volume(ribbon, brain)),
      "not in the same space"
    )
  })

  it("accepts a ribbon that lands on the volume", {
    ribbon <- array(3L, dim = c(4, 1, 1))
    brain <- array(c(TRUE, TRUE, TRUE, FALSE), dim = c(4, 1, 1))
    expect_true(ribbon_lands_on_volume(ribbon, brain))
  })
})


describe("create_wholebrain_from_volume argument groups", {
  # The retired arguments are only observable at the point the pipeline is
  # handed them, so stop there rather than building an atlas.
  capture_setup <- function(args) {
    seen <- NULL
    local_mocked_bindings(
      wholebrain_setup = function(...) list(config = list(...), dirs = NULL),
      wholebrain_run_pipeline = function(setup, opts, labels, start_time) {
        list(config = setup$config, opts = opts, labels = labels)
      }
    )
    do.call(
      create_wholebrain_from_volume,
      c(list(input_volume = "v.nii"), args)
    )
  }

  it("fills projection_opts out with its defaults", {
    seen <- capture_setup(list())

    expect_identical(seen$config$subject, "fsaverage5")
    expect_identical(seen$config$projfrac, 0.5)
    expect_identical(seen$config$min_vertices, 50L)
  })

  it("takes projection settings from projection_opts", {
    seen <- capture_setup(list(
      projection_opts = list(projfrac = 0.7, subject = "fsaverage6")
    ))

    expect_identical(seen$config$projfrac, 0.7)
    expect_identical(seen$config$subject, "fsaverage6")
    # untouched entries keep their defaults
    expect_identical(seen$config$min_vertices, 50L)
  })

  it("routes the labels list to the pipeline", {
    seen <- capture_setup(list(
      labels = list(cortical = c("a", "b"), subcortical = "c")
    ))

    expect_identical(seen$labels$cortical, c("a", "b"))
    expect_identical(seen$labels$subcortical, "c")
    expect_null(seen$labels$cerebellar)
  })

  it("lands the retired flat arguments where the lists now hold them", {
    withr::local_options(lifecycle_verbosity = "warning")
    expect_snapshot(
      old <- capture_setup(list(
        cortical_labels = c("a", "b"),
        subcortical_labels = "c",
        projfrac = 0.7,
        subject = "fsaverage6"
      ))
    )
    new <- capture_setup(list(
      labels = list(cortical = c("a", "b"), subcortical = "c"),
      projection_opts = list(projfrac = 0.7, subject = "fsaverage6")
    ))

    expect_identical(old$labels, new$labels)
    expect_identical(old$config$projfrac, new$config$projfrac)
    expect_identical(old$config$subject, new$config$subject)
  })

  it("deprecates each retired argument", {
    # Errors rather than warnings, for the reason spelled out in the
    # regheader block below: lifecycle throttles an indirect warning to once
    # per session, so whether a warning arrives here depends on what ran
    # first. Errors carry no such budget.
    withr::local_options(lifecycle_verbosity = "error")

    for (arg in c(
      "cortical_labels",
      "subcortical_labels",
      "cerebellar_labels",
      "projfrac",
      "subject",
      "registration",
      "min_vertices",
      "cerebellar_space"
    )) {
      expect_error(
        capture_setup(stats::setNames(list("x"), arg)),
        class = "lifecycle_error_deprecated",
        info = arg
      )
    }
  })

  it("refuses a retired argument alongside the list entry replacing it", {
    expect_error(
      capture_setup(list(
        cortical_labels = "a",
        labels = list(cortical = "b")
      )),
      "Cannot use both"
    )
  })

  it("rejects an unknown projection_opts entry by name", {
    expect_error(
      capture_setup(list(projection_opts = list(nope = 1))),
      "Unknown .*projection_opts.* entr"
    )
  })

  it("says which list a sub-pipeline option belongs in", {
    expect_error(
      capture_setup(list(decimate = 0.5)),
      "subcortical_opts"
    )
  })

  it("carries cerebellar_space through cerebellar_opts", {
    seen <- capture_setup(list(
      cerebellar_opts = list(cerebellar_space = "MNI152NLin6AsymC")
    ))

    expect_identical(seen$config$cerebellar_space, "MNI152NLin6AsymC")
    # and is not forwarded to the cerebellar builder, which has no such argument
    expect_false("cerebellar_space" %in% names(seen$opts$cerebellar))
  })
})
