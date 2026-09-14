fsaverage5_file <- function(...) {
  file.path(freesurfer::fs_subj_dir(), "fsaverage5", ...)
}

write_lut <- function(path, idx, label, colour) {
  rgb <- grDevices::col2rgb(colour)
  writeLines(
    sprintf("%d %s %d %d %d 0", idx, label, rgb[1, ], rgb[2, ], rgb[3, ]),
    path
  )
  path
}

testthat::describe("create_cortical_from_annotation on fsaverage5", {
  it("builds the Desikan-Killiany atlas from the shipped aparc annotations", {
    skip_if_no_freesurfer()
    skip_if_not_installed("freesurferformats")

    annots <- c(
      fsaverage5_file("label", "lh.aparc.annot"),
      fsaverage5_file("label", "rh.aparc.annot")
    )
    expect_true(all(file.exists(annots)))

    expect_warning(
      atlas <- create_cortical_from_annotation(
        input_annot = annots,
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

testthat::describe("create_subcortical_from_volume on fsaverage5", {
  it("meshes structures from the shipped aseg", {
    skip_if_no_freesurfer()

    aseg <- fsaverage5_file("mri", "aseg.mgz")
    expect_true(file.exists(aseg))
    lut <- write_lut(
      withr::local_tempfile(fileext = ".txt"),
      idx = c(10L, 17L, 49L, 53L),
      label = c(
        "Left-Thalamus",
        "Left-Hippocampus",
        "Right-Thalamus",
        "Right-Hippocampus"
      ),
      colour = c("#00760E", "#DCD814", "#00760E", "#DCD814")
    )

    atlas <- create_subcortical_from_volume(
      input_volume = aseg,
      input_lut = lut,
      atlas_name = "aseg_fsaverage5",
      output_dir = withr::local_tempdir(),
      steps = 1:3,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(atlas$type, "subcortical")
    expect_setequal(
      atlas$core$label,
      c(
        "Left-Thalamus",
        "Left-Hippocampus",
        "Right-Thalamus",
        "Right-Hippocampus"
      )
    )
    meshes <- atlas$data$meshes
    expect_identical(nrow(meshes), 4L)
    for (mesh in meshes$mesh) {
      expect_gt(nrow(mesh$vertices), 0)
      expect_gt(nrow(mesh$faces), 0)
    }
  })
})

testthat::describe("create_wholebrain_from_volume on fsaverage5", {
  it("classifies the shipped aseg into cortical, subcortical, and cerebellar", {
    skip_if_no_freesurfer()

    volume <- fsaverage5_file("mri", "aseg.mgz")
    expect_true(file.exists(volume))
    lut <- file.path(freesurfer::fs_dir(), "FreeSurferColorLUT.txt")
    expect_true(file.exists(lut))

    cerebellum <- c("Left-Cerebellum-Cortex", "Right-Cerebellum-Cortex")

    result <- create_wholebrain_from_volume(
      input_volume = volume,
      input_lut = lut,
      atlas_name = "aseg_fsaverage5",
      output_dir = withr::local_tempdir(),
      registration = "header",
      cerebellar_labels = cerebellum,
      steps = 1:2,
      verbose = FALSE
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
