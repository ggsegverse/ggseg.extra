.cap <- new.env()

# Test fixture helpers ----

create_mock_suit_surface <- function() {
  skip_if_not_installed("gifti") # nolint: object_usage_linter.
  skip_if_not_installed("base64enc") # nolint: object_usage_linter.

  dir <- withr::local_tempdir(.local_envir = parent.frame())
  surf_file <- file.path(dir, "SUIT.flat.surf.gii")

  pointset <- c(0, 0, 0, 1, 0, 0, 0.5, 1, 0, 1.5, 1, 0)
  pointset_b64 <- base64enc::base64encode(
    writeBin(as.double(pointset), raw(), size = 4)
  )

  triangles <- c(0L, 1L, 2L, 1L, 3L, 2L)
  triangles_b64 <- base64enc::base64encode(
    writeBin(triangles, raw(), size = 4)
  )

  # nolint start: indentation_linter.
  xml <- sprintf(
    '<?xml version="1.0" encoding="UTF-8"?>
<GIFTI Version="1.0" NumberOfDataArrays="2">
  <MetaData/><LabelTable/>
  <DataArray Intent="NIFTI_INTENT_POINTSET" DataType="NIFTI_TYPE_FLOAT32"
    ArrayIndexingOrder="RowMajorOrder" Dimensionality="2"
    Dim0="4" Dim1="3" Encoding="Base64Binary" Endian="LittleEndian">
    <MetaData/><Data>%s</Data>
  </DataArray>
  <DataArray Intent="NIFTI_INTENT_TRIANGLE" DataType="NIFTI_TYPE_INT32"
    ArrayIndexingOrder="RowMajorOrder" Dimensionality="2"
    Dim0="2" Dim1="3" Encoding="Base64Binary" Endian="LittleEndian">
    <MetaData/><Data>%s</Data>
  </DataArray>
</GIFTI>',
    pointset_b64,
    triangles_b64
  )
  # nolint end

  writeLines(xml, surf_file)
  surf_file
}


create_mock_suit_labels <- function(n_vertices = 4) {
  skip_if_not_installed("gifti") # nolint: object_usage_linter.
  skip_if_not_installed("base64enc") # nolint: object_usage_linter.

  dir <- withr::local_tempdir(.local_envir = parent.frame())
  label_file <- file.path(dir, "Lobules-SUIT.label.gii")

  labels <- as.integer(c(1, 1, 2, 2))
  if (n_vertices > 4) {
    labels <- c(labels, rep(0L, n_vertices - 4))
  }
  labels_b64 <- base64enc::base64encode(
    writeBin(labels, raw(), size = 4)
  )

  # nolint start: indentation_linter.
  xml <- sprintf(
    '<?xml version="1.0" encoding="UTF-8"?>
<GIFTI Version="1.0" NumberOfDataArrays="1">
  <MetaData/>
  <LabelTable>
    <Label Key="0" Red="0" Green="0" Blue="0" Alpha="0">Background</Label>
    <Label Key="1" Red="0.8" Green="0.2" Blue="0.2" Alpha="1">Left I-IV</Label>
    <Label Key="2" Red="0.2" Green="0.8" Blue="0.2" Alpha="1">Vermis VI</Label>
  </LabelTable>
  <DataArray Intent="NIFTI_INTENT_LABEL" DataType="NIFTI_TYPE_INT32"
    ArrayIndexingOrder="RowMajorOrder" Dimensionality="1"
    Dim0="%d" Encoding="Base64Binary" Endian="LittleEndian">
    <MetaData/><Data>%s</Data>
  </DataArray>
</GIFTI>',
    n_vertices,
    labels_b64
  )
  # nolint end

  writeLines(xml, label_file)
  label_file
}


# Tests ----

describe("suit_flatmap_path", {
  it("returns a valid file path", {
    path <- suit_flatmap_path()
    expect_true(file.exists(path))
    expect_true(grepl("tpl-SUIT_flat\\.surf\\.gii$", path))
  })
})


describe("suit_3d_path", {
  it("returns a valid file path", {
    path <- suit_3d_path()
    expect_true(file.exists(path))
    expect_true(grepl("tpl-SUIT_3d\\.surf\\.gii$", path))
  })
})


describe("read_suit_flatmap", {
  it("extracts 2D coordinates and faces from GIFTI surface", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    surf <- create_mock_suit_surface()
    result <- read_suit_flatmap(surf)

    expect_type(result, "list")
    expect_true(all(c("verts_2d", "faces", "n_vertices") %in% names(result)))
    expect_identical(ncol(result$verts_2d), 2L)
    expect_identical(ncol(result$faces), 3L)
    expect_identical(result$n_vertices, nrow(result$verts_2d))
  })

  it("errors on missing file", {
    expect_error(
      read_suit_flatmap("nonexistent.surf.gii"),
      "not found"
    )
  })

  it("reads bundled SUIT flatmap correctly", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    result <- read_suit_flatmap(suit_flatmap_path())

    expect_identical(result$n_vertices, 28935L)
    expect_identical(ncol(result$verts_2d), 2L)
    expect_identical(nrow(result$faces), 56588L)
  })

  it("errors on invalid GIFTI file", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    tmp <- withr::local_tempfile(fileext = ".surf.gii")
    writeLines(
      '<?xml version="1.0"?><GIFTI Version="1.0"
      NumberOfDataArrays="0"><MetaData/><LabelTable/></GIFTI>',
      tmp
    )

    expect_error(read_suit_flatmap(tmp))
  })
})


describe("cerebellar_build_sf_flatmap", {
  it("errors when no vertices match the flatmap", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    components <- list(
      vertices_df = data.frame(
        label = "fake_region",
        stringsAsFactors = FALSE
      )
    )
    components$vertices_df$vertices <- list(99999L)

    expect_warning(
      expect_error(
        cerebellar_build_sf_flatmap(
          components,
          suit_flatmap_path(),
          tolerance = 0,
          smooth_refinements = 0,
          verbose = FALSE
        ),
        "No vertices matched"
      ),
      "references vertex.*but flatmap"
    )
  })
})


describe("build_vertex_label_vector_cerebellum", {
  it("assigns all labels without hemisphere filtering", {
    vertices_df <- data.frame(
      label = c("left_I-IV", "right_I-IV", "vermis_VI"),
      stringsAsFactors = FALSE
    )
    vertices_df$vertices <- list(0:3, 4:7, 8:9)

    result <- build_vertex_label_vector_cerebellum(vertices_df, 10)

    expect_length(result, 10)
    expect_identical(result[1:4], rep("left_I-IV", 4))
    expect_identical(result[5:8], rep("right_I-IV", 4))
    expect_identical(result[9:10], rep("vermis_VI", 2))
  })

  it("returns NA for unlabelled vertices", {
    vertices_df <- data.frame(
      label = "left_I-IV",
      stringsAsFactors = FALSE
    )
    vertices_df$vertices <- list(0:2)

    result <- build_vertex_label_vector_cerebellum(vertices_df, 5)

    expect_identical(sum(is.na(result)), 2L)
  })
})


