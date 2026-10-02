# Tests for R/wholebrain_context.R -- the aseg cortical ribbon context.

describe("wholebrain cortex context from the aseg ribbon", {
  it("keeps only the voxels the ribbon covers when the mantle is solid", {
    skip_if_not_installed("RNifti")
    arr <- array(1000L, dim = c(12, 5, 5))
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    # 300 cortical voxels against a 150-voxel ribbon: a solid mantle. The
    # ribbon is three voxels thick, so the grid can carry it.
    left <- right <- array(FALSE, dim = dim(arr))
    left[1:3, , ] <- TRUE
    right[10:12, , ] <- TRUE
    local_mocked_bindings(
      aseg_context_volume = function(...) mock_cortex_ribbon(left, right)
    )

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result == 3L), 75L)
    expect_identical(sum(result == 42L), 75L)
    # The six middle x-slices are cortex the ribbon does not cover: the
    # sulcal space that makes the silhouette read as a brain.
    expect_identical(sum(result == 0L), 150L)
  })

  it("never writes context over a structure", {
    skip_if_not_installed("RNifti")
    arr <- array(1000L, dim = c(8, 5, 5))
    arr[2, 2, 2] <- 10L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    ribbon <- array(0L, dim = dim(arr))
    ribbon[1:3, , ] <- 3L
    local_mocked_bindings(aseg_context_volume = function(...) ribbon)

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = 1000L,
      output_file = out_file,
      target_idx = 101L
    )

    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(result[2, 2, 2], 101L)
    expect_identical(sum(result == 3L), 74L)
  })

  it("keeps a cortical mask that is already a ribbon", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(6, 3, 3))
    arr[1:2, , ] <- 1000L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    ribbon <- array(3L, dim = dim(arr))
    local_mocked_bindings(aseg_context_volume = function(...) ribbon)

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = integer(0),
      cortical_idx = 1000L,
      output_file = out_file
    )

    # Every cortical voxel is context and nothing else is, which is the
    # midline split this has always done.
    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result %in% c(3L, 42L)), 18L)
  })

  it("does not look for an aseg when the atlas has no cortex", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(4, 3, 3))
    arr[1, 1, 1] <- 10L
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), vol_file)
    out_file <- withr::local_tempfile(fileext = ".nii.gz")

    seen <- new.env()
    seen$called <- FALSE
    local_mocked_bindings(
      aseg_context_volume = function(...) {
        seen$called <- TRUE
        NULL
      }
    )

    wholebrain_prepare_subcortical_volume(
      input_volume = vol_file,
      subcortical_idx = 10L,
      cortical_idx = integer(0),
      output_file = out_file
    )

    expect_false(seen$called)
    result <- as.array(RNifti::readNifti(out_file))
    expect_identical(sum(result %in% c(3L, 42L)), 0L)
  })
})


describe("cortex_mask_is_solid", {
  it("calls a mantle several ribbons thick solid", {
    mask <- array(TRUE, dim = c(4, 4, 4))
    ribbon <- array(0L, dim = c(4, 4, 4))
    ribbon[1, , ] <- 3L
    expect_true(cortex_mask_is_solid(mask, ribbon, verbose = FALSE))
  })

  it("calls a mask no thicker than the ribbon a ribbon", {
    mask <- array(FALSE, dim = c(4, 4, 4))
    mask[1, , ] <- TRUE
    ribbon <- array(3L, dim = c(4, 4, 4))
    expect_false(cortex_mask_is_solid(mask, ribbon, verbose = FALSE))
  })

  it("says which way it decided when verbose", {
    mask <- array(FALSE, dim = c(4, 4, 4))
    mask[1, , ] <- TRUE
    ribbon <- array(3L, dim = c(4, 4, 4))
    expect_message(
      cortex_mask_is_solid(mask, ribbon, verbose = TRUE),
      "already a ribbon"
    )
  })

  it("survives an empty ribbon", {
    mask <- array(TRUE, dim = c(2, 2, 2))
    expect_true(
      cortex_mask_is_solid(mask, array(0L, dim = c(2, 2, 2)), verbose = FALSE)
    )
  })

  it("compares the ratio it measured, not a rounded one", {
    # 1.4951 ribbons' worth of voxels is not 1.5, however it prints.
    ribbon <- array(0L, dim = c(30, 30, 30))
    ribbon[1:10000] <- 3L
    mask <- array(FALSE, dim = dim(ribbon))
    mask[1:14951] <- TRUE
    expect_false(cortex_mask_is_solid(mask, ribbon, verbose = FALSE))
  })

  it("says so when the mantle is solid", {
    mask <- array(TRUE, dim = c(4, 4, 4))
    ribbon <- array(0L, dim = c(4, 4, 4))
    ribbon[1, , ] <- 3L
    expect_message(
      cortex_mask_is_solid(mask, ribbon, verbose = TRUE),
      "solid mantle"
    )
  })
})


