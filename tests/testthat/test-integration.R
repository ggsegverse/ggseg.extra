describe("integration tests", {
  it("creates atlas from labels and renders with ggseg3d", {
    skip_render_on_windows()
    skip_if_not_installed("freesurferformats")

    labels <- unlist(test_label_files())
    atlas <- create_cortical_from_labels(
      labels,
      atlas_name = "integration_test",
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_identical(nrow(atlas$core), 3L)

    expect_no_error({
      p <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = "left")
    })
  })

  it("creates atlas from annotation and renders with ggseg3d", {
    skip_render_on_windows()
    skip_if_not_installed("freesurferformats")

    annots <- test_annot_files()
    annot_files <- c(annots$lh, annots$rh)

    atlas <- create_cortical_from_annotation(
      input_annot = annot_files,
      verbose = FALSE
    )

    expect_s3_class(atlas, "ggseg_atlas")
    expect_gt(nrow(atlas$core), 0)

    expect_no_error({
      p <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = "left")
    })
  })

  it("reads colortable files", {
    lut_file <- test_lut_file()
    skip_if(!file.exists(lut_file), "Test LUT file not found")

    ctab <- read_ctab(lut_file)

    expect_s3_class(ctab, "data.frame")
    expect_true(all(c("idx", "label", "R", "G", "B", "A") %in% names(ctab)))
    expect_identical(nrow(ctab), 5L)
  })

  it("test data files exist", {
    labels <- test_label_files()
    expect_true(all(file.exists(unlist(labels))))

    mgz <- test_mgz_file()
    expect_true(file.exists(mgz))

    lut <- test_lut_file()
    expect_true(file.exists(lut))
  })
})