describe("flatmap_triangles_to_polygons", {
  it("produces valid sf polygons from uniform triangles", {
    verts <- matrix(
      c(
        0,
        0,
        1,
        0,
        0.5,
        1,
        1.5,
        1
      ),
      ncol = 2,
      byrow = TRUE
    )
    faces <- matrix(c(0, 1, 2, 1, 3, 2), ncol = 3, byrow = TRUE)
    labels <- c("left_I", "left_I", "left_I", "left_I")

    result <- flatmap_triangles_to_polygons(verts, faces, labels)

    expect_s3_class(result, "sf")
    expect_gte(nrow(result), 1)
    expect_true("label" %in% names(result))
  })

  it("splits boundary triangles between regions", {
    verts <- matrix(
      c(
        0,
        0,
        1,
        0,
        0.5,
        1
      ),
      ncol = 2,
      byrow = TRUE
    )
    faces <- matrix(c(0, 1, 2), ncol = 3)
    labels <- c("left_I", "left_I", "right_I")

    result <- flatmap_triangles_to_polygons(verts, faces, labels)

    expect_s3_class(result, "sf")
    expect_identical(nrow(result), 2L)
    expect_true(all(c("left_I", "right_I") %in% result$label))
  })

  it("errors when no labelled triangles exist", {
    verts <- matrix(c(0, 0, 1, 0, 0.5, 1), ncol = 2, byrow = TRUE)
    faces <- matrix(c(0, 1, 2), ncol = 3)
    labels <- rep(NA_character_, 3)

    expect_error(
      flatmap_triangles_to_polygons(verts, faces, labels),
      "No labelled triangles"
    )
  })

  it("skips degenerate (zero-area) triangles", {
    verts <- matrix(
      c(
        0,
        0,
        1,
        0,
        2,
        0,
        0.5,
        1
      ),
      ncol = 2,
      byrow = TRUE
    )
    faces <- matrix(c(0, 1, 2, 0, 1, 3), ncol = 3, byrow = TRUE)
    labels <- c("left_I", "left_I", "left_I", "left_I")

    result <- flatmap_triangles_to_polygons(verts, faces, labels)

    expect_s3_class(result, "sf")
    expect_gte(nrow(result), 1)
  })
})


describe("detect_cerebellar_hemi", {
  it("detects Left prefix", {
    expect_identical(detect_cerebellar_hemi("Left I-IV"), "left")
    expect_identical(detect_cerebellar_hemi("Left Crus I"), "left")
  })

  it("detects Right prefix", {
    expect_identical(detect_cerebellar_hemi("Right I-IV"), "right")
  })

  it("detects Vermis prefix", {
    expect_identical(detect_cerebellar_hemi("Vermis VI"), "vermis")
    expect_identical(detect_cerebellar_hemi("Vermis CrusII"), "vermis")
  })

  it("detects vermis in label body", {
    expect_identical(detect_cerebellar_hemi("region_vermis"), "vermis")
  })

  it("defaults to midline for ambiguous labels", {
    expect_identical(detect_cerebellar_hemi("Dentate"), "midline")
  })

  it("does not match single-letter prefixes", {
    expect_identical(detect_cerebellar_hemi("Lobule_X"), "midline")
    expect_identical(detect_cerebellar_hemi("Region_5"), "midline")
    expect_identical(detect_cerebellar_hemi("Volume_1"), "midline")
  })
})


describe("clean_cerebellar_region", {
  it("removes Left/Right/Vermis prefix", {
    expect_identical(clean_cerebellar_region("Left I-IV"), "I-IV")
    expect_identical(clean_cerebellar_region("Right Crus I"), "Crus I")
    expect_identical(clean_cerebellar_region("Vermis VI"), "VI")
  })

  it("preserves full name when no prefix", {
    expect_identical(clean_cerebellar_region("Dentate"), "Dentate")
  })
})


describe("read_suit_parcellation", {
  it("errors on missing files", {
    expect_error(
      read_suit_parcellation("nonexistent.label.gii"),
      "not found"
    )
  })

  it("parses mock GIFTI label file", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    label_file <- create_mock_suit_labels()
    result <- read_suit_parcellation(label_file)

    expect_s3_class(result, "tbl_df")
    expected_cols <- c("hemi", "region", "label", "colour", "vertices")
    expect_true(all(expected_cols %in% names(result)))
    expect_gt(nrow(result), 0)
    expect_true(all(result$hemi %in% c("left", "right", "vermis", "midline")))
  })
})


describe("extract_gifti_label_table", {
  it("returns NULL for GIFTI without labels", {
    gii <- list(label = NULL, data = list())
    expect_null(extract_gifti_label_table(gii))
  })

  it("extracts labels from gifti format (rownames + Key column)", {
    lt <- matrix(
      c(
        "0",
        "0",
        "0",
        "0",
        "0",
        "1",
        "0.8",
        "0.2",
        "0.2",
        "1",
        "2",
        "0.2",
        "0.8",
        "0.2",
        "1"
      ),
      ncol = 5,
      byrow = TRUE,
      dimnames = list(
        c("Background", "Left I-IV", "Vermis VI"),
        c("Key", "Red", "Green", "Blue", "Alpha")
      )
    )
    gii <- list(label = as.data.frame(lt))
    result <- extract_gifti_label_table(gii)
    expect_identical(nrow(result), 3L)
    expect_true(all(c("id", "name", "colour") %in% names(result)))
    expect_identical(result$name, c("Background", "Left I-IV", "Vermis VI"))
  })
})


describe("create_cerebellar_from_gifti", {
  it("errors on empty gifti_files", {
    expect_error(
      create_cerebellar_from_gifti(gifti_files = character()),
      "must not be empty"
    )
  })

  it("runs full pipeline with bundled flatmap", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    label_file <- create_mock_suit_labels(n_vertices = 28935)

    atlas <- create_cerebellar_from_gifti(
      gifti_files = label_file,
      atlas_name = "test_cerebellum",
      smooth_refinements = 0,
      tolerance = 0,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_s3_class(atlas, "cerebellar_atlas")
    expect_identical(atlas$type, "cerebellar")
    expect_s3_class(atlas$data, "ggseg_data_cerebellar")
    expect_gt(nrow(atlas$core), 0)

    sf_data <- ggseg.formats::atlas_sf(atlas)
    expect_s3_class(sf_data, "sf")
    expect_true("flatmap" %in% sf_data$view)
  })
})


describe("create_cerebellar_from_annotation", {
  it("errors on empty input_annot", {
    expect_error(
      create_cerebellar_from_annotation(input_annot = character()),
      "must not be empty"
    )
  })
})


describe("create_cerebellar_from_volume", {
  it("errors on missing volume", {
    expect_error(
      create_cerebellar_from_volume(),
      "volume.*required"
    )
  })

  it("errors on nonexistent volume file", {
    expect_error(
      create_cerebellar_from_volume(volume = "nonexistent.nii.gz"),
      "not found"
    )
  })
})