describe("ribbon_interior_fraction", {
  it("is zero for a ribbon one voxel thick", {
    ribbon <- array(FALSE, dim = c(12, 5, 5))
    ribbon[1, , ] <- TRUE
    expect_identical(ribbon_interior_fraction(ribbon), 0)
  })

  it("counts the voxels with a full neighbourhood", {
    ribbon <- array(FALSE, dim = c(12, 5, 5))
    ribbon[1:3, , ] <- TRUE
    # Only x = 2 has ribbon either side of it, and only the 3 x 3 core of
    # the slice has ribbon above, below and beside it.
    expect_identical(ribbon_interior_fraction(ribbon), 9 / 75)
  })

  it("is zero for an empty ribbon", {
    expect_identical(
      ribbon_interior_fraction(array(FALSE, dim = c(4, 4, 4))),
      0
    )
  })

  it("is zero when an axis is too short to have an interior", {
    ribbon <- array(TRUE, dim = c(4, 4, 1))
    expect_identical(ribbon_interior_fraction(ribbon), 0)
  })
})


describe("ribbon_is_resolved", {
  it("accepts a ribbon that is a voxel thick through itself", {
    aseg <- array(0L, dim = c(12, 5, 5))
    aseg[1:3, , ] <- 3L
    expect_true(ribbon_is_resolved(aseg, verbose = FALSE))
  })

  it("declines a ribbon the grid has flattened to a sheet", {
    aseg <- array(0L, dim = c(12, 5, 5))
    aseg[1, , ] <- 3L
    aseg[12, , ] <- 42L
    expect_false(ribbon_is_resolved(aseg, verbose = FALSE))
  })

  it("takes the threshold itself as resolved", {
    aseg <- array(0L, dim = c(12, 5, 5))
    aseg[1:3, , ] <- 3L
    expect_true(ribbon_is_resolved(aseg, verbose = FALSE, min_interior = 0.12))
    expect_false(ribbon_is_resolved(aseg, verbose = FALSE, min_interior = 0.13))
  })

  it("ignores the posterior fossa labels, which are not cortex", {
    aseg <- array(8L, dim = c(12, 5, 5))
    aseg[1, , ] <- 3L
    expect_false(ribbon_is_resolved(aseg, verbose = FALSE))
  })

  it("says which way it decided when verbose", {
    coarse <- array(0L, dim = c(12, 5, 5))
    coarse[1, , ] <- 3L
    expect_message(
      ribbon_is_resolved(coarse, verbose = TRUE),
      "too coarse"
    )

    fine <- array(0L, dim = c(12, 5, 5))
    fine[1:3, , ] <- 3L
    expect_message(
      ribbon_is_resolved(fine, verbose = TRUE),
      "Taking the silhouette from the resampled"
    )
  })
})


describe("aseg_volume_path", {
  it("warns and returns NULL without FreeSurfer", {
    local_mocked_bindings(have_fs_quietly = function() FALSE)
    expect_warning(
      expect_null(aseg_volume_path("cvs_avg35_inMNI152")),
      "FreeSurfer is not available"
    )
  })

  it("warns and returns NULL when the subject has no aseg", {
    subj_dir <- withr::local_tempdir()
    local_mocked_bindings(have_fs_quietly = function() TRUE)
    local_mocked_bindings(
      fs_subj_dir = function() subj_dir,
      .package = "freesurfer"
    )
    expect_warning(
      expect_null(aseg_volume_path("nosuchsubject")),
      "does not exist"
    )
  })

  it("returns the path when the aseg is there", {
    subj_dir <- withr::local_tempdir()
    mri <- file.path(subj_dir, "subj", "mri")
    dir.create(mri, recursive = TRUE)
    file.create(file.path(mri, "aseg.mgz"))
    local_mocked_bindings(have_fs_quietly = function() TRUE)
    local_mocked_bindings(
      fs_subj_dir = function() subj_dir,
      .package = "freesurfer"
    )
    expect_identical(
      aseg_volume_path("subj"),
      as.character(fs::path(mri, "aseg.mgz"))
    )
  })
})


describe("aseg_context_volume resampling", {
  it("warns and falls back when the resampling fails", {
    local_mocked_bindings(
      run_cmd = function(cmd, ...) {
        cli::cli_abort(c(
          "FreeSurfer command failed (exit 1).",
          "i" = "FreeSurfer said:",
          " " = "ERROR: bad header"
        ))
      }
    )
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")

    expect_snapshot(
      expect_null(aseg_context_volume(
        "a.nii.gz",
        "subj",
        c(2L, 2L, 2L),
        array(TRUE, c(2, 2, 2))
      ))
    )
  })
})


