describe("aseg_subcortical_labels", {
  it("returns the 14 lumped subcortical aseg ids as integers", {
    ids <- aseg_subcortical_labels()
    expect_type(ids, "integer")
    expect_length(ids, 14)
    # thalamus, hippocampus, accumbens (left/right)
    expect_true(all(c(10L, 49L, 17L, 53L, 26L, 58L) %in% ids))
    # cortex / white matter must NOT be in the replaced set
    expect_false(any(c(2L, 41L, 3L, 42L) %in% ids))
  })
})

describe("embed_labels_in_aseg", {
  it("blanks replaced structures and stamps parcels, keeping other context", {
    # 10, 49 = replaced subcortical; 42 = cortex, 2 = white matter (context)
    aseg <- array(c(10L, 42L, 49L, 2L), dim = c(2, 2, 1))
    parcels <- array(c(211L, 0L, 0L, 0L), dim = c(2, 2, 1))

    out <- embed_labels_in_aseg(aseg, parcels, c(10L, 49L))

    expect_identical(out[1, 1, 1], 211L) # parcel stamped where thalamus was
    expect_identical(out[2, 1, 1], 42L) # cortex context preserved
    expect_identical(out[1, 2, 1], 0L) # replaced structure blanked, no parcel
    expect_identical(out[2, 2, 1], 2L) # white-matter context preserved
  })

  it("lets parcels win over surviving context where they overlap", {
    aseg <- array(c(42L, 42L), dim = c(2, 1, 1))
    parcels <- array(c(300L, 0L), dim = c(2, 1, 1))

    out <- embed_labels_in_aseg(aseg, parcels, integer(0))

    expect_identical(out[1, 1, 1], 300L) # parcel overrides cortex
    expect_identical(out[2, 1, 1], 42L) # untouched context kept
  })

  it("preserves the input dimensions", {
    aseg <- array(sample(0:60, 24, replace = TRUE), dim = c(2, 3, 4))
    parcels <- array(0L, dim = c(2, 3, 4))
    out <- embed_labels_in_aseg(aseg, parcels, aseg_subcortical_labels())
    expect_identical(dim(out), c(2L, 3L, 4L))
  })
})

describe("validate_labels_clear_of_aseg", {
  it("aborts when a parcel id is also a surviving aseg id", {
    aseg <- array(c(0L, 16L, 42L, 10L), dim = c(2, 2, 1))

    expect_error(
      validate_labels_clear_of_aseg(c(16L, 1001L), aseg, c(10L, 49L)),
      "16"
    )
  })

  it("accepts parcel ids clear of the aseg context", {
    aseg <- array(c(0L, 16L, 42L, 10L), dim = c(2, 2, 1))

    expect_no_error(validate_labels_clear_of_aseg(
      c(1001L, 1002L),
      aseg,
      c(10L, 49L)
    ))
  })

  it("accepts parcel ids that reuse a replaced aseg id", {
    aseg <- array(c(0L, 16L, 42L, 10L), dim = c(2, 2, 1))

    expect_no_error(validate_labels_clear_of_aseg(10L, aseg, c(10L, 49L)))
  })
})

describe("prepare_subcortical_mni152", {
  it("embeds MNI152 parcels into the fsaverage5 aseg context", {
    skip_if(!freesurfer::have_fs(), "FreeSurfer not available")

    aseg_mgz <- fsaverage5_file("mri", "aseg.mgz")
    skip_if(!file.exists(aseg_mgz), "fsaverage5 aseg not available")
    reg <- file.path(freesurfer::fs_dir(), "average", "mni152.register.dat")
    skip_if(!file.exists(reg), "mni152.register.dat not available")

    # a minimal parcellation on the FSL-MNI152 1mm grid with two central blobs
    arr <- array(0L, dim = c(182L, 218L, 182L))
    arr[89:93, 108:112, 90:94] <- 211L
    arr[95:99, 108:112, 90:94] <- 212L
    vol <- RNifti::asNifti(arr)
    RNifti::pixdim(vol) <- c(1, 1, 1)
    # FreeSurfer refuses to orient a volume with no valid qform or sform and
    # says so on stderr, so give the fixture the real FSL-MNI152 1mm affine.
    RNifti::sform(vol) <- structure(
      matrix(
        c(-1, 0, 0, 90, 0, 1, 0, -126, 0, 0, 1, -72, 0, 0, 0, 1),
        nrow = 4,
        byrow = TRUE
      ),
      code = 4L
    )
    in_path <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(vol, in_path)

    merged <- prepare_subcortical_mni152(
      input_volume = in_path,
      labels = c(211L, 212L),
      verbose = FALSE
    )

    expect_named(merged, c("volume", "lut"))
    expect_true(file.exists(merged$volume))
    expect_true(all(c("idx", "label", "R", "G", "B") %in% names(merged$lut)))
    # the two parcels are named in the returned colour table
    expect_true(all(c(211L, 212L) %in% merged$lut$idx))
  })
})