describe("read_cerebellar_annotation", {
  it("errors on missing files", {
    expect_error(
      read_cerebellar_annotation("nonexistent.annot"),
      "not found"
    )
  })

  it("parses annotation with cerebellar hemisphere detection", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = c(1L, 1L, 2L, 2L, 3L),
      colortable_df = data.frame(
        code = 1:3,
        struct_name = c("Left I-IV", "Right Crus I", "Vermis VI"),
        r = c(200, 100, 50),
        g = c(50, 200, 150),
        b = c(50, 50, 200),
        a = c(0, 0, 0),
        hex_color_string_rgb = c("#C83232", "#6464C8", "#329632"),
        stringsAsFactors = FALSE
      )
    )

    local_mocked_bindings(
      read.fs.annot = function(...) mock_annot,
      .package = "freesurferformats"
    )

    tmp <- withr::local_tempfile(fileext = ".annot")
    writeLines("mock", tmp)

    result <- read_cerebellar_annotation(tmp)

    expect_s3_class(result, "tbl_df")
    expect_identical(nrow(result), 3L)
    expected_cols <- c("hemi", "region", "label", "colour", "vertices")
    expect_true(all(expected_cols %in% names(result)))
    expect_identical(result$hemi, c("left", "right", "vermis"))
    expect_identical(result$region, c("I-IV", "Crus I", "VI"))
    expect_identical(lengths(result$vertices), c(2L, 2L, 1L))
  })

  it("errors when no regions found", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = integer(0),
      colortable_df = data.frame(
        code = integer(),
        struct_name = character(),
        r = numeric(),
        g = numeric(),
        b = numeric(),
        a = numeric(),
        hex_color_string_rgb = character(),
        stringsAsFactors = FALSE
      )
    )
    local_mocked_bindings(
      read.fs.annot = function(...) mock_annot,
      .package = "freesurferformats"
    )

    tmp <- withr::local_tempfile(fileext = ".annot")
    writeLines("mock", tmp)

    expect_error(
      read_cerebellar_annotation(tmp),
      "No regions found"
    )
  })
})


describe("resolve_cerebellar_lut", {
  it("auto-generates labels when no LUT provided", {
    vol <- array(c(0L, 1L, 2L, 0L, 1L, 2L, 0L, 0L), dim = c(2, 2, 2))
    vertex_labels <- c(1L, 2L, 0L, 1L)

    result <- resolve_cerebellar_lut(vol, vertex_labels)

    expect_true(all(c("idx", "label") %in% names(result)))
    expect_identical(result$idx, c(1L, 2L))
    expect_identical(result$label, c("region_1", "region_2"))
  })

  it("uses data.frame LUT when provided", {
    vol <- array(c(0L, 1L, 2L, 0L, 1L, 2L, 0L, 0L), dim = c(2, 2, 2))
    vertex_labels <- c(1L, 2L)
    lut <- data.frame(
      stringsAsFactors = FALSE,
      idx = c(1L, 2L, 3L),
      label = c("Left I-IV", "Vermis VI", "Right V"),
      R = c(255, 0, 0),
      G = c(0, 255, 0),
      B = c(0, 0, 255)
    )

    result <- resolve_cerebellar_lut(vol, vertex_labels, lut)

    expect_identical(nrow(result), 2L)
    expect_true("color" %in% names(result))
  })

  it("errors on data.frame LUT missing required columns", {
    vol <- array(c(0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L), dim = c(2, 2, 2))
    vertex_labels <- 1L
    lut <- data.frame(name = "test", stringsAsFactors = FALSE)

    expect_error(
      resolve_cerebellar_lut(vol, vertex_labels, lut),
      "idx.*label"
    )
  })

  it("reads file path LUT", {
    vol <- array(c(0L, 1L, 2L, 0L, 1L, 2L, 0L, 0L), dim = c(2, 2, 2))
    vertex_labels <- c(1L, 2L)

    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines(
      c(
        "  1  Left_I-IV   200 50 50 0",
        "  2  Vermis_VI   50 200 50 0"
      ),
      tmp
    )

    result <- resolve_cerebellar_lut(vol, vertex_labels, tmp)

    expect_identical(nrow(result), 2L)
    expect_true("label" %in% names(result))
  })
})


describe("read_suit_parcellation edge cases", {
  it("handles labels without LUT entry", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    label_file <- create_mock_suit_labels(n_vertices = 4)

    local_mocked_bindings(
      readgii = function(file) {
        list(
          data = list(as.integer(c(1, 2, 3, 0))),
          label = NULL
        )
      },
      .package = "gifti"
    )

    result <- read_suit_parcellation(label_file)

    expect_gt(nrow(result), 0)
    expect_true(all(grepl("^region_", result$region)))
    expect_false(anyNA(result$colour))
  })

  it("warns and skips GIFTI files with empty data arrays", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    label_file <- create_mock_suit_labels(n_vertices = 4)

    local_mocked_bindings(
      readgii = function(file) list(data = list(), label = NULL),
      .package = "gifti"
    )

    expect_warning(
      {
        result <- read_suit_parcellation(label_file)
      },
      "No data arrays"
    )
    expect_identical(nrow(result), 0L)
  })

  it("handles matrix-format data arrays", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    label_file <- create_mock_suit_labels(n_vertices = 4)

    local_mocked_bindings(
      readgii = function(file) {
        list(
          data = list(matrix(c(1L, 1L, 2L, 0L), ncol = 1)),
          label = NULL
        )
      },
      .package = "gifti"
    )

    result <- read_suit_parcellation(label_file)
    expect_identical(nrow(result), 2L)
  })

  it("returns empty tibble when all labels are zero", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    label_file <- create_mock_suit_labels(n_vertices = 4)

    local_mocked_bindings(
      readgii = function(file) {
        list(data = list(as.integer(c(0, 0, 0, 0))), label = NULL)
      },
      .package = "gifti"
    )

    result <- read_suit_parcellation(label_file)
    expect_identical(nrow(result), 0L)
  })

  it("skips regions with zero vertices after filtering", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    lt <- matrix(
      c(
        "0",
        "0",
        "0",
        "0",
        "0",
        "1",
        "0.8",
        "0.2",
        "0.2",
        "1",
        "2",
        "0.2",
        "0.8",
        "0.2",
        "1"
      ),
      ncol = 5,
      byrow = TRUE,
      dimnames = list(
        c("Background", "Left I-IV", "Vermis VI"),
        c("Key", "Red", "Green", "Blue", "Alpha")
      )
    )

    local_mocked_bindings(
      readgii = function(file) {
        list(
          data = list(as.integer(c(1, 1, 0, 0))),
          label = as.data.frame(lt)
        )
      },
      .package = "gifti"
    )

    label_file <- create_mock_suit_labels(n_vertices = 4)
    result <- read_suit_parcellation(label_file)

    expect_identical(nrow(result), 1L)
    expect_identical(result$hemi[1], "left")
  })
})


