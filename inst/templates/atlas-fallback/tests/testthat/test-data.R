describe("ATLASNAME", {
  it("is a valid ggseg_atlas", {
    expect_s3_class(ATLASNAME(), "ggseg_atlas")
    expect_true(ggseg.formats::is_ggseg_atlas(ATLASNAME()))
  })

  it("renders with ggseg", {
    skip_if_not_installed("ggseg")
    skip_if_not_installed("ggplot2")
    skip_if_not_installed("vdiffr")
    p <- ggplot2::ggplot() +
      ggseg::geom_brain(
        atlas = ATLASNAME(),
        mapping = ggplot2::aes(fill = label),
        position = ggseg::position_brain(hemi ~ view),
        show.legend = FALSE
      ) +
      ggplot2::scale_fill_manual(
        values = ATLASNAME()$palette,
        na.value = "grey"
      ) +
      ggplot2::theme_void()
    vdiffr::expect_doppelganger("ATLASNAME-2d", p)
  })

  it("renders with ggseg3d", {
    skip_if_not_installed("ggseg3d")
    skip_if_not_installed("ggseg.meshes")
    p <- ggseg3d::ggseg3d(atlas = ATLASNAME())
    expect_s3_class(p, c("plotly", "htmlwidget"))
  })
})
