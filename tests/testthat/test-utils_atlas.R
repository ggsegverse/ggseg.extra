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

  it("reads lh and rh as tokens, not as letters inside a word", {
    expect_identical(detect_hemi("ctx-lh-entorhinal"), "left")
    expect_identical(detect_hemi("7Networks_RH_Vis_1"), "right")
    expect_true(is.na(detect_hemi("Entorhinal")))
    expect_true(is.na(detect_hemi("Alhambra")))
  })

  it("handles NA and empty input", {
    expect_true(is.na(detect_hemi(NA)))
    expect_true(is.na(detect_hemi("")))
  })
})


describe("check_lut_hemi", {
  it("names the values that are not a hemisphere", {
    lut <- data.frame(
      idx = 1:5,
      label = c("A", "B", "C", "D", "E"),
      hemi = c("rigth", "both", "LH", NA, "")
    )
    expect_snapshot(check_lut_hemi(lut), error = TRUE)
  })

  it("checks a lookup table file as it does a data frame", {
    lut <- data.frame(
      idx = 1L,
      label = "A",
      R = 1L,
      G = 2L,
      B = 3L,
      A = 0L,
      hemi = "rigth"
    )
    path <- withr::local_tempfile(fileext = ".txt")
    write_lut(lut, path)

    expect_error(check_lut_hemi(path), "unrecognised")
  })

  it("accepts every spelling normalise_hemi() reads, and undeclared rows", {
    spellings <- c("left", "lh", "L", "Right", "rh", "r", "midline", "vermis")
    lut <- data.frame(hemi = c(spellings, NA, ""))
    expect_no_error(check_lut_hemi(lut))
    expect_no_error(check_lut_hemi(data.frame(idx = 1L)))
    expect_false(anyNA(vapply(spellings, normalise_hemi, character(1))))
  })
})


describe("lut_hemi", {
  it("takes a declared hemisphere over what the name says", {
    row <- data.frame(label = "Left-Thalamus", hemi = "rh")
    expect_identical(lut_hemi(row, row$label), "right")
  })

  it("falls back to the name for a row that declares nothing", {
    row <- data.frame(label = "Left-Thalamus", hemi = NA_character_)
    expect_identical(lut_hemi(row, row$label), detect_hemi(row$label))
    expect_identical(
      lut_hemi(data.frame(label = "Left-Thalamus"), "Left-Thalamus"),
      detect_hemi("Left-Thalamus")
    )
  })

  it("reads the name with the reader it is given", {
    row <- data.frame(label = "Vermis_VI")
    expect_identical(
      lut_hemi(row, row$label, from_name = detect_cerebellar_hemi),
      detect_cerebellar_hemi(row$label)
    )
  })
})