describe("extract_gifti_label_table edge cases", {
  it("handles lowercase key/label format", {
    gii <- list(
      label = data.frame(
        key = c(0L, 1L, 2L),
        label = c("Background", "Left I-IV", "Vermis VI"),
        red = c(0, 0.8, 0.2),
        green = c(0, 0.2, 0.8),
        blue = c(0, 0.2, 0.2),
        stringsAsFactors = FALSE
      )
    )
    result <- extract_gifti_label_table(gii)
    expect_identical(nrow(result), 3L)
    expect_identical(result$name, c("Background", "Left I-IV", "Vermis VI"))
    expect_true("colour" %in% names(result))
  })

  it("handles Key format without RGB columns", {
    lt <- matrix(
      c("0", "0", "1", "0"),
      ncol = 2,
      byrow = TRUE,
      dimnames = list(c("Background", "Region1"), c("Key", "Alpha"))
    )
    gii <- list(label = as.data.frame(lt))
    result <- extract_gifti_label_table(gii)
    expect_identical(nrow(result), 2L)
    expect_true(all(is.na(result$colour)))
  })

  it("handles lowercase format without rgb columns", {
    gii <- list(
      label = data.frame(
        key = c(0L, 1L),
        label = c("BG", "Region"),
        stringsAsFactors = FALSE
      )
    )
    result <- extract_gifti_label_table(gii)
    expect_identical(nrow(result), 2L)
    expect_true(all(is.na(result$colour)))
  })

  it("returns NULL for unrecognized format", {
    gii <- list(label = data.frame(foo = 1, bar = 2))
    expect_null(extract_gifti_label_table(gii))
  })
})


describe("clean_cerebellar_region edge cases", {
  it("returns original name when prefix removal leaves empty string", {
    expect_identical(clean_cerebellar_region("Left"), "Left")
    expect_identical(clean_cerebellar_region("Right"), "Right")
  })
})


describe("read_cerebellar_volume", {
  it("samples volume onto surface and returns atlas data", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(10, 10, 10))
    vol[3:5, 3:5, 3:5] <- 1L
    vol[6:8, 6:8, 6:8] <- 2L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    local_mocked_bindings(
      sample_volume_at_surface = function(...) {
        c(1L, 1L, 2L, 2L, 0L)
      }
    )

    result <- read_cerebellar_volume(vol_file, "mock_3d.surf.gii", NULL)

    expect_s3_class(result, "tbl_df")
    expect_gt(nrow(result), 0)
    expected_cols <- c("hemi", "region", "label", "colour", "vertices")
    expect_true(all(expected_cols %in% names(result)))
  })

  it("errors when no regions found after sampling", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    local_mocked_bindings(
      sample_volume_at_surface = function(...) integer(2)
    )

    expect_error(
      read_cerebellar_volume(vol_file, "mock.surf.gii", NULL),
      "No regions found"
    )
  })
})


describe("sample_volume_at_surface", {
  it("maps surface vertices to volume voxels", {
    skip_if_not_installed("RNifti")
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L
    vol[4, 4, 4] <- 2L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(vol)
    RNifti::writeNifti(nii, vol_file)

    result <- sample_volume_at_surface(vol, vol_file, suit_3d_path())

    expect_length(result, 28935)
    expect_type(result, "integer")
  })
})


describe("cerebellar pipeline orchestration", {
  it("create_cerebellar_from_gifti derives atlas_name from file", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    label_file <- create_mock_suit_labels(n_vertices = 28935)

    atlas <- create_cerebellar_from_gifti(
      gifti_files = label_file,
      smooth_refinements = 0,
      tolerance = 0,
      verbose = FALSE
    )

    expect_gt(nchar(atlas$atlas), 0)
  })

  it("create_cerebellar_from_annotation derives atlas_name", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = c(1L, 1L, 2L),
      colortable_df = data.frame(
        code = 1:2,
        struct_name = c("Left I-IV", "Vermis VI"),
        r = c(200, 50),
        g = c(50, 200),
        b = c(50, 50),
        a = c(0, 0),
        hex_color_string_rgb = c("#C83232", "#329632"),
        stringsAsFactors = FALSE
      )
    )
    local_mocked_bindings(
      read.fs.annot = function(...) mock_annot,
      .package = "freesurferformats"
    )

    local_mocked_bindings(
      cerebellar_build_sf_flatmap = function(...) {
        sf::st_sf(
          label = c("left_I-IV", "vermis_VI"),
          view = "flatmap",
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
      warn_if_large_atlas = function(...) NULL,
      preview_atlas = function(...) NULL
    )

    tmp <- withr::local_tempfile(fileext = ".annot")
    writeLines("mock", tmp)

    atlas <- create_cerebellar_from_annotation(
      input_annot = tmp,
      verbose = FALSE
    )

    expect_s3_class(atlas, "cerebellar_atlas")
    expect_identical(atlas$type, "cerebellar")
  })
})


describe("cerebellar_build_sf_flatmap smoothing and simplification", {
  it("applies topology-preserving simplification", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    components <- list(
      vertices_df = data.frame(
        label = "left_I-IV",
        stringsAsFactors = FALSE
      )
    )
    components$vertices_df$vertices <- list(0:999)

    result <- cerebellar_build_sf_flatmap(
      components,
      suit_flatmap_path(),
      tolerance = 0,
      smooth_refinements = 2,
      verbose = FALSE
    )

    expect_s3_class(result, "sf")
    expect_true("flatmap" %in% result$view)
  })

  it("applies simplification when tolerance > 0", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    components <- list(
      vertices_df = data.frame(
        label = "left_I-IV",
        stringsAsFactors = FALSE
      )
    )
    components$vertices_df$vertices <- list(0:999)

    result <- cerebellar_build_sf_flatmap(
      components,
      suit_flatmap_path(),
      tolerance = 0.5,
      smooth_refinements = 0,
      verbose = FALSE
    )

    expect_s3_class(result, "sf")
  })

  it("verbose mode prints progress messages", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    components <- list(
      vertices_df = data.frame(
        label = "left_I-IV",
        stringsAsFactors = FALSE
      )
    )
    components$vertices_df$vertices <- list(0:999)

    expect_messages(
      cerebellar_build_sf_flatmap(
        components,
        suit_flatmap_path(),
        tolerance = 0,
        smooth_refinements = 0,
        verbose = TRUE
      ),
      "Reading SUIT flatmap|Building polygons"
    )
  })
})


