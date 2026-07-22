.cap <- new.env()

describe("create_cortical_from_annotation", {
  it("validates annotation files exist", {
    expect_error(
      create_cortical_from_annotation(
        input_annot = "nonexistent.annot",
        verbose = FALSE
      ),
      "not found"
    )
  })

  it("creates atlas from annotation", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas <- expect_warnings(
      create_cortical_from_annotation(
        input_annot = annot_files,
        verbose = FALSE
      ),
      "vertices"
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(atlas$type, "cortical")
    expect_gt(nrow(atlas$core), 0)
  })

  it("includes vertices for 3D rendering", {
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas <- expect_warnings(
      create_cortical_from_annotation(
        input_annot = annot_files,
        verbose = FALSE
      ),
      "vertices"
    )

    vertices <- ggseg.formats::atlas_vertices(atlas)
    expect_gt(nrow(vertices), 0)
    expect_true("vertices" %in% names(vertices))
  })

  it("can render with ggseg3d", {
    skip_render_on_windows()
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas <- expect_warnings(
      create_cortical_from_annotation(
        input_annot = annot_files,
        verbose = FALSE
      ),
      "vertices"
    )

    expect_no_error({
      p <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = "left")
    })
  })
})


describe("cortical_project_and_build", {
  it("runs projection and returns atlas", {
    do.call(local_mocked_bindings, mock_cortical_pipeline_bindings())

    components <- mock_components("lh_frontal", "left", "frontal", "#FF0000")
    components$vertices_df <- data.frame(
      stringsAsFactors = FALSE,
      label = "lh_frontal",
      vertices = I(list(1:10))
    )

    result <- cortical_project_and_build(
      components = components,
      atlas_name = "test",
      hemisphere = c("lh", "rh"),
      views = "lateral",
      config = list(
        steps = 1:2,
        skip_existing = FALSE,
        tolerance = 1,
        cleanup = FALSE,
        verbose = FALSE
      ),
      dirs = mock_dirs(),
      start_time = Sys.time()
    )

    expect_s3_class(result, "ggseg_atlas")
  })
})


describe("create_cortical_from_annotation pipeline flow", {
  it("passes input_annot to read_annotation_data", {
    .cap$captured <- list()
    local_mocked_bindings(
      read_annotation_data = function(annot_files) {
        .cap$captured$annot <- annot_files
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
            stringsAsFactors = FALSE,
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
      input_annot = "lh.test.annot",
      verbose = FALSE
    )

    expect_identical(.cap$captured$annot, "lh.test.annot")
    expect_s3_class(result, "ggseg_atlas")
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
    expect_gt(nrow(atlas_data), 0)
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
    expect_true(all(lengths(atlas_data$vertices) > 0))
  })

  it("errors when files not found", {
    expect_error(
      read_annotation_data("nonexistent.annot"),
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
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(atlas$atlas, "test_atlas")
    expect_identical(atlas$type, "cortical")
    expect_identical(nrow(atlas$core), 3L)
  })

  it("correctly parses hemisphere from filename", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    atlas <- create_cortical_from_labels(
      labels,
      verbose = FALSE
    )

    expect_true("left" %in% atlas$core$hemi)
    expect_true("right" %in% atlas$core$hemi)
    expect_identical(sum(atlas$core$hemi == "left"), 2L)
    expect_identical(sum(atlas$core$hemi == "right"), 1L)
  })

  it("stores vertices correctly", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    atlas <- create_cortical_from_labels(
      labels,
      verbose = FALSE
    )

    vertices <- ggseg.formats::atlas_vertices(atlas)
    expect_gt(nrow(vertices), 0)
    expect_length(vertices$vertices[[1]], 5)
  })

  it("accepts custom names and colours via input_lut", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    custom_lut <- data.frame(
      stringsAsFactors = FALSE,
      region = c("Motor", "Visual", "Motor"),
      hex = c("#FF0000", "#00FF00", "#0000FF")
    )

    atlas <- create_cortical_from_labels(
      labels,
      input_lut = custom_lut,
      verbose = FALSE
    )

    expect_identical(atlas$core$region, custom_lut$region)
    expect_true(all(custom_lut$hex %in% atlas$palette))
  })

  it("errors when label files not found", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE)
    )
    expect_error(
      create_cortical_from_labels(
        "nonexistent.label",
        verbose = FALSE
      ),
      "Label files not found"
    )
  })

  it("does not require FreeSurfer for label files", {
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    expect_no_error(
      suppressWarnings(
        create_cortical_from_labels(
          labels,
          verbose = FALSE
        )
      )
    )
  })
})


