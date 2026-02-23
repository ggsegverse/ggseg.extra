describe("detect_hemi_from_gifti_filename", {
  it("detects lh from lh. prefix", {
    expect_equal(detect_hemi_from_gifti_filename("lh.aparc.label.gii"), "lh")
  })

  it("detects rh from rh. prefix", {
    expect_equal(detect_hemi_from_gifti_filename("rh.aparc.label.gii"), "rh")
  })

  it("detects left from .L. pattern", {
    expect_equal(
      detect_hemi_from_gifti_filename("aparc.L.label.gii"),
      "lh"
    )
  })

  it("detects right from .R. pattern", {
    expect_equal(
      detect_hemi_from_gifti_filename("aparc.R.label.gii"),
      "rh"
    )
  })

  it("detects from _lh_ pattern", {
    expect_equal(
      detect_hemi_from_gifti_filename("atlas_lh_aparc.label.gii"),
      "lh"
    )
  })

  it("returns NA for undetectable hemisphere", {
    expect_true(is.na(detect_hemi_from_gifti_filename("aparc.label.gii")))
  })
})


describe("read_gifti_annotation", {
  it("errors when file does not exist", {
    expect_error(
      read_gifti_annotation("nonexistent.label.gii"),
      "not found"
    )
  })

  it("returns tibble with correct structure", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = c(1L, 1L, 2L, 2L, 0L),
      colortable_df = data.frame(
        struct_name = c("region_a", "region_b"),
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

    tmp <- withr::local_tempfile(
      pattern = "lh.test",
      fileext = ".label.gii"
    )
    writeLines("mock", tmp)

    result <- read_gifti_annotation(tmp)

    expect_s3_class(result, "tbl_df")
    expect_named(result, c("hemi", "region", "label", "colour", "vertices"))
    expect_true(all(result$hemi == "left"))
    expect_true("lh_region_a" %in% result$label)
    expect_true("lh_region_b" %in% result$label)
  })

  it("extracts 0-indexed vertex indices", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = c(1L, 1L, 2L),
      colortable_df = data.frame(
        struct_name = c("a", "b"),
        r = c(100L, 200L),
        g = c(100L, 200L),
        b = c(100L, 200L),
        a = c(0L, 0L),
        code = c(1L, 2L),
        hex_color_string_rgb = c("#646464", "#C8C8C8"),
        hex_color_string_rgba = c("#64646400", "#C8C8C800"),
        struct_index = c(0L, 1L),
        stringsAsFactors = FALSE
      )
    )

    local_mocked_bindings(
      read.fs.annot.gii = function(...) mock_annot,
      .package = "freesurferformats"
    )

    tmp <- withr::local_tempfile(
      pattern = "rh.test",
      fileext = ".label.gii"
    )
    writeLines("mock", tmp)

    result <- read_gifti_annotation(tmp)
    region_a <- result[result$region == "a", ]

    expect_equal(region_a$vertices[[1]], c(0L, 1L))
  })

  it("warns and skips files with undetectable hemisphere", {
    skip_if_not_installed("freesurferformats")

    tmp <- withr::local_tempfile(
      pattern = "unknown",
      fileext = ".label.gii"
    )
    writeLines("mock", tmp)

    expect_warning(
      result <- read_gifti_annotation(tmp),
      "Cannot detect hemisphere"
    )
    expect_equal(nrow(result), 0)
  })
})


