describe("create_cortical_from_annotation on fsaverage5", {
  it("builds the Desikan-Killiany atlas from the shipped aparc annotations", {
    skip_if_no_freesurfer()
    skip_if_not_installed("freesurferformats")

    # Desikan-Killiany is a sensible atlas and no longer trips the vertex
    # warning, which used to fire on 7 shipped atlases in 10.
    expect_no_warning(
      atlas <- create_cortical_from_annotation(
        input_annot = c(
          fsaverage5_file("label", "lh.aparc.annot"),
          fsaverage5_file("label", "rh.aparc.annot")
        ),
        atlas_name = "dk_fsaverage5",
        output_dir = withr::local_tempdir(),
        verbose = FALSE
      )
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(atlas$type, "cortical")
    expect_setequal(unique(atlas$core$hemi), c("left", "right"))
    expect_true(all(
      c("superiorfrontal", "precentral", "insula") %in% atlas$core$region
    ))

    vertices <- ggseg.formats::atlas_vertices(atlas)
    expect_gt(nrow(vertices), 60)
    expect_true(all(lengths(vertices$vertices) > 0))
  })
})

describe("create_subcortical_from_volume on fsaverage5", {
  it("meshes structures from the shipped aseg", {
    skip_if_no_freesurfer()

    structures <- c(
      "Left-Thalamus",
      "Left-Hippocampus",
      "Right-Thalamus",
      "Right-Hippocampus"
    )
    lut <- data.frame(
      idx = c(10L, 17L, 49L, 53L),
      label = structures,
      R = c(0L, 220L, 0L, 220L),
      G = c(118L, 216L, 118L, 216L),
      B = c(14L, 20L, 14L, 20L),
      A = 0L,
      stringsAsFactors = FALSE
    )

    atlas <- create_subcortical_from_volume(
      input_volume = fsaverage5_file("mri", "aseg.mgz"),
      input_lut = lut,
      atlas_name = "aseg_fsaverage5",
      output_dir = withr::local_tempdir(),
      steps = 1:3,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(atlas$type, "subcortical")
    expect_setequal(atlas$core$label, structures)
    meshes <- atlas$data$meshes
    expect_identical(nrow(meshes), 4L)
    for (mesh in meshes$mesh) {
      expect_gt(nrow(mesh$vertices), 0)
      expect_gt(nrow(mesh$faces), 0)
    }
  })
})

describe("create_wholebrain_from_volume on fsaverage5", {
  it("classifies the shipped aseg into cortical, subcortical, and cerebellar", {
    skip_if_no_freesurfer()

    cerebellum <- c("Left-Cerebellum-Cortex", "Right-Cerebellum-Cortex")

    # FreeSurferColorLUT.txt carries no type column, so the pipeline falls
    # back to the vertex count for whatever the explicit vectors leave over.
    result <- NULL
    # The shipped aseg has 31 labels the cortical surface never sees, which
    # the pipeline defaults to subcortical and now says so.
    expect_warning(
      expect_warning(
        result <- create_wholebrain_from_volume(
          input_volume = fsaverage5_file("mri", "aseg.mgz"),
          input_lut = file.path(freesurfer::fs_dir(), "FreeSurferColorLUT.txt"),
          atlas_name = "aseg_fsaverage5",
          output_dir = withr::local_tempdir(),
          projection_opts = list(registration = "header"),
          labels = list(cerebellar = cerebellum),
          steps = 1:2,
          verbose = FALSE
        ),
        "not on the cortical surface"
      ),
      "by surface vertex count"
    )

    expect_true(all(
      c("Left-Cerebral-Cortex", "Right-Cerebral-Cortex") %in%
        result$cortical_labels
    ))
    expect_true(all(
      c("Left-Thalamus", "Left-Hippocampus", "Right-Putamen") %in%
        result$subcortical_labels
    ))
    expect_setequal(result$cerebellar_labels, cerebellum)
  })
})


describe("white matter in a real whole-brain volume", {
  it("draws the aseg's cerebral white matter as backdrop, not as regions", {
    skip_if_no_freesurfer()

    # The shipped aseg is a genuine whole-brain volume and it carries
    # Left-/Right-Cerebral-White-Matter (2, 41). FreeSurferColorLUT.txt has no
    # `type` column, so without one the vertex count calls them cortical --
    # white matter sits under the ribbon and the projection samples through
    # it. Declaring the type is what routes them to the backdrop instead.
    volume <- fsaverage5_file("mri", "aseg.mgz")
    lut <- read_lut(file.path(freesurfer::fs_dir(), "FreeSurferColorLUT.txt"))
    wm <- c("Left-Cerebral-White-Matter", "Right-Cerebral-White-Matter")
    lut$type <- NA_character_
    lut$type[lut$label %in% wm] <- "white_matter"

    lut_file <- withr::local_tempfile(fileext = ".txt")
    write_lut(lut, lut_file)

    result <- NULL
    expect_warning(
      expect_warning(
        result <- create_wholebrain_from_volume(
          input_volume = volume,
          input_lut = lut_file,
          atlas_name = "aseg_wm_fsaverage5",
          output_dir = withr::local_tempdir(),
          projection_opts = list(registration = "header"),
          steps = 1:2,
          verbose = FALSE
        ),
        "not on the cortical surface"
      ),
      "by surface vertex count"
    )

    expect_setequal(result$white_matter_labels, wm)
    expect_false(any(wm %in% result$cortical_labels))
    expect_false(any(wm %in% result$subcortical_labels))
    expect_false(any(wm %in% result$cerebellar_labels))

    # And the backdrop the subcortical sub-atlas is drawn against holds them.
    backdrop <- default_backdrop_labels(
      lut,
      cortical_labels = result$cortical_labels,
      white_matter_labels = result$white_matter_labels
    )
    expect_true(all(wm %in% backdrop))
  })

  it("still calls the aseg's white matter cortical when nothing declares it", {
    skip_if_no_freesurfer()

    # The regression this guards: the same volume and the stock lookup table,
    # which declares nothing. White matter has no type, so the vertex count
    # decides, and it decides wrong. Pinned so the gap cannot quietly close
    # for the wrong reason, or quietly widen.
    result <- NULL
    expect_warning(
      expect_warning(
        result <- create_wholebrain_from_volume(
          input_volume = fsaverage5_file("mri", "aseg.mgz"),
          input_lut = file.path(freesurfer::fs_dir(), "FreeSurferColorLUT.txt"),
          atlas_name = "aseg_nowm_fsaverage5",
          output_dir = withr::local_tempdir(),
          projection_opts = list(registration = "header"),
          steps = 1:2,
          verbose = FALSE
        ),
        "not on the cortical surface"
      ),
      "by surface vertex count"
    )

    expect_identical(result$white_matter_labels, character(0))
    expect_true(
      "Left-Cerebral-White-Matter" %in%
        c(result$cortical_labels, result$subcortical_labels)
    )
  })
})
