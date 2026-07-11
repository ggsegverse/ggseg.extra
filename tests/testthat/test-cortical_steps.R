.cap <- new.env()

describe("cortical_brain_snapshots", {
  it("dispatches snapshot_brain_full_batch for each hemisphere", {
    .cap$captured <- list()
    local_mocked_bindings(
      snapshot_brain_full_batch = function(atlas, hemisphere, views, ...) {
        .cap$captured[[length(.cap$captured) + 1]] <- list(
          hemisphere = hemisphere,
          views = views
        )
      },
      progressor = function(...) function(...) NULL
    )

    atlas_3d <- structure(list(), class = "ggseg_atlas")
    dirs <- list(base = tempdir())

    cortical_brain_snapshots(
      atlas_3d,
      hemisphere = c("lh", "rh"),
      views = c("lateral", "medial"),
      dirs = dirs,
      skip_existing = FALSE
    )

    expect_length(.cap$captured, 2)
    hemis <- vapply(.cap$captured, `[[`, character(1), "hemisphere")
    expect_true(all(c("lh", "rh") %in% hemis))
    expect_identical(.cap$captured[[1]]$views, c("lateral", "medial"))
  })
})


describe("cortical_region_snapshots", {
  it("filters grid to matching hemi-label pairs", {
    .cap$captured <- list()
    local_mocked_bindings(
      snapshot_region_batch = function(
        atlas,
        region_label,
        hemisphere,
        views,
        ...
      ) {
        .cap$captured[[length(.cap$captured) + 1]] <- list(
          region_label = region_label,
          hemisphere = hemisphere
        )
      },
      filter_visible_regions = function(region_grid, vertices_df) {
        region_grid
      },
      progressor = function(...) function(...) NULL
    )

    components <- list(
      core = data.frame(
        label = c("lh_frontal", "rh_frontal"),
        stringsAsFactors = FALSE
      ),
      vertices_df = data.frame(stringsAsFactors = FALSE, label = character(0))
    )
    atlas_3d <- structure(list(), class = "ggseg_atlas")
    dirs <- list(snapshots = tempdir())

    cortical_region_snapshots(
      atlas_3d,
      components,
      hemisphere = c("lh", "rh"),
      views = "lateral",
      dirs = dirs,
      skip_existing = FALSE
    )

    labels <- vapply(.cap$captured, `[[`, character(1), "region_label")
    hemis <- vapply(.cap$captured, `[[`, character(1), "hemisphere")
    expect_true(all(hemis[labels == "lh_frontal"] == "lh"))
    expect_true(all(hemis[labels == "rh_frontal"] == "rh"))
  })
})


describe("cortical_isolate_regions", {
  it("calls isolate_region for each file in snapshots dir", {
    snap_dir <- withr::local_tempdir("snap_")
    file.create(file.path(snap_dir, "region1.png"))
    file.create(file.path(snap_dir, "region2.png"))

    .cap$captured <- list()
    local_mocked_bindings(
      isolate_region = function(input_file, output_file, ...) {
        .cap$captured[[length(.cap$captured) + 1]] <- basename(input_file)
      },
      progressor = function(...) function(...) NULL
    )

    dirs <- list(
      snapshots = snap_dir,
      masks = withr::local_tempdir("masks_"),
      processed = withr::local_tempdir("proc_")
    )

    cortical_isolate_regions(dirs, skip_existing = FALSE)

    expect_identical(
      sort(unlist(.cap$captured)),
      c("region1.png", "region2.png")
    )
  })
})


describe("cortical_build_sf", {
  it("produces sf with label and view columns", {
    local_mocked_bindings(
      load_reduced_contours = function(base_dir) {
        sf::st_sf(
          hemi = c("left", "right"),
          view = c("lateral", "lateral"),
          label = c("lh_frontal", "rh_frontal"),
          geometry = sf::st_sfc(
            sf::st_polygon(list(matrix(
              c(0, 0, 1, 0, 1, 1, 0, 0),
              ncol = 2,
              byrow = TRUE
            ))),
            sf::st_polygon(list(matrix(
              c(2, 0, 3, 0, 3, 1, 2, 0),
              ncol = 2,
              byrow = TRUE
            )))
          )
        )
      },
      layout_cortical_views = function(df) df
    )

    dirs <- list(base = tempdir())
    result <- cortical_build_sf(dirs)

    expect_s3_class(result, "sf")
    expect_true(all(c("label", "view") %in% names(result)))
  })
})


