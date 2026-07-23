describe("read_volume", {
  it("errors on missing file", {
    expect_error(
      read_volume("/nonexistent/file.mgz"),
      "not found"
    )
  })

  it("errors on unsupported format", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines("test", tmp)

    expect_error(
      read_volume(tmp),
      "Unsupported volume format"
    )
  })

  it("reads MGZ files", {
    skip_if_no_freesurfer()

    mgz_file <- test_mgz_file()
    skip_if(!file.exists(mgz_file), "Test MGZ file not found")

    vol <- read_volume(mgz_file)
    expect_true(is.array(vol))
    expect_length(dim(vol), 3)
  })

  it("reads NIfTI files when RNifti available", {
    skip_if_not_installed("RNifti")

    tmp <- withr::local_tempfile(fileext = ".nii.gz")
    vol <- array(1:27, dim = c(3, 3, 3))
    RNifti::writeNifti(vol, tmp)

    result <- read_volume(tmp)
    expect_true(is.array(result))
    expect_identical(dim(result), c(3L, 3L, 3L))
  })
})


describe("read_volume with reorient FALSE", {
  it("returns niftiImage when reorient is FALSE", {
    skip_if_not_installed("RNifti")

    tmp <- withr::local_tempfile(fileext = ".nii.gz")
    vol <- array(1:27, dim = c(3, 3, 3))
    RNifti::writeNifti(vol, tmp)

    result <- read_volume(tmp, reorient = FALSE)

    expect_s3_class(result, "niftiImage")
  })
})


describe("reorient_volume_to_ras", {
  # LIA vox2ras: axis1 -> Left (-R), axis2 -> Inferior (-S), axis3 -> Anterior
  lia <- rbind(c(-1, 0, 0), c(0, 0, 1), c(0, -1, 0))

  it("reorients an LIA volume to RAS+", {
    vol <- array(0L, dim = c(2, 2, 2))
    vol[1, 1, 1] <- 1L

    out <- reorient_volume_to_ras(vol, lia)

    expect_identical(dim(out), c(2L, 2L, 2L))
    # [1,1,1] in LIA = most Left, Superior, Posterior -> in RAS that voxel is at
    # max-R (dim1=2), min-A (dim2=1), max-S (dim3=2)
    expect_equal(
      which(out == 1L, arr.ind = TRUE)[1, ],
      c(2L, 1L, 2L),
      ignore_attr = TRUE
    )
  })

  it("leaves an already-RAS volume unchanged", {
    vol <- array(seq_len(8), dim = c(2, 2, 2))
    expect_identical(reorient_volume_to_ras(vol, diag(4)), vol)
  })

  it("accepts a bare 3x3 direction matrix", {
    vol <- array(seq_len(8), dim = c(2, 2, 2))
    expect_identical(reorient_volume_to_ras(vol, diag(3)), vol)
  })

  it("errors when the affine has no clear axis mapping", {
    vol <- array(0L, dim = c(2, 2, 2))
    degenerate <- rbind(c(1, 1, 0), c(1, 1, 0), c(0, 0, 1))
    expect_error(
      reorient_volume_to_ras(vol, degenerate),
      "RAS axis mapping"
    )
  })
})


describe("read_volume MGZ reorientation", {
  lia <- rbind(c(-1, 0, 0, 2), c(0, 0, 1, -2), c(0, -1, 0, 2), c(0, 0, 0, 1))

  make_lia_mgz <- function() {
    tmp <- withr::local_tempfile(
      fileext = ".mgz",
      .local_envir = parent.frame()
    )
    vol <- array(0L, dim = c(4, 4, 4))
    vol[1, 1, 1] <- 7L
    freesurferformats::write.fs.mgh(tmp, vol, vox2ras_matrix = lia)
    tmp
  }

  it("reorients a native-LIA MGZ to RAS+ by default", {
    out <- read_volume(make_lia_mgz())

    expect_identical(dim(out), c(4L, 4L, 4L))
    expect_equal(
      which(out == 7L, arr.ind = TRUE)[1, ],
      c(4L, 1L, 4L),
      ignore_attr = TRUE
    )
  })

  it("preserves native voxel order when reorient is FALSE", {
    out <- read_volume(make_lia_mgz(), reorient = FALSE)

    expect_equal(
      which(out == 7L, arr.ind = TRUE)[1, ],
      c(1L, 1L, 1L),
      ignore_attr = TRUE
    )
  })
})


