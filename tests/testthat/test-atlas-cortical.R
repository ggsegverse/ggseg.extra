describe("create_cortical_from_annotation", {
  it("checks for FreeSurfer when geometry is requested", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) {
        if (abort) {
          cli::cli_abort("FreeSurfer not found")
        }
        FALSE
      }
    )

    expect_error(
      create_cortical_from_annotation(
        input_annot = c("lh.test.annot", "rh.test.annot"),
        steps = NULL,
        verbose = FALSE
      ),
      "FreeSurfer"
    )
  })

  it("validates annotation files exist", {
    expect_error(
      create_cortical_from_annotation(
        input_annot = c("nonexistent.annot"),
        steps = 1,
        verbose = FALSE
      ),
      "not found"
    )
  })

  it("creates 3D-only atlas from annotation", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas <- create_cortical_from_annotation(
      input_annot = annot_files,
      steps = 1,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_equal(atlas$type, "cortical")
    expect_true(nrow(atlas$core) > 0)
  })

  it("includes vertices for 3D rendering", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas <- create_cortical_from_annotation(
      input_annot = annot_files,
      steps = 1,
      verbose = FALSE
    )

    vertices <- ggseg.formats::atlas_vertices(atlas)
    expect_true(nrow(vertices) > 0)
    expect_true("vertices" %in% names(vertices))
  })

  it("can render with ggseg3d", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas <- create_cortical_from_annotation(
      input_annot = annot_files,
      steps = 1,
      verbose = FALSE
    )

    expect_no_error({
      p <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = "left")
    })
  })
})


describe("cortical_pipeline", {
  it("dispatches region_snapshot_fn with correct args for step 3", {
    captured_snapshot_args <- NULL
    do.call(local_mocked_bindings, mock_cortical_pipeline_bindings())

    custom_fn <- function(...) {
      captured_snapshot_args <<- list(...)
    }

    components <- mock_components("lh_frontal", "left", "frontal", "#FF0000")
    components$vertices_df <- data.frame(
      label = "lh_frontal",
      vertices = I(list(1:10))
    )

    cortical_pipeline(
      atlas_3d = structure(list(), class = "ggseg_atlas"),
      components = components,
      atlas_name = "test",
      hemisphere = c("lh", "rh"),
      views = c("lateral"),
      region_snapshot_fn = custom_fn,
      config = list(
        steps = 2:8,
        skip_existing = FALSE,
        tolerance = 1,
        smoothness = 5,
        cleanup = FALSE,
        verbose = FALSE
      ),
      dirs = mock_dirs(),
      start_time = Sys.time()
    )

    expect_false(is.null(captured_snapshot_args))
  })

  it("skips snapshot steps when not in steps vector", {
    step2_called <- FALSE
    step4_called <- FALSE
    local_mocked_bindings(
      cortical_brain_snapshots = function(...) {
        step2_called <<- TRUE
      },
      cortical_isolate_regions = function(...) {
        step4_called <<- TRUE
      },
      extract_contours = function(...) NULL,
      smooth_contours = function(...) NULL,
      reduce_vertex = function(...) NULL,
      cortical_build_sf = function(...) mock_sf_polygon(),
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      warn_if_large_atlas = function(...) NULL,
      preview_atlas = function(...) NULL
    )

    result <- cortical_pipeline(
      atlas_3d = structure(list(), class = "ggseg_atlas"),
      components = mock_components(),
      atlas_name = "test",
      hemisphere = "lh",
      views = "lateral",
      region_snapshot_fn = function(...) NULL,
      config = list(
        steps = 5:8,
        skip_existing = FALSE,
        tolerance = 1,
        smoothness = 5,
        cleanup = FALSE,
        verbose = FALSE
      ),
      dirs = mock_dirs(),
      start_time = Sys.time()
    )

    expect_false(step2_called)
    expect_false(step4_called)
    expect_s3_class(result, "ggseg_atlas")
  })
})


