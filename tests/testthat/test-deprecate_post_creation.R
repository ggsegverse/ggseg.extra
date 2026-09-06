describe("post-creation tweaks passed to a pipeline", {
  it("points dilate at atlas_dilate()", {
    lifecycle::expect_deprecated(
      check_post_creation_dots("create_subcortical_from_volume", dilate = 2)
    )
  })

  it("points smoothness at atlas_smooth()", {
    lifecycle::expect_deprecated(
      check_post_creation_dots("create_subcortical_from_volume", smoothness = 1)
    )
  })

  it("points tolerance at atlas_simplify()", {
    lifecycle::expect_deprecated(
      check_post_creation_dots("create_cortical_from_annotation", tolerance = 1)
    )
  })

  it("hands the values back so a caller can still honour them", {
    dots <- suppressWarnings(
      check_post_creation_dots("create_subcortical_from_volume", dilate = 2L)
    )
    expect_identical(dots$dilate, 2L)
  })

  it("says nothing when dots are empty", {
    expect_silent(check_post_creation_dots("create_subcortical_from_volume"))
  })

  it("still errors on a typo, as an unused argument always did", {
    expect_snapshot(
      check_post_creation_dots(
        "create_subcortical_from_volume",
        toolerance = 1
      ),
      error = TRUE
    )
  })

  it("errors on an unnamed extra argument", {
    expect_snapshot(
      check_post_creation_dots("create_subcortical_from_volume", 42),
      error = TRUE
    )
  })

  it("names the function the caller actually used", {
    expect_snapshot(
      check_post_creation_dots("create_tract_from_tractography", tolerance = 1)
    )
  })
})