describe("read_lut", {
  it("reads color table from file", {
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    result <- read_lut(lut_file)

    expect_s3_class(result, "data.frame")
    expect_true(all(c("idx", "label", "R", "G", "B", "A") %in% names(result)))
    expect_gt(nrow(result), 0)
  })

  it("reads optional type column when present", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines(
      c(
        "  0  Unknown          0   0   0   0",
        "  1  Lobule-I        205 130 176   0  Anterior",
        "  2  Lobule-II       100  50  25   0  Posterior"
      ),
      tmp
    )

    result <- read_lut(tmp)

    expect_s3_class(result, "data.frame")
    expect_identical(nrow(result), 3L)
    expect_true("type" %in% names(result))
    expect_identical(result$type, c(NA, "Anterior", "Posterior"))
  })

  it("omits type column when no rows have it", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines(
      c(
        "  0  Unknown          0   0   0   0",
        "  1  Region1        205 130 176   0"
      ),
      tmp
    )

    result <- read_lut(tmp)

    expect_named(result, c("idx", "label", "R", "G", "B", "A"))
  })
})


describe("read_ctab (deprecated)", {
  it("warns about deprecation and delegates to read_lut", {
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    lifecycle::expect_deprecated(result <- read_ctab(lut_file))

    expect_identical(result, read_lut(lut_file))
  })
})


describe("write_lut", {
  it("writes color table to file", {
    ctab <- data.frame(
      stringsAsFactors = FALSE,
      idx = c(1L, 2L, 3L),
      label = c("Region1", "Region2", "Region3"),
      R = c(255, 0, 0),
      G = c(0, 255, 0),
      B = c(0, 0, 255),
      A = c(0, 0, 0)
    )

    tmp <- withr::local_tempfile(fileext = ".txt")
    write_lut(ctab, tmp)

    expect_true(file.exists(tmp))

    read_back <- read_lut(tmp)
    expect_identical(nrow(read_back), 3L)
    expect_identical(read_back$idx, ctab$idx)
  })

  it("truncates long label names to 29 characters", {
    long_label <- strrep("a", 40)
    ctab <- data.frame(
      idx = 1,
      label = long_label,
      R = 255,
      G = 0,
      B = 0,
      A = 0
    )

    tmp <- withr::local_tempfile(fileext = ".txt")
    write_lut(ctab, tmp)

    content <- readLines(tmp)
    expect_true(all(nchar(content) < 60))
  })
})


describe("write_ctab (deprecated)", {
  it("warns about deprecation and delegates to write_lut", {
    ctab <- data.frame(
      stringsAsFactors = FALSE,
      idx = 1L,
      label = "Region1",
      R = 255,
      G = 0,
      B = 0,
      A = 0
    )
    tmp <- withr::local_tempfile(fileext = ".txt")

    lifecycle::expect_deprecated(write_ctab(ctab, tmp))

    expect_true(file.exists(tmp))
  })
})


describe("is_lut", {
  it("returns TRUE for valid color table", {
    ctab <- data.frame(
      stringsAsFactors = FALSE,
      idx = 1:3,
      label = c("a", "b", "c"),
      R = c(255, 0, 0),
      G = c(0, 255, 0),
      B = c(0, 0, 255),
      A = c(0, 0, 0)
    )

    expect_true(is_lut(ctab))
  })

  it("returns FALSE for non-data.frame", {
    expect_false(is_lut(list(idx = 1, label = "a")))
    expect_false(is_lut("not a data.frame"))
    expect_false(is_lut(NULL))
  })

  it("returns FALSE for missing columns", {
    partial <- data.frame(
      stringsAsFactors = FALSE,
      idx = 1,
      label = "a",
      R = 255
    )
    expect_false(is_lut(partial))
  })
})


describe("is_ctab (deprecated)", {
  it("warns about deprecation and delegates to is_lut", {
    ctab <- data.frame(
      stringsAsFactors = FALSE,
      idx = 1,
      label = "a",
      R = 255,
      G = 0,
      B = 0,
      A = 0
    )

    lifecycle::expect_deprecated(result <- is_ctab(ctab))

    expect_true(result)
  })
})