describe("create_cortical_from_annotation pipeline flow", {
  it("step 1 passes input_annot to read_annotation_data", {
    captured <- list()
    local_mocked_bindings(
      read_annotation_data = function(annot_files) {
        captured$annot <<- annot_files
        dplyr::tibble(
          hemi = "left",
          region = "frontal",
          label = "lh_frontal",
          colour = "#FF0000",
          vertices = list(1:10)
        )
      },
      build_atlas_components = function(data) {
        list(
          core = data.frame(
            hemi = "left",
            region = "frontal",
            label = "lh_frontal",
            stringsAsFactors = FALSE
          ),
          palette = c(lh_frontal = "#FF0000"),
          vertices_df = data.frame(
            label = "lh_frontal",
            vertices = I(list(1:10))
          )
        )
      },
      ggseg_atlas = function(...) {
        structure(list(...), class = "ggseg_atlas")
      },
      ggseg_data_cortical = function(...) list(...)
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    result <- create_cortical_from_annotation(
      input_annot = c("lh.test.annot"),
      steps = 1,
      verbose = FALSE
    )

    expect_equal(captured$annot, c("lh.test.annot"))
    expect_s3_class(result, "ggseg_atlas")
  })

  it("returns early for steps = 1 without calling step 2", {
    step2_called <- FALSE
    local_mocked_bindings(
      read_annotation_data = function(annot_files) {
        dplyr::tibble(
          hemi = "left",
          region = "frontal",
          label = "lh_frontal",
          colour = "#FF0000",
          vertices = list(1:10)
        )
      },
      build_atlas_components = function(data) {
        list(
          core = data.frame(
            hemi = "left",
            region = "frontal",
            label = "lh_frontal",
            stringsAsFactors = FALSE
          ),
          palette = c(lh_frontal = "#FF0000"),
          vertices_df = data.frame(
            label = "lh_frontal",
            vertices = I(list(1:10))
          )
        )
      },
      ggseg_atlas = function(...) {
        structure(list(...), class = "ggseg_atlas")
      },
      ggseg_data_cortical = function(...) list(...),
      cortical_brain_snapshots = function(...) {
        step2_called <<- TRUE
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    create_cortical_from_annotation(
      input_annot = c("lh.test.annot"),
      steps = 1,
      verbose = FALSE
    )

    expect_false(step2_called)
  })
})


describe("read_annotation_data", {
  it("reads annotation data from files", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas_data <- read_annotation_data(annot_files)

    expect_s3_class(atlas_data, "tbl_df")
    expect_true(all(
      c("hemi", "region", "label", "colour", "vertices") %in%
        names(atlas_data)
    ))
    expect_true(nrow(atlas_data) > 0)
  })

  it("returns data for both hemispheres", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas_data <- read_annotation_data(annot_files)

    expect_true("left" %in% atlas_data$hemi)
    expect_true("right" %in% atlas_data$hemi)
  })

  it("creates proper labels with hemisphere prefix", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas_data <- read_annotation_data(annot_files)

    lh_labels <- atlas_data$label[atlas_data$hemi == "left"]
    rh_labels <- atlas_data$label[atlas_data$hemi == "right"]

    expect_true(all(grepl("^lh_", lh_labels)))
    expect_true(all(grepl("^rh_", rh_labels)))
  })

  it("includes vertex indices as list column", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas_data <- read_annotation_data(annot_files)

    expect_type(atlas_data$vertices, "list")
    expect_true(all(
      vapply(atlas_data$vertices, is.integer, logical(1))
    ))
    expect_true(all(
      vapply(
        atlas_data$vertices,
        function(x) length(x) > 0,
        logical(1)
      )
    ))
  })

  it("errors when files not found", {
    expect_error(
      read_annotation_data(c("nonexistent.annot")),
      "not found"
    )
  })
})