describe("transform_mni_to_suit", {
  it("errors on missing input volume", {
    expect_error(
      transform_mni_to_suit("nonexistent.nii.gz", "xfm.nii"),
      "not found"
    )
  })

  it("errors on missing deformation field", {
    skip_if_not_installed("RNifti")
    vol <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(array(0L, dim = c(3, 3, 3))), vol)

    expect_error(
      transform_mni_to_suit(vol, "nonexistent_xfm.nii"),
      "not found"
    )
  })

  it("errors on invalid deformation field dimensions", {
    skip_if_not_installed("RNifti")
    vol <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(array(0L, dim = c(3, 3, 3))), vol)

    bad_xfm <- withr::local_tempfile(fileext = ".nii")
    RNifti::writeNifti(RNifti::asNifti(array(0, dim = c(3, 3, 3))), bad_xfm)

    expect_error(
      transform_mni_to_suit(vol, bad_xfm),
      "5D NIfTI"
    )
  })

  it("resamples volume using nearest-neighbor interpolation", {
    skip_if_not_installed("RNifti")

    mni <- array(0L, dim = c(5, 5, 5))
    mni[3, 3, 3] <- 1L
    mni_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(mni), mni_file)

    xfm <- array(0, dim = c(3, 3, 3, 1, 3))
    mni_nii <- RNifti::readNifti(mni_file)
    center_world <- RNifti::voxelToWorld(c(3, 3, 3), mni_nii)
    for (i in 1:3) {
      for (j in 1:3) {
        for (k in 1:3) {
          xfm[i, j, k, 1, ] <- center_world
        }
      }
    }
    xfm_file <- withr::local_tempfile(fileext = ".nii")
    RNifti::writeNifti(RNifti::asNifti(xfm, reference = mni_nii), xfm_file)

    result_file <- transform_mni_to_suit(mni_file, xfm_file)
    result <- RNifti::readNifti(result_file)

    expect_true(all(drop(as.array(result)) == 1L))
  })
})


describe("suit_deformation_field", {
  it("errors without internet when not cached", {
    local_mocked_bindings(can_reach_github = function() FALSE)

    tmp <- withr::local_tempdir()
    expect_error(
      suit_deformation_field(cache_dir = tmp),
      "Cannot reach GitHub"
    )
  })

  it("returns cached path without downloading", {
    tmp <- withr::local_tempdir()
    cached <- file.path(
      tmp,
      "tpl-SUIT_from-MNI152NLin6AsymC_mode-image_xfm.nii"
    )
    writeBin(raw(1e6 + 1), cached)

    result <- suit_deformation_field(cache_dir = tmp)
    expect_identical(result, cached)
  })

  it("accepts both MNI template options", {
    expect_error(
      suit_deformation_field(template = "invalid"),
      "arg.*should be one of"
    )
  })
})


describe("can_reach_github", {
  it("returns TRUE or FALSE", {
    result <- can_reach_github()
    expect_type(result, "logical")
    expect_length(result, 1)
  })
})


describe("fill_unlabelled_from_voxel_neighbors", {
  it("fills unlabelled vertices from nearest non-zero voxel neighbor", {
    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L
    vol[4, 4, 4] <- 2L

    vox_coords <- matrix(
      c(
        2,
        2,
        2,
        2,
        2,
        3,
        4,
        4,
        4,
        3,
        3,
        3
      ),
      ncol = 3,
      byrow = TRUE
    )
    labels <- c(1L, 0L, 2L, 0L)

    result <- fill_unlabelled_from_voxel_neighbors(
      labels,
      vox_coords,
      vol,
      dim(vol)
    )
    expect_identical(result[1], 1L)
    expect_identical(result[2], 1L)
    expect_identical(result[3], 2L)
    expect_true(result[4] %in% c(1L, 2L))
  })

  it("returns unchanged labels when all already labelled", {
    vol <- array(1L, dim = c(3, 3, 3))
    vox_coords <- matrix(c(2, 2, 2), ncol = 3)
    labels <- 1L
    result <- fill_unlabelled_from_voxel_neighbors(
      labels,
      vox_coords,
      vol,
      dim(vol)
    )
    expect_identical(result, 1L)
  })

  it("expands to radius 2 when radius 1 finds no neighbors", {
    vol <- array(0L, dim = c(7, 7, 7))
    vol[1, 1, 1] <- 5L

    vox_coords <- matrix(
      c(
        1,
        1,
        1,
        1,
        1,
        3
      ),
      ncol = 3,
      byrow = TRUE
    )
    labels <- c(5L, 0L)

    result <- fill_unlabelled_from_voxel_neighbors(
      labels,
      vox_coords,
      vol,
      dim(vol),
      max_radius = 3L
    )
    expect_identical(result[1], 5L)
    expect_identical(result[2], 5L)
  })
})


describe("fill_unlabelled_from_mesh_neighbors", {
  it("propagates labels along mesh edges using majority vote", {
    faces <- matrix(
      c(
        1L,
        2L,
        3L,
        3L,
        4L,
        5L
      ),
      ncol = 3,
      byrow = TRUE
    )
    labels <- c(1L, 1L, 0L, 0L, 2L)

    result <- fill_unlabelled_from_mesh_neighbors(labels, faces, 5)

    expect_identical(result[1], 1L)
    expect_identical(result[2], 1L)
    expect_identical(result[3], 1L)
    expect_identical(result[5], 2L)
    expect_true(result[4] %in% c(1L, 2L))
  })

  it("returns unchanged when no unlabelled vertices", {
    faces <- matrix(c(1L, 2L, 3L), ncol = 3)
    labels <- c(1L, 2L, 3L)
    result <- fill_unlabelled_from_mesh_neighbors(labels, faces, 3)
    expect_identical(result, c(1L, 2L, 3L))
  })

  it("stops when isolated vertices cannot be reached", {
    faces <- matrix(c(1L, 2L, 3L), ncol = 3)
    labels <- c(1L, 0L, 0L, 0L, 0L)

    result <- fill_unlabelled_from_mesh_neighbors(labels, faces, 5)

    expect_identical(result[1], 1L)
    expect_true(result[2] != 0L)
    expect_true(result[3] != 0L)
    expect_identical(result[4], 0L)
    expect_identical(result[5], 0L)
  })
})


describe("rescue_orphaned_region", {
  it("finds nearest unassigned vertices to orphaned voxel centroid", {
    skip_if_not_installed("RNifti")
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    vol <- array(0L, dim = c(10, 10, 10))
    vol[5, 5, 5] <- 7L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(vol)
    RNifti::writeNifti(nii, vol_file)

    centroid_world <- RNifti::voxelToWorld(c(5, 5, 5), nii)

    local_mocked_bindings(
      readgii = function(file) {
        list(
          data = list(
            pointset = matrix(
              c(
                centroid_world[1],
                centroid_world[2],
                centroid_world[3],
                centroid_world[1] + 1,
                centroid_world[2],
                centroid_world[3],
                centroid_world[1] + 100,
                centroid_world[2],
                centroid_world[3]
              ),
              ncol = 3,
              byrow = TRUE
            )
          )
        )
      },
      .package = "gifti"
    )

    vertex_labels <- c(0L, 0L, 0L)
    result <- rescue_orphaned_region(
      vol,
      7L,
      vol_file,
      "mock.surf.gii",
      vertex_labels,
      n_vertices = 2L
    )

    expect_length(result, 2)
    expect_true(0L %in% result)
    expect_true(1L %in% result)
    expect_false(2L %in% result)
  })

  it("returns empty integer when label has no voxels", {
    skip_if_not_installed("RNifti")
    vol <- array(0L, dim = c(3, 3, 3))
    result <- rescue_orphaned_region(
      vol,
      99L,
      "unused",
      "unused",
      integer(0)
    )
    expect_length(result, 0)
    expect_type(result, "integer")
  })

  it("falls back to nearest vertices when all are assigned", {
    skip_if_not_installed("RNifti")
    skip_if_not_installed("gifti") # nolint: object_usage_linter.

    vol <- array(0L, dim = c(5, 5, 5))
    vol[3, 3, 3] <- 1L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(vol)
    RNifti::writeNifti(nii, vol_file)

    centroid_world <- RNifti::voxelToWorld(c(3, 3, 3), nii)

    local_mocked_bindings(
      readgii = function(file) {
        list(
          data = list(
            pointset = matrix(
              c(
                centroid_world[1],
                centroid_world[2],
                centroid_world[3],
                centroid_world[1] + 50,
                centroid_world[2],
                centroid_world[3]
              ),
              ncol = 3,
              byrow = TRUE
            )
          )
        )
      },
      .package = "gifti"
    )

    vertex_labels <- c(5L, 5L)
    result <- rescue_orphaned_region(
      vol,
      1L,
      vol_file,
      "mock.surf.gii",
      vertex_labels,
      n_vertices = 1L
    )

    expect_length(result, 1)
    expect_identical(result, 0L)
  })
})