describe("get_lut", {
  it("reads and adds hex colors from file path", {
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    result <- get_lut(lut_file)

    expect_true("color" %in% names(result))
    expect_true("roi" %in% names(result))
    expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", result$color)))
  })

  it("accepts data.frame input", {
    ctab <- data.frame(
      stringsAsFactors = FALSE,
      idx = c(1, 2),
      label = c("Region1", "Region2"),
      R = c(255, 0),
      G = c(0, 255),
      B = c(0, 0),
      A = c(0, 0)
    )

    result <- get_lut(ctab)

    expect_identical(result$color, c("#FF0000", "#00FF00"))
    expect_identical(result$roi, c("0001", "0002"))
  })

  it("errors for invalid color table format", {
    invalid <- data.frame(x = 1, y = 2)

    expect_error(get_lut(invalid), "correct format")
  })
})


describe("get_ctab (deprecated)", {
  it("warns about deprecation and delegates to get_lut", {
    ctab <- data.frame(
      stringsAsFactors = FALSE,
      idx = 1,
      label = "Region1",
      R = 255,
      G = 0,
      B = 0,
      A = 0
    )

    lifecycle::expect_deprecated(result <- get_ctab(ctab))

    expect_identical(result, get_lut(ctab))
  })
})


describe("read_label_vertices", {
  it("warns and returns empty for malformed file", {
    skip_if_not_installed("freesurferformats")

    tmp <- withr::local_tempfile(fileext = ".label")
    writeLines("", tmp)

    expect_warning(
      {
        result <- read_label_vertices(tmp)
      },
      "Could not parse"
    )

    expect_type(result, "integer")
    expect_length(result, 0)
  })

  it("reads standard FreeSurfer label file", {
    skip_if_not_installed("freesurferformats")

    tmp <- withr::local_tempfile(fileext = ".label")
    content <- c(
      "#!ascii label from subject",
      "3",
      "100  0.0  0.0  0.0  0.0",
      "101  1.0  0.0  0.0  0.0",
      "102  2.0  0.0  0.0  0.0"
    )
    writeLines(content, tmp)

    result <- read_label_vertices(tmp)

    expect_identical(result, c(100L, 101L, 102L))
  })

  it("returns 0-indexed vertex indices", {
    skip_if_not_installed("freesurferformats")

    tmp <- withr::local_tempfile(fileext = ".label")
    content <- c(
      "#!ascii label",
      "2",
      "0  0.0  0.0  0.0  0.0",
      "1  1.0  0.0  0.0  0.0"
    )
    writeLines(content, tmp)

    result <- read_label_vertices(tmp)

    expect_identical(result, c(0L, 1L))
  })
})


describe("read_dpv", {
  it("reads vertices and 0-indexed faces from a .dpv file", {
    tmp <- withr::local_tempfile(fileext = ".dpv")
    writeLines(
      c(
        "#!ascii",
        "3 1",
        "0 0 0 0",
        "1 0 0 0",
        "0 1 0 0",
        "0 1 2 0"
      ),
      tmp
    )

    result <- read_dpv(tmp)

    expect_type(result, "list")
    expect_true(all(c("vertices", "faces") %in% names(result)))
    expect_identical(nrow(result$vertices), 3L)
    expect_identical(nrow(result$faces), 1L)
    expect_named(result$vertices, c("x", "y", "z"))
    expect_named(result$faces, c("i", "j", "k"))
    expect_identical(as.numeric(result$faces[1, ]), c(0, 1, 2))
  })
})