describe("labels_read_files", {
  it("reads label files and builds atlas data tibble", {
    labels <- unlist(test_label_files())
    default_colours <- rep(NA_character_, length(labels))

    result <- labels_read_files(labels, NULL, NULL, default_colours)

    expect_s3_class(result, "tbl_df")
    expect_identical(nrow(result), 3L)
    expect_true(all(
      c("hemi", "region", "label", "colour", "vertices") %in%
        names(result)
    ))
    expect_true("left" %in% result$hemi)
    expect_true("right" %in% result$hemi)
  })

  it("uses custom region_names when provided", {
    labels <- unlist(test_label_files())
    default_colours <- rep(NA_character_, length(labels))
    custom_names <- c("Motor", "Visual", "Motor")

    result <- labels_read_files(labels, custom_names, NULL, default_colours)

    expect_identical(result$region, custom_names)
  })
})


describe("labels_read_files hemisphere-less filenames", {
  it("assigns region without hemi prefix for unknown hemisphere", {
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

    default_colours <- rep(NA_character_, 1)

    result <- labels_read_files(
      c(nohemi_file),
      NULL,
      NULL,
      default_colours
    )

    expect_identical(result$label[1], "some_region")
    expect_true(is.na(result$hemi[1]))
  })
})


describe("labels_region_snapshots", {
  it("also takes NA region snapshots", {
    .cap$region_captured <- list()
    .cap$na_captured <- list()
    local_mocked_bindings(
      snapshot_region_batch = function(...) {
        .cap$region_captured[[length(.cap$region_captured) + 1]] <- TRUE
      },
      snapshot_na_regions_batch = function(...) {
        .cap$na_captured[[length(.cap$na_captured) + 1]] <- TRUE
      },
      filter_visible_regions = function(region_grid, vertices_df) {
        region_grid
      },
      progressor = function(...) function(...) NULL
    )

    components <- list(
      core = data.frame(
        label = c("lh_motor", "rh_motor"),
        region = c("motor", "motor"),
        stringsAsFactors = FALSE
      )
    )
    atlas_3d <- structure(list(), class = "ggseg_atlas")
    dirs <- list(snapshots = tempdir())

    labels_region_snapshots(
      atlas_3d,
      components,
      hemi_short = c("lh", "rh"),
      views = "lateral",
      dirs = dirs,
      skip_existing = FALSE
    )

    expect_gt(length(.cap$region_captured), 0)
    expect_gt(length(.cap$na_captured), 0)
  })
})


describe("validate_cortical_config", {
  it("returns list with all expected fields", {
    local_mocked_bindings(
      is_verbose = function(x) TRUE,
      get_cleanup = function(x) FALSE,
      get_skip_existing = function(x) FALSE,
      get_tolerance = function(x) 0.5,
      get_output_dir = function(x) tempdir()
    )

    result <- validate_cortical_config(
      NULL,
      NULL,
      NULL,
      NULL,
      NULL
    )

    expect_type(result, "list")
    expected_fields <- c(
      "output_dir",
      "verbose",
      "cleanup",
      "skip_existing",
      "tolerance"
    )
    expect_true(all(expected_fields %in% names(result)))
  })
})


describe("parse_lut_colours", {
  it("returns NULLs when input is NULL", {
    result <- parse_lut_colours(NULL)

    expect_null(result$region_names)
    expect_null(result$colours)
  })

  it("extracts hex colours from data.frame", {
    lut <- data.frame(
      stringsAsFactors = FALSE,
      region = c("Motor", "Visual"),
      hex = c("#FF0000", "#00FF00")
    )

    result <- parse_lut_colours(lut)

    expect_identical(result$region_names, c("Motor", "Visual"))
    expect_identical(result$colours, c("#FF0000", "#00FF00"))
  })

  it("converts RGB columns to hex", {
    lut <- data.frame(
      stringsAsFactors = FALSE,
      region = "Motor",
      R = 255,
      G = 0,
      B = 128
    )

    result <- parse_lut_colours(lut)

    expect_identical(result$region_names, "Motor")
    expect_identical(
      result$colours,
      grDevices::rgb(255, 0, 128, maxColorValue = 255)
    )
  })

  it("returns NULL colours when no colour columns", {
    lut <- data.frame(stringsAsFactors = FALSE, region = c("Motor", "Visual"))

    result <- parse_lut_colours(lut)

    expect_identical(result$region_names, c("Motor", "Visual"))
    expect_null(result$colours)
  })

  it("reads from file path via read_ctab", {
    local_mocked_bindings(
      read_ctab = function(path) {
        data.frame(
          stringsAsFactors = FALSE,
          region = "FromFile",
          hex = "#AABBCC"
        )
      }
    )

    result <- parse_lut_colours("/fake/path.ctab")

    expect_identical(result$region_names, "FromFile")
    expect_identical(result$colours, "#AABBCC")
  })
})
