describe("check_unused_dots", {
  it("accepts no dots", {
    expect_no_error(check_unused_dots("create_cortical_from_annotation"))
  })

  it("names a single unknown argument and the function it reached", {
    expect_error(
      check_unused_dots("create_cortical_from_annotation", tolerance = 0.1),
      "1 unused argument passed to"
    )
    expect_error(
      check_unused_dots("create_cortical_from_annotation", tolerance = 0.1),
      "tolerance"
    )
  })

  it("counts and pluralises several unknown arguments", {
    expect_error(
      check_unused_dots("f", tolerance = 1, smoothness = 2),
      "2 unused arguments passed to"
    )
  })

  it("counts unnamed arguments rather than collapsing them to one", {
    expect_error(check_unused_dots("f", 1, 2, 3), "3 unnamed arguments")
  })

  it("counts named and unnamed together", {
    expect_error(check_unused_dots("f", 1, dilate = 2), "2 unused arguments")
  })

  it("rejects the post-creation tweaks that used to be absorbed", {
    for (arg in c("dilate", "smoothness", "tolerance", "smooth_refinements")) {
      args <- list("create_cortical_from_annotation", 1)
      names(args) <- c("fn", arg)
      expect_error(do.call(check_unused_dots, args), "unused argument")
    }
  })
})