describe("read_annotation_data", {
  it("warns and skips files without hemisphere prefix", {
    skip_if_not_installed("freesurferformats")

    tmp <- withr::local_tempfile(fileext = ".annot")
    writeLines("dummy", tmp)

    local_mocked_bindings(
      read.fs.annot = function(...) {
        stop("should not be called")
      },
      .package = "freesurferformats"
    )

    expect_warning(
      {
        result <- read_annotation_data(tmp)
      },
      "Cannot detect hemisphere"
    )

    expect_identical(nrow(result), 0L)
  })

  it("skips regions with zero matching vertices", {
    skip_if_not_installed("freesurferformats")

    tmp_dir <- withr::local_tempdir()
    tmp_lh <- file.path(tmp_dir, "lh.test.annot")
    writeLines("dummy", tmp_lh)

    mock_annot <- list(
      label_codes = c(1L, 1L, 1L),
      colortable_df = data.frame(
        struct_name = c("motor", "ghost_region"),
        r = c(255L, 0L),
        g = c(0L, 255L),
        b = c(0L, 0L),
        a = c(0L, 0L),
        code = c(1L, 999L),
        hex_color_string_rgb = c("#FF0000", "#00FF00"),
        hex_color_string_rgba = c("#FF000000", "#00FF0000"),
        struct_index = c(0L, 1L),
        stringsAsFactors = FALSE
      )
    )

    local_mocked_bindings(
      read.fs.annot = function(...) mock_annot,
      .package = "freesurferformats"
    )

    result <- read_annotation_data(tmp_lh)

    region_names <- result$region
    expect_true("motor" %in% region_names)
    expect_false("ghost_region" %in% region_names)
  })
})


describe("read_neuromaps_volume", {
  it("projects volume to surface and returns atlas data", {
    skip_if_not_installed("RNifti")

    output_dir <- withr::local_tempdir()
    surf_dir <- file.path(output_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    n <- 10242L
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- if (grepl("lh", hemisphere, fixed = TRUE)) {
          c(rep(1, 5000), rep(2, 5242))
        } else {
          c(rep(1, 4000), rep(2, 6242))
        }
        RNifti::writeNifti(array(values, dim = c(n, 1, 1)), output_file)
      }
    )

    result <- read_neuromaps_volume("fake.nii.gz", output_dir = output_dir)

    expect_s3_class(result, "tbl_df")
    expect_named(result, c("hemi", "region", "label", "colour", "vertices"))
    expect_true("left" %in% result$hemi)
    expect_true("right" %in% result$hemi)
  })

  it("auto-assigns colours to regions without colour", {
    skip_if_not_installed("RNifti")

    output_dir <- withr::local_tempdir()
    surf_dir <- file.path(output_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    n <- 10242L
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(1, 5000), rep(2, 5242))
        RNifti::writeNifti(array(values, dim = c(n, 1, 1)), output_file)
      }
    )

    result <- read_neuromaps_volume("fake.nii.gz", output_dir = output_dir)

    named_regions <- result[result$region != "unknown", ]
    expect_false(anyNA(named_regions$colour))
  })

  it("handles continuous values with binning", {
    skip_if_not_installed("RNifti")

    output_dir <- withr::local_tempdir()
    surf_dir <- file.path(output_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    n <- 10242L
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- seq(0.1, 10, length.out = n)
        RNifti::writeNifti(array(values, dim = c(n, 1, 1)), output_file)
      }
    )

    result <- read_neuromaps_volume(
      "fake.nii.gz",
      n_bins = 5,
      output_dir = output_dir
    )

    expect_s3_class(result, "tbl_df")
    bin_regions <- result[grepl("^bin_", result$region), ]
    expect_gt(nrow(bin_regions), 0)
    expect_false(anyNA(bin_regions$colour))
  })

  it("errors when mri_vol2surf fails to produce output", {
    skip_if_not_installed("RNifti")

    output_dir <- withr::local_tempdir()

    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      mri_vol2surf = function(...) invisible(NULL)
    )

    expect_error(
      read_neuromaps_volume("fake.nii.gz", output_dir = output_dir),
      "mri_vol2surf failed"
    )
  })

  it("includes medial wall as unknown region for parcellation data", {
    skip_if_not_installed("RNifti")

    output_dir <- withr::local_tempdir()
    surf_dir <- file.path(output_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    n <- 10242L
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        values <- c(rep(0, 2000), rep(1, 4000), rep(2, 4242))
        RNifti::writeNifti(array(values, dim = c(n, 1, 1)), output_file)
      }
    )

    result <- read_neuromaps_volume("fake.nii.gz", output_dir = output_dir)

    expect_true("unknown" %in% result$region)
  })
})


