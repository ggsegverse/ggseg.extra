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

describe("prepare_subcortical_mni152", {
  it("embeds MNI152 parcels into the fsaverage5 aseg context", {
    skip_if(!freesurfer::have_fs(), "FreeSurfer not available")

    aseg_mgz <- file.path(
      freesurfer::fs_subj_dir(),
      "fsaverage5",
      "mri",
      "aseg.mgz"
    )
    skip_if(!file.exists(aseg_mgz), "fsaverage5 aseg not available")
    reg <- file.path(freesurfer::fs_dir(), "average", "mni152.register.dat")
    skip_if(!file.exists(reg), "mni152.register.dat not available")

    # a minimal parcellation on the FSL-MNI152 1mm grid with two central blobs
    arr <- array(0L, dim = c(182L, 218L, 182L))
    arr[89:93, 108:112, 90:94] <- 211L
    arr[95:99, 108:112, 90:94] <- 212L
    vol <- RNifti::asNifti(arr)
    RNifti::pixdim(vol) <- c(1, 1, 1)
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