describe("read_cifti_annotation", {
  it("errors when file does not exist", {
    skip_if_not_installed("ciftiTools")

    expect_error(
      read_cifti_annotation("nonexistent.dlabel.nii"),
      "not found"
    )
  })

  it("returns tibble with correct structure", {
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

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", tmp)

    result <- read_cifti_annotation(tmp)

    expect_s3_class(result, "tbl_df")
    expect_named(result, c("hemi", "region", "label", "colour", "vertices"))
    expect_true("left" %in% result$hemi)
    expect_true("right" %in% result$hemi)
    expect_true("lh_region_a" %in% result$label)
    expect_true("rh_region_b" %in% result$label)
  })

  it("uses maxColorValue = 1 for CIFTI colours", {
    skip_if_not_installed("ciftiTools")

    n <- 10242L
    mock_cii <- list(
      data = list(
        cortex_left = matrix(rep(1L, n), ncol = 1),
        cortex_right = NULL
      ),
      meta = list(
        cifti = list(
          labels = list(
            data.frame(
              Key = 1L,
              Label = "test_region",
              Red = 1.0,
              Green = 0.0,
              Blue = 0.0,
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

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", tmp)

    result <- read_cifti_annotation(tmp)
    expect_equal(result$colour[result$region == "test_region"], "#FF0000")
  })

  it("errors when vertex count does not match fsaverage5", {
    skip_if_not_installed("ciftiTools")

    mock_cii <- list(
      data = list(
        cortex_left = matrix(rep(1L, 5000), ncol = 1),
        cortex_right = NULL
      ),
      meta = list(
        cifti = list(
          labels = list(
            data.frame(
              Key = 1L,
              Label = "test",
              Red = 1.0,
              Green = 0.0,
              Blue = 0.0,
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

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", tmp)

    expect_error(
      read_cifti_annotation(tmp),
      "expected 10242"
    )
  })
})


describe("create_cortical_from_gifti", {
  it("creates ggseg_atlas with steps = 1", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = c(1L, 1L, 2L, 2L, 0L),
      colortable_df = data.frame(
        struct_name = c("region_a", "region_b"),
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
      is_interactive = function() FALSE,
      preview_atlas = function(atlas) invisible(atlas)
    )

    lh <- withr::local_tempfile(pattern = "lh.test", fileext = ".label.gii")
    rh <- withr::local_tempfile(pattern = "rh.test", fileext = ".label.gii")
    writeLines("mock", lh)
    writeLines("mock", rh)

    result <- create_cortical_from_gifti(
      gifti_files = c(lh, rh),
      atlas_name = "test_gifti",
      steps = 1,
      verbose = FALSE,
      cleanup = FALSE
    )

    expect_s3_class(result, "ggseg_atlas")
    expect_true(nrow(result$core) > 0)
  })
})


describe("is_integer_valued", {
  it("returns TRUE for integer vectors", {
    expect_true(is_integer_valued(c(1, 2, 3, 0)))
  })

  it("returns TRUE for integer vectors with NaN", {
    expect_true(is_integer_valued(c(1, 2, NaN, 0)))
  })

  it("returns FALSE for continuous values", {
    expect_false(is_integer_valued(c(0.5, 1.2, -0.3)))
  })

  it("returns TRUE for all-NaN input", {
    expect_true(is_integer_valued(c(NaN, NaN)))
  })
})


describe("parse_continuous_values", {
  it("bins values into quantile groups", {
    values <- c(seq(0, 1, length.out = 100), NaN, NaN)
    result <- parse_continuous_values(values, "left", "lh", n_bins = 5)

    region_names <- vapply(result, function(r) r$region[1], character(1))
    expect_true("bin_1" %in% region_names)
    expect_true("bin_5" %in% region_names)
    expect_true("unknown" %in% region_names)

    total_verts <- sum(vapply(
      result, function(r) length(r$vertices[[1]]), integer(1)
    ))
    expect_equal(total_verts, 102)
  })

  it("assigns NaN vertices to unknown", {
    values <- c(1.0, 2.0, NaN, NaN, NaN)
    result <- parse_continuous_values(values, "right", "rh", n_bins = 2)

    unknown <- Filter(function(r) r$region[1] == "unknown", result)
    expect_length(unknown, 1)
    expect_equal(length(unknown[[1]]$vertices[[1]]), 3)
  })

  it("auto-detects n_bins via Sturges when NULL", {
    values <- rnorm(10000)
    result <- parse_continuous_values(values, "left", "lh", n_bins = NULL)

    bins <- Filter(function(r) grepl("^bin_", r$region[1]), result)
    expected <- as.integer(nclass.Sturges(values))
    expect_equal(length(bins), expected)
  })

  it("clamps auto-detected bins to 5-20 range", {
    few <- rnorm(10)
    result <- parse_continuous_values(few, "left", "lh", n_bins = NULL)
    bins <- Filter(function(r) grepl("^bin_", r$region[1]), result)
    expect_gte(length(bins), 3)
    expect_lte(length(bins), 20)
  })
})


describe("parse_parcellation_values", {
  it("creates regions from integer IDs", {
    values <- c(1, 1, 2, 2, 0)
    result <- parse_parcellation_values(
      values, "left", "lh", label_table = NULL
    )

    region_names <- vapply(result, function(r) r$region[1], character(1))
    expect_true("parcel_1" %in% region_names)
    expect_true("parcel_2" %in% region_names)
    expect_true("unknown" %in% region_names)
  })

  it("treats NaN as medial wall", {
    values <- c(1, 2, NaN)
    result <- parse_parcellation_values(
      values, "left", "lh", label_table = NULL
    )

    unknown <- Filter(function(r) r$region[1] == "unknown", result)
    expect_length(unknown, 1)
    expect_equal(unknown[[1]]$vertices[[1]], 2L)
  })

  it("uses label_table when provided", {
    values <- c(1, 1, 2, 0)
    lt <- data.frame(
      id = c(1L, 2L),
      region = c("frontal", "parietal"),
      colour = c("#FF0000", "#00FF00"),
      stringsAsFactors = FALSE
    )
    result <- parse_parcellation_values(values, "left", "lh", label_table = lt)

    labels <- vapply(result, function(r) r$label[1], character(1))
    expect_true("lh_frontal" %in% labels)
    expect_true("lh_parietal" %in% labels)
  })
})


describe("read_neuromaps_annotation", {
  it("auto-detects continuous data and bins it", {
    skip_if_not_installed("gifti")

    n <- 10242L
    mock_gii <- list(data = list(rnorm(n)))

    local_mocked_bindings(
      read_gifti = function(...) mock_gii,
      .package = "gifti"
    )

    lh <- withr::local_tempfile(
      pattern = "source-test_hemi-L",
      fileext = ".func.gii"
    )
    rh <- withr::local_tempfile(
      pattern = "source-test_hemi-R",
      fileext = ".func.gii"
    )
    writeLines("mock", lh)
    writeLines("mock", rh)

    result <- read_neuromaps_annotation(c(lh, rh), n_bins = 5)

    expect_s3_class(result, "tbl_df")
    expect_named(result, c("hemi", "region", "label", "colour", "vertices"))

    bin_regions <- result[grepl("^bin_", result$region), ]
    expect_equal(length(unique(bin_regions$region)), 5)

    expect_true("left" %in% result$hemi)
    expect_true("right" %in% result$hemi)
  })

  it("auto-detects integer parcellation data", {
    skip_if_not_installed("gifti")

    n <- 10242L
    mock_gii <- list(data = list(c(rep(1, 5000), rep(2, 5000), rep(0, 242))))

    local_mocked_bindings(
      read_gifti = function(...) mock_gii,
      .package = "gifti"
    )

    lh <- withr::local_tempfile(
      pattern = "source-test_hemi-L",
      fileext = ".func.gii"
    )
    writeLines("mock", lh)

    result <- read_neuromaps_annotation(lh)

    parcel_regions <- result[grepl("^parcel_", result$region), ]
    expect_equal(nrow(parcel_regions), 2)
    expect_true("unknown" %in% result$region)
  })

  it("handles all-NaN medial wall in continuous data", {
    skip_if_not_installed("gifti")

    n <- 10242L
    vals <- rnorm(n)
    vals[1:1000] <- NaN
    mock_gii <- list(data = list(vals))

    local_mocked_bindings(
      read_gifti = function(...) mock_gii,
      .package = "gifti"
    )

    lh <- withr::local_tempfile(
      pattern = "source-test_hemi-L",
      fileext = ".func.gii"
    )
    writeLines("mock", lh)

    result <- read_neuromaps_annotation(lh, n_bins = 3)

    unknown <- result[result$region == "unknown", ]
    expect_equal(length(unknown$vertices[[1]]), 1000)

    total_verts <- sum(vapply(result$vertices, length, integer(1)))
    expect_equal(total_verts, n)
  })
})


describe("create_cortical_from_cifti", {
  it("creates ggseg_atlas with steps = 1", {
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
      is_interactive = function() FALSE,
      preview_atlas = function(atlas) invisible(atlas)
    )

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", tmp)

    result <- create_cortical_from_cifti(
      cifti_file = tmp,
      atlas_name = "test_cifti",
      steps = 1,
      verbose = FALSE,
      cleanup = FALSE
    )

    expect_s3_class(result, "ggseg_atlas")
    expect_true(nrow(result$core) > 0)
    expect_true("left" %in% result$core$hemi)
    expect_true("right" %in% result$core$hemi)
  })

  it("auto-derives atlas_name from filename", {
    skip_if_not_installed("ciftiTools")

    n <- 10242L
    mock_cii <- list(
      data = list(
        cortex_left = matrix(c(rep(1L, 5000), rep(2L, 5242)), ncol = 1),
        cortex_right = NULL
      ),
      meta = list(
        cifti = list(
          labels = list(
            data.frame(
              Key = c(1L, 2L),
              Label = c("a", "b"),
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
      is_interactive = function() FALSE,
      preview_atlas = function(atlas) invisible(atlas)
    )

    tmp <- withr::local_tempfile(pattern = "my.atlas", fileext = ".dlabel.nii")
    writeLines("mock", tmp)

    result <- create_cortical_from_cifti(
      cifti_file = tmp, steps = 1, verbose = FALSE, cleanup = FALSE
    )
    expect_true(grepl("my_atlas", result$atlas))
  })

  it("calls cortical_pipeline for steps > 1", {
    skip_if_not_installed("ciftiTools")

    pipeline_called <- FALSE
    n <- 10242L
    mock_cii <- list(
      data = list(
        cortex_left = matrix(rep(1L, n), ncol = 1),
        cortex_right = NULL
      ),
      meta = list(
        cifti = list(
          labels = list(
            data.frame(
              Key = 1L, Label = "a", Red = 1, Green = 0, Blue = 0,
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
      cortical_pipeline = function(...) {
        pipeline_called <<- TRUE
        structure(list(), class = "ggseg_atlas")
      }
    )

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", tmp)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    create_cortical_from_cifti(
      cifti_file = tmp, steps = 1:8, verbose = FALSE
    )
    expect_true(pipeline_called)
  })
})


describe("create_cortical_from_gifti", {
  it("auto-derives atlas_name from filename", {
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
      is_interactive = function() FALSE,
      preview_atlas = function(atlas) invisible(atlas)
    )

    tmp <- withr::local_tempfile(pattern = "lh.myatlas", fileext = ".label.gii")
    writeLines("mock", tmp)

    result <- create_cortical_from_gifti(
      gifti_files = tmp, steps = 1, verbose = FALSE, cleanup = FALSE
    )
    expect_true(grepl("myatlas", result$atlas))
  })

  it("calls cortical_pipeline for steps > 1", {
    skip_if_not_installed("freesurferformats")

    pipeline_called <- FALSE
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
      cortical_pipeline = function(...) {
        pipeline_called <<- TRUE
        structure(list(), class = "ggseg_atlas")
      }
    )

    tmp <- withr::local_tempfile(pattern = "lh.test", fileext = ".label.gii")
    writeLines("mock", tmp)
    withr::local_options(ggseg.extra.output_dir = withr::local_tempdir())

    create_cortical_from_gifti(
      gifti_files = tmp, steps = 1:8, verbose = FALSE
    )
    expect_true(pipeline_called)
  })
})