describe("read_cifti_annotation", {
  it("skips label_table entries with zero matching vertices", {
    skip_if_not_installed("ciftiTools")

    local_mocked_bindings(
      read_cifti = function(...) {
        list(
          data = list(
            cortex_left = matrix(c(rep(1L, 5000), rep(2L, 5242)), ncol = 1),
            cortex_right = matrix(rep(1L, 10242), ncol = 1)
          ),
          meta = list(
            cifti = list(
              labels = list(data.frame(
                Key = c(1L, 2L, 999L),
                Label = c("region_a", "region_b", "ghost"),
                Red = c(1, 0, 0.5),
                Green = c(0, 1, 0.5),
                Blue = c(0, 0, 0.5),
                Alpha = c(1, 1, 1),
                stringsAsFactors = FALSE
              ))
            )
          )
        )
      },
      .package = "ciftiTools"
    )

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    file.create(tmp)

    result <- read_cifti_annotation(tmp)

    expect_false("ghost" %in% result$region)
    expect_true("region_a" %in% result$region)
    expect_true("region_b" %in% result$region)
  })

  it("creates unknown region for unlabeled vertices", {
    skip_if_not_installed("ciftiTools")

    local_mocked_bindings(
      read_cifti = function(...) {
        list(
          data = list(
            cortex_left = matrix(c(rep(1L, 5000), rep(0L, 5242)), ncol = 1),
            cortex_right = NULL
          ),
          meta = list(
            cifti = list(
              labels = list(data.frame(
                Key = 1L,
                Label = "region_a",
                Red = 1,
                Green = 0,
                Blue = 0,
                Alpha = 1,
                stringsAsFactors = FALSE
              ))
            )
          )
        )
      },
      .package = "ciftiTools"
    )

    tmp <- withr::local_tempfile(fileext = ".dlabel.nii")
    file.create(tmp)

    result <- read_cifti_annotation(tmp)

    expect_true("unknown" %in% result$region)
    unknown_row <- result[result$region == "unknown", ]
    expect_identical(unknown_row$colour[1], "#BEBEBE")
  })
})


describe("parse_parcellation_values", {
  it("skips parcel_id with zero matching vertices", {
    values <- c(1, 1, 2, 2, 0)
    result <- parse_parcellation_values(values, "left", "lh", NULL)
    regions <- vapply(result, function(x) x$region[1], character(1))
    expect_true("parcel_1" %in% regions)
    expect_true("parcel_2" %in% regions)
  })
})


describe("parse_continuous_values", {
  it("skips bins with zero vertices", {
    values <- c(rep(NaN, 10240), 0.5, 9.5)
    result <- parse_continuous_values(values, "left", "lh", n_bins = 10)
    bin_regions <- vapply(
      result[vapply(
        result,
        function(x) grepl("^bin_", x$region[1]),
        logical(1)
      )],
      function(x) x$region[1],
      character(1)
    )
    expect_lte(length(bin_regions), 10)
    expect_gte(length(bin_regions), 1)
  })
})


describe("read_neuromaps_volume vertex count mismatch", {
  it("aborts when projected surface has wrong vertex count", {
    skip_if_not_installed("RNifti")

    output_dir <- withr::local_tempdir()
    surf_dir <- file.path(output_dir, "surface_overlays")
    dir.create(surf_dir, recursive = TRUE)

    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      mri_vol2surf = function(input_file, output_file, hemisphere, ...) {
        wrong_n <- 5000L
        values <- rep(1, wrong_n)
        RNifti::writeNifti(array(values, dim = c(wrong_n, 1, 1)), output_file)
      }
    )

    expect_error(
      read_neuromaps_volume("fake.nii.gz", output_dir = output_dir),
      "expected.*10242"
    )
  })
})