describe("label_to_region", {
  it("flattens every separator a build script might key on", {
    # A script keying a `name` column on `region` has to key on what the
    # pipeline derives. Handling underscores but not hyphens is how one
    # region silently joins to NA.
    expect_identical(
      label_to_region("Central_Lateral-Lateral_Posterior-Medial_Pulvinar_Left"),
      "central lateral lateral posterior medial pulvinar"
    )
    expect_identical(
      label_to_region("Ventral_Anterior_Right"),
      "ventral anterior"
    )
    expect_identical(label_to_region("SNc_PBP_VTA_Right"), "snc pbp vta")
  })

  it("is vectorised over labels", {
    expect_identical(
      label_to_region(c("Pu_Left", "Pu_Right", "AV_Left")),
      c("pu", "pu", "av")
    )
  })

  it("removes hemisphere prefix and normalizes", {
    expect_identical(label_to_region("Left-Thalamus"), "thalamus")
    expect_identical(label_to_region("right_Amygdala"), "amygdala")
    expect_identical(
      label_to_region("lh.superior_frontal"),
      "superior frontal"
    )
  })

  it("converts underscores and dashes to spaces", {
    expect_identical(label_to_region("superior_frontal"), "superior frontal")
    expect_identical(label_to_region("pre-central"), "pre central")
  })

  it("can skip hemisphere removal", {
    expect_identical(
      label_to_region("Left-Thalamus", remove_hemi = FALSE),
      "left thalamus"
    )
  })

  it("can skip normalization", {
    expect_identical(
      label_to_region("Left-Thalamus", normalize = FALSE),
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
        grepl("(^|\\s)(left|right|lh|rh|l|r)(\\s|$)", label_to_region(label)),
        info = paste("hemisphere left in region for", label)
      )
    }
  })

  it("pairs the hemispheres of a structure on region", {
    expect_identical(
      label_to_region("L_Fx"),
      label_to_region("R_Fx")
    )
    expect_identical(
      label_to_region("Fx_L"),
      label_to_region("Fx_R")
    )
    expect_identical(
      label_to_region("Area_5L_SPL_left"),
      label_to_region("Area_5L_SPL_right")
    )
  })

  it("keeps a name that is only a hemisphere word", {
    expect_identical(label_to_region("left"), "left")
  })

  it("does not strip a leading letter that is not an affix", {
    expect_identical(
      label_to_region("Rolandic_operculum"),
      "rolandic operculum"
    )
    expect_identical(label_to_region("Lingual"), "lingual")
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
    dirs <- setup_atlas_dirs(tmp, atlas_name = "test_atlas", type = "cortical")

    expect_true(dir.exists(dirs$base))
    expect_true(dir.exists(dirs$snapshots))
    # processed/ and masks/ went with the PNG round-trip
    expect_null(dirs$processed)
    expect_null(dirs$masks)
  })

  it("creates additional dirs for subcortical type", {
    tmp <- withr::local_tempdir()
    dirs <- setup_atlas_dirs(
      tmp,
      atlas_name = "test_subcort",
      type = "subcortical"
    )

    expect_true(dir.exists(dirs$meshes))
  })

  it("handles existing directories without error", {
    tmp <- withr::local_tempdir()
    dirs1 <- setup_atlas_dirs(tmp, atlas_name = "test_atlas")

    expect_no_error({
      dirs2 <- setup_atlas_dirs(tmp, atlas_name = "test_atlas")
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

  it("drops the compression suffix along with the format's", {
    expect_identical(derive_atlas_name("/data/thalamus.nii.gz"), "thalamus")
    expect_identical(derive_atlas_name("/data/thalamus.nii"), "thalamus")
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


describe("setup_atlas_dirs working directory safety", {
  it("rejects an atlas name that is not one directory name", {
    output_dir <- withr::local_tempdir()

    expect_snapshot(setup_atlas_dirs(output_dir, atlas_name = ""), error = TRUE)
    for (unusable in list("..", ".", "a/b", "a\\b", " ", NA_character_)) {
      expect_error(
        setup_atlas_dirs(output_dir, atlas_name = unusable),
        "must be a single name"
      )
    }
  })

  it("aborts before building when cleanup would remove someone's files", {
    output_dir <- withr::local_tempdir()
    sources <- file.path(output_dir, "dkt")
    dir.create(sources)
    file.create(file.path(sources, "lh.dkt.annot"))

    expect_error(
      setup_atlas_dirs(output_dir, atlas_name = "dkt", cleanup = TRUE),
      "already holds files this build did not write"
    )
    expect_identical(
      list.files(sources, all.files = TRUE, no.. = TRUE),
      "lh.dkt.annot"
    )
  })

  it("builds in a directory holding other files when cleanup is off", {
    output_dir <- withr::local_tempdir()
    sources <- file.path(output_dir, "dkt")
    dir.create(sources)
    file.create(file.path(sources, "lh.dkt.annot"))

    dirs <- setup_atlas_dirs(output_dir, atlas_name = "dkt", cleanup = FALSE)

    expect_true(dir.exists(dirs$snapshots))
    expect_true(file.exists(file.path(sources, "lh.dkt.annot")))
  })

  it("reuses the working directory an earlier build left behind", {
    output_dir <- withr::local_tempdir()
    first <- setup_atlas_dirs(output_dir, atlas_name = "dkt", cleanup = TRUE)
    file.create(file.path(first$base, "step1.rds"))

    expect_no_error(
      setup_atlas_dirs(output_dir, atlas_name = "dkt", cleanup = TRUE)
    )
  })

  it("recognises a working directory from before the marker by its manifest", {
    output_dir <- withr::local_tempdir()
    legacy <- file.path(output_dir, "dkt")
    dir.create(legacy)
    file.create(file.path(legacy, cache_manifest_name))
    file.create(file.path(legacy, "step1.rds"))

    expect_false(holds_foreign_files(legacy))
  })
})


describe("remove_working_dir", {
  it("removes a directory the build marked as its own", {
    work <- mark_working_dir(file.path(withr::local_tempdir(), "work"))
    file.create(file.path(work, "step1.rds"))

    expect_true(remove_working_dir(work))
    expect_false(dir.exists(work))
  })

  it("keeps a directory holding files no build wrote, and says so", {
    sources <- withr::local_tempdir()
    file.create(file.path(sources, "lh.dkt.annot"))

    expect_warning(
      removed <- remove_working_dir(sources),
      "holds files this build did not write"
    )
    expect_false(removed)
    expect_true(file.exists(file.path(sources, "lh.dkt.annot")))
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

  it("clears the nested working directories when cleanup is TRUE", {
    dirs <- setup_atlas_dirs(
      withr::local_tempdir(),
      atlas_name = "test_atlas",
      type = "subcortical"
    )
    file.create(file.path(dirs$snapshots, "view.rda"))
    file.create(file.path(dirs$meshes, "0010_smooth"))

    finalize_atlas(
      NULL,
      config = list(cleanup = TRUE, verbose = FALSE, steps = 1L),
      dirs = dirs,
      start_time = Sys.time()
    )

    # One recursive unlink() of base is the whole cleanup, which only works
    # because setup_atlas_dirs() nests the others inside it.
    expect_false(dir.exists(dirs$base))
    expect_false(dir.exists(dirs$snapshots))
    expect_false(dir.exists(dirs$meshes))
  })
})


describe("lut_names", {
  it("uses the name the lookup table gives", {
    row <- data.frame(idx = 10L, label = "Left-Thalamus", names = "Thalamus")

    expect_identical(lut_names(row, "thalamus"), "Thalamus")
  })

  it("falls back to the region when the table gives none", {
    blank <- data.frame(idx = 10L, label = "Left-Thalamus", names = " ")
    missing <- data.frame(idx = 10L, label = "Left-Thalamus", names = NA)
    no_column <- data.frame(idx = 10L, label = "Left-Thalamus")

    expect_identical(lut_names(blank, "thalamus"), "thalamus")
    expect_identical(lut_names(missing, "thalamus"), "thalamus")
    expect_identical(lut_names(no_column, "thalamus"), "thalamus")
    expect_identical(lut_names(no_column[0, ], "thalamus"), "thalamus")
  })
})


describe("core_with_names", {
  core <- data.frame(
    hemi = c("left", "right"),
    region = c("thalamus", "amygdala"),
    label = c("Left-Thalamus", "Right-Amygdala")
  )

  it("names every row after its region when there are no names", {
    expect_identical(core_with_names(core)$names, c("thalamus", "amygdala"))
  })

  it("keeps the names it is given and fills only the gaps", {
    partly <- transform(core, names = c("Thalamus proper", NA))

    expect_identical(
      core_with_names(partly)$names,
      c("Thalamus proper", "amygdala")
    )
  })

  it("always returns a character column", {
    numbered <- transform(core, names = c(1, 2))

    expect_type(core_with_names(numbered)$names, "character")
  })
})


describe("lut_context_values", {
  it("reads the usual spellings of yes and no, from a file or a data frame", {
    expect_identical(
      lut_context_values(c("TRUE", "false", "yes", "No", "1", "0", NA, "")),
      c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, NA, NA)
    )
    expect_identical(lut_context_values(c(TRUE, NA)), c(TRUE, NA))
  })

  it("aborts on a value that is neither", {
    expect_snapshot(lut_context_values(c("TRUE", "backdrop")), error = TRUE)
  })
})


describe("lut_is_context", {
  it("is true only for the rows the table marks", {
    lut <- data.frame(idx = 1:3, context = c(TRUE, FALSE, NA))

    expect_identical(lut_is_context(lut), c(TRUE, FALSE, FALSE))
  })

  it("is false throughout for a table without the column", {
    expect_identical(lut_is_context(data.frame(idx = 1:2)), c(FALSE, FALSE))
  })
})


describe("context_pattern for one atlas", {
  it("matches that atlas's context shapes and none of its regions", {
    atlas <- ggseg.formats::atlas_region_contextual(
      ggseg.formats::aseg(),
      "Thalamus",
      match_on = "label"
    )
    pattern <- context_pattern(atlas)

    expect_true(all(grepl(pattern, c("Left-Thalamus", "Right-Thalamus"))))
    expect_false(any(grepl(pattern, atlas$core$label)))
  })

  it("matches nothing when the atlas draws no context", {
    atlas <- ggseg.formats::atlas_context_remove(ggseg.formats::dk())

    expect_false(any(grepl(context_pattern(atlas), atlas$core$label)))
  })

  it("rejects what is not an atlas", {
    expect_error(context_pattern("dk"), "must be a")
  })
})


describe("context_pattern", {
  it("matches the silhouette labels the volumetric pipelines produce", {
    expect_true(all(grepl(
      context_pattern(),
      c("cortex", "cortex_", "cortex_left", "cortex_right")
    )))
  })

  it("matches the backdrops the surface pipelines generate", {
    expect_true(all(grepl(
      context_pattern(),
      c("lh_cortex", "rh_cortex", "cerebellum")
    )))
  })

  # A parcellation's own medial wall is demoted to backdrop during the build,
  # so from a plotting point of view it is the same thing as a generated one.
  # While the pattern missed it, `exclude = context_pattern()` protected
  # nothing on an annotation atlas.
  it("matches the backdrops a parcellation carries", {
    expect_true(all(grepl(
      context_pattern(),
      c(
        "lh_FreeSurfer_Defined_Medial_Wall",
        "rh_Medial_Wall",
        "lh_unknown",
        "lh_???"
      ),
      ignore.case = TRUE
    )))
  })

  it("does not match structures that merely have cortex in the name", {
    expect_false(any(grepl(
      context_pattern(),
      c(
        "Cerebellar_Cortex_left",
        "Left-Cerebral-Cortex",
        "ctx-lh-cuneus",
        "Left-Cerebellum-Cortex",
        "lh_unknown_gyrus",
        "left_I-IV"
      ),
      ignore.case = TRUE
    )))
  })
})


describe("validate_steps", {
  it("returns all steps when NULL", {
    expect_identical(validate_steps(NULL, 3L), 1:3)
  })

  it("accepts whole numbers in range", {
    expect_identical(validate_steps(c(1, 3), 3L), c(1L, 3L))
  })

  it("refuses a fractional step rather than truncating it", {
    expect_error(validate_steps(2.9, 3L), "whole numbers between 1 and 3")
  })

  it("refuses a character step rather than coercing it", {
    expect_error(validate_steps("2", 3L), "whole numbers between 1 and 3")
  })

  it("refuses steps outside the range", {
    expect_error(validate_steps(0, 3L), "whole numbers")
    expect_error(validate_steps(4, 3L), "whole numbers")
    expect_error(validate_steps(NA, 3L), "whole numbers")
  })
})


describe("resolve_opts", {
  it("keeps an entry the caller explicitly set to NULL as NULL", {
    # modifyList drops a NULL rather than storing one, so the entry is absent
    # rather than NULL -- which reads back as NULL and is what the caller
    # asked for. Pinned because the two routes to NULL are not obviously the
    # same, and `projfrac_range = NULL` is a documented way to switch off
    # multi-depth sampling.
    out <- resolve_opts(
      list(b = NULL),
      "opts",
      list(a = 1, b = c(0, 1, 0.1))
    )

    expect_null(out$b)
    expect_identical(out$a, 1)
  })

  it("fills unset entries from the defaults", {
    out <- resolve_opts(list(a = 9), "opts", list(a = 1, b = 2))

    expect_identical(out$a, 9)
    expect_identical(out$b, 2)
  })
})


describe("drop_labels_without_geometry", {
  make_components <- function() {
    list(
      core = data.frame(
        hemi = c("left", "right"),
        region = c("a", "b"),
        label = c("region_a", "region_b"),
        stringsAsFactors = FALSE
      ),
      palette = c(region_a = "#FF0000", region_b = "#00FF00"),
      meshes_df = tibble(
        label = c("region_a", "region_b"),
        mesh = list(NULL, NULL)
      ),
      vertices_df = tibble(
        label = c("region_a", "region_b"),
        vertices = list(0:4, 5:9)
      ),
      vol_idx = c(region_a = 10L, region_b = 11L)
    )
  }
  drawn <- function(...) {
    data.frame(stringsAsFactors = FALSE, label = c(...))
  }

  it("drops a label the geometry does not have, and names it", {
    expect_warning(
      result <- drop_labels_without_geometry(
        make_components(),
        drawn("region_a", NA)
      ),
      "region_b"
    )
    expect_identical(result$core$label, "region_a")
  })

  it("prunes every label-keyed field together", {
    # A palette entry or mesh left behind for a dropped region is the same
    # inconsistency in a new place.
    suppressWarnings(
      result <- drop_labels_without_geometry(
        make_components(),
        drawn("region_a")
      )
    )

    expect_named(result$palette, "region_a")
    expect_identical(result$meshes_df$label, "region_a")
    expect_identical(result$vertices_df$label, "region_a")
    expect_named(result$vol_idx, "region_a")
  })

  it("keeps everything and stays quiet when all labels have geometry", {
    expect_no_warning(
      result <- drop_labels_without_geometry(
        make_components(),
        drawn("region_a", "region_b")
      )
    )
    expect_setequal(result$core$label, c("region_a", "region_b"))
  })

  it("tolerates components carrying only core and palette", {
    bare <- make_components()
    bare$meshes_df <- NULL
    bare$vertices_df <- NULL
    bare$vol_idx <- NULL

    suppressWarnings(
      result <- drop_labels_without_geometry(bare, drawn("region_a"))
    )

    expect_identical(result$core$label, "region_a")
    expect_null(result$meshes_df)
  })

  it("tolerates an atlas built without a palette", {
    none <- make_components()
    none$palette <- NULL

    suppressWarnings(
      result <- drop_labels_without_geometry(none, drawn("region_a"))
    )

    expect_null(result$palette)
  })

  it("aborts rather than build an atlas with no drawable region", {
    expect_snapshot(
      drop_labels_without_geometry(make_components(), NULL),
      error = TRUE
    )
  })
})
