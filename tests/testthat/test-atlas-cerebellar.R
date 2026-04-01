# Test fixture helpers ----

create_mock_suit_surface <- function() {
  skip_if_not_installed("gifti")
  skip_if_not_installed("base64enc")

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
</GIFTI>', pointset_b64, triangles_b64)

  writeLines(xml, surf_file)
  surf_file
}


create_mock_suit_labels <- function(n_vertices = 4) {
  skip_if_not_installed("gifti")
  skip_if_not_installed("base64enc")

  dir <- withr::local_tempdir(.local_envir = parent.frame())
  label_file <- file.path(dir, "Lobules-SUIT.label.gii")

  labels <- as.integer(c(1, 1, 2, 2))
  if (n_vertices > 4) {
    labels <- c(labels, rep(0L, n_vertices - 4))
  }
  labels_b64 <- base64enc::base64encode(
    writeBin(labels, raw(), size = 4)
  )

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
</GIFTI>', n_vertices, labels_b64)

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
    skip_if_not_installed("gifti")

    surf <- create_mock_suit_surface()
    result <- read_suit_flatmap(surf)

    expect_type(result, "list")
    expect_true(all(c("verts_2d", "faces", "n_vertices") %in% names(result)))
    expect_equal(ncol(result$verts_2d), 2)
    expect_equal(ncol(result$faces), 3)
    expect_equal(result$n_vertices, nrow(result$verts_2d))
  })

  it("errors on missing file", {
    expect_error(
      read_suit_flatmap("nonexistent.surf.gii"),
      "not found"
    )
  })

  it("reads bundled SUIT flatmap correctly", {
    skip_if_not_installed("gifti")

    result <- read_suit_flatmap(suit_flatmap_path())

    expect_equal(result$n_vertices, 28935)
    expect_equal(ncol(result$verts_2d), 2)
    expect_equal(nrow(result$faces), 56588)
  })

  it("errors on invalid GIFTI file", {
    skip_if_not_installed("gifti")

    tmp <- withr::local_tempfile(fileext = ".surf.gii")
    writeLines('<?xml version="1.0"?><GIFTI Version="1.0"
      NumberOfDataArrays="0"><MetaData/><LabelTable/></GIFTI>', tmp)

    expect_error(read_suit_flatmap(tmp))
  })
})


describe("cerebellar_build_sf_flatmap", {
  it("errors when no vertices match the flatmap", {
    skip_if_not_installed("gifti")

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
          components, suit_flatmap_path(),
          tolerance = 0, smooth_refinements = 0, verbose = FALSE
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
    expect_equal(result[1:4], rep("left_I-IV", 4))
    expect_equal(result[5:8], rep("right_I-IV", 4))
    expect_equal(result[9:10], rep("vermis_VI", 2))
  })

  it("returns NA for unlabelled vertices", {
    vertices_df <- data.frame(
      label = "left_I-IV",
      stringsAsFactors = FALSE
    )
    vertices_df$vertices <- list(0:2)

    result <- build_vertex_label_vector_cerebellum(vertices_df, 5)

    expect_equal(sum(is.na(result)), 2)
  })
})


describe("flatmap_triangles_to_polygons", {
  it("produces valid sf polygons from uniform triangles", {
    verts <- matrix(c(
      0, 0,
      1, 0,
      0.5, 1,
      1.5, 1
    ), ncol = 2, byrow = TRUE)
    faces <- matrix(c(0, 1, 2, 1, 3, 2), ncol = 3, byrow = TRUE)
    labels <- c("left_I", "left_I", "left_I", "left_I")

    result <- flatmap_triangles_to_polygons(verts, faces, labels)

    expect_s3_class(result, "sf")
    expect_true(nrow(result) >= 1)
    expect_true("label" %in% names(result))
  })

  it("splits boundary triangles between regions", {
    verts <- matrix(c(
      0, 0,
      1, 0,
      0.5, 1
    ), ncol = 2, byrow = TRUE)
    faces <- matrix(c(0, 1, 2), ncol = 3)
    labels <- c("left_I", "left_I", "right_I")

    result <- flatmap_triangles_to_polygons(verts, faces, labels)

    expect_s3_class(result, "sf")
    expect_true(nrow(result) == 2)
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
    verts <- matrix(c(
      0, 0,
      1, 0,
      2, 0,
      0.5, 1
    ), ncol = 2, byrow = TRUE)
    faces <- matrix(c(0, 1, 2, 0, 1, 3), ncol = 3, byrow = TRUE)
    labels <- c("left_I", "left_I", "left_I", "left_I")

    result <- flatmap_triangles_to_polygons(verts, faces, labels)

    expect_s3_class(result, "sf")
    expect_true(nrow(result) >= 1)
  })
})