describe("read_cerebellar_volume deep nucleus and orphan branches", {
  it("marks Dentate as deep nucleus when no surface vertices found", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L
    vol[3, 3, 3] <- 2L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    lut <- data.frame(
      idx = c(1L, 2L),
      label = c("Left Dentate", "Left Lobule-I"),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      sample_volume_at_surface = function(...) {
        c(0L, 2L, 2L, 0L, 0L)
      }
    )

    expect_warning(
      {
        result <- read_cerebellar_volume(vol_file, "mock.surf.gii", lut)
      },
      "deep"
    )

    dentate_row <- result[grepl("Dentate", result$region, fixed = TRUE), ]
    expect_identical(nrow(dentate_row), 1L)
    expect_true(dentate_row$deep)
    expect_identical(lengths(dentate_row$vertices), 0L)

    lobule_row <- result[grepl("Lobule", result$region, fixed = TRUE), ]
    expect_false(lobule_row$deep)
    expect_gt(lengths(lobule_row$vertices), 0)
  })

  it("rescues orphaned non-nucleus region via nearest vertices", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    lut <- data.frame(
      idx = 1L,
      label = "Left Lobule-V",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      sample_volume_at_surface = function(...) c(0L, 0L, 0L),
      rescue_orphaned_region = function(...) c(0L, 1L)
    )

    expect_warning(
      {
        result <- read_cerebellar_volume(vol_file, "mock.surf.gii", lut)
      },
      "assigned.*nearest"
    )

    expect_identical(lengths(result$vertices), 2L)
    expect_false(result$deep)
  })

  it("auto-fills NA colours for non-unknown regions", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L
    vol[3, 3, 3] <- 2L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    lut <- data.frame(
      idx = c(1L, 2L),
      label = c("Left Lobule-I", "Right Lobule-II"),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      sample_volume_at_surface = function(...) c(1L, 2L, 1L)
    )

    result <- read_cerebellar_volume(vol_file, "mock.surf.gii", lut)

    expect_false(anyNA(result$colour))
    expect_true(all(grepl("^#", result$colour)))
  })

  it("uses colour from LUT color column when present", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    lut <- data.frame(
      idx = 1L,
      label = "Left Lobule-I",
      R = 255L,
      G = 0L,
      B = 0L,
      A = 0L,
      roi = "0001",
      color = "#FF0000",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      sample_volume_at_surface = function(...) c(1L, 1L)
    )

    result <- read_cerebellar_volume(vol_file, "mock.surf.gii", lut)
    expect_identical(result$colour, "#FF0000")
  })
})


describe("cerebellar_create_meshes", {
  it("warns when volume labels and atlas regions count differ", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L
    vol[3, 3, 3] <- 2L
    vol[4, 4, 4] <- 3L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    components <- list(
      core = data.frame(
        label = c("region_a", "region_b"),
        stringsAsFactors = FALSE
      ),
      vol_idx = NULL
    )
    dirs <- mock_dirs()

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      subcort_create_meshes = function(input_volume, colortable, ...) {
        stats::setNames(
          lapply(colortable$label, function(l) {
            list(
              vertices = data.frame(x = 0, y = 0, z = 0),
              faces = data.frame(V1 = 1, V2 = 1, V3 = 1)
            )
          }),
          colortable$label
        )
      }
    )

    expect_warning(
      {
        result <- cerebellar_create_meshes(
          vol_file,
          components,
          dirs,
          skip_existing = FALSE,
          verbose = FALSE,
          decimate = 0.5
        )
      },
      "Volume has 3.*but atlas has 2"
    )

    expect_identical(nrow(result), 2L)
    expect_true(all(c("label", "mesh") %in% names(result)))
  })

  it("uses vol_idx mapping when available", {
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 10L
    vol[3, 3, 3] <- 20L
    vol[4, 4, 4] <- 99L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    components <- list(
      core = data.frame(
        label = c("lobule_I", "lobule_II", "lobule_III"),
        stringsAsFactors = FALSE
      ),
      vol_idx = c(lobule_I = 10L, lobule_II = 20L, lobule_III = 30L)
    )
    dirs <- mock_dirs()

    .cap$captured_ct <- NULL
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      subcort_create_meshes = function(input_volume, colortable, ...) {
        .cap$captured_ct <- colortable
        stats::setNames(
          lapply(colortable$label, function(l) list()),
          colortable$label
        )
      }
    )

    result <- cerebellar_create_meshes(
      vol_file,
      components,
      dirs,
      skip_existing = FALSE,
      verbose = FALSE,
      decimate = 0.5
    )

    expect_identical(sort(.cap$captured_ct$label), c("lobule_I", "lobule_II"))
    expect_false("lobule_III" %in% .cap$captured_ct$label)
    expect_identical(sort(.cap$captured_ct$idx), c(10L, 20L))
  })

  it("errors when volume file not found", {
    local_mocked_bindings(check_fs = function(...) TRUE)

    expect_error(
      cerebellar_create_meshes(
        "nonexistent.nii.gz",
        list(),
        list(),
        skip_existing = FALSE,
        verbose = FALSE,
        decimate = 0.5
      ),
      "not found"
    )
  })
})


describe("clean_cerebellar_region with whitespace collapsing", {
  it("collapses multiple internal spaces", {
    expect_identical(
      clean_cerebellar_region("Left  Crus   I"),
      "Crus I"
    )
  })
})


