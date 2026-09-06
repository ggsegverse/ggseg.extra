describe("atlas_dilate", {
  mk <- function(x, size = 1) {
    sf::st_polygon(list(matrix(
      c(x, 0, x + size, 0, x + size, size, x, size, x, 0),
      ncol = 2,
      byrow = TRUE
    )))
  }
  mk_atlas <- function() {
    geom <- sf::st_sf(
      label = c("cortex", "Left-Thalamus"),
      view = c("coronal_1", "coronal_1"),
      geometry = sf::st_sfc(mk(0, 4), mk(10))
    )
    ggseg.formats::ggseg_atlas(
      atlas = "demo",
      type = "subcortical",
      palette = c("Left-Thalamus" = "#f00"),
      core = data.frame(
        hemi = "left",
        region = "thalamus",
        label = "Left-Thalamus"
      ),
      data = ggseg.formats::ggseg_data_subcortical(geom = geom)
    )
  }
  area_of <- function(atlas, label) {
    g <- ggseg.formats::atlas_geom(atlas)
    as.numeric(sf::st_area(g$geometry[g$label == label]))
  }

  it("grows the regions it is given", {
    out <- atlas_dilate(mk_atlas(), 0.5)
    expect_gt(
      area_of(out, "Left-Thalamus"),
      area_of(mk_atlas(), "Left-Thalamus")
    )
  })

  it("leaves excluded labels untouched", {
    out <- atlas_dilate(mk_atlas(), 0.5, exclude = "^cortex")
    expect_identical(area_of(out, "cortex"), area_of(mk_atlas(), "cortex"))
    expect_gt(
      area_of(out, "Left-Thalamus"),
      area_of(mk_atlas(), "Left-Thalamus")
    )
  })

  it("only touches the labels it is pointed at", {
    out <- atlas_dilate(mk_atlas(), 0.5, labels = "Thalamus")
    expect_identical(area_of(out, "cortex"), area_of(mk_atlas(), "cortex"))
  })

  it("shrinks on a negative amount", {
    out <- atlas_dilate(mk_atlas(), -0.1, labels = "Thalamus")
    expect_lt(
      area_of(out, "Left-Thalamus"),
      area_of(mk_atlas(), "Left-Thalamus")
    )
  })

  it("returns the atlas unchanged for zero", {
    a <- mk_atlas()
    expect_identical(atlas_dilate(a, 0), a)
  })

  it("keeps the representation it was given", {
    poly <- ggseg.formats::as_polygon_atlas(mk_atlas())
    expect_true(ggseg.formats::is_atlas_polygon(atlas_dilate(poly, 0.2)))
    expect_true(ggseg.formats::is_atlas_sf(atlas_dilate(mk_atlas(), 0.2)))
  })

  it("rejects both selectors at once", {
    expect_snapshot(
      atlas_dilate(mk_atlas(), 0.5, labels = "a", exclude = "b"),
      error = TRUE
    )
  })

  it("rejects a non-numeric amount", {
    expect_snapshot(atlas_dilate(mk_atlas(), "lots"), error = TRUE)
  })
})