describe("detect_cerebellar_hemi", {
  it("detects Left prefix", {
    expect_equal(detect_cerebellar_hemi("Left I-IV"), "left")
    expect_equal(detect_cerebellar_hemi("Left Crus I"), "left")
  })

  it("detects Right prefix", {
    expect_equal(detect_cerebellar_hemi("Right I-IV"), "right")
  })

  it("detects Vermis prefix", {
    expect_equal(detect_cerebellar_hemi("Vermis VI"), "vermis")
    expect_equal(detect_cerebellar_hemi("Vermis CrusII"), "vermis")
  })

  it("detects vermis in label body", {
    expect_equal(detect_cerebellar_hemi("region_vermis"), "vermis")
  })

  it("defaults to midline for ambiguous labels", {
    expect_equal(detect_cerebellar_hemi("Dentate"), "midline")
  })
})


describe("clean_cerebellar_region", {
  it("removes Left/Right/Vermis prefix", {
    expect_equal(clean_cerebellar_region("Left I-IV"), "I-IV")
    expect_equal(clean_cerebellar_region("Right Crus I"), "Crus I")
    expect_equal(clean_cerebellar_region("Vermis VI"), "VI")
  })

  it("preserves full name when no prefix", {
    expect_equal(clean_cerebellar_region("Dentate"), "Dentate")
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
    skip_if_not_installed("gifti")

    label_file <- create_mock_suit_labels()
    result <- read_suit_parcellation(label_file)

    expect_s3_class(result, "tbl_df")
    expected_cols <- c("hemi", "region", "label", "colour", "vertices")
    expect_true(all(expected_cols %in% names(result)))
    expect_true(nrow(result) > 0)
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
      c("0", "0", "0", "0", "0",
        "1", "0.8", "0.2", "0.2", "1",
        "2", "0.2", "0.8", "0.2", "1"),
      ncol = 5, byrow = TRUE,
      dimnames = list(
        c("Background", "Left I-IV", "Vermis VI"),
        c("Key", "Red", "Green", "Blue", "Alpha")
      )
    )
    gii <- list(label = as.data.frame(lt))
    result <- extract_gifti_label_table(gii)
    expect_equal(nrow(result), 3)
    expect_true(all(c("id", "name", "colour") %in% names(result)))
    expect_equal(result$name, c("Background", "Left I-IV", "Vermis VI"))
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
    skip_if_not_installed("gifti")
    skip_if_not_installed("base64enc")

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
    expect_equal(atlas$type, "cerebellar")
    expect_s3_class(atlas$data, "ggseg_data_cerebellar")
    expect_true(nrow(atlas$core) > 0)

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
    expect_equal(nrow(result), 3)
    expected_cols <- c("hemi", "region", "label", "colour", "vertices")
    expect_true(all(expected_cols %in% names(result)))
    expect_equal(result$hemi, c("left", "right", "vermis"))
    expect_equal(result$region, c("I-IV", "Crus I", "VI"))
    expect_equal(lengths(result$vertices), c(2L, 2L, 1L))
  })

  it("errors when no regions found", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = integer(0),
      colortable_df = data.frame(
        code = integer(), struct_name = character(),
        r = numeric(), g = numeric(), b = numeric(), a = numeric(),
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
    expect_equal(result$idx, c(1L, 2L))
    expect_equal(result$label, c("region_1", "region_2"))
  })

  it("uses data.frame LUT when provided", {
    vol <- array(c(0L, 1L, 2L, 0L, 1L, 2L, 0L, 0L), dim = c(2, 2, 2))
    vertex_labels <- c(1L, 2L)
    lut <- data.frame(
      idx = c(1L, 2L, 3L),
      label = c("Left I-IV", "Vermis VI", "Right V"),
      R = c(255, 0, 0),
      G = c(0, 255, 0),
      B = c(0, 0, 255)
    )

    result <- resolve_cerebellar_lut(vol, vertex_labels, lut)

    expect_equal(nrow(result), 2)
    expect_true("color" %in% names(result))
  })

  it("errors on data.frame LUT missing required columns", {
    vol <- array(c(0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L), dim = c(2, 2, 2))
    vertex_labels <- c(1L)
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
    writeLines(c(
      "  1  Left_I-IV   200 50 50 0",
      "  2  Vermis_VI   50 200 50 0"
    ), tmp)

    result <- resolve_cerebellar_lut(vol, vertex_labels, tmp)

    expect_equal(nrow(result), 2)
    expect_true("label" %in% names(result))
  })
})


