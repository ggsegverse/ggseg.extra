describe("create_cortical_from_annotation on fsaverage5", {
  it("builds the Desikan-Killiany atlas from the shipped aparc annotations", {
    skip_if_no_freesurfer()
    skip_if_not_installed("freesurferformats")

    expect_warning(
      atlas <- create_cortical_from_annotation(
        input_annot = c(
          fsaverage5_file("label", "lh.aparc.annot"),
          fsaverage5_file("label", "rh.aparc.annot")
        ),
        atlas_name = "dk_fsaverage5",
        output_dir = withr::local_tempdir(),
        verbose = FALSE
      ),
      "Large atlases"
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
    expect_warning(
      result <- create_wholebrain_from_volume(
        input_volume = fsaverage5_file("mri", "aseg.mgz"),
        input_lut = file.path(freesurfer::fs_dir(), "FreeSurferColorLUT.txt"),
        atlas_name = "aseg_fsaverage5",
        output_dir = withr::local_tempdir(),
        registration = "header",
        cerebellar_labels = cerebellum,
        steps = 1:2,
        verbose = FALSE
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
