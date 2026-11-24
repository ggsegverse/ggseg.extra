nuclei_labels <- "Dentate|Interposed|Fastigial"

nuclei_outline <- function(atlas) {
  flat <- ggseg.formats:::polygons_unnest(
    ggseg.formats::atlas_polygons(atlas)
  )
  flat[flat$view == "nuclei", , drop = FALSE]
}

# Bumpiness, measured: a scalloped outline walks further round the same area
# than a smooth one, so perimeter over sqrt(area) falls as bumps go.
roughness <- function(d) {
  rings <- split(d, interaction(d$label, d$group, d$subgroup, drop = TRUE))
  total <- vapply(
    rings,
    function(r) {
      x <- r$x
      y <- r$y
      perim <- sum(sqrt(diff(c(x, x[1]))^2 + diff(c(y, y[1]))^2))
      area <- abs(sum(x * c(y[-1], y[1]) - c(x[-1], x[1]) * y)) / 2
      if (area <= 0) NA_real_ else perim / sqrt(area)
    },
    numeric(1)
  )
  mean(total, na.rm = TRUE)
}


describe("smooth_ring_arc()", {
  it("leaves a ring with too few vertices alone", {
    x <- c(0, 1, 1, 0)
    y <- c(0, 0, 1, 1)
    expect_identical(smooth_ring_arc(x, y, span = 1), list(x = x, y = y))
  })

  it("returns as many points as it was given", {
    t <- seq(0, 2 * pi, length.out = 200)[-200]
    out <- smooth_ring_arc(cos(t), sin(t), span = 0.5)
    expect_length(out$x, length(t))
    expect_length(out$y, length(t))
  })

  it("wraps the window, so a circle stays centred", {
    # A one-sided window drags a closed ring round itself; a wrapped one
    # leaves a shape that is already smooth where it is.
    t <- seq(0, 2 * pi, length.out = 400)[-400]
    out <- smooth_ring_arc(cos(t), sin(t), span = 0.5)
    expect_equal(mean(out$x), 0, tolerance = 1e-6)
    expect_equal(mean(out$y), 0, tolerance = 1e-6)
  })

  it("takes the bumps off a scalloped circle", {
    t <- seq(0, 2 * pi, length.out = 600)[-600]
    r <- 1 + 0.05 * sin(40 * t)
    rough <- data.frame(
      x = r * cos(t),
      y = r * sin(t),
      label = "a",
      group = 1,
      subgroup = 1
    )
    out <- smooth_ring_arc(rough$x, rough$y, span = 0.4)
    smooth <- data.frame(
      x = out$x,
      y = out$y,
      label = "a",
      group = 1,
      subgroup = 1
    )
    expect_lt(roughness(smooth), roughness(rough))
  })

  it("does not collapse a ring towards its centre", {
    # The half-window is capped below a third of the ring for this reason.
    t <- seq(0, 2 * pi, length.out = 100)[-100]
    out <- smooth_ring_arc(cos(t), sin(t), span = 1e6)
    expect_gt(diff(range(out$x)), 0.5)
  })
})


describe("check_span()", {
  it("requires a span for the arc method", {
    expect_error(check_span(NULL), "required")
  })

  it("rejects a span that is not a single non-negative number", {
    expect_error(check_span(c(1, 2)), "single")
    expect_error(check_span(-1), "non-negative")
    expect_error(check_span("1"), "single")
    expect_error(check_span(NA_real_), "single")
  })

  it("passes a good span through", {
    expect_identical(check_span(1.5), 1.5)
  })
})


describe("atlas_smooth(method = \"arc\")", {
  atlas <- ggseg.formats::suit()

  it("errors without a span rather than guessing one", {
    expect_error(atlas_smooth(atlas, method = "arc"), "required")
  })

  it("is a no-op at span 0", {
    expect_identical(atlas_smooth(atlas, method = "arc", span = 0), atlas)
  })

  it("moves vertices without adding any", {
    # This is what separates it from the corner-rounding methods, and why
    # vertex_budget does not apply to it.
    out <- atlas_smooth(atlas, method = "arc", span = 1, labels = nuclei_labels)
    expect_identical(nrow(nuclei_outline(out)), nrow(nuclei_outline(atlas)))
  })

  it("actually takes the bumps off, which the other methods did not", {
    out <- atlas_smooth(atlas, method = "arc", span = 1, labels = nuclei_labels)
    expect_lt(roughness(nuclei_outline(out)), roughness(nuclei_outline(atlas)))
  })

  it("smooths more at a wider span", {
    narrow <- atlas_smooth(
      atlas,
      method = "arc",
      span = 0.5,
      labels = nuclei_labels
    )
    wide <- atlas_smooth(
      atlas,
      method = "arc",
      span = 2,
      labels = nuclei_labels
    )
    expect_lt(
      roughness(nuclei_outline(wide)),
      roughness(nuclei_outline(narrow))
    )
  })

  it("leaves unselected geometry byte-identical", {
    # A selector is a guarantee, not a hint.
    out <- atlas_smooth(atlas, method = "arc", span = 2, labels = nuclei_labels)
    flat_before <- ggseg.formats:::polygons_unnest(
      ggseg.formats::atlas_polygons(atlas)
    )
    flat_after <- ggseg.formats:::polygons_unnest(
      ggseg.formats::atlas_polygons(out)
    )
    expect_identical(
      flat_after[flat_after$view == "flatmap", ],
      flat_before[flat_before$view == "flatmap", ]
    )
  })

  it("ignores vertex_budget, which has nothing to take back", {
    preserve <- atlas_smooth(
      atlas,
      method = "arc",
      span = 1,
      labels = nuclei_labels,
      vertex_budget = "preserve"
    )
    free <- atlas_smooth(
      atlas,
      method = "arc",
      span = 1,
      labels = nuclei_labels,
      vertex_budget = "free"
    )
    expect_identical(nuclei_outline(preserve), nuclei_outline(free))
  })

  it("keeps a boundary two structures share", {
    # Smoothing rings independently opens a gap exactly where neighbours
    # touch, which is the most visible thing smoothing can do to an atlas.
    out <- atlas_smooth(atlas, method = "arc", span = 2, labels = nuclei_labels)
    before <- nuclei_outline(atlas)
    after <- nuclei_outline(out)

    shared_before <- sum(duplicated(
      paste(round(before$x, 6), round(before$y, 6))
    ))
    shared_after <- sum(duplicated(
      paste(round(after$x, 6), round(after$y, 6))
    ))
    expect_gt(shared_before, 0)
    expect_gte(shared_after, shared_before)
  })

  it("produces a valid atlas", {
    out <- atlas_smooth(atlas, method = "arc", span = 1, labels = nuclei_labels)
    expect_no_error(ggseg.formats::assert_ggseg_atlas(out))
  })
})