describe("create_cortical_from_labels", {
  it("creates atlas from label files", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    atlas <- create_cortical_from_labels(
      labels,
      atlas_name = "test_atlas",
      steps = 1,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_equal(atlas$atlas, "test_atlas")
    expect_equal(atlas$type, "cortical")
    expect_equal(nrow(atlas$core), 3)
  })

  it("correctly parses hemisphere from filename", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    atlas <- create_cortical_from_labels(
      labels,
      steps = 1,
      verbose = FALSE
    )

    expect_true("left" %in% atlas$core$hemi)
    expect_true("right" %in% atlas$core$hemi)
    expect_equal(sum(atlas$core$hemi == "left"), 2)
    expect_equal(sum(atlas$core$hemi == "right"), 1)
  })

  it("stores vertices correctly", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    atlas <- create_cortical_from_labels(
      labels,
      steps = 1,
      verbose = FALSE
    )

    vertices <- ggseg.formats::atlas_vertices(atlas)
    expect_true(nrow(vertices) > 0)
    expect_equal(length(vertices$vertices[[1]]), 5)
  })

  it("accepts custom names and colours via input_lut", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    custom_lut <- data.frame(
      region = c("Motor", "Visual", "Motor"),
      hex = c("#FF0000", "#00FF00", "#0000FF")
    )

    atlas <- create_cortical_from_labels(
      labels,
      input_lut = custom_lut,
      steps = 1,
      verbose = FALSE
    )

    expect_equal(atlas$core$region, custom_lut$region)
    expect_true(all(custom_lut$hex %in% atlas$palette))
  })

  it("errors when label files not found", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      check_magick = function() invisible(TRUE)
    )
    expect_error(
      create_cortical_from_labels(
        c("nonexistent.label"),
        verbose = FALSE
      ),
      "Label files not found"
    )
  })

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
      create_cortical_from_labels(
        c("lh.test.label"),
        verbose = FALSE
      ),
      "FreeSurfer"
    )
  })
})


describe("read_label_vertices", {
  it("reads vertex indices from label file", {
    label_file <- test_label_files()$lh_region1
    vertices <- read_label_vertices(label_file)

    expect_type(vertices, "integer")
    expect_equal(length(vertices), 5)
    expect_equal(vertices, c(100L, 101L, 102L, 150L, 151L))
  })

  it("handles different label files", {
    label_file <- test_label_files()$lh_region2
    vertices <- read_label_vertices(label_file)

    expect_equal(length(vertices), 3)
    expect_equal(vertices, c(200L, 201L, 202L))
  })

  it("handles right hemisphere labels", {
    label_file <- test_label_files()$rh_region1
    vertices <- read_label_vertices(label_file)

    expect_equal(length(vertices), 4)
  })
})


describe("cortical_resolve_step1", {
  it("loads cached data when files exist and skip_existing is TRUE", {
    tmp_dir <- withr::local_tempdir()
    mock_atlas <- structure(list(atlas = "test"), class = "ggseg_atlas")
    mock_components <- list(
      core = data.frame(hemi = "left", region = "r", label = "lh_r"),
      palette = c(lh_r = "#FF0000"),
      vertices_df = data.frame(label = "lh_r", vertices = I(list(1:5)))
    )
    saveRDS(mock_atlas, file.path(tmp_dir, "atlas_3d.rds"))
    saveRDS(mock_components, file.path(tmp_dir, "components.rds"))

    result <- cortical_resolve_step1(
      config = list(steps = 1L, skip_existing = TRUE, verbose = FALSE),
      dirs = list(base = tmp_dir),
      atlas_name = "test",
      read_fn = function() stop("should not be called"),
      step_label = "test",
      cache_label = "test"
    )

    expect_s3_class(result$atlas_3d, "ggseg_atlas")
    expect_equal(result$components$palette, mock_components$palette)
  })
})


describe("cortical_finalize", {
  it("returns atlas and logs when verbose", {
    local_mocked_bindings(
      log_elapsed = function(...) NULL,
      warn_if_large_atlas = function(...) NULL,
      preview_atlas = function(x) x
    )
    mock_atlas <- structure(
      list(core = data.frame(hemi = "left", region = "r", label = "lh_r")),
      class = "ggseg_atlas"
    )
    dirs <- list(base = withr::local_tempdir())

    expect_message(
      result <- cortical_finalize(
        mock_atlas,
        config = list(
          steps = 1L, cleanup = FALSE, verbose = TRUE
        ),
        dirs = dirs,
        start_time = Sys.time()
      ),
      "1 regions"
    )

    expect_s3_class(result, "ggseg_atlas")
  })

  it("cleans up when cleanup is TRUE", {
    local_mocked_bindings(
      log_elapsed = function(...) NULL,
      warn_if_large_atlas = function(...) NULL,
      preview_atlas = function(x) x
    )
    mock_atlas <- structure(
      list(core = data.frame(hemi = "left", region = "r", label = "lh_r")),
      class = "ggseg_atlas"
    )
    base_dir <- withr::local_tempdir()
    dir.create(file.path(base_dir, "subdir"))

    cortical_finalize(
      mock_atlas,
      config = list(
        steps = 1L:8L, cleanup = TRUE, verbose = FALSE
      ),
      dirs = list(base = file.path(base_dir, "subdir")),
      start_time = Sys.time()
    )

    expect_false(dir.exists(file.path(base_dir, "subdir")))
  })
})


