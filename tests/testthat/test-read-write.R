describe("is_volume_file", {
  it("detects MGZ files", {
    expect_true(is_volume_file("atlas.mgz"))
    expect_true(is_volume_file("/path/to/aseg.mgz"))
  })

  it("detects NIfTI files", {
    expect_true(is_volume_file("atlas.nii"))
    expect_true(is_volume_file("atlas.nii.gz"))
    expect_true(is_volume_file("/path/to/data.nii.gz"))
  })

  it("rejects non-volume files", {
    expect_false(is_volume_file("atlas.txt"))
    expect_false(is_volume_file("atlas.label"))
    expect_false(is_volume_file("atlas.png"))
  })

  it("is case insensitive", {
    expect_true(is_volume_file("atlas.MGZ"))
    expect_true(is_volume_file("atlas.NII"))
    expect_true(is_volume_file("atlas.NII.GZ"))
  })
})

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
    expect_equal(length(dim(vol)), 3)
  })

  it("reads NIfTI files when RNifti available", {
    skip_if_not_installed("RNifti")

    tmp <- withr::local_tempfile(fileext = ".nii.gz")
    vol <- array(1:27, dim = c(3, 3, 3))
    RNifti::writeNifti(vol, tmp)

    result <- read_volume(tmp)
    expect_true(is.array(result))
    expect_equal(dim(result), c(3, 3, 3))
  })
})


describe("read_volume with reorient FALSE", {
  it("returns niftiImage when reorient is FALSE", {
    skip_if_not_installed("RNifti")

    tmp <- withr::local_tempfile(fileext = ".nii.gz")
    vol <- array(1:27, dim = c(3, 3, 3))
    RNifti::writeNifti(vol, tmp)

    result <- read_volume(tmp, reorient = FALSE)

    expect_true(inherits(result, "niftiImage"))
  })
})


describe("read_ply_mesh", {
  make_ply_file <- function(vertices, faces) {
    tmp <- tempfile(fileext = ".ply")
    lines <- c(
      "ply",
      "format ascii 1.0",
      paste("element vertex", nrow(vertices)),
      "property float x",
      "property float y",
      "property float z",
      paste("element face", nrow(faces)),
      "property list uchar int vertex_index",
      "end_header"
    )
    for (i in seq_len(nrow(vertices))) {
      lines <- c(lines, paste(vertices[i, ], collapse = " "))
    }
    for (i in seq_len(nrow(faces))) {
      lines <- c(lines, paste(c(3, faces[i, ]), collapse = " "))
    }
    writeLines(lines, tmp)
    tmp
  }

  it("reads PLY file and returns vertices and faces", {
    verts <- matrix(
      c(0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0),
      ncol = 3,
      byrow = TRUE
    )
    fcs <- matrix(c(0, 1, 2, 1, 3, 2), ncol = 3, byrow = TRUE)
    ply_file <- make_ply_file(verts, fcs)
    withr::defer(unlink(ply_file))

    result <- read_ply_mesh(ply_file)

    expect_type(result, "list")
    expect_named(result, c("vertices", "faces"))
    expect_s3_class(result$vertices, "data.frame")
    expect_s3_class(result$faces, "data.frame")
    expect_equal(nrow(result$vertices), 4)
    expect_equal(nrow(result$faces), 2)
    expect_equal(names(result$vertices), c("x", "y", "z"))
    expect_equal(names(result$faces), c("i", "j", "k"))
  })

  it("extracts correct vertex coordinates", {
    verts <- matrix(c(1, 4, 7, 2, 5, 8, 3, 6, 9), ncol = 3, byrow = TRUE)
    fcs <- matrix(c(0, 1, 2), ncol = 3, byrow = TRUE)
    ply_file <- make_ply_file(verts, fcs)
    withr::defer(unlink(ply_file))

    result <- read_ply_mesh(ply_file)

    expect_equal(result$vertices$x, c(1, 2, 3))
    expect_equal(result$vertices$y, c(4, 5, 6))
    expect_equal(result$vertices$z, c(7, 8, 9))
  })

  it("extracts correct face indices", {
    verts <- matrix(
      c(0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0),
      ncol = 3,
      byrow = TRUE
    )
    fcs <- matrix(c(1, 2, 3, 2, 3, 1), ncol = 3, byrow = TRUE)
    ply_file <- make_ply_file(verts, fcs)
    withr::defer(unlink(ply_file))

    result <- read_ply_mesh(ply_file)

    expect_equal(result$faces$i, c(1, 2))
    expect_equal(result$faces$j, c(2, 3))
    expect_equal(result$faces$k, c(3, 1))
  })

  it("errors on non-string input", {
    expect_error(read_ply_mesh(list(vb = matrix(1:12, nrow = 4))), "file path")
  })

  it("errors on non-PLY file", {
    tmp <- tempfile(fileext = ".ply")
    writeLines("not a ply file", tmp)
    withr::defer(unlink(tmp))
    expect_error(read_ply_mesh(tmp), "Not a valid PLY")
  })
})


describe("read_ctab", {
  it("reads color table from file", {
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    result <- read_ctab(lut_file)

    expect_s3_class(result, "data.frame")
    expect_equal(names(result), c("idx", "label", "R", "G", "B", "A"))
    expect_true(nrow(result) > 0)
  })
})


