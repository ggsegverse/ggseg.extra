# Tests for R/wholebrain_context.R -- which labels a whole-brain atlas draws
# as backdrop, and the hemisphere split that writes them.

describe("wholebrain cortex context from the volume midline", {
  it("splits the cortical mask at the midline", {
    skip_if_not_installed("RNifti")
    arr <- array(1000L, dim = c(12, 5, 5))
    vol_file <- local_volume_at_midline(arr, midline = 6)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result == 3L), 150L)
    expect_identical(sum(result == 42L), 150L)
    expect_identical(sum(result == 0L), 0L)
  })

  it("never writes context over a structure", {
    skip_if_not_installed("RNifti")
    arr <- array(1000L, dim = c(8, 5, 5))
    arr[2, 2, 2] <- 10L
    vol_file <- local_volume_at_midline(arr, midline = 4)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = 1000L,
      output_file = out_file,
      target_idx = 101L
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(result[2, 2, 2], 101L)
    expect_identical(sum(result == 3L), 99L)
    expect_identical(sum(result == 42L), 100L)
  })

  it("writes no context when the atlas has no cortical labels", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(4, 3, 3))
    arr[1, 1, 1] <- 10L
    vol_file <- local_volume_at_midline(arr, midline = 2)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    prepared <- wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = integer(0),
      output_file = out_file
    )

    expect_identical(prepared$context_idx, integer(0))
    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result %in% c(3L, 42L)), 0L)
  })
})


describe("declined_context_labels()", {
  lut <- function(context) {
    out <- data.frame(idx = 1:3, label = c("a", "b", "c"))
    if (!missing(context)) {
      out$context <- context
    }
    out
  }

  it("is empty for a table with no context column", {
    expect_identical(declined_context_labels(lut()), character(0))
  })

  it("is empty for a NULL table", {
    expect_identical(declined_context_labels(NULL), character(0))
  })

  it("is empty when every row says nothing", {
    expect_identical(
      declined_context_labels(lut(c(NA, NA, NA))),
      character(0)
    )
  })

  it("names only the rows that explicitly decline", {
    expect_identical(
      declined_context_labels(lut(c(FALSE, NA, TRUE))),
      "a"
    )
  })

  it("reads the written forms of declining as well as FALSE", {
    expect_identical(
      declined_context_labels(lut(c("no", "0", "yes"))),
      c("a", "b")
    )
  })
})


describe("default_backdrop_labels()", {
  lut <- function(context) {
    out <- data.frame(
      idx = 1:3,
      label = c("ctx_a", "ctx_b", "wm_a")
    )
    if (!missing(context)) {
      out$context <- context
    }
    out
  }

  it("takes every cortical label when the table has no context column", {
    expect_identical(
      default_backdrop_labels(lut(), c("ctx_a", "ctx_b")),
      c("ctx_a", "ctx_b")
    )
  })

  it("takes every cortical label when the column says nothing", {
    expect_identical(
      default_backdrop_labels(lut(c(NA, NA, NA)), c("ctx_a", "ctx_b")),
      c("ctx_a", "ctx_b")
    )
  })

  it("drops the label whose row explicitly declines", {
    expect_identical(
      default_backdrop_labels(lut(c(NA, FALSE, NA)), c("ctx_a", "ctx_b")),
      "ctx_a"
    )
  })

  it("can be declined down to nothing", {
    expect_identical(
      default_backdrop_labels(lut(c(FALSE, FALSE, NA)), c("ctx_a", "ctx_b")),
      character(0)
    )
  })

  it("adds the white-matter labels to the cortical ones", {
    expect_identical(
      default_backdrop_labels(lut(), c("ctx_a", "ctx_b"), "wm_a"),
      c("ctx_a", "ctx_b", "wm_a")
    )
  })

  it("drops a white-matter label whose row declines", {
    expect_identical(
      default_backdrop_labels(
        lut(c(NA, NA, FALSE)),
        c("ctx_a", "ctx_b"),
        "wm_a"
      ),
      c("ctx_a", "ctx_b")
    )
  })

  it("is white matter alone when there is no cortex", {
    expect_identical(
      default_backdrop_labels(lut(), character(0), "wm_a"),
      "wm_a"
    )
  })

  it("is empty when there is nothing to draw", {
    expect_identical(
      default_backdrop_labels(lut(), character(0), character(0)),
      character(0)
    )
  })

  it("survives a NULL table", {
    expect_identical(
      default_backdrop_labels(NULL, "ctx_a", "wm_a"),
      c("ctx_a", "wm_a")
    )
  })
})