describe("cortical_pipeline verbose and cleanup paths", {
  it("logs verbose messages for each step", {
    do.call(local_mocked_bindings, mock_cortical_pipeline_bindings())

    scrub <- function(x) {
      x <- gsub("\\[\\d+ms\\]", "[<TIME>]", x)
      x <- gsub("/tmp/Rtmp[^ ']*|/var/folders[^ ']*", "<TMPDIR>", x)
      gsub("[A-Za-z]:[^ ']*Rtmp[^ ']*", "<TMPDIR>", x)
    }
    expect_snapshot(
      cortical_pipeline(
        atlas_3d = structure(list(), class = "ggseg_atlas"),
        components = mock_components(),
        atlas_name = "test",
        hemisphere = "lh",
        views = "lateral",
        region_snapshot_fn = function(...) NULL,
        config = list(
          steps = 2:8,
          skip_existing = FALSE,
          tolerance = 1,
          smoothness = 5,
          cleanup = FALSE,
          verbose = TRUE
        ),
        dirs = mock_dirs(),
        start_time = Sys.time()
      ),
      transform = scrub
    )
  })

  it("cleans up base directory and emits message when cleanup and verbose", {
    do.call(local_mocked_bindings, mock_cortical_pipeline_bindings())

    base_dir <- withr::local_tempdir()
    actual_base <- file.path(base_dir, "atlas_work")
    dir.create(actual_base)

    expect_message(
      cortical_pipeline(
        atlas_3d = structure(list(), class = "ggseg_atlas"),
        components = mock_components(),
        atlas_name = "test",
        hemisphere = "lh",
        views = "lateral",
        region_snapshot_fn = function(...) NULL,
        config = list(
          steps = 8L,
          skip_existing = FALSE,
          tolerance = 1,
          smoothness = 5,
          cleanup = TRUE,
          verbose = TRUE
        ),
        dirs = list(
          base = actual_base,
          snapshots = tempdir(),
          processed = tempdir(),
          masks = tempdir()
        ),
        start_time = Sys.time()
      ),
      "Temporary files removed"
    )

    expect_false(dir.exists(actual_base))
  })

  it("returns atlas_3d and logs completion when step 8 not in steps", {
    local_mocked_bindings(
      extract_contours = function(...) NULL,
      smooth_contours = function(...) NULL,
      reduce_vertex = function(...) NULL,
      preview_atlas = function(...) NULL,
      log_elapsed = function(...) NULL
    )

    mock_atlas <- structure(list(atlas = "test_3d"), class = "ggseg_atlas")

    result <- NULL
    expect_message(
      result <- cortical_pipeline(
        atlas_3d = mock_atlas,
        components = mock_components(),
        atlas_name = "test",
        hemisphere = "lh",
        views = "lateral",
        region_snapshot_fn = function(...) NULL,
        config = list(
          steps = 5:7,
          skip_existing = FALSE,
          tolerance = 1,
          smoothness = 5,
          cleanup = FALSE,
          verbose = TRUE
        ),
        dirs = mock_dirs(),
        start_time = Sys.time()
      ),
      "Completed steps"
    )

    expect_s3_class(result, "ggseg_atlas")
  })
})


describe("create_cortical_from_annotation magick check", {
  it("checks for ImageMagick when steps > 1", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      check_magick = function() cli::cli_abort("ImageMagick not found")
    )

    expect_error(
      create_cortical_from_annotation(
        input_annot = c("lh.test.annot"),
        steps = 2:8,
        verbose = FALSE
      ),
      "ImageMagick"
    )
  })
})


