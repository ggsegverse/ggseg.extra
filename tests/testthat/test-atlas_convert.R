describe("re-exported conversion functions", {
  it("re-exports convert_legacy_brain_atlas from ggseg.formats", {
    expect_identical(
      convert_legacy_brain_atlas,
      ggseg.formats::convert_legacy_brain_atlas
    )
  })
})
