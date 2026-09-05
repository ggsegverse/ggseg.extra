describe("post-creation tweaks passed to a pipeline", {
  it("points dilate at atlas_dilate()", {
    lifecycle::expect_deprecated(
      warn_post_creation_args("create_subcortical_from_volume", dilate = 2)
    )
  })

  it("points smoothness at atlas_smooth()", {
    lifecycle::expect_deprecated(
      warn_post_creation_args("create_subcortical_from_volume", smoothness = 1)
    )
  })

  it("points tolerance at atlas_simplify()", {
    lifecycle::expect_deprecated(
      warn_post_creation_args("create_cortical_from_annotation", tolerance = 1)
    )
  })

  it("says nothing when none were given", {
    expect_silent(warn_post_creation_args("create_subcortical_from_volume"))
  })

  it("names the function the caller actually used", {
    expect_snapshot(
      warn_post_creation_args("create_tract_from_tractography", tolerance = 1)
    )
  })
})