describe("aseg_context_volume", {
  it("returns NULL when there is no aseg to resample", {
    local_mocked_bindings(aseg_volume_path = function(...) NULL)
    expect_null(
      aseg_context_volume(
        "a.nii.gz",
        "subj",
        c(2L, 2L, 2L),
        array(TRUE, c(2, 2, 2))
      )
    )
  })

  it("warns and returns NULL when the resampled grid differs", {
    skip_if_not_installed("RNifti")
    resampled <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(array(3L, dim = c(2, 2, 2))), resampled)
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")
    local_mocked_bindings(
      resample_volume_to_grid = function(...) list(file = resampled)
    )

    expect_warning(
      expect_null(aseg_context_volume(
        "a.nii.gz",
        "subj",
        c(3L, 3L, 3L),
        array(TRUE, c(3, 3, 3))
      )),
      "does not share the volume's grid"
    )
  })

  it("keeps the cortex and posterior fossa indices and nothing else", {
    skip_if_not_installed("RNifti")
    aseg <- array(0L, dim = c(2, 2, 2))
    aseg[1, 1, 1] <- 3L
    aseg[2, 1, 1] <- 42L
    aseg[1, 2, 1] <- 8L
    aseg[2, 2, 1] <- 16L
    # Cerebellar white matter and an unrelated structure are dropped.
    aseg[1, 1, 2] <- 7L
    aseg[2, 1, 2] <- 17L
    resampled <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(aseg), resampled)
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")
    local_mocked_bindings(
      resample_volume_to_grid = function(...) list(file = resampled)
    )

    context <- aseg_context_volume(
      "a.nii.gz",
      "subj",
      c(2L, 2L, 2L),
      array(TRUE, c(2, 2, 2))
    )
    expect_identical(
      sort(unique(as.vector(context))),
      c(0L, 3L, 8L, 16L, 42L)
    )
    expect_identical(context[1, 1, 2], 0L)
    expect_identical(context[2, 1, 2], 0L)
  })

  it("judges the space on the cortical ribbon, not the posterior fossa", {
    skip_if_not_installed("RNifti")
    # The fossa is wanted exactly where the atlas has nothing, so an atlas
    # labelling grey matter only - MarsAtlas - fails the overlap gate if the
    # fossa counts towards it, and loses its context entirely.
    aseg <- array(0L, dim = c(4, 4, 4))
    # nolint next: commas_linter. air formats empty subscripts without spaces.
    aseg[,, 1] <- 3L
    # nolint next: commas_linter. air formats empty subscripts without spaces.
    aseg[,, 2:4] <- 8L
    brain_mask <- array(FALSE, dim = c(4, 4, 4))
    # nolint next: commas_linter. air formats empty subscripts without spaces.
    brain_mask[,, 1] <- TRUE
    resampled <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(aseg), resampled)
    local_mocked_bindings(aseg_volume_path = function(...) "aseg.mgz")
    local_mocked_bindings(
      resample_volume_to_grid = function(...) list(file = resampled)
    )

    context <- aseg_context_volume(
      "a.nii.gz",
      "subj",
      c(4L, 4L, 4L),
      brain_mask
    )

    expect_false(is.null(context))
    expect_true(any(context == 8L))
  })
})


describe("ribbon_lands_on_volume", {
  it("rejects an empty ribbon", {
    ribbon <- array(0L, dim = c(2, 2, 2))
    expect_warning(
      expect_false(ribbon_lands_on_volume(ribbon, array(TRUE, c(2, 2, 2)))),
      "no cortex"
    )
  })

  it("reports the overlap it measured", {
    ribbon <- array(3L, dim = c(4, 1, 1))
    brain <- array(c(TRUE, FALSE, FALSE, FALSE), dim = c(4, 1, 1))
    expect_warning(
      ribbon_lands_on_volume(ribbon, brain),
      "25%"
    )
  })

  it("rejects a ribbon that lands outside the volume", {
    ribbon <- array(3L, dim = c(4, 1, 1))
    brain <- array(c(TRUE, FALSE, FALSE, FALSE), dim = c(4, 1, 1))
    expect_warning(
      expect_false(ribbon_lands_on_volume(ribbon, brain)),
      "not in the same space"
    )
  })

  it("accepts a ribbon that lands on the volume", {
    ribbon <- array(3L, dim = c(4, 1, 1))
    brain <- array(c(TRUE, TRUE, TRUE, FALSE), dim = c(4, 1, 1))
    expect_true(ribbon_lands_on_volume(ribbon, brain))
  })
})
