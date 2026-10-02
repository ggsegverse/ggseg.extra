# Tests for R/surface_dilation.R -- cortex masks and surface dilation.

describe("fill_surface_labels", {
  it("warns and returns overlay when surface file not found", {
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent/subjects",
      .package = "freesurfer"
    )

    overlay <- c(1L, 0L, 2L, 0L)
    expect_warning(
      {
        result <- fill_surface_labels(overlay, "lh", "fsaverage5")
      },
      "skipping dilation"
    )
    expect_identical(result, overlay)
  })

  it("breaks when no newly_labeled vertices remain", {
    local_fake_fsaverage(
      n_vertices = 5L,
      faces = matrix(c(1L, 2L, 3L), nrow = 1),
      cortex = 0:2
    )

    overlay <- c(1L, 0L, 2L, 0L, 0L)
    result <- fill_surface_labels(overlay, "lh", "fsaverage5")
    expect_identical(result[1], 1L)
    expect_identical(result[3], 2L)
    expect_true(result[2] != 0L)
    expect_identical(result[4], 0L)
    expect_identical(result[5], 0L)
  })
})


describe("load_cortex_mask", {
  it("returns logical vector from cortex label file", {
    local_fake_fsaverage(
      n_vertices = 6L,
      faces = matrix(c(1L, 2L, 3L), nrow = 1),
      cortex = c(0L, 2L, 4L)
    )

    mask <- load_cortex_mask("lh", n_vertices = 6L, subject = "fsaverage5")
    expect_type(mask, "logical")
    expect_length(mask, 6L)
    expect_identical(mask, c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE))
  })

  it("errors when cortex label file missing", {
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent/subjects",
      .package = "freesurfer"
    )

    expect_error(
      load_cortex_mask("lh", n_vertices = 10L, subject = "fsaverage5"),
      "Cortex label not found"
    )
  })
})


describe("fill_surface_labels with cortex mask", {
  it("does not dilate into medial wall vertices", {
    local_fake_fsaverage(
      n_vertices = 6L,
      faces = matrix(
        c(1L, 2L, 3L, 3L, 4L, 5L, 5L, 6L, 1L),
        nrow = 3,
        byrow = TRUE
      ),
      cortex = 0:2
    )

    overlay <- c(1L, 0L, 0L, 0L, 0L, 0L)
    result <- fill_surface_labels(overlay, "lh", "fsaverage5")

    expect_identical(result[1], 1L)
    expect_true(result[2] != 0L)
    expect_true(result[3] != 0L)
    expect_identical(result[4], 0L)
    expect_identical(result[5], 0L)
    expect_identical(result[6], 0L)
  })
})


describe("fill_surface_labels stalled dilation", {
  it("breaks when no unlabeled vertex has a labeled neighbor", {
    local_fake_fsaverage(
      n_vertices = 4L,
      faces = matrix(c(1L, 2L, 3L, 3L, 4L, 1L), nrow = 2, byrow = TRUE),
      cortex = 0:3
    )

    overlay <- c(0L, 0L, 0L, 0L)
    result <- fill_surface_labels(overlay, "lh", "fsaverage5")
    expect_identical(result, overlay)
  })
})


describe("mask_to_cortex", {
  it("clears labelled vertices outside the cortex label", {
    local_fake_fsaverage(
      n_vertices = 6L,
      faces = matrix(c(1L, 2L, 3L), nrow = 1),
      cortex = 0:2
    )

    expect_identical(
      mask_to_cortex(c(1L, 0L, 2L, 5L, 5L, 5L), "lh", "fsaverage5"),
      c(1L, 0L, 2L, 0L, 0L, 0L)
    )
  })
})