describe("create_cortical_from_annotation verbose output", {
  it("prints atlas name and paths when verbose is TRUE", {
    local_mocked_bindings(
      read_annotation_data = function(annot_files) {
        dplyr::tibble(
          hemi = "left",
          region = "frontal",
          label = "lh_frontal",
          colour = "#FF0000",
          vertices = list(1:10)
        )
      },
      build_atlas_components = function(data) {
        list(
          core = data.frame(
            hemi = "left",
            region = "frontal",
            label = "lh_frontal",
            stringsAsFactors = FALSE
          ),
          palette = c(lh_frontal = "#FF0000"),
          vertices_df = data.frame(
            label = "lh_frontal",
            vertices = I(list(1:10))
          )
        )
      },
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      log_elapsed = function(...) NULL
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    scrub <- function(x) {
      x <- gsub("\\[\\d+ms\\]", "[<TIME>]", x)
      x <- gsub("/tmp/Rtmp[^ ']*|/var/folders[^ ']*", "<TMPDIR>", x)
      gsub("[A-Za-z]:[^ ']*Rtmp[^ ']*", "<TMPDIR>", x)
    }
    expect_snapshot(
      create_cortical_from_annotation(
        input_annot = c("lh.test.annot"),
        steps = 1,
        verbose = TRUE
      ),
      transform = scrub
    )
  })
})


describe("create_cortical_from_annotation full pipeline path", {
  it("passes correct components and config to cortical_pipeline", {
    captured_pipeline_args <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      check_magick = function() invisible(TRUE),
      read_annotation_data = function(annot_files) {
        dplyr::tibble(
          hemi = "left",
          region = "frontal",
          label = "lh_frontal",
          colour = "#FF0000",
          vertices = list(1:10)
        )
      },
      build_atlas_components = function(data) {
        list(
          core = data.frame(
            hemi = "left",
            region = "frontal",
            label = "lh_frontal",
            stringsAsFactors = FALSE
          ),
          palette = c(lh_frontal = "#FF0000"),
          vertices_df = data.frame(
            label = "lh_frontal",
            vertices = I(list(1:10))
          )
        )
      },
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      cortical_pipeline = function(...) {
        captured_pipeline_args <<- list(...)
        structure(list(), class = "ggseg_atlas")
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    result <- create_cortical_from_annotation(
      input_annot = c("lh.test.annot"),
      steps = 1:8,
      verbose = FALSE
    )

    expect_s3_class(result, "ggseg_atlas")
    expect_equal(captured_pipeline_args$atlas_name, "test")
    expect_equal(
      captured_pipeline_args$components$palette,
      c(lh_frontal = "#FF0000")
    )
    expect_s3_class(captured_pipeline_args$atlas_3d, "ggseg_atlas")
  })
})


describe("cortical_resolve_step1 verbose paths", {
  it("prints progress step when verbose is TRUE and step runs", {
    local_mocked_bindings(
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...)
    )

    tmp_dir <- withr::local_tempdir()
    read_fn <- function() {
      dplyr::tibble(
        hemi = "left",
        region = "frontal",
        label = "lh_frontal",
        colour = "#FF0000",
        vertices = list(1:10)
      )
    }

    expect_message(
      cortical_resolve_step1(
        config = list(steps = 1L, skip_existing = FALSE, verbose = TRUE),
        dirs = list(base = tmp_dir),
        atlas_name = "test",
        read_fn = read_fn,
        step_label = "1/8 Reading annotation files",
        cache_label = "Step 1 (Read annotations)"
      ),
      "1/8 Reading"
    )
  })

  it("aborts when read_fn returns zero rows", {
    tmp_dir <- withr::local_tempdir()
    read_fn <- function() {
      dplyr::tibble(
        hemi = character(),
        region = character(),
        label = character(),
        colour = character(),
        vertices = list()
      )
    }

    expect_error(
      cortical_resolve_step1(
        config = list(steps = 1L, skip_existing = FALSE, verbose = FALSE),
        dirs = list(base = tmp_dir),
        atlas_name = "test",
        read_fn = read_fn,
        step_label = "1/8 test",
        cache_label = "test"
      ),
      "No regions found"
    )
  })

  it("prints loaded existing data when verbose and skip_existing", {
    tmp_dir <- withr::local_tempdir()
    mock_atlas <- structure(list(atlas = "test"), class = "ggseg_atlas")
    mock_components <- list(
      core = data.frame(hemi = "left", region = "r", label = "lh_r"),
      palette = c(lh_r = "#FF0000"),
      vertices_df = data.frame(label = "lh_r", vertices = I(list(1:5)))
    )
    saveRDS(mock_atlas, file.path(tmp_dir, "atlas_3d.rds"))
    saveRDS(mock_components, file.path(tmp_dir, "components.rds"))

    expect_message(
      cortical_resolve_step1(
        config = list(steps = 1L, skip_existing = TRUE, verbose = TRUE),
        dirs = list(base = tmp_dir),
        atlas_name = "test",
        read_fn = function() stop("should not be called"),
        step_label = "test",
        cache_label = "test"
      ),
      "Loaded existing atlas data"
    )
  })
})




describe("create_cortical_from_labels verbose and LUT paths", {
  it("prints verbose output when verbose is TRUE", {
    local_mocked_bindings(
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      log_elapsed = function(...) NULL
    )

    labels <- unlist(test_label_files())

    scrub <- function(x) {
      x <- gsub("\\[\\d+ms\\]", "[<TIME>]", x)
      x <- gsub("/tmp/Rtmp[^ ']*|/var/folders[^ ']*", "<TMPDIR>", x)
      gsub("[A-Za-z]:[^ ']*Rtmp[^ ']*", "<TMPDIR>", x)
    }
    expect_snapshot(
      create_cortical_from_labels(
        labels,
        atlas_name = "test_atlas",
        steps = 1,
        verbose = TRUE
      ),
      transform = scrub
    )
  })

  it("extracts colours from RGB columns in LUT", {
    labels <- unlist(test_label_files())
    rgb_lut <- data.frame(
      region = c("Motor", "Visual", "Motor"),
      R = c(255, 0, 0),
      G = c(0, 255, 0),
      B = c(0, 0, 255)
    )

    local_mocked_bindings(
      ggseg_atlas = function(...) {
        args <- list(...)
        structure(
          list(
            atlas = args$atlas,
            type = args$type,
            palette = args$palette,
            core = args$core,
            data = args$data
          ),
          class = "ggseg_atlas"
        )
      },
      ggseg_data_cortical = function(...) list(...),
      log_elapsed = function(...) NULL
    )

    atlas <- create_cortical_from_labels(
      labels,
      input_lut = rgb_lut,
      atlas_name = "test_atlas",
      steps = 1,
      verbose = FALSE
    )

    expect_true(!is.null(atlas$palette))
    expect_true(any(grepl("^#", atlas$palette)))
  })

  it("sets NULL colour when LUT lacks hex and RGB columns", {
    labels <- unlist(test_label_files())
    bad_lut <- data.frame(
      region = c("Motor", "Visual", "Motor"),
      score = c(1, 2, 3)
    )

    local_mocked_bindings(
      ggseg_atlas = function(...) {
        args <- list(...)
        structure(
          list(
            atlas = args$atlas,
            type = args$type,
            palette = args$palette,
            core = args$core,
            data = args$data
          ),
          class = "ggseg_atlas"
        )
      },
      ggseg_data_cortical = function(...) list(...),
      log_elapsed = function(...) NULL
    )

    atlas <- create_cortical_from_labels(
      labels,
      input_lut = bad_lut,
      atlas_name = "test_atlas",
      steps = 1,
      verbose = FALSE
    )

    expect_null(atlas$palette)
  })

  it("passes correct atlas_name and components to cortical_pipeline", {
    captured_args <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      check_magick = function() invisible(TRUE),
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      cortical_pipeline = function(...) {
        captured_args <<- list(...)
        structure(list(), class = "ggseg_atlas")
      }
    )

    labels <- unlist(test_label_files())
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    result <- create_cortical_from_labels(
      labels,
      atlas_name = "test_atlas",
      steps = 1:8,
      verbose = FALSE
    )

    expect_s3_class(result, "ggseg_atlas")
    expect_equal(captured_args$atlas_name, "test_atlas")
    expect_s3_class(captured_args$atlas_3d, "ggseg_atlas")
    expect_true(nrow(captured_args$components$core) > 0)
  })
})


