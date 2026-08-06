describe("ATLASNAME", {
  it("is a valid ggseg_atlas", {
    expect_s3_class(ATLASNAME(), "ggseg_atlas")
    expect_true(ggseg.formats::is_ggseg_atlas(ATLASNAME()))
  })

  it("renders with ggseg", {
    skip_if_not_installed("ggseg")
    skip_if_not_installed("vdiffr")
    vdiffr::expect_doppelganger(
      "ATLASNAME-2d",
      ggseg::brain_test_plot(ATLASNAME())
    )
  })

  it("renders with ggseg3d", {
    skip_if_not_installed("ggseg3d")
    skip_if_not_installed("ggseg.meshes")
    p <- ggseg3d::ggseg3d(atlas = ATLASNAME())
    expect_s3_class(p, c("plotly", "htmlwidget"))
  })
})
