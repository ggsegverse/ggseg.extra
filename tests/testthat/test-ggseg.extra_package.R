describe("package integrity", {
  it("has a non-empty package name in its DESCRIPTION", {
    expect_true(nzchar(utils::packageDescription("ggseg.extra")$Package))
  })

  it("exposes its key exported creators as functions", {
    exported <- c(
      "create_cortical_from_gifti",
      "create_cerebellar_from_gifti",
      "create_subcortical_from_volume",
      "create_tract_from_tractography",
      "coregister_volume"
    )

    for (fn in exported) {
      expect_true(exists(fn), info = fn)
      expect_true(is.function(get(fn)), info = fn)
    }
  })
})