describe("cerebellar_read_data", {
  it("returns cached data when skip_existing and files exist", {
    dirs <- list(base = withr::local_tempdir())

    mock_components <- list(
      core = data.frame(
        hemi = "left",
        region = "I-IV",
        label = "left_I-IV",
        stringsAsFactors = FALSE
      ),
      palette = c("left_I-IV" = "#FF0000"),
      vertices_df = data.frame(stringsAsFactors = FALSE, label = "left_I-IV")
    )
    mock_components$vertices_df$vertices <- list(0:3)

    saveRDS(mock_components, file.path(dirs$base, "components.rds"))

    local_mocked_bindings(
      load_or_run_step = function(step, steps, files, skip_existing, ...) {
        list(
          run = FALSE,
          data = list("components.rds" = mock_components)
        )
      }
    )

    config <- list(
      steps = 1L,
      skip_existing = TRUE,
      verbose = FALSE
    )
    result <- cerebellar_read_data(config, dirs, read_fn = function() {
      stop("should not be called")
    })

    expect_identical(result$components, mock_components)
    expect_null(result$deep_data)
  })

  it("loads deep_data.rds when cached and present", {
    dirs <- list(base = withr::local_tempdir())

    mock_components <- list(
      core = data.frame(
        hemi = "left",
        region = "I-IV",
        label = "left_I-IV",
        stringsAsFactors = FALSE
      )
    )
    mock_deep <- tibble(
      hemi = "midline",
      region = "Dentate",
      label = "midline_Dentate",
      colour = "#0000FF",
      vol_idx = 5L,
      deep = TRUE
    )
    mock_deep$vertices <- list(integer(0))

    saveRDS(mock_components, file.path(dirs$base, "components.rds"))
    saveRDS(mock_deep, file.path(dirs$base, "deep_data.rds"))

    local_mocked_bindings(
      load_or_run_step = function(...) {
        list(
          run = FALSE,
          data = list("components.rds" = mock_components)
        )
      }
    )

    config <- list(steps = 1L, skip_existing = TRUE, verbose = FALSE)
    result <- cerebellar_read_data(config, dirs, read_fn = stop)

    expect_false(is.null(result$deep_data))
    expect_true(all(result$deep_data$deep))
  })

  it("separates deep nuclei from surface data when deep column present", {
    dirs <- list(base = withr::local_tempdir())

    atlas_data <- tibble(
      hemi = c("left", "midline"),
      region = c("I-IV", "Dentate"),
      label = c("left_I-IV", "midline_Dentate"),
      colour = c("#FF0000", NA_character_),
      vol_idx = c(1L, 2L),
      vertices = list(0:3, integer(0)),
      deep = c(FALSE, TRUE)
    )

    local_mocked_bindings(
      load_or_run_step = function(...) {
        list(run = TRUE, data = list())
      }
    )

    config <- list(
      steps = 1L,
      skip_existing = FALSE,
      verbose = FALSE,
      tolerance = 0,
      smooth_refinements = 0
    )

    result <- cerebellar_read_data(config, dirs, read_fn = function() {
      atlas_data
    })

    expect_false(is.null(result$deep_data))
    expect_identical(nrow(result$deep_data), 1L)
    expect_identical(result$deep_data$label, "midline_Dentate")
    expect_true("midline_Dentate" %in% result$components$core$label)
    expect_true(file.exists(file.path(dirs$base, "deep_data.rds")))
  })

  it("fills missing colours for deep nuclei", {
    dirs <- list(base = withr::local_tempdir())

    atlas_data <- tibble(
      hemi = c("left", "midline"),
      region = c("I-IV", "Dentate"),
      label = c("left_I-IV", "midline_Dentate"),
      colour = c("#FF0000", NA_character_),
      vol_idx = c(1L, 2L),
      vertices = list(0:3, integer(0)),
      deep = c(FALSE, TRUE)
    )

    local_mocked_bindings(
      load_or_run_step = function(...) {
        list(run = TRUE, data = list())
      }
    )

    config <- list(
      steps = 1L,
      skip_existing = FALSE,
      verbose = FALSE,
      tolerance = 0,
      smooth_refinements = 0
    )

    result <- cerebellar_read_data(config, dirs, read_fn = function() {
      atlas_data
    })

    deep_colour <- result$components$palette["midline_Dentate"]
    expect_false(is.na(deep_colour))
    expect_true(grepl("^#", deep_colour))
  })
})


describe("cerebellar_project_and_build", {
  it("builds atlas without deep nuclei when deep_data is NULL", {
    components <- list(
      core = data.frame(
        hemi = "left",
        region = "I-IV",
        label = "left_I-IV",
        stringsAsFactors = FALSE
      ),
      palette = c("left_I-IV" = "#FF0000"),
      vertices_df = data.frame(label = "left_I-IV", stringsAsFactors = FALSE)
    )
    components$vertices_df$vertices <- list(0:999)

    dirs <- mock_dirs()
    config <- list(
      verbose = FALSE,
      tolerance = 0,
      smooth_refinements = 0,
      cleanup = FALSE,
      skip_existing = FALSE
    )

    atlas <- cerebellar_project_and_build(
      components = components,
      deep_data = NULL,
      volume = NULL,
      atlas_name = "test_cer",
      config = config,
      dirs = dirs,
      start_time = Sys.time()
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_s3_class(atlas, "cerebellar_atlas")
    expect_identical(atlas$type, "cerebellar")
    expect_gt(nrow(atlas$core), 0)
  })
})


describe("cerebellar_process_deep_nuclei", {
  it("returns NULL sf/meshes when vol_idx column missing", {
    skip_if_not_installed("terra")

    deep_data <- tibble(
      hemi = "midline",
      region = "Dentate",
      label = "midline_Dentate",
      colour = "#0000FF",
      deep = TRUE
    )
    deep_data$vertices <- list(integer(0))

    dirs <- mock_dirs()

    expect_warning(
      {
        result <- cerebellar_process_deep_nuclei(
          volume = "unused.nii.gz",
          deep_data = deep_data,
          dirs = dirs,
          verbose = TRUE
        )
      },
      "vol_idx"
    )

    expect_null(result$sf)
    expect_null(result$meshes)
  })

  it("creates sf geometries from deep nuclei voxels", {
    skip_if_not_installed("terra")
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(20, 20, 20))
    vol[8:12, 8:12, 8:12] <- 1L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    deep_data <- tibble(
      hemi = "midline",
      region = "Dentate",
      label = "midline_Dentate",
      colour = "#0000FF",
      vol_idx = 1L,
      deep = TRUE
    )
    deep_data$vertices <- list(integer(0))

    dirs <- mock_dirs()

    local_mocked_bindings(check_fs = function(...) FALSE)

    result <- cerebellar_process_deep_nuclei(
      volume = vol_file,
      deep_data = deep_data,
      dirs = dirs,
      verbose = FALSE
    )

    expect_s3_class(result$sf, "sf")
    expect_gt(nrow(result$sf), 0)
    expect_identical(result$sf$label, "midline_Dentate")
    expect_identical(result$sf$view, "nuclei")
    expect_null(result$meshes)
  })

  it("skips labels with zero voxels in volume", {
    skip_if_not_installed("terra")
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(10, 10, 10))
    vol[3:5, 3:5, 3:5] <- 1L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    deep_data <- tibble(
      hemi = c("midline", "midline"),
      region = c("Dentate", "Fastigial"),
      label = c("midline_Dentate", "midline_Fastigial"),
      colour = c("#0000FF", "#00FF00"),
      vol_idx = c(1L, 99L),
      deep = c(TRUE, TRUE)
    )
    deep_data$vertices <- list(integer(0), integer(0))

    dirs <- mock_dirs()
    local_mocked_bindings(check_fs = function(...) FALSE)

    result <- cerebellar_process_deep_nuclei(
      volume = vol_file,
      deep_data = deep_data,
      dirs = dirs,
      verbose = FALSE
    )

    expect_identical(nrow(result$sf), 1L)
    expect_identical(result$sf$label, "midline_Dentate")
  })

  it("creates 3D meshes when FreeSurfer available", {
    skip_if_no_freesurfer()
    skip_if_not_installed("terra")
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(20, 20, 20))
    vol[5:15, 5:15, 5:15] <- 1L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    deep_data <- tibble(
      hemi = "midline",
      region = "Dentate",
      label = "midline_Dentate",
      colour = "#0000FF",
      vol_idx = 1L,
      deep = TRUE
    )
    deep_data$vertices <- list(integer(0))

    dirs <- mock_dirs()

    result <- cerebellar_process_deep_nuclei(
      volume = vol_file,
      deep_data = deep_data,
      dirs = dirs,
      verbose = TRUE
    )

    expect_s3_class(result$sf, "sf")
    if (!is.null(result$meshes)) {
      expect_gt(nrow(result$meshes), 0)
      expect_true("mesh" %in% names(result$meshes))
    }
  })
})