describe("read_label_vertices", {
  it("reads vertex indices from label file", {
    label_file <- test_label_files()$lh_region1
    vertices <- read_label_vertices(label_file)

    expect_type(vertices, "integer")
    expect_length(vertices, 5)
    expect_identical(vertices, c(100L, 101L, 102L, 150L, 151L))
  })

  it("handles different label files", {
    label_file <- test_label_files()$lh_region2
    vertices <- read_label_vertices(label_file)

    expect_length(vertices, 3)
    expect_identical(vertices, c(200L, 201L, 202L))
  })

  it("handles right hemisphere labels", {
    label_file <- test_label_files()$rh_region1
    vertices <- read_label_vertices(label_file)

    expect_length(vertices, 4)
  })
})


describe("cortical_read_data", {
  it("loads cached data when files exist and skip_existing is TRUE", {
    tmp_dir <- withr::local_tempdir()
    mock_atlas <- structure(list(atlas = "test"), class = "ggseg_atlas")
    mock_components <- list(
      core = data.frame(
        stringsAsFactors = FALSE,
        hemi = "left",
        region = "r",
        label = "lh_r"
      ),
      palette = c(lh_r = "#FF0000"),
      vertices_df = data.frame(
        stringsAsFactors = FALSE,
        label = "lh_r",
        vertices = I(list(1:5))
      )
    )
    saveRDS(mock_atlas, file.path(tmp_dir, "atlas_3d.rds"))
    saveRDS(mock_components, file.path(tmp_dir, "components.rds"))

    result <- cortical_read_data(
      config = list(steps = 1:2, skip_existing = TRUE, verbose = FALSE),
      dirs = list(base = tmp_dir),
      atlas_name = "test",
      read_fn = function() stop("should not be called"),
      step_label = "test",
      cache_label = "test"
    )

    expect_s3_class(result$atlas_3d, "ggseg_atlas")
    expect_identical(result$components$palette, mock_components$palette)
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
      list(
        core = data.frame(
          stringsAsFactors = FALSE,
          hemi = "left",
          region = "r",
          label = "lh_r"
        )
      ),
      class = "ggseg_atlas"
    )
    dirs <- list(base = withr::local_tempdir())

    expect_messages(
      {
        result <- cortical_finalize(
          mock_atlas,
          config = list(
            steps = 1:2,
            cleanup = FALSE,
            verbose = TRUE
          ),
          dirs = dirs,
          start_time = Sys.time()
        )
      },
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
      list(
        core = data.frame(
          stringsAsFactors = FALSE,
          hemi = "left",
          region = "r",
          label = "lh_r"
        )
      ),
      class = "ggseg_atlas"
    )
    base_dir <- withr::local_tempdir()
    dir.create(file.path(base_dir, "subdir"))

    cortical_finalize(
      mock_atlas,
      config = list(
        steps = 1:2,
        cleanup = TRUE,
        verbose = FALSE
      ),
      dirs = list(base = file.path(base_dir, "subdir")),
      start_time = Sys.time()
    )

    expect_false(dir.exists(file.path(base_dir, "subdir")))
  })
})