describe("write_ctab", {
  it("writes color table to file", {
    ctab <- data.frame(
      idx = c(1, 2, 3),
      label = c("Region1", "Region2", "Region3"),
      R = c(255, 0, 0),
      G = c(0, 255, 0),
      B = c(0, 0, 255),
      A = c(0, 0, 0)
    )

    tmp <- withr::local_tempfile(fileext = ".txt")
    write_ctab(ctab, tmp)

    expect_true(file.exists(tmp))

    read_back <- read_ctab(tmp)
    expect_equal(nrow(read_back), 3)
    expect_equal(read_back$idx, ctab$idx)
  })

  it("truncates long label names to 29 characters", {
    long_label <- paste(rep("a", 40), collapse = "")
    ctab <- data.frame(
      idx = 1,
      label = long_label,
      R = 255,
      G = 0,
      B = 0,
      A = 0
    )

    tmp <- withr::local_tempfile(fileext = ".txt")
    write_ctab(ctab, tmp)

    content <- readLines(tmp)
    expect_true(all(nchar(content) < 60))
  })
})


describe("is_ctab", {
  it("returns TRUE for valid color table", {
    ctab <- data.frame(
      idx = 1:3,
      label = c("a", "b", "c"),
      R = c(255, 0, 0),
      G = c(0, 255, 0),
      B = c(0, 0, 255),
      A = c(0, 0, 0)
    )

    expect_true(is_ctab(ctab))
  })

  it("returns FALSE for non-data.frame", {
    expect_false(is_ctab(list(idx = 1, label = "a")))
    expect_false(is_ctab("not a data.frame"))
    expect_false(is_ctab(NULL))
  })

  it("returns FALSE for missing columns", {
    partial <- data.frame(idx = 1, label = "a", R = 255)
    expect_false(is_ctab(partial))
  })
})


describe("get_ctab", {
  it("reads and adds hex colors from file path", {
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    result <- get_ctab(lut_file)

    expect_true("color" %in% names(result))
    expect_true("roi" %in% names(result))
    expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", result$color)))
  })

  it("accepts data.frame input", {
    ctab <- data.frame(
      idx = c(1, 2),
      label = c("Region1", "Region2"),
      R = c(255, 0),
      G = c(0, 255),
      B = c(0, 0),
      A = c(0, 0)
    )

    result <- get_ctab(ctab)

    expect_equal(result$color, c("#FF0000", "#00FF00"))
    expect_equal(result$roi, c("0001", "0002"))
  })

  it("errors for invalid color table format", {
    invalid <- data.frame(x = 1, y = 2)

    expect_error(get_ctab(invalid), "correct format")
  })
})


describe("read_label_vertices", {
  it("warns and returns empty for malformed file", {
    skip_if_not_installed("freesurferformats")

    tmp <- withr::local_tempfile(fileext = ".label")
    writeLines("", tmp)

    expect_warning(
      result <- read_label_vertices(tmp),
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

    expect_equal(result, c(100L, 101L, 102L))
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

    expect_equal(result, c(0L, 1L))
  })
})


describe("write_dpv and read_dpv", {
  it("round-trips vertex and face data", {
    vertices <- data.frame(x = c(0, 1, 0), y = c(0, 0, 1), z = c(0, 0, 0))
    faces <- data.frame(i = 1, j = 2, k = 3)

    tmp <- withr::local_tempfile(fileext = ".dpv")
    write_dpv(tmp, vertices, faces)

    result <- read_dpv(tmp)

    expect_true(is.list(result))
    expect_true(all(c("vertices", "faces") %in% names(result)))
  })

  it("converts 1-indexed faces to 0-indexed", {
    vertices <- data.frame(x = c(0, 1, 0), y = c(0, 0, 1), z = c(0, 0, 0))
    faces <- data.frame(i = 1, j = 2, k = 3)

    tmp <- withr::local_tempfile(fileext = ".dpv")
    write_dpv(tmp, vertices, faces)

    content <- readLines(tmp)
    last_line <- content[length(content)]
    face_values <- as.numeric(strsplit(trimws(last_line), " ")[[1]])

    expect_true(all(face_values[1:3] >= 0))
    expect_true(all(face_values[1:3] < 3))
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
      result <- read_annotation_data(tmp),
      "Cannot detect hemisphere"
    )

    expect_equal(nrow(result), 0)
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
        values <- if (grepl("lh", hemisphere)) {
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
    expect_true(all(!is.na(named_regions$colour)))
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
      "fake.nii.gz", n_bins = 5, output_dir = output_dir
    )

    expect_s3_class(result, "tbl_df")
    bin_regions <- result[grepl("^bin_", result$region), ]
    expect_true(nrow(bin_regions) > 0)
    expect_true(all(!is.na(bin_regions$colour)))
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
    expect_equal(unknown_row$colour[1], "#BEBEBE")
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
    expect_true(length(bin_regions) <= 10)
    expect_true(length(bin_regions) >= 1)
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
    expect_equal(unknown_row$colour[1], "#BEBEBE")
  })
})