describe("create_cortical_from_labels hemi fallback", {
  it("defaults to both hemispheres when all hemi values are NA", {
    captured_hemisphere <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      check_magick = function() invisible(TRUE),
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      cortical_pipeline = function(...) {
        args <- list(...)
        captured_hemisphere <<- args$hemisphere
        structure(list(), class = "ggseg_atlas")
      }
    )

    tmp <- withr::local_tempdir()
    nohemi_file <- file.path(tmp, "some_region.label")
    writeLines(
      c(
        "#!ascii label",
        "3",
        "100  0.0  0.0  0.0  0.0",
        "101  1.0  1.0  1.0  0.0",
        "102  2.0  2.0  2.0  0.0"
      ),
      nohemi_file
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    create_cortical_from_labels(
      c(nohemi_file),
      atlas_name = "test_nohemi",
      steps = 1:8,
      verbose = FALSE
    )

    expect_equal(captured_hemisphere, c("lh", "rh"))
  })
})


describe("create_cortical_from_gifti verbose", {
  it("emits 'from GIFTI' message when verbose and steps > 1", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = c(1L, 1L, 2L, 2L),
      colortable_df = data.frame(
        struct_name = c("a", "b"),
        r = c(255L, 0L),
        g = c(0L, 255L),
        b = c(0L, 0L),
        a = c(0L, 0L),
        code = c(1L, 2L),
        hex_color_string_rgb = c("#FF0000", "#00FF00"),
        hex_color_string_rgba = c("#FF000000", "#00FF0000"),
        struct_index = c(0L, 1L),
        stringsAsFactors = FALSE
      )
    )

    local_mocked_bindings(
      read.fs.annot.gii = function(...) mock_annot,
      .package = "freesurferformats"
    )
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      check_magick = function() invisible(TRUE),
      cortical_pipeline = function(...) structure(list(), class = "ggseg_atlas")
    )

    tmp <- withr::local_tempfile(pattern = "lh.test", fileext = ".label.gii")
    writeLines("mock", tmp)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_message(
      create_cortical_from_gifti(
        gifti_files = tmp,
        atlas_name = "test_gifti",
        steps = 1:2,
        verbose = TRUE
      ),
      "from GIFTI"
    )
  })
})


