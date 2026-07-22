.cap <- new.env()


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


describe("validate_surface_config", {
  it("returns list with all expected fields", {
    local_mocked_bindings(
      is_verbose = function(x) TRUE,
      get_cleanup = function(x) FALSE,
      get_skip_existing = function(x) FALSE,
      get_tolerance = function(x) 0.5,
      get_output_dir = function(x) tempdir()
    )

    result <- validate_surface_config(
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

  it("reads from file path via read_lut", {
    local_mocked_bindings(
      read_lut = function(path) {
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
