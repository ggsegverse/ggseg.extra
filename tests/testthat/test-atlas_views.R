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

# Empty a view without naming it: take out exactly the regions one view
# draws. Those regions appear in the other views too, so they thin out
# while the chosen view is left drawing nothing but context.
empty_one_view <- function(atlas, view) {
  context <- ggseg.formats::atlas_context(atlas)
  pairs <- view_label_pairs(atlas)
  drawn <- pairs[!pairs$label %in% context, , drop = FALSE]
  labels <- unique(drawn$label[drawn$view == view])

  ggseg.formats::atlas_region_remove(
    atlas,
    paste0("^(", paste(labels, collapse = "|"), ")$"),
    match_on = "label"
  )
}

describe("atlas_view_remove_empty()", {
  it("drops the view that draws nothing and keeps the rest", {
    atlas <- ggseg.formats::aseg()
    views <- ggseg.formats::atlas_views(atlas)
    target <- views[which.min(atlas_view_region_counts(atlas))]
    emptied <- empty_one_view(atlas, target)

    expect_message(
      trimmed <- atlas_view_remove_empty(emptied),
      "Dropping"
    )
    expect_equal(
      ggseg.formats::atlas_views(trimmed),
      setdiff(views, target)
    )
  })

  it("names the view it dropped", {
    atlas <- ggseg.formats::aseg()
    target <- ggseg.formats::atlas_views(atlas)[[
      which.min(atlas_view_region_counts(atlas))
    ]]

    expect_message(
      atlas_view_remove_empty(empty_one_view(atlas, target)),
      target
    )
  })

  it("returns an atlas with no empty view unchanged", {
    atlas <- ggseg.formats::aseg()
    expect_equal(ggseg.formats::atlas_views_empty(atlas), character(0))
    expect_equal(atlas_view_remove_empty(atlas), atlas)
  })

  # Two notions of "empty" live in the ecosystem -- this counts drawn
  # regions per view, ggseg.formats reads core membership. They have to be
  # the same notion, or the reporter and this verb disagree about what they
  # are talking about.
  it("drops exactly the views atlas_view_region_counts() scores zero", {
    atlas <- ggseg.formats::aseg()
    target <- ggseg.formats::atlas_views(atlas)[[
      which.min(atlas_view_region_counts(atlas))
    ]]
    emptied <- empty_one_view(atlas, target)

    counts <- atlas_view_region_counts(emptied)
    expect_setequal(
      ggseg.formats::atlas_views_empty(emptied),
      names(counts)[counts == 0L]
    )
  })

  it("agrees with the zero case of atlas_view_remove_sparse()", {
    atlas <- ggseg.formats::aseg()
    target <- ggseg.formats::atlas_views(atlas)[[
      which.min(atlas_view_region_counts(atlas))
    ]]
    emptied <- empty_one_view(atlas, target)

    expect_message(by_empty <- atlas_view_remove_empty(emptied), "Dropping")
    expect_message(
      by_threshold <- atlas_view_remove_sparse(emptied, min_regions = 1),
      "Dropping"
    )
    expect_equal(
      ggseg.formats::atlas_views(by_empty),
      ggseg.formats::atlas_views(by_threshold)
    )
  })

  it("reads polygon and sf geometry the same way", {
    atlas <- ggseg.formats::aseg()
    target <- ggseg.formats::atlas_views(atlas)[[
      which.min(atlas_view_region_counts(atlas))
    ]]
    emptied <- empty_one_view(atlas, target)
    expect_true(ggseg.formats::is_atlas_polygon(emptied))

    expect_message(from_poly <- atlas_view_remove_empty(emptied), "Dropping")
    expect_message(
      from_sf <- atlas_view_remove_empty(ggseg.formats::as_sf_atlas(emptied)),
      "Dropping"
    )

    expect_true(ggseg.formats::is_atlas_polygon(from_poly))
    expect_equal(
      ggseg.formats::atlas_views(from_poly),
      ggseg.formats::atlas_views(from_sf)
    )
  })

  it("errors rather than returning an atlas with no views left", {
    # Contextual, not removed: the geometry survives and keeps drawing, so
    # every view still exists and every one of them draws no *region*.
    # Removing the regions outright takes their geometry with them and
    # leaves no view to be empty in the first place.
    all_context <- ggseg.formats::atlas_region_contextual(
      ggseg.formats::aseg(),
      ".",
      match_on = "label"
    )
    expect_setequal(
      ggseg.formats::atlas_views_empty(all_context),
      ggseg.formats::atlas_views(all_context)
    )

    expect_error(
      atlas_view_remove_empty(all_context),
      "no view at all"
    )
  })

  it("warns and returns the atlas when there is no 2D geometry", {
    atlas <- ggseg.formats::aseg()
    atlas$data$geom <- NULL

    expect_warning(
      unchanged <- atlas_view_remove_empty(atlas),
      "no 2D geometry"
    )
    expect_equal(unchanged, atlas)
  })
})