describe("create_cortical_from_cifti verbose", {
  it("emits 'from CIFTI' message when verbose and steps > 1", {
    skip_if_not_installed("ciftiTools")

    n <- 10242L
    mock_cii <- list(
      data = list(
        cortex_left = matrix(c(rep(1L, 5000), rep(2L, 5242)), ncol = 1),
        cortex_right = matrix(c(rep(1L, 4000), rep(2L, 6242)), ncol = 1)
      ),
      meta = list(
        cifti = list(
          labels = list(
            data.frame(
              Key = c(1L, 2L),
              Label = c("region_a", "region_b"),
              Red = c(1, 0),
              Green = c(0, 1),
              Blue = c(0, 0),
              stringsAsFactors = FALSE
            )
          )
        )
      )
    )

    local_mocked_bindings(
      read_cifti = function(...) mock_cii,
      .package = "ciftiTools"
    )
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      check_magick = function() invisible(TRUE),
      cortical_pipeline = function(...) structure(list(), class = "ggseg_atlas")
    )

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", tmp)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_message(
      create_cortical_from_cifti(
        cifti_file = tmp,
        atlas_name = "test_cifti",
        steps = 1:2,
        verbose = TRUE
      ),
      "from CIFTI"
    )
  })
})


describe("create_cortical_from_neuromaps verbose", {
  it("emits 'Fetching neuromaps' and 'from neuromaps' messages", {
    skip_if_not_installed("neuromapr")
    skip_if_not(
      exists("fetch_neuromaps_annotation", envir = asNamespace("neuromapr")),
      "neuromapr without neuromaps support"
    )
    skip_if_not_installed("gifti")

    n <- 10242L
    mock_gii <- list(data = list(c(rep(1, 5000), rep(2, 5242))))

    lh <- withr::local_tempfile(
      pattern = "source-test_hemi-L_feature",
      fileext = ".func.gii"
    )
    rh <- withr::local_tempfile(
      pattern = "source-test_hemi-R_feature",
      fileext = ".func.gii"
    )
    writeLines("mock", lh)
    writeLines("mock", rh)

    local_mocked_bindings(
      fetch_neuromaps_annotation = function(...) c(lh, rh),
      .package = "neuromapr"
    )
    local_mocked_bindings(
      read_gifti = function(...) mock_gii,
      .package = "gifti"
    )
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      check_magick = function() invisible(TRUE),
      cortical_pipeline = function(...) structure(list(), class = "ggseg_atlas")
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_message(
      create_cortical_from_neuromaps(
        source = "test",
        desc = "testdesc",
        atlas_name = "test_neuromaps",
        steps = 1:2,
        verbose = TRUE
      ),
      "Fetching neuromaps"
    )

    expect_message(
      create_cortical_from_neuromaps(
        source = "test",
        desc = "testdesc",
        atlas_name = "test_neuromaps",
        steps = 1:2,
        verbose = TRUE
      ),
      "from neuromaps"
    )
  })

  it("emits 'Volume annotation detected' for .nii.gz files", {
    skip_if_not_installed("neuromapr")
    skip_if_not(
      exists("fetch_neuromaps_annotation", envir = asNamespace("neuromapr")),
      "neuromapr without neuromaps support"
    )

    n <- 10242L
    mock_annot <- data.frame(
      hemi = rep("left", 3),
      region = c("bin_01", "bin_02", "unknown"),
      label = c("bin_01", "bin_02", "unknown"),
      colour = c("#FF0000", "#00FF00", NA),
      vertices = I(list(1:5000, 5001:9000, 9001:n)),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      fetch_neuromaps_annotation = function(...) "brain_map.nii.gz",
      .package = "neuromapr"
    )
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      check_magick = function() invisible(TRUE),
      read_neuromaps_volume = function(...) mock_annot,
      cortical_pipeline = function(...) structure(list(), class = "ggseg_atlas")
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_message(
      create_cortical_from_neuromaps(
        source = "test",
        desc = "vol",
        atlas_name = "test_vol",
        steps = 1:2,
        verbose = TRUE
      ),
      "Volume annotation detected"
    )
  })
})


