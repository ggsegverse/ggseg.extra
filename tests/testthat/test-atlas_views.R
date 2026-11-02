describe("atlas_view_region_counts()", {
  it("counts the distinct regions in each view", {
    counts <- atlas_view_region_counts(ggseg.formats::aseg())

    expect_named(counts, ggseg.formats::atlas_views(ggseg.formats::aseg()))
    expect_type(counts, "integer")
    expect_true(all(counts > 0))
  })

  it("does not count context towards a view's regions", {
    atlas <- ggseg.formats::aseg()
    context <- ggseg.formats::atlas_context(atlas)
    expect_true(length(context) > 0)

    pairs <- view_label_pairs(atlas)
    with_context <- tapply(pairs$label, pairs$view, function(x) {
      length(unique(x))
    })
    without <- atlas_view_region_counts(atlas)

    expect_true(all(without < with_context[names(without)]))
  })

  it("reads polygon and sf geometry the same way", {
    atlas <- ggseg.formats::aseg()
    expect_true(ggseg.formats::is_atlas_polygon(atlas))

    expect_equal(
      atlas_view_region_counts(atlas),
      atlas_view_region_counts(ggseg.formats::as_sf_atlas(atlas))
    )
  })
})

describe("atlas_view_remove_sparse()", {
  it("drops the views below the threshold and keeps the rest", {
    atlas <- ggseg.formats::aseg()
    counts <- atlas_view_region_counts(atlas)
    cutoff <- min(counts) + 1L

    expect_message(
      trimmed <- atlas_view_remove_sparse(atlas, min_regions = cutoff),
      "Dropping"
    )

    expect_equal(
      ggseg.formats::atlas_views(trimmed),
      names(counts)[counts >= cutoff]
    )
  })

  it("keeps a view holding exactly min_regions", {
    atlas <- ggseg.formats::aseg()
    counts <- atlas_view_region_counts(atlas)

    expect_equal(
      atlas_view_remove_sparse(atlas, min_regions = min(counts)),
      atlas
    )
  })

  it("returns the atlas untouched when every view is full enough", {
    atlas <- ggseg.formats::aseg()
    expect_equal(atlas_view_remove_sparse(atlas, min_regions = 0), atlas)
  })

  it("keeps the representation it was given", {
    atlas <- ggseg.formats::aseg()
    cutoff <- min(atlas_view_region_counts(atlas)) + 1L

    expect_message(
      trimmed <- atlas_view_remove_sparse(atlas, min_regions = cutoff)
    )
    expect_true(ggseg.formats::is_atlas_polygon(trimmed))
  })

  it("errors rather than returning an atlas with no views left", {
    atlas <- ggseg.formats::aseg()
    too_many <- max(atlas_view_region_counts(atlas)) + 1L

    expect_error(
      atlas_view_remove_sparse(atlas, min_regions = too_many),
      "would drop every view"
    )
  })

  it("rejects a min_regions that is not a single non-negative number", {
    atlas <- ggseg.formats::aseg()

    expect_error(atlas_view_remove_sparse(atlas, "five"), "non-negative")
    expect_error(atlas_view_remove_sparse(atlas, c(1, 2)), "non-negative")
    expect_error(atlas_view_remove_sparse(atlas, -1), "non-negative")
    expect_error(atlas_view_remove_sparse(atlas, NA_real_), "non-negative")
  })

  it("warns and returns the atlas when there is no 2D geometry", {
    atlas <- ggseg.formats::aseg()
    atlas$data$geom <- NULL

    expect_warning(
      unchanged <- atlas_view_remove_sparse(atlas),
      "no 2D geometry"
    )
    expect_equal(unchanged, atlas)
  })
})
