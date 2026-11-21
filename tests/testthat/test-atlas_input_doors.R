# An atlas reaches these verbs in one of three representations: the S7 object
# this release builds, the plain tagged list every atlas package published
# before ggseg.formats 3.0.0 still ships, and an S7 atlas stamped with an
# older schema. Editing a published atlas is what this package's verbs are
# for, so the legacy list is the common case rather than the exotic one --
# and every other fixture in this suite is a current S7 atlas, which is how
# three legacy-only bugs got through.

door_atlas <- function() {
  square <- function(x0, y0, side = 1) {
    sf::st_polygon(list(matrix(
      c(x0, y0, x0 + side, y0, x0 + side, y0 + side, x0, y0 + side, x0, y0),
      ncol = 2,
      byrow = TRUE
    )))
  }

  # "cortex" is geometry with no row in `core`, so it is this atlas's context;
  # view "v2" draws nothing but that, so it is an empty view.
  geom <- sf::st_sf(
    label = c("region_a", "region_b", "cortex", "cortex"),
    view = c("v1", "v1", "v1", "v2"),
    geometry = sf::st_sfc(
      square(0, 0),
      square(2, 0),
      square(-1, -1, 6),
      square(-1, -1, 6)
    )
  )

  ggseg.formats::ggseg_atlas(
    atlas = "doors",
    type = "subcortical",
    palette = c(region_a = "#000000", region_b = "#111111"),
    core = data.frame(
      hemi = c("left", "right"),
      region = c("a", "b"),
      label = c("region_a", "region_b"),
      display = c("A", "B"),
      stringsAsFactors = FALSE
    ),
    data = ggseg.formats::ggseg_data_subcortical(geom = geom)
  )
}

as_legacy_atlas <- function(atlas) {
  structure(
    as.list(atlas),
    class = c(
      paste0(ggseg.formats::atlas_type(atlas), "_atlas"),
      "ggseg_atlas",
      "list"
    )
  )
}

as_stale_atlas <- function(atlas) {
  attr(atlas, "schema") <- 0L
  atlas
}

representations <- list(
  legacy = as_legacy_atlas,
  stale_schema = as_stale_atlas
)

# An S7 object carries a frozen copy of its class, and two copies of the same
# class are not `identical()`, so comparing the objects whole would report a
# difference that is not one. Compare everything an atlas actually holds.
expect_same_atlas <- function(object, expected) {
  expect_identical(
    ggseg.formats::atlas_name(object),
    ggseg.formats::atlas_name(expected)
  )
  expect_identical(
    ggseg.formats::atlas_core(object),
    ggseg.formats::atlas_core(expected)
  )
  expect_identical(
    ggseg.formats::atlas_palette(object),
    ggseg.formats::atlas_palette(expected)
  )
  expect_identical(
    ggseg.formats::atlas_data(object),
    ggseg.formats::atlas_data(expected)
  )
  expect_identical(
    ggseg.formats::atlas_geom(object),
    ggseg.formats::atlas_geom(expected)
  )
  invisible(object)
}

# Verbs that hand an atlas back.
atlas_verbs <- list(
  atlas_smooth = function(atlas) atlas_smooth(atlas, smoothness = 0.4),
  atlas_simplify = function(atlas) atlas_simplify(atlas, keep = 0.5),
  atlas_polish = function(atlas) {
    atlas_polish(atlas, keep = 0.5, smoothness = 0.4)
  },
  atlas_dilate = function(atlas) atlas_dilate(atlas, 0.05),
  atlas_view_remove_empty = function(atlas) atlas_view_remove_empty(atlas),
  atlas_view_remove_sparse = function(atlas) {
    atlas_view_remove_sparse(atlas, min_regions = 1)
  },
  # The selector is handed the atlas the verb is working on, so it has to be
  # handed the upgraded one.
  atlas_simplify_by_selector = function(atlas) {
    atlas_simplify(atlas, keep = 0.5, exclude = context_pattern)
  }
)

# Verbs that report on an atlas rather than reshaping it.
atlas_reporters <- list(
  count_vertices = function(atlas) count_vertices(atlas),
  atlas_view_region_counts = function(atlas) atlas_view_region_counts(atlas),
  context_pattern = function(atlas) context_pattern(atlas)
)


describe("exported verbs on a legacy or stale atlas", {
  current <- door_atlas()

  for (rep_name in names(representations)) {
    as_rep <- representations[[rep_name]]

    it(paste("reshapes", rep_name, "to the same atlas as an S7 one"), {
      for (verb in names(atlas_verbs)) {
        f <- atlas_verbs[[verb]]
        expected <- suppressMessages(f(current))
        actual <- suppressMessages(f(as_rep(current)))

        expect_true(ggseg.formats::is_ggseg_atlas(actual), label = verb)
        # The door's whole point: whatever came in, what comes out is the
        # object the rest of the ecosystem expects.
        expect_true(
          ggseg.formats::atlas_schema_is_current(actual),
          label = verb
        )
        expect_same_atlas(actual, expected)
      }
    })

    it(paste("reports the same numbers for", rep_name, "as for an S7 one"), {
      for (verb in names(atlas_reporters)) {
        f <- atlas_reporters[[verb]]
        expect_identical(
          suppressMessages(f(as_rep(current))),
          suppressMessages(f(current)),
          label = verb
        )
      }
    })
  }

  it("leaves a current atlas untouched at the door", {
    for (verb in names(atlas_reporters)) {
      f <- atlas_reporters[[verb]]
      expect_no_error(f(current))
    }
  })
})


describe("the door's boundary errors", {
  # Every verb keeps the two conditions `assert_ggseg_atlas()` raises, so
  # code catching them by class still works.
  calls <- list(
    atlas_smooth = function(x) atlas_smooth(x),
    atlas_simplify = function(x) atlas_simplify(x),
    atlas_polish = function(x) atlas_polish(x),
    atlas_dilate = function(x) atlas_dilate(x, 1),
    atlas_view_remove_empty = function(x) atlas_view_remove_empty(x),
    atlas_view_remove_sparse = function(x) atlas_view_remove_sparse(x),
    atlas_view_region_counts = function(x) atlas_view_region_counts(x),
    count_vertices = function(x) count_vertices(x),
    context_pattern = function(x) context_pattern(x)
  )

  it("refuses something that is not an atlas", {
    for (verb in names(calls)) {
      expect_error(
        calls[[verb]](42),
        class = "ggseg.formats_not_atlas",
        label = verb
      )
    }
  })

  it("refuses a legacy atlas whose structure is invalid", {
    broken <- structure(
      list(atlas = "broken", type = "subcortical"),
      class = c("subcortical_atlas", "ggseg_atlas", "list")
    )

    for (verb in names(calls)) {
      expect_error(
        calls[[verb]](broken),
        class = "ggseg.formats_invalid_atlas",
        label = verb
      )
    }
  })
})