describe("read_suit_parcellation edge cases", {
  it("handles labels without LUT entry", {
    skip_if_not_installed("gifti")
    skip_if_not_installed("base64enc")

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

    expect_true(nrow(result) > 0)
    expect_true(all(grepl("^region_", result$region)))
    expect_false(any(is.na(result$colour)))
  })

  it("warns and skips GIFTI files with empty data arrays", {
    skip_if_not_installed("gifti")
    skip_if_not_installed("base64enc")

    label_file <- create_mock_suit_labels(n_vertices = 4)

    local_mocked_bindings(
      readgii = function(file) list(data = list(), label = NULL),
      .package = "gifti"
    )

    expect_warning(
      result <- read_suit_parcellation(label_file),
      "No data arrays"
    )
    expect_equal(nrow(result), 0)
  })

  it("handles matrix-format data arrays", {
    skip_if_not_installed("gifti")
    skip_if_not_installed("base64enc")

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
    expect_equal(nrow(result), 2)
  })

  it("returns empty tibble when all labels are zero", {
    skip_if_not_installed("gifti")
    skip_if_not_installed("base64enc")

    label_file <- create_mock_suit_labels(n_vertices = 4)

    local_mocked_bindings(
      readgii = function(file) {
        list(data = list(as.integer(c(0, 0, 0, 0))), label = NULL)
      },
      .package = "gifti"
    )

    result <- read_suit_parcellation(label_file)
    expect_equal(nrow(result), 0)
  })

  it("skips regions with zero vertices after filtering", {
    skip_if_not_installed("gifti")
    skip_if_not_installed("base64enc")

    lt <- matrix(
      c("0", "0", "0", "0", "0",
        "1", "0.8", "0.2", "0.2", "1",
        "2", "0.2", "0.8", "0.2", "1"),
      ncol = 5, byrow = TRUE,
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

    expect_equal(nrow(result), 1)
    expect_equal(result$hemi[1], "left")
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
    expect_equal(nrow(result), 3)
    expect_equal(result$name, c("Background", "Left I-IV", "Vermis VI"))
    expect_true("colour" %in% names(result))
  })

  it("handles Key format without RGB columns", {
    lt <- matrix(
      c("0", "0", "1", "0"),
      ncol = 2, byrow = TRUE,
      dimnames = list(c("Background", "Region1"), c("Key", "Alpha"))
    )
    gii <- list(label = as.data.frame(lt))
    result <- extract_gifti_label_table(gii)
    expect_equal(nrow(result), 2)
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
    expect_equal(nrow(result), 2)
    expect_true(all(is.na(result$colour)))
  })

  it("returns NULL for unrecognized format", {
    gii <- list(label = data.frame(foo = 1, bar = 2))
    expect_null(extract_gifti_label_table(gii))
  })
})


describe("clean_cerebellar_region edge cases", {
  it("returns original name when prefix removal leaves empty string", {
    expect_equal(clean_cerebellar_region("Left"), "Left")
    expect_equal(clean_cerebellar_region("Right"), "Right")
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
    expect_true(nrow(result) > 0)
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
    skip_if_not_installed("gifti")

    vol <- array(0L, dim = c(5, 5, 5))
    vol[2, 2, 2] <- 1L
    vol[4, 4, 4] <- 2L

    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    nii <- RNifti::asNifti(vol)
    RNifti::writeNifti(nii, vol_file)

    result <- sample_volume_at_surface(vol, vol_file, suit_3d_path())

    expect_length(result, 28935)
    expect_true(is.integer(result))
  })
})


describe("cerebellar pipeline orchestration", {
  it("create_cerebellar_from_gifti derives atlas_name from file", {
    skip_if_not_installed("gifti")
    skip_if_not_installed("base64enc")

    label_file <- create_mock_suit_labels(n_vertices = 28935)

    atlas <- create_cerebellar_from_gifti(
      gifti_files = label_file,
      smooth_refinements = 0,
      tolerance = 0,
      verbose = FALSE
    )

    expect_true(nchar(atlas$atlas) > 0)
  })

  it("create_cerebellar_from_annotation derives atlas_name", {
    skip_if_not_installed("freesurferformats")

    mock_annot <- list(
      label_codes = c(1L, 1L, 2L),
      colortable_df = data.frame(
        code = 1:2,
        struct_name = c("Left I-IV", "Vermis VI"),
        r = c(200, 50), g = c(50, 200), b = c(50, 50), a = c(0, 0),
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
              c(0, 0, 1, 0, 1, 1, 0, 0), ncol = 2, byrow = TRUE
            ))),
            sf::st_polygon(list(matrix(
              c(2, 0, 3, 0, 3, 1, 2, 0), ncol = 2, byrow = TRUE
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
    expect_equal(atlas$type, "cerebellar")
  })
})


describe("cerebellar_build_sf_flatmap smoothing and simplification", {
  it("applies topology-preserving simplification", {
    skip_if_not_installed("gifti")

    components <- list(
      vertices_df = data.frame(
        label = "left_I-IV",
        stringsAsFactors = FALSE
      )
    )
    components$vertices_df$vertices <- list(0:999)

    result <- cerebellar_build_sf_flatmap(
      components, suit_flatmap_path(),
      tolerance = 0, smooth_refinements = 2, verbose = FALSE
    )

    expect_s3_class(result, "sf")
    expect_true("flatmap" %in% result$view)
  })

  it("applies simplification when tolerance > 0", {
    skip_if_not_installed("gifti")

    components <- list(
      vertices_df = data.frame(
        label = "left_I-IV",
        stringsAsFactors = FALSE
      )
    )
    components$vertices_df$vertices <- list(0:999)

    result <- cerebellar_build_sf_flatmap(
      components, suit_flatmap_path(),
      tolerance = 0.5, smooth_refinements = 0, verbose = FALSE
    )

    expect_s3_class(result, "sf")
  })

  it("verbose mode prints progress messages", {
    skip_if_not_installed("gifti")

    components <- list(
      vertices_df = data.frame(
        label = "left_I-IV",
        stringsAsFactors = FALSE
      )
    )
    components$vertices_df$vertices <- list(0:999)

    expect_message(
      cerebellar_build_sf_flatmap(
        components, suit_flatmap_path(),
        tolerance = 0, smooth_refinements = 0, verbose = TRUE
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
    for (i in 1:3) for (j in 1:3) for (k in 1:3) {
      xfm[i, j, k, 1, ] <- center_world
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
      tmp, "tpl-SUIT_from-MNI152NLin6AsymC_mode-image_xfm.nii"
    )
    writeBin(raw(1e6 + 1), cached)

    result <- suit_deformation_field(cache_dir = tmp)
    expect_equal(result, cached)
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
