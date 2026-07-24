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
    data = ggseg.formats::ggseg_data_subcortical(geom = sf_df)
  )
}

describe("subcortical_slabs", {
  vol <- array(0L, dim = c(20, 20, 20))
  vol[8:12, 6:14, 9:11] <- 17L

  it("produces the requested slab counts and types", {
    v <- subcortical_slabs(
      vol,
      labels = 17,
      coronal = 3,
      axial = 2,
      sagittal = 1
    )
    expect_identical(nrow(v), 6L)
    expect_identical(sum(v$type == "coronal"), 3L)
    expect_identical(sum(v$type == "axial"), 2L)
    expect_identical(sum(v$type == "sagittal"), 1L)
    expect_setequal(names(v), c("name", "type", "start", "end"))
  })

  it("slabs span the label bounding box on the right axis", {
    v <- subcortical_slabs(
      vol,
      labels = 17,
      coronal = 3,
      axial = 2,
      sagittal = 1
    )
    coronal <- v[v$type == "coronal", ]
    expect_identical(min(coronal$start), 6) # dim2 lower
    expect_lte(max(coronal$end), 14) # dim2 upper
    sagittal <- v[v$type == "sagittal", ]
    expect_identical(sagittal$start, 8) # dim1 lower
    expect_identical(sagittal$end, 12) # dim1 upper
  })

  it("pads the bounding box", {
    v <- subcortical_slabs(vol, labels = 17, sagittal = 1, pad = 2)
    expect_identical(v$start, 6) # min 8, padded by 2
    expect_identical(v$end, 14) # max 12, padded by 2
  })

  it("errors when no labels are present", {
    expect_error(
      subcortical_slabs(vol, labels = 999, coronal = 1),
      "None of"
    )
  })

  it("errors when no orientation is requested", {
    expect_error(subcortical_slabs(vol, labels = 17), "at least one slab")
  })

  it("reads a path volume in the builder's reorient frame (round-trip)", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(10, 12, 14))
    arr[2:4, 5:9, 8:12] <- 17L
    f <- withr::local_tempfile(fileext = ".nii.gz")
    # Non-RAS on disk so read_volume() must reorient; subcortical_slabs() owns
    # that read, so a path must agree with the same volume already in the
    # builder's frame rather than the raw on-disk array. The RNifti
    # orientation/IO setup emits incidental warnings unrelated to the contract.
    suppressWarnings({
      img <- RNifti::asNifti(arr)
      RNifti::orientation(img) <- "LAS"
      RNifti::writeNifti(img, f)
    })

    from_path <- subcortical_slabs(f, labels = 17, coronal = 2, axial = 2)
    from_frame <- subcortical_slabs(
      read_volume(f, reorient = TRUE),
      labels = 17,
      coronal = 2,
      axial = 2
    )
    expect_identical(from_path, from_frame)
  })
})


describe("subcortical_views (deprecated)", {
  it("warns about deprecation and delegates to subcortical_slabs", {
    vol <- array(0L, dim = c(20, 20, 20))
    vol[8:12, 6:14, 9:11] <- 17L

    lifecycle::expect_deprecated(
      result <- subcortical_views(vol, labels = 17, coronal = 1)
    )

    expect_identical(result, subcortical_slabs(vol, labels = 17, coronal = 1))
  })
})

describe("aseg_context", {
  it("keeps focus as core and demotes everything else", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    expect_identical(a$core$label, "L_hypothalamus_anterior_inferior")
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
    expect_false(
      "Left-Cerebral-White-Matter" %in% ggseg.formats::atlas_geom(a)$label
    )
  })

  it("keeps demoted context geometry for display", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    # Left-Thalamus is context: gone from core but its sf geometry remains.
    expect_true("Left-Thalamus" %in% ggseg.formats::atlas_geom(a)$label)
  })

  it("drops views with no focus region", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    expect_false("coronal_2" %in% ggseg.formats::atlas_views(a))
    expect_true("coronal_1" %in% ggseg.formats::atlas_views(a))
  })

  it("can keep empty views when asked", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE,
      drop_empty_views = FALSE
    )
    expect_true("coronal_2" %in% ggseg.formats::atlas_views(a))
  })
})

describe("aseg_context input validation and white-matter punch", {
  it("errors when atlas is not a ggseg_atlas", {
    expect_error(
      aseg_context(list(x = 1), focus = "hypothalamus"),
      "ggseg_atlas"
    )
  })

  it("punches the cerebral white matter out of the cortex silhouette", {
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = TRUE
    )
    # focus survives the punch and context demotion
    expect_identical(a$core$label, "L_hypothalamus_anterior_inferior")
    # white matter is stripped from the geometry (hidden label + punched)
    expect_false(
      "Left-Cerebral-White-Matter" %in% ggseg.formats::atlas_geom(a)$label
    )
  })
})

describe("aseg_punch_white_matter", {
  it("skips with an info message when cortex/white matter not both present", {
    atlas <- make_test_atlas()
    out <- expect_messages(
      aseg_punch_white_matter(
        atlas,
        cortex = "^cortex",
        white_matter = "White-Matter$",
        sf_labels = "cortex" # white matter absent
      ),
      "Skipping white-matter punch"
    )
    expect_identical(out, atlas)
  })

  it("subtracts white matter from cortex when both are present", {
    atlas <- make_test_atlas()
    out <- aseg_punch_white_matter(
      atlas,
      cortex = "^cortex",
      white_matter = "White-Matter$",
      sf_labels = ggseg.formats::atlas_geom(atlas)$label
    )
    expect_true(ggseg.formats::is_ggseg_atlas(out))
  })
})

