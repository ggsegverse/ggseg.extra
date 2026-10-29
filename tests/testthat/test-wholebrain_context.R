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
