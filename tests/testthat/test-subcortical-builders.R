mk_square <- function(x0, y0, s = 2) {
  sf::st_polygon(list(rbind(
    c(x0, y0),
    c(x0 + s, y0),
    c(x0 + s, y0 + s),
    c(x0, y0 + s),
    c(x0, y0)
  )))
}

# Minimal subcortical atlas: a focus region whose name is a superstring of a
# context region (hypothalamus / Thalamus), a hidden white-matter label, and a
# cortex silhouette. A second view carries only context.
make_test_atlas <- function() {
  labels <- c(
    "L_hypothalamus_anterior_inferior",
    "Left-Thalamus",
    "Left-Cerebral-White-Matter"
  )
  core <- data.frame(
    hemi = "left",
    region = c("hypothalamus anterior inferior", "thalamus", "white matter"),
    label = labels,
    stringsAsFactors = FALSE
  )
  palette <- stats::setNames(c("#FF0000", "#00FF00", "#0000FF"), labels)

  sf_df <- sf::st_sf(
    label = c(labels, "cortex", "Left-Thalamus", "cortex"),
    view = c(rep("coronal_1", 4), "coronal_2", "coronal_2"),
    geometry = sf::st_sfc(list(
      mk_square(0, 0),
      mk_square(3, 0),
      mk_square(6, 0),
      mk_square(-2, -2, 12),
      mk_square(3, 0),
      mk_square(-2, -2, 12)
    ))
  )

  ggseg.formats::ggseg_atlas(
    atlas = "test",
    type = "subcortical",
    core = core,
    palette = palette,
    data = ggseg.formats::ggseg_data_subcortical(sf = sf_df)
  )
}

describe("subcortical_views", {
  vol <- array(0L, dim = c(20, 20, 20))
  vol[8:12, 6:14, 9:11] <- 17L

  it("produces the requested slab counts and types", {
    v <- subcortical_views(
      vol,
      labels = 17,
      coronal = 3,
      axial = 2,
      sagittal = 1
    )
    expect_equal(nrow(v), 6)
    expect_equal(sum(v$type == "coronal"), 3)
    expect_equal(sum(v$type == "axial"), 2)
    expect_equal(sum(v$type == "sagittal"), 1)
    expect_setequal(names(v), c("name", "type", "start", "end"))
  })

  it("slabs span the label bounding box on the right axis", {
    v <- subcortical_views(
      vol,
      labels = 17,
      coronal = 3,
      axial = 2,
      sagittal = 1
    )
    coronal <- v[v$type == "coronal", ]
    expect_equal(min(coronal$start), 6) # dim2 lower
    expect_true(max(coronal$end) <= 14) # dim2 upper
    sagittal <- v[v$type == "sagittal", ]
    expect_equal(sagittal$start, 8) # dim1 lower
    expect_equal(sagittal$end, 12) # dim1 upper
  })

  it("pads the bounding box", {
    v <- subcortical_views(vol, labels = 17, sagittal = 1, pad = 2)
    expect_equal(v$start, 6) # min 8, padded by 2
    expect_equal(v$end, 14) # max 12, padded by 2
  })

  it("errors when no labels are present", {
    expect_error(
      subcortical_views(vol, labels = 999, coronal = 1),
      "None of"
    )
  })

  it("errors when no orientation is requested", {
    expect_error(subcortical_views(vol, labels = 17), "at least one slab")
  })
})

describe("aseg_context", {
  it("keeps focus as core and demotes everything else", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    expect_equal(a$core$label, "L_hypothalamus_anterior_inferior")
  })

  it("does not let a substring context entry swallow the focus", {
    # "Thalamus" is a substring of "hypothalamus": focus must survive.
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    expect_true("L_hypothalamus_anterior_inferior" %in% a$core$label)
    expect_false("Left-Thalamus" %in% a$core$label)
  })

  it("removes hidden labels entirely (not just from core)", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    expect_false("Left-Cerebral-White-Matter" %in% a$core$label)
    expect_false("Left-Cerebral-White-Matter" %in% a$data$sf$label)
  })

  it("keeps demoted context geometry for display", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    # Left-Thalamus is context: gone from core but its sf geometry remains.
    expect_true("Left-Thalamus" %in% a$data$sf$label)
  })

  it("drops views with no focus region", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    expect_false("coronal_2" %in% a$data$sf$view)
    expect_true("coronal_1" %in% a$data$sf$view)
  })

  it("can keep empty views when asked", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE,
      drop_empty_views = FALSE
    )
    expect_true("coronal_2" %in% a$data$sf$view)
  })
})

describe("lut_add / lut_combine", {
  base <- data.frame(
    idx = 0L,
    label = "Unknown",
    R = 0L,
    G = 0L,
    B = 0L,
    A = 0L
  )

  it("appends recycled rows", {
    out <- lut_add(
      base,
      idx = 20001:20002,
      label = c("Left-Hippocampus-ant", "Left-Hippocampus-post"),
      R = c(220, 60),
      G = c(190, 140),
      B = c(30, 200)
    )
    expect_equal(nrow(out), 3)
    expect_true(all(c(20001L, 20002L) %in% out$idx))
    expect_true(is_ctab(out))
  })

  it("recycles a scalar channel", {
    out <- lut_add(base, idx = 1:3, label = "x", R = 10, G = 20, B = 30)
    expect_equal(out$R[out$idx %in% 1:3], c(10L, 10L, 10L))
  })

  it("combines tables and aligns a missing type column", {
    a <- data.frame(
      idx = 1L,
      label = "a",
      R = 1L,
      G = 1L,
      B = 1L,
      A = 0L,
      type = "subcortical",
      stringsAsFactors = FALSE
    )
    b <- data.frame(idx = 2L, label = "b", R = 2L, G = 2L, B = 2L, A = 0L)
    out <- lut_combine(a, b)
    expect_equal(nrow(out), 2)
    expect_true("type" %in% names(out))
    expect_true(is.na(out$type[out$idx == 2]))
  })

  it("warns on duplicate indices", {
    a <- data.frame(idx = 1L, label = "a", R = 1L, G = 1L, B = 1L, A = 0L)
    expect_warning(lut_combine(a, a), "Duplicate")
  })

  it("rejects non-color-tables", {
    expect_error(lut_combine(data.frame(x = 1)), "color table")
    expect_error(lut_add(data.frame(x = 1), 1, "a", 1, 1, 1), "color table")
  })
})