describe("lut_add / lut_combine", {
  base <- data.frame(
    stringsAsFactors = FALSE,
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
    expect_identical(nrow(out), 3L)
    expect_true(all(c(20001L, 20002L) %in% out$idx))
    expect_true(is_lut(out))
  })

  it("recycles a scalar channel", {
    out <- lut_add(base, idx = 1:3, label = "x", R = 10, G = 20, B = 30)
    expect_identical(out$R[out$idx %in% 1:3], c(10L, 10L, 10L))
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
    b <- data.frame(
      stringsAsFactors = FALSE,
      idx = 2L,
      label = "b",
      R = 2L,
      G = 2L,
      B = 2L,
      A = 0L
    )
    out <- lut_combine(a, b)
    expect_identical(nrow(out), 2L)
    expect_true("type" %in% names(out))
    expect_true(is.na(out$type[out$idx == 2]))
  })

  it("warns on duplicate indices", {
    a <- data.frame(
      stringsAsFactors = FALSE,
      idx = 1L,
      label = "a",
      R = 1L,
      G = 1L,
      B = 1L,
      A = 0L
    )
    expect_warning(lut_combine(a, a), "Duplicate")
  })

  it("rejects non-LUTs", {
    expect_error(lut_combine(data.frame(x = 1)), "LUT")
    expect_error(lut_add(data.frame(x = 1), 1, "a", 1, 1, 1), "LUT")
  })

  it("errors instead of mis-recycling a mismatched-length label", {
    expect_error(
      lut_add(
        base,
        idx = 1:4,
        label = c("a", "b", "c"),
        R = 1,
        G = 1,
        B = 1
      ),
      "label.*must have length 1 or 4"
    )
  })

  it("errors instead of mis-recycling a mismatched-length channel", {
    expect_error(
      lut_add(base, idx = 1:4, label = "x", R = c(1, 2, 3), G = 1, B = 1),
      "R.*must have length 1 or 4"
    )
  })
})

describe("aseg_hidden_labels", {
  it("returns the standard set of stripped aseg patterns", {
    out <- aseg_hidden_labels()
    expect_type(out, "character")
    expect_setequal(
      out,
      c(
        "White-Matter",
        "WM-hypointensities",
        "-Ventricle",
        "-Vent$",
        "CSF",
        "Cerebral-Cortex",
        "choroid-plexus",
        "vessel",
        "CC_"
      )
    )
  })
})

describe("create_subcortical_from_volume slab/context specs", {
  it("exposes slabs and context as formals (whole-brain forwards them)", {
    fmls <- names(formals(create_subcortical_from_volume))
    expect_true(all(c("slabs", "context") %in% fmls))
  })

  it("expands a slabs list spec via subcortical_slabs()", {
    vol <- array(0L, dim = c(20, 20, 20))
    vol[8:12, 6:14, 9:11] <- 17L
    out <- resolve_subcort_slabs_spec(
      list(labels = 17, coronal = 3, axial = 2),
      vol
    )
    expect_s3_class(out, "data.frame")
    expect_identical(nrow(out), 5L)
    expect_setequal(out$type, c("coronal", "axial"))
  })

  it("passes a data.frame slabs table through unchanged", {
    df <- data.frame(
      stringsAsFactors = FALSE,
      name = "v",
      type = "coronal",
      start = 1L,
      end = 2L
    )
    expect_identical(resolve_subcort_slabs_spec(df, NULL), df)
  })

  it("passes NULL slabs through unchanged", {
    expect_null(resolve_subcort_slabs_spec(NULL, NULL))
  })

  it("errors on a non-list, non-data.frame slabs value", {
    expect_error(resolve_subcort_slabs_spec(42, NULL), "data.frame or a list")
  })

  it("errors when context is not a list", {
    expect_error(validate_subcort_context_arg("nope", 1:9), "must be a list")
  })

  it("warns when context is set but the 2D build (step 9) is skipped", {
    expect_warning(
      validate_subcort_context_arg(list(focus = "x"), 1:3),
      "step 9"
    )
  })

  it("is silent for valid context (with step 9) or NULL context", {
    expect_silent(validate_subcort_context_arg(list(focus = "x"), 1:9))
    expect_silent(validate_subcort_context_arg(NULL, 1:3))
  })

  it("applies aseg_context() to the atlas via a context spec", {
    a <- apply_subcort_context_spec(
      make_test_atlas(),
      list(focus = "hypothalamus", punch_white_matter = FALSE)
    )
    expect_identical(a$core$label, "L_hypothalamus_anterior_inferior")
  })

  it("leaves the atlas unchanged when context is NULL", {
    atlas <- make_test_atlas()
    expect_identical(apply_subcort_context_spec(atlas, NULL), atlas)
  })
})


describe("aseg_context with a mesh-only atlas", {
  it("falls back to empty sf labels when there is no 2D geometry", {
    local_mocked_bindings(
      atlas_geom = function(...) NULL,
      .package = "ggseg.formats"
    )
    a <- aseg_context(
      make_test_atlas(),
      focus = "hypothalamus",
      punch_white_matter = FALSE
    )
    expect_s3_class(a, "ggseg_atlas")
  })
})
