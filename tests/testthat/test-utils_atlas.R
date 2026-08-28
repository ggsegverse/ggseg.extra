describe("detect_hemi", {
  it("returns the default for non-scalar input instead of erroring", {
    expect_identical(
      detect_hemi(c("Left-x", "Right-y")),
      NA_character_
    )
    expect_identical(detect_hemi(character(0)), NA_character_)
  })

  it("detects left from prefix", {
    expect_identical(detect_hemi("Left-Thalamus"), "left")
    expect_identical(detect_hemi("left_amygdala"), "left")
    expect_identical(detect_hemi("lh.aparc"), "left")
    expect_identical(detect_hemi("lh_region"), "left")
    expect_identical(detect_hemi("L_motor"), "left")
  })

  it("detects right from prefix", {
    expect_identical(detect_hemi("Right-Thalamus"), "right")
    expect_identical(detect_hemi("right_amygdala"), "right")
    expect_identical(detect_hemi("rh.aparc"), "right")
    expect_identical(detect_hemi("rh_region"), "right")
    expect_identical(detect_hemi("R_motor"), "right")
  })

  it("detects from suffix", {
    expect_identical(detect_hemi("cst_left"), "left")
    expect_identical(detect_hemi("cst_right"), "right")
    expect_identical(detect_hemi("tract_lh"), "left")
    expect_identical(detect_hemi("tract_rh"), "right")
  })

  it("detects from anywhere when not strict", {
    expect_identical(detect_hemi("motor_left_area"), "left")
    expect_identical(detect_hemi("rightHemisphere"), "right")
  })

  it("returns NA for ambiguous labels", {
    expect_true(is.na(detect_hemi("brainstem")))
    expect_true(is.na(detect_hemi("corpus_callosum")))
  })

  it("handles NA and empty input", {
    expect_true(is.na(detect_hemi(NA)))
    expect_true(is.na(detect_hemi("")))
  })
})


describe("clean_region_name", {
  it("removes hemisphere prefix and normalizes", {
    expect_identical(clean_region_name("Left-Thalamus"), "thalamus")
    expect_identical(clean_region_name("right_Amygdala"), "amygdala")
    expect_identical(
      clean_region_name("lh.superior_frontal"),
      "superior frontal"
    )
  })

  it("converts underscores and dashes to spaces", {
    expect_identical(clean_region_name("superior_frontal"), "superior frontal")
    expect_identical(clean_region_name("pre-central"), "pre central")
  })

  it("can skip hemisphere removal", {
    expect_identical(
      clean_region_name("Left-Thalamus", remove_hemi = FALSE),
      "left thalamus"
    )
  })

  it("can skip normalization", {
    expect_identical(
      clean_region_name("Left-Thalamus", normalize = FALSE),
      "Thalamus"
    )
  })

  it("strips every hemisphere affix detect_hemi() recognises", {
    # If the two disagree, the hemisphere lands in `region` as well as `hemi`
    # and the two sides of one structure stop pairing.
    labels <- c(
      "R_Fx",
      "L_Fx",
      "Left-Thalamus",
      "rh_atr",
      "Ch_123_Basal_Forebrain_right",
      "Area_5L_SPL_left",
      "Fx_L",
      "Fx_R",
      "Fx-r",
      "Cing_l",
      "tract_lh",
      "cst_right"
    )
    for (label in labels) {
      expect_false(
        is.na(detect_hemi(label)),
        info = paste("detect_hemi failed on", label)
      )
      expect_false(
        grepl("(^|\\s)(left|right|lh|rh|l|r)(\\s|$)", clean_region_name(label)),
        info = paste("hemisphere left in region for", label)
      )
    }
  })

  it("pairs the hemispheres of a structure on region", {
    expect_identical(
      clean_region_name("L_Fx"),
      clean_region_name("R_Fx")
    )
    expect_identical(
      clean_region_name("Fx_L"),
      clean_region_name("Fx_R")
    )
    expect_identical(
      clean_region_name("Area_5L_SPL_left"),
      clean_region_name("Area_5L_SPL_right")
    )
  })

  it("keeps a name that is only a hemisphere word", {
    expect_identical(clean_region_name("left"), "left")
  })

  it("does not strip a leading letter that is not an affix", {
    expect_identical(
      clean_region_name("Rolandic_operculum"),
      "rolandic operculum"
    )
    expect_identical(clean_region_name("Lingual"), "lingual")
  })
})


describe("hemi_to_long", {
  it("converts short to long form", {
    expect_identical(hemi_to_long("lh"), "left")
    expect_identical(hemi_to_long("rh"), "right")
  })

  it("returns unchanged for non-short forms", {
    expect_identical(hemi_to_long("left"), "left")
    expect_identical(hemi_to_long("subcort"), "subcort")
  })
})