describe("get_tkras_to_world", {
  it("computes transform matrix from FreeSurfer mri_info", {
    skip_if_no_freesurfer()
    skip_if_not_installed("RNifti")

    vol <- array(0L, dim = c(10, 10, 10))
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol), vol_file)

    result <- get_tkras_to_world(vol_file)

    expect_true(is.matrix(result))
    expect_identical(dim(result), c(4L, 4L))
    expect_identical(result[4, ], c(0, 0, 0, 1))
  })
})


describe("run_cerebellar_creation verbose output", {
  it("prints header and input files when verbose", {
    dirs_tmp <- withr::local_tempdir()

    local_mocked_bindings(
      setup_atlas_dirs = function(...) {
        list(
          base = dirs_tmp,
          snapshots = dirs_tmp,
          processed = dirs_tmp,
          masks = dirs_tmp
        )
      },
      cerebellar_read_data = function(...) {
        list(
          components = list(
            core = data.frame(
              hemi = "left",
              region = "I-IV",
              label = "left_I-IV",
              stringsAsFactors = FALSE
            ),
            palette = c("left_I-IV" = "#FF0000"),
            vertices_df = data.frame(
              label = "left_I-IV",
              stringsAsFactors = FALSE
            )
          ),
          deep_data = NULL
        )
      },
      cerebellar_project_and_build = function(...) {
        structure(list(), class = "ggseg_atlas")
      }
    )

    config <- list(
      verbose = TRUE,
      output_dir = dirs_tmp,
      steps = 1:2,
      skip_existing = FALSE,
      cleanup = FALSE,
      tolerance = 0,
      smooth_refinements = 0
    )

    expect_messages(
      run_cerebellar_creation(
        atlas_name = "test_verbose",
        config = config,
        read_fn = function() tibble(),
        input_files = c("file1.gii", "file2.gii")
      ),
      "Creating cerebellar atlas"
    )
  })
})


describe("read_suit_parcellation vertex overlap warning", {
  it("warns when vertices assigned to multiple regions across files", {
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_if_not_installed("base64enc") # nolint: object_usage_linter.

    make_label_gii <- function(values, lt = NULL) {
      dir <- withr::local_tempdir(.local_envir = parent.frame(2))
      label_file <- file.path(
        dir,
        paste0("parcellation_", sample(1e6, 1), ".label.gii")
      )

      labels_b64 <- base64enc::base64encode(
        writeBin(as.integer(values), raw(), size = 4)
      )

      lt_xml <- if (!is.null(lt)) {
        paste(
          vapply(
            seq_len(nrow(lt)),
            function(i) {
              sprintf(
                '<Label Key="%d" Red="%.1f" Green="%.1f" Blue="%.1f" Alpha="1">%s</Label>', # nolint: line_length_linter.
                lt$id[i],
                lt$r[i],
                lt$g[i],
                lt$b[i],
                lt$name[i]
              )
            },
            character(1)
          ),
          collapse = "\n    "
        )
      } else {
        ""
      }

      # nolint start: indentation_linter.
      xml <- sprintf(
        '<?xml version="1.0" encoding="UTF-8"?>
<GIFTI Version="1.0" NumberOfDataArrays="1">
  <MetaData/><LabelTable>%s</LabelTable>
  <DataArray Intent="NIFTI_INTENT_LABEL" DataType="NIFTI_TYPE_INT32"
    ArrayIndexingOrder="RowMajorOrder" Dimensionality="1"
    Dim0="%d" Encoding="Base64Binary" Endian="LittleEndian">
    <MetaData/><Data>%s</Data>
  </DataArray>
</GIFTI>',
        lt_xml,
        length(values),
        labels_b64
      )
      # nolint end

      writeLines(xml, label_file)
      label_file
    }

    lt <- data.frame(
      id = c(0L, 1L, 2L),
      name = c("Background", "Left I-IV", "Vermis VI"),
      r = c(0, 0.8, 0.2),
      g = c(0, 0.2, 0.8),
      b = c(0, 0.2, 0.2),
      stringsAsFactors = FALSE
    )

    file1 <- make_label_gii(c(1L, 1L, 0L, 0L), lt)
    file2 <- make_label_gii(c(0L, 2L, 2L, 0L), lt)

    expect_warning(
      {
        result <- read_suit_parcellation(c(file1, file2))
      },
      "overlaps"
    )

    expect_s3_class(result, "tbl_df")
    expect_gte(nrow(result), 2)
  })
})


describe("create_cerebellar_from_volume integration", {
  it("runs the full pipeline with a real NIfTI volume", {
    skip_if_not_installed("RNifti")
    skip_if_not_installed("gifti") # nolint: object_usage_linter.
    skip_on_cran()

    vol <- array(0L, dim = c(112, 93, 66))
    hdr <- RNifti::dumpNifti(RNifti::asNifti(vol))
    hdr$sform_code <- 2L
    hdr$srow_x <- c(1, 0, 0, -55)
    hdr$srow_y <- c(0, 1, 0, -92)
    hdr$srow_z <- c(0, 0, 1, -65)

    vol[30:40, 47:51, 38:42] <- 1L
    vol[70:80, 47:51, 38:42] <- 2L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(vol, reference = hdr), vol_file)

    lut <- data.frame(
      idx = c(1L, 2L),
      label = c("Left Lobule-I", "Right Lobule-V"),
      stringsAsFactors = FALSE
    )

    atlas <- create_cerebellar_from_volume(
      volume = vol_file,
      input_lut = lut,
      atlas_name = "test_cer_integ",
      smooth_refinements = 0,
      tolerance = 0,
      verbose = FALSE,
      cleanup = TRUE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_s3_class(atlas, "cerebellar_atlas")
    expect_gte(nrow(atlas$core), 2)

    sf_data <- ggseg.formats::atlas_sf(atlas)
    expect_s3_class(sf_data, "sf")
    expect_true("flatmap" %in% sf_data$view)
  })
})
