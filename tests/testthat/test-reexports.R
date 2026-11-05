describe("re-exported ggseg.formats API (ggsegverse/ggseg#183)", {
  deprecated <- c(
    "as_brain_atlas",
    "brain_atlas",
    "brain_data_cortical",
    "brain_data_subcortical",
    "brain_data_tract",
    "brain_labels",
    "brain_regions",
    "brain_views",
    "is_brain_atlas",
    "unify_legacy_atlases"
  )
  formats_api <- setdiff(getNamespaceExports("ggseg.formats"), deprecated)

  it("covers every non-deprecated ggseg.formats export", {
    expect_in(formats_api, getNamespaceExports("ggseg.extra"))
  })

  it("re-exports the ggseg.formats objects themselves, not copies", {
    for (name in formats_api) {
      expect_identical(
        getExportedValue("ggseg.extra", name),
        getExportedValue("ggseg.formats", name),
        label = name
      )
    }
  })

  it("leaves the deprecated functions in ggseg.formats", {
    expect_false(any(deprecated %in% getNamespaceExports("ggseg.extra")))
  })
})
