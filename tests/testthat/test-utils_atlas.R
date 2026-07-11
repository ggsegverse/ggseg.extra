describe("detect_hemi", {
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


describe("detect_hemi_vec", {
  it("works on vectors", {
    labels <- c("Left-Thalamus", "Right-Amygdala", "brainstem")
    result <- detect_hemi_vec(labels)
    expect_identical(result, c("left", "right", NA_character_))
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


describe("clean_region_names", {
  it("works on vectors", {
    labels <- c("Left-Thalamus", "right_Amygdala", "lh.superior_frontal")
    result <- clean_region_names(labels)
    expect_identical(result, c("thalamus", "amygdala", "superior frontal"))
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
    expect_identical(dirs$snapshots, file.path(tmp, "snapshots"))
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

  it("auto-generates colours when all are NA", {
    atlas_data <- data.frame(
      hemi = c("left", "right"),
      region = c("motor", "visual"),
      label = c("lh_motor", "rh_visual"),
      colour = c(NA_character_, NA_character_),
      stringsAsFactors = FALSE
    )
    atlas_data$vertices <- list(c(1L, 2L), c(3L, 4L))

    result <- build_atlas_components(atlas_data)

    expect_false(is.null(result$palette))
    expect_length(result$palette, 2)
    expect_true(all(grepl("^#", result$palette)))
  })

  it("auto-generates colours for NA entries while keeping existing ones", {
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
    expect_true(grepl("^#", result$palette[["lh_visual"]]))
    expect_false(is.na(result$palette[["lh_visual"]]))
  })

  it("does not generate colour for unknown label", {
    atlas_data <- data.frame(
      hemi = c("left", "left"),
      region = c("unknown", "motor"),
      label = c("unknown", "lh_motor"),
      colour = c(NA_character_, NA_character_),
      stringsAsFactors = FALSE
    )
    atlas_data$vertices <- list(1L, c(2L, 3L))

    result <- build_atlas_components(atlas_data)

    expect_true(is.na(result$palette[["unknown"]]))
    expect_true(grepl("^#", result$palette[["lh_motor"]]))
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