describe("prepare_subcortical_mni152 registration call", {
  # The end-to-end test above needs a real FreeSurfer, so it is skipped
  # wherever CI runs. This covers the one thing the mri_vol2vol call has to
  # get right: nearest-neighbour resampling of the resolved registration.
  # Anything else turns integer parcel ids into values the volume never held.
  it("resamples the parcels onto the aseg grid with nearest neighbour", {
    skip_if_not_installed("freesurfer")
    skip_if_not_installed("RNifti")

    dims <- c(4L, 4L, 4L)
    write_vol <- function(arr, path) {
      RNifti::writeNifti(RNifti::asNifti(arr), path)
      path
    }

    parcels <- array(0L, dim = dims)
    parcels[1, 1, 1] <- 211L
    parcels[2, 1, 1] <- 212L
    in_path <- withr::local_tempfile(fileext = ".nii.gz")
    write_vol(parcels, in_path)

    # Context the parcels subdivide (10) plus context that survives (2).
    aseg <- array(2L, dim = dims)
    aseg[1:2, 1, 1] <- 10L

    subjects_dir <- withr::local_tempdir()
    dir.create(
      file.path(subjects_dir, "fsaverage5", "mri"),
      recursive = TRUE
    )
    aseg_mgz <- file.path(subjects_dir, "fsaverage5", "mri", "aseg.mgz")
    file.create(aseg_mgz)

    seen <- new.env(parent = emptyenv())
    local_mocked_bindings(check_fs = function(...) TRUE)
    local_mocked_bindings(
      read_fs_color_lut = function() {
        data.frame(
          stringsAsFactors = FALSE,
          idx = 2L,
          label = "wm",
          R = 1L,
          G = 1L,
          B = 1L,
          A = 0L
        )
      }
    )
    local_mocked_bindings(
      mri_convert = function(file, outfile, ...) write_vol(aseg, outfile),
      mri_vol2vol = function(mov, targ, reg, outfile, interp, ...) {
        # Read while it is still there: the mov volume is a tempfile the
        # caller unlinks on exit.
        seen$mov_ids <- sort(unique(as.integer(
          as.array(RNifti::readNifti(mov))
        )))
        seen$targ <- targ
        seen$reg <- reg
        seen$interp <- interp
        write_vol(parcels, outfile)
      },
      .package = "freesurfer"
    )

    merged <- prepare_subcortical_mni152(
      input_volume = in_path,
      labels = c(211L, 212L),
      registration = "header",
      subjects_dir = subjects_dir,
      verbose = FALSE
    )

    expect_identical(seen$interp, "nearest")
    expect_identical(seen$reg, "header")
    expect_identical(seen$targ, as.character(fs::path(aseg_mgz)))
    # Only the requested parcels are handed over to be resampled.
    expect_identical(seen$mov_ids, c(0L, 211L, 212L))

    out <- as.array(RNifti::readNifti(merged$volume))
    # The parcels replaced the structure they subdivide; the rest stayed.
    expect_identical(out[1, 1, 1], 211L)
    expect_identical(out[2, 1, 1], 212L)
    expect_identical(out[4, 4, 4], 2L)
  })
})


describe("check_fs_output", {
  it("passes a file the command wrote", {
    output <- withr::local_tempfile()
    writeLines("data", output)

    expect_identical(check_fs_output(output, "mri_convert", "aseg.mgz"), output)
  })

  it("aborts when the command left nothing, or an empty file", {
    missing <- withr::local_tempfile()
    empty <- withr::local_tempfile()
    file.create(empty)

    expect_error(
      check_fs_output(missing, "mri_convert", "aseg.mgz"),
      "mri_convert.*produced no output"
    )
    expect_error(
      check_fs_output(empty, "mri_vol2vol", "parcels.nii.gz"),
      "mri_vol2vol.*produced no output"
    )
  })
})