describe("cortical_region_snapshots invisible-region filtering", {
  it("skips regions that face away from the camera", {
    captured <- list()
    local_mocked_bindings(
      snapshot_region_batch = function(
        atlas, region_label, hemisphere, views, ...
      ) {
        captured[[length(captured) + 1]] <<- list(
          region_label = region_label,
          hemisphere = hemisphere,
          view = views[1]
        )
      },
      progressor = function(...) function(...) NULL,
      filter_visible_regions = function(region_grid, vertices_df) {
        region_grid[region_grid$region_label != "lh_hidden", , drop = FALSE]
      }
    )

    components <- list(
      core = data.frame(
        label = c("lh_visible", "lh_hidden"),
        stringsAsFactors = FALSE
      ),
      vertices_df = data.frame(label = character(0))
    )
    atlas_3d <- structure(list(), class = "ggseg_atlas")
    dirs <- list(snapshots = tempdir())

    cortical_region_snapshots(
      atlas_3d,
      components,
      hemisphere = "lh",
      views = "lateral",
      dirs = dirs,
      skip_existing = FALSE
    )

    labels <- vapply(captured, `[[`, character(1), "region_label")
    expect_true("lh_visible" %in% labels)
    expect_false("lh_hidden" %in% labels)
  })
})


describe("filter_visible_regions with empty vertices", {
  it("keeps region when vertices list is empty", {
    fake_mesh <- list(
      vertices = data.frame(x = 1:10, y = 1:10, z = 1:10),
      faces = data.frame(i = 0:7, j = 1:8, k = 2:9)
    )
    local_mocked_bindings(
      get_brain_mesh = function(...) fake_mesh,
      .package = "ggseg.formats"
    )

    region_grid <- data.frame(
      region_label = "lh_empty",
      hemisphere = "lh",
      view = "lateral",
      stringsAsFactors = FALSE
    )
    vertices_df <- data.frame(
      label = "lh_empty",
      vertices = I(list(integer(0)))
    )

    result <- filter_visible_regions(region_grid, vertices_df)
    expect_equal(nrow(result), 1)
  })
})