describe("hemi_to_short", {
  it("converts long to short form", {
    expect_identical(hemi_to_short("left"), "lh")
    expect_identical(hemi_to_short("right"), "rh")
  })

  it("returns unchanged for non-long forms", {
    expect_identical(hemi_to_short("lh"), "lh")
    expect_identical(hemi_to_short("subcort"), "subcort")
  })
})


describe("setup_atlas_dirs", {
  it("creates standard directory structure", {
    tmp <- withr::local_tempdir()
    dirs <- setup_atlas_dirs(tmp, "test_atlas", type = "cortical")

    expect_true(dir.exists(dirs$base))
    expect_true(dir.exists(dirs$snapshots))
    expect_true(dir.exists(dirs$processed))
    expect_true(dir.exists(dirs$masks))
  })

  it("creates additional dirs for subcortical type", {
    tmp <- withr::local_tempdir()
    dirs <- setup_atlas_dirs(tmp, "test_subcort", type = "subcortical")

    expect_true(dir.exists(dirs$meshes))
  })

  it("handles existing directories without error", {
    tmp <- withr::local_tempdir()
    dirs1 <- setup_atlas_dirs(tmp, "test_atlas")

    expect_no_error({
      dirs2 <- setup_atlas_dirs(tmp, "test_atlas")
    })
    expect_identical(dirs1$base, dirs2$base)
  })
})


describe("setup_atlas_dirs with NULL atlas_name", {
  it("uses output_dir directly as base when atlas_name is NULL", {
    tmp <- withr::local_tempdir()
    dirs <- setup_atlas_dirs(tmp, atlas_name = NULL)

    expect_identical(dirs$base, tmp)
    expect_true(dir.exists(dirs$snapshots))
    expect_identical(dirs$snapshots, as.character(fs::path(tmp, "snapshots")))
  })
})


describe("build_atlas_components", {
  it("builds core, palette and vertices from atlas data", {
    atlas_data <- data.frame(
      hemi = c("left", "left", "right"),
      region = c("motor", "visual", "motor"),
      label = c("lh_motor", "lh_visual", "rh_motor"),
      colour = c("#FF0000", "#00FF00", "#0000FF"),
      stringsAsFactors = FALSE
    )
    atlas_data$vertices <- list(c(1L, 2L, 3L), c(4L, 5L), c(6L, 7L, 8L))

    result <- build_atlas_components(atlas_data)

    expect_true("core" %in% names(result))
    expect_true("palette" %in% names(result))
    expect_true("vertices_df" %in% names(result))

    expect_identical(nrow(result$core), 3L)
    expect_length(result$palette, 3)
    expect_identical(nrow(result$vertices_df), 3L)
  })

  it("builds meshes_df when mesh column present", {
    atlas_data <- data.frame(
      hemi = c("left", "right"),
      region = c("thalamus", "thalamus"),
      label = c("Left-Thalamus", "Right-Thalamus"),
      colour = c("#FF0000", "#0000FF"),
      stringsAsFactors = FALSE
    )
    mock_mesh <- list(
      vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
      faces = data.frame(i = 1, j = 2, k = 3)
    )
    atlas_data$mesh <- list(mock_mesh, mock_mesh)

    result <- build_atlas_components(atlas_data)

    expect_true("meshes_df" %in% names(result))
    expect_identical(nrow(result$meshes_df), 2L)
  })

  it("returns no palette when all colours are NA", {
    atlas_data <- data.frame(
      hemi = c("left", "right"),
      region = c("motor", "visual"),
      label = c("lh_motor", "rh_visual"),
      colour = c(NA_character_, NA_character_),
      stringsAsFactors = FALSE
    )
    atlas_data$vertices <- list(c(1L, 2L), c(3L, 4L))

    result <- build_atlas_components(atlas_data)

    expect_null(result$palette)
  })

  it("keeps supplied colours and leaves NA entries NA", {
    atlas_data <- data.frame(
      hemi = c("left", "left", "right"),
      region = c("motor", "visual", "motor"),
      label = c("lh_motor", "lh_visual", "rh_motor"),
      colour = c("#FF0000", NA_character_, "#0000FF"),
      stringsAsFactors = FALSE
    )
    atlas_data$vertices <- list(c(1L, 2L), 3L, c(4L, 5L))

    result <- build_atlas_components(atlas_data)

    expect_identical(result$palette[["lh_motor"]], "#FF0000")
    expect_identical(result$palette[["rh_motor"]], "#0000FF")
    expect_true(is.na(result$palette[["lh_visual"]]))
  })

  it("returns no palette when only the unknown label is present", {
    atlas_data <- data.frame(
      hemi = c("left", "left"),
      region = c("unknown", "motor"),
      label = c("unknown", "lh_motor"),
      colour = c(NA_character_, NA_character_),
      stringsAsFactors = FALSE
    )
    atlas_data$vertices <- list(1L, c(2L, 3L))

    result <- build_atlas_components(atlas_data)

    expect_null(result$palette)
  })

  it("handles duplicate labels in palette", {
    atlas_data <- data.frame(
      hemi = c("left", "left"),
      region = c("motor", "motor"),
      label = c("lh_motor", "lh_motor"),
      colour = c("#FF0000", "#FF0000"),
      stringsAsFactors = FALSE
    )
    atlas_data$vertices <- list(c(1L, 2L), c(3L, 4L))

    result <- build_atlas_components(atlas_data)

    expect_length(result$palette, 1)
    expect_named(result$palette, "lh_motor")
  })
})