describe("cortical_project_and_build verbose and cleanup paths", {
  it("logs verbose messages for each step", {
    do.call(local_mocked_bindings, mock_cortical_pipeline_bindings())

    scrub <- function(x) {
      x <- gsub("\\[\\d+\\.?\\d*[ms]s?\\]", "[<TIME>]", x)
      x <- gsub("/tmp/Rtmp[^ ']*|/var/folders[^ ']*", "<TMPDIR>", x)
      gsub("[A-Za-z]:[^ ']*Rtmp[^ ']*", "<TMPDIR>", x)
    }
    expect_snapshot(
      invisible(cortical_project_and_build(
        components = mock_components(),
        atlas_name = "test",
        hemisphere = "lh",
        views = "lateral",
        config = list(
          steps = 1:2,
          skip_existing = FALSE,
          tolerance = 1,
          cleanup = FALSE,
          verbose = TRUE
        ),
        dirs = mock_dirs(),
        start_time = Sys.time()
      )),
      transform = scrub
    )
  })

  it("cleans up base directory and emits message when cleanup and verbose", {
    do.call(local_mocked_bindings, mock_cortical_pipeline_bindings())

    base_dir <- withr::local_tempdir()
    actual_base <- file.path(base_dir, "atlas_work")
    dir.create(actual_base)

    expect_messages(
      cortical_project_and_build(
        components = mock_components(),
        atlas_name = "test",
        hemisphere = "lh",
        views = "lateral",
        config = list(
          steps = 1:2,
          skip_existing = FALSE,
          tolerance = 1,
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
            stringsAsFactors = FALSE,
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
      x <- gsub("\\[\\d+\\.?\\d*[ms]s?\\]", "[<TIME>]", x)
      x <- gsub("/tmp/Rtmp[^ ']*|/var/folders[^ ']*", "<TMPDIR>", x)
      gsub("[A-Za-z]:[^ ']*Rtmp[^ ']*", "<TMPDIR>", x)
    }
    expect_snapshot(
      invisible(create_cortical_from_annotation(
        input_annot = "lh.test.annot",
        verbose = TRUE
      )),
      transform = scrub
    )
  })
})


describe("create_cortical_from_annotation full pipeline path", {
  it("passes correct components and config to cortical_project_and_build", {
    .cap$captured_pipeline_args <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
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
            stringsAsFactors = FALSE,
            label = "lh_frontal",
            vertices = I(list(1:10))
          )
        )
      },
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      cortical_project_and_build = function(...) {
        .cap$captured_pipeline_args <- list(...)
        structure(list(), class = "ggseg_atlas")
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    result <- create_cortical_from_annotation(
      input_annot = "lh.test.annot",
      verbose = FALSE
    )

    expect_s3_class(result, "ggseg_atlas")
    expect_identical(.cap$captured_pipeline_args$atlas_name, "test")
    expect_identical(
      .cap$captured_pipeline_args$components$palette,
      c(lh_frontal = "#FF0000")
    )
  })
})