describe("read_neuromaps_annotation", {
  it("skips label_table entries with zero matching vertices", {
    skip_if_not_installed("gifti")

    tmp_dir <- withr::local_tempdir()
    gii_file <- file.path(tmp_dir, "source_hemi-L_feature.func.gii")
    file.create(gii_file)

    local_mocked_bindings(
      read_gifti = function(...) {
        list(data = list(c(rep(1, 5000), rep(2, 5242))))
      },
      .package = "gifti"
    )

    label_tbl <- data.frame(
      id = c(1L, 2L, 999L),
      region = c("area_a", "area_b", "phantom"),
      stringsAsFactors = FALSE
    )

    result <- read_neuromaps_annotation(gii_file, label_table = label_tbl)

    expect_true("area_a" %in% result$region)
    expect_true("area_b" %in% result$region)
    expect_false("phantom" %in% result$region)
  })

  it("creates unknown region for unlabeled vertices", {
    skip_if_not_installed("gifti")

    tmp_dir <- withr::local_tempdir()
    gii_file <- file.path(tmp_dir, "source_hemi-L_feature.func.gii")
    file.create(gii_file)

    local_mocked_bindings(
      read_gifti = function(...) {
        list(data = list(c(rep(1, 5000), rep(0, 5242))))
      },
      .package = "gifti"
    )

    result <- read_neuromaps_annotation(gii_file, label_table = NULL)

    expect_true("unknown" %in% result$region)
    unknown_row <- result[result$region == "unknown", ]
    expect_identical(unknown_row$colour[1], "#BEBEBE")
  })
})


describe("read_volume dimensionality and reorientation", {
  it("reorients a non-RAS NIfTI to RAS when reorient is TRUE", {
    skip_if_not_installed("RNifti")

    tmp <- withr::local_tempfile(fileext = ".nii.gz")
    vol <- array(0L, dim = c(3, 3, 3))
    vol[1, 1, 1] <- 5L
    nii <- RNifti::asNifti(vol)
    lpi_xform <- structure(diag(c(-1, -1, -1, 1)), code = 2L)
    RNifti::sform(nii) <- lpi_xform
    RNifti::qform(nii) <- lpi_xform
    RNifti::writeNifti(nii, tmp)

    result <- read_volume(tmp, reorient = TRUE)
    native <- read_volume(tmp, reorient = FALSE)

    expect_true(is.array(result))
    expect_identical(dim(result), c(3L, 3L, 3L))
    expect_identical(sum(result), 5L)
    expect_identical(which(result == 5L), 27L)
    expect_false(identical(as.integer(result), as.integer(native)))
  })

  it("aborts when the volume is not three-dimensional", {
    skip_if_not_installed("RNifti")

    tmp <- withr::local_tempfile(fileext = ".nii.gz")
    vol <- array(1L, dim = c(3, 3, 3, 2))
    RNifti::writeNifti(vol, tmp)

    expect_error(read_volume(tmp), "Expected a 3D volume")
  })
})


describe("lut_combine", {
  it("combines multiple LUTs and drops NULL inputs", {
    a <- data.frame(idx = 0L, label = "Unknown", R = 0L, G = 0L, B = 0L, A = 0L)
    b <- data.frame(idx = 1L, label = "Region1", R = 5L, G = 6L, B = 7L, A = 0L)

    out <- lut_combine(a, NULL, b)

    expect_true(is_lut(out))
    expect_identical(nrow(out), 2L)
    expect_identical(out$idx, c(0L, 1L))
  })

  it("aligns columns present in only some tables with NA", {
    a <- data.frame(
      idx = 0L,
      label = "Unknown",
      R = 0L,
      G = 0L,
      B = 0L,
      A = 0L,
      type = "cortical",
      stringsAsFactors = FALSE
    )
    b <- data.frame(
      idx = 1L,
      label = "Region1",
      R = 5L,
      G = 6L,
      B = 7L,
      A = 0L,
      stringsAsFactors = FALSE
    )

    out <- lut_combine(a, b)

    expect_true("type" %in% names(out))
    expect_identical(out$type, c("cortical", NA_character_))
  })

  it("aborts when no LUTs are supplied", {
    expect_error(lut_combine(), "at least one LUT")
    expect_error(lut_combine(NULL), "at least one LUT")
  })

  it("aborts when an input is not a LUT", {
    a <- data.frame(idx = 0L, label = "Unknown", R = 0L, G = 0L, B = 0L, A = 0L)
    expect_error(lut_combine(a, data.frame(x = 1)), "must be LUTs")
  })

  it("warns about duplicate label indices", {
    a <- data.frame(idx = 1L, label = "Region1", R = 0L, G = 0L, B = 0L, A = 0L)
    b <- data.frame(idx = 1L, label = "Region2", R = 5L, G = 6L, B = 7L, A = 0L)

    expect_warning(lut_combine(a, b), "Duplicate label indices")
  })
})