describe("parse_lut_colours", {
  it("returns NULLs for a NULL lut", {
    result <- parse_lut_colours(NULL)
    expect_null(result$region_names)
    expect_null(result$colours)
  })

  it("reads region names and colours from a region-column data.frame", {
    lut <- data.frame(
      region = c("Unknown", "region1"),
      R = c(0L, 205L),
      G = c(0L, 130L),
      B = c(0L, 176L)
    )
    result <- parse_lut_colours(lut)
    expect_identical(result$region_names, c("Unknown", "region1"))
    expect_identical(result$colours, c("#000000", "#CD82B0"))
  })

  it("falls back to a label column for ctab-schema data.frames", {
    lut <- data.frame(
      idx = 0:1,
      label = c("Unknown", "region1"),
      R = c(0L, 205L),
      G = c(0L, 130L),
      B = c(0L, 176L),
      A = c(0L, 0L)
    )
    result <- parse_lut_colours(lut)
    expect_identical(result$region_names, c("Unknown", "region1"))
    expect_identical(result$colours, c("#000000", "#CD82B0"))
  })

  it("reads region names from a FreeSurfer-style ctab file path", {
    lut_file <- withr::local_tempfile()
    writeLines(
      c(
        "  0  Unknown                         0   0   0   0",
        "  1  region1                       205 130 176   0"
      ),
      lut_file
    )

    result <- parse_lut_colours(lut_file)

    expect_identical(result$region_names, c("Unknown", "region1"))
    expect_identical(result$colours, c("#000000", "#CD82B0"))
  })

  it("returns NULL region names when no region or label column exists", {
    lut <- data.frame(
      idx = 0:1,
      R = c(0L, 205L),
      G = c(0L, 130L),
      B = c(0L, 176L)
    )

    result <- parse_lut_colours(lut)

    expect_null(result$region_names)
    expect_identical(result$colours, c("#000000", "#CD82B0"))
  })
})


describe("derive_atlas_name", {
  it("strips hemisphere prefixes and single extensions", {
    expect_identical(derive_atlas_name("lh.aparc.annot"), "aparc")
  })

  it("strips the double extension for gifti and nifti files", {
    expect_identical(derive_atlas_name("schaefer.nii"), "schaefer")
    expect_identical(derive_atlas_name("lh.myatlas.label.gii"), "myatlas")
  })

  it("aborts for missing or non-scalar input", {
    expect_error(derive_atlas_name(character(0)), "single input file")
    expect_error(derive_atlas_name(NA), "single input file")
    expect_error(
      derive_atlas_name(c("a.nii", "b.nii")),
      "single input file"
    )
  })
})


describe("finalize_atlas", {
  it("converts an sf-backed atlas to a polygon atlas", {
    sf_obj <- sf::st_sf(
      label = "test",
      view = "v1",
      geometry = sf::st_sfc(sf::st_polygon(list(matrix(
        c(0, 0, 1, 0, 1, 1, 0, 0),
        ncol = 2,
        byrow = TRUE
      ))))
    )
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "subcortical",
      palette = c(test = "#000000"),
      core = data.frame(
        label = "test",
        region = "test",
        stringsAsFactors = FALSE
      ),
      data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
    )
    expect_true(ggseg.formats::is_atlas_sf(atlas))

    result <- finalize_atlas(
      atlas,
      config = list(cleanup = FALSE, verbose = FALSE, steps = 1L),
      dirs = list(base = withr::local_tempdir()),
      start_time = Sys.time()
    )

    expect_true(ggseg.formats::is_atlas_polygon(result))
  })
})