describe("cortical_read_data verbose paths", {
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

    expect_messages(
      cortical_read_data(
        config = list(steps = 1:2, skip_existing = FALSE, verbose = TRUE),
        dirs = list(base = tmp_dir),
        atlas_name = "test",
        read_fn = read_fn,
        step_label = "Reading annotation files",
        cache_label = "Read annotations"
      ),
      "Reading"
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
      cortical_read_data(
        config = list(steps = 1:2, skip_existing = FALSE, verbose = FALSE),
        dirs = list(base = tmp_dir),
        atlas_name = "test",
        read_fn = read_fn,
        step_label = "test",
        cache_label = "test"
      ),
      "No regions found"
    )
  })

  it("prints loaded existing data when verbose and skip_existing", {
    tmp_dir <- withr::local_tempdir()
    mock_atlas <- structure(list(atlas = "test"), class = "ggseg_atlas")
    mock_components <- list(
      core = data.frame(
        stringsAsFactors = FALSE,
        hemi = "left",
        region = "r",
        label = "lh_r"
      ),
      palette = c(lh_r = "#FF0000"),
      vertices_df = data.frame(
        stringsAsFactors = FALSE,
        label = "lh_r",
        vertices = I(list(1:5))
      )
    )
    saveRDS(mock_atlas, file.path(tmp_dir, "atlas_3d.rds"))
    saveRDS(mock_components, file.path(tmp_dir, "components.rds"))

    expect_messages(
      cortical_read_data(
        config = list(steps = 1:2, skip_existing = TRUE, verbose = TRUE),
        dirs = list(base = tmp_dir),
        atlas_name = "test",
        read_fn = function() stop("should not be called"),
        step_label = "test",
        cache_label = "test"
      ),
      "Loaded cached atlas data"
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
      x <- gsub("\\[\\d+\\.?\\d*[ms]s?\\]", "[<TIME>]", x)
      x <- gsub("/tmp/Rtmp[^ ']*|/var/folders[^ ']*", "<TMPDIR>", x)
      gsub("[A-Za-z]:[^ ']*Rtmp[^ ']*", "<TMPDIR>", x)
    }
    expect_snapshot(
      invisible(create_cortical_from_labels(
        labels,
        atlas_name = "test_atlas",
        verbose = TRUE
      )),
      transform = scrub
    )
  })

  it("extracts colours from RGB columns in LUT", {
    labels <- unlist(test_label_files())
    rgb_lut <- data.frame(
      stringsAsFactors = FALSE,
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
      verbose = FALSE
    )

    expect_false(is.null(atlas$palette))
    expect_true(any(grepl("^#", atlas$palette)))
  })

  it("sets NULL colour when LUT lacks hex and RGB columns", {
    labels <- unlist(test_label_files())
    bad_lut <- data.frame(
      stringsAsFactors = FALSE,
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
      verbose = FALSE
    )

    expect_false(is.null(atlas$palette))
  })

  it("passes correct atlas_name and components to cortical_project_and_build", {
    .cap$captured_args <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      cortical_project_and_build = function(...) {
        .cap$captured_args <- list(...)
        structure(list(), class = "ggseg_atlas")
      }
    )

    labels <- unlist(test_label_files())
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    result <- create_cortical_from_labels(
      labels,
      atlas_name = "test_atlas",
      verbose = FALSE
    )

    expect_s3_class(result, "ggseg_atlas")
    expect_identical(.cap$captured_args$atlas_name, "test_atlas")
    expect_gt(nrow(.cap$captured_args$components$core), 0)
  })
})


describe("create_cortical_from_labels hemi fallback", {
  it("defaults to both hemispheres when all hemi values are NA", {
    .cap$captured_hemisphere <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
      ggseg_data_cortical = function(...) list(...),
      cortical_project_and_build = function(...) {
        args <- list(...)
        .cap$captured_hemisphere <- args$hemisphere
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
      verbose = FALSE
    )

    expect_identical(.cap$captured_hemisphere, c("lh", "rh"))
  })
})


describe("create_cortical_from_gifti verbose", {
  it("emits 'from GIFTI' message when verbose", {
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
      cortical_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    tmp <- withr::local_tempfile(pattern = "lh.test", fileext = ".label.gii")
    writeLines("mock", tmp)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_messages(
      create_cortical_from_gifti(
        gifti_files = tmp,
        atlas_name = "test_gifti",
        verbose = TRUE
      ),
      "from GIFTI"
    )
  })
})


describe("create_cortical_from_cifti verbose", {
  it("emits 'from CIFTI' message when verbose", {
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
      cortical_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", tmp)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_messages(
      create_cortical_from_cifti(
        cifti_file = tmp,
        atlas_name = "test_cifti",
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
      cortical_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_messages(
      create_cortical_from_neuromaps(
        source = "test",
        desc = "testdesc",
        atlas_name = "test_neuromaps",
        verbose = TRUE
      ),
      "Fetching neuromaps",
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
      read_neuromaps_volume = function(...) mock_annot,
      cortical_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    expect_messages(
      create_cortical_from_neuromaps(
        source = "test",
        desc = "vol",
        atlas_name = "test_vol",
        verbose = TRUE
      ),
      "Volume annotation detected"
    )
  })
})
