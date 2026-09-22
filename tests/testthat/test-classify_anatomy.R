# Fixtures for the anatomy label classifier.
write_test_volume <- function(arr) {
  file <- tempfile(fileext = ".nii.gz")
  RNifti::writeNifti(RNifti::asNifti(arr), file)
  file
}

cortical_sheet_volume <- function() {
  arr <- array(0L, dim = c(10L, 10L, 10L))
  arr[2:9, 2:9, 9] <- 1L
  arr[4:6, 4:6, 4:6] <- 2L
  arr
}

cortical_sheet_aseg <- function() {
  aseg <- array(2L, dim = c(10L, 10L, 10L))
  aseg[2:9, 2:9, 9] <- 1001L
  aseg[4:6, 4:6, 4:6] <- 10L
  aseg
}

cortical_sheet_lut <- function() {
  data.frame(
    idx = 1:2,
    label = c("thin_sheet", "deep_blob"),
    R = c(10L, 20L),
    G = c(10L, 20L),
    B = c(10L, 20L),
    A = 0L,
    stringsAsFactors = FALSE
  )
}

# Copies rather than returning source_file, because the production caller
# unlinks whatever it gets back and would take the fixture with it.
mocked_resample <- function(source_file, target, verbose) {
  copy <- tempfile(fileext = ".nii.gz")
  file.copy(source_file, copy)
  copy
}

# Stands in for the FreeSurfer subject: writes the aseg array to a file and
# points the production lookup and resample at it.
local_aseg <- function(aseg = cortical_sheet_aseg(), env = parent.frame()) {
  aseg_file <- write_test_volume(aseg)
  withr::defer(unlink(aseg_file), envir = env)
  local_mocked_bindings(
    aparc_aseg_path = function(subject) aseg_file,
    resample_volume_to_grid = mocked_resample,
    .env = env
  )
}

describe("subcortical_grey_idx()", {
  it("excludes the ventricles, which are CSF and not grey matter", {
    ventricles <- c(4L, 5L, 14L, 15L, 43L, 44L)
    expect_length(intersect(subcortical_grey_idx(), ventricles), 0L)
  })

  it("covers both hemispheres of every deep grey structure", {
    expect_length(subcortical_grey_idx(), 16L)
    expect_true(all(
      c(10L, 17L, 18L, 49L, 53L, 54L) %in% subcortical_grey_idx()
    ))
  })
})


describe("tissue_class()", {
  it("counts the aparc cortical parcels of both hemispheres as cortex", {
    expect_identical(
      as.character(tissue_class(c(1000L, 1035L, 2000L, 2035L, 3L, 42L))),
      rep("cortex", 6L)
    )
  })

  it("does not count wmparc white matter as cortex", {
    expect_identical(
      as.character(tissue_class(c(3000L, 4035L, 5001L, 5002L, 2L, 41L))),
      rep("other", 6L)
    )
  })

  it("does not count ventricles or CSF as any kind of grey", {
    expect_identical(
      as.character(tissue_class(c(4L, 14L, 15L, 43L, 24L))),
      rep("other", 5L)
    )
  })

  it("separates deep, cerebellar and brainstem grey", {
    expect_identical(
      as.character(tissue_class(c(10L, 53L, 8L, 47L, 16L, 7L, 46L))),
      c(
        "subcortex",
        "subcortex",
        "cerebellum",
        "cerebellum",
        "brainstem",
        "other",
        "other"
      )
    )
  })
})


describe("classify_labels_by_anatomy()", {
  it("separates cerebellum before cortex", {
    comp <- data.frame(
      idx = 1:2,
      label = c("tentorium_straddler", "temporal"),
      cortex = c(0.3, 0.9),
      subcortex = c(0, 0),
      cerebellum = c(0.6, 0),
      brainstem = c(0, 0)
    )
    expect_identical(
      classify_labels_by_anatomy(comp),
      c("cerebellar", "cortical")
    )
  })

  it("leaves a cerebellar peduncle label to the brainstem on a tie", {
    comp <- data.frame(
      idx = 1L,
      label = "peduncle",
      cortex = 0,
      subcortex = 0,
      cerebellum = 0.4,
      brainstem = 0.5
    )
    expect_identical(classify_labels_by_anatomy(comp), "subcortical")
  })

  it("keeps a white-matter label out of cortex despite a stray ribbon voxel", {
    comp <- data.frame(
      idx = 1L,
      label = "deep_white",
      cortex = 0.01,
      subcortex = 0,
      cerebellum = 0,
      brainstem = 0
    )
    expect_identical(classify_labels_by_anatomy(comp), "subcortical")
  })

  it("keeps a label out of cerebellum despite a stray cerebellar voxel", {
    comp <- data.frame(
      idx = 1L,
      label = "mostly_unlabelled",
      cortex = 0,
      subcortex = 0,
      cerebellum = 0.01,
      brainstem = 0
    )
    expect_identical(classify_labels_by_anatomy(comp), "subcortical")
  })

  it("calls a label with no labelled grey subcortical", {
    comp <- data.frame(
      idx = 1L,
      label = "unlabelled",
      cortex = 0,
      subcortex = 0,
      cerebellum = 0,
      brainstem = 0
    )
    expect_identical(classify_labels_by_anatomy(comp), "subcortical")
  })
})


describe("lut_classify_anatomy()", {
  it("types a thin cortical sheet cortical and a deep blob subcortical", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()

    result <- lut_classify_anatomy(volume, cortical_sheet_lut(), verbose = 0L)

    expect_s3_class(result, "data.frame")
    expect_identical(result$type, c("cortical", "subcortical"))
    expect_identical(result$label, c("thin_sheet", "deep_blob"))
    expect_identical(result$R, c(10L, 20L))
  })

  it("does not count ventricle voxels as grey matter", {
    arr <- array(0L, dim = c(10L, 10L, 10L))
    arr[1:8, 1, 1] <- 1L
    volume <- write_test_volume(arr)

    aseg <- array(2L, dim = c(10L, 10L, 10L))
    aseg[1:6, 1, 1] <- 4L
    aseg[7:8, 1, 1] <- 1001L
    local_aseg(aseg)

    lut <- data.frame(idx = 1L, label = "beside_ventricle")
    expect_identical(
      lut_classify_anatomy(volume, lut, verbose = 0L)$type,
      "cortical"
    )
  })

  it("reads a LUT given as a file path", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()
    lut_file <- tempfile(fileext = ".txt")
    write_lut(cortical_sheet_lut(), lut_file)

    expect_identical(
      lut_classify_anatomy(volume, lut_file, verbose = 0L)$type,
      c("cortical", "subcortical")
    )
  })

  it("replaces an existing type column", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()
    lut <- cortical_sheet_lut()
    lut$type <- c("subcortical", "cortical")

    expect_identical(
      lut_classify_anatomy(volume, lut, verbose = 0L)$type,
      c("cortical", "subcortical")
    )
  })

  it("types labels the volume does not carry as subcortical, and says so", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()
    lut <- rbind(
      cortical_sheet_lut(),
      data.frame(
        idx = 99L,
        label = "never_drawn",
        R = 1L,
        G = 1L,
        B = 1L,
        A = 0L
      )
    )

    expect_warning(
      result <- lut_classify_anatomy(volume, lut, verbose = 0L),
      "not in the volume"
    )
    expect_identical(
      result$type,
      c("cortical", "subcortical", "subcortical")
    )
  })

  it("reports the split when verbose", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()

    expect_message(
      lut_classify_anatomy(volume, cortical_sheet_lut(), verbose = 1L),
      "1 cortical, 1 subcortical, 0 cerebellar"
    )
  })

  it("writes a type column that survives a LUT round trip", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()
    lut_file <- tempfile(fileext = ".txt")

    typed <- lut_classify_anatomy(volume, cortical_sheet_lut(), verbose = 0L)
    write_lut(typed, lut_file)

    expect_identical(read_lut(lut_file)$type, typed$type)
  })

  it("honours a raised min_cortical", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()
    lut <- data.frame(idx = 1L, label = "half_cortical")

    # The sheet is wholly cortical, so only a threshold above 1 excludes it.
    expect_identical(
      lut_classify_anatomy(volume, lut, min_cortical = 1, verbose = 0L)$type,
      "cortical"
    )
  })

  it("honours a raised min_fraction", {
    arr <- array(0L, dim = c(10L, 10L, 10L))
    arr[1:10, 1, 1] <- 1L
    volume <- write_test_volume(arr)

    aseg <- array(2L, dim = c(10L, 10L, 10L))
    aseg[1, 1, 1] <- 1001L
    local_aseg(aseg)
    lut <- data.frame(idx = 1L, label = "one_ribbon_voxel")

    expect_identical(
      lut_classify_anatomy(volume, lut, min_fraction = 0.05, verbose = 0L)$type,
      "cortical"
    )
    expect_identical(
      lut_classify_anatomy(volume, lut, min_fraction = 0.2, verbose = 0L)$type,
      "subcortical"
    )
  })

  it("leaves the background label untyped and does not call it absent", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()
    lut <- rbind(
      data.frame(
        idx = 0L,
        label = "Unknown",
        R = 0L,
        G = 0L,
        B = 0L,
        A = 0L
      ),
      cortical_sheet_lut()
    )

    result <- NULL
    expect_no_warning(
      result <- lut_classify_anatomy(volume, lut, verbose = 0L)
    )
    expect_identical(result$type, c(NA, "cortical", "subcortical"))
  })

  it("errors on a repeated label, which would mistype a row", {
    volume <- write_test_volume(cortical_sheet_volume())
    lut <- data.frame(idx = 1:2, label = c("same", "same"))
    expect_error(
      lut_classify_anatomy(volume, lut),
      "repeated .*label"
    )
  })

  it("errors on a repeated idx", {
    volume <- write_test_volume(cortical_sheet_volume())
    lut <- data.frame(idx = c(1L, 1L), label = c("a", "b"))
    expect_error(
      lut_classify_anatomy(volume, lut),
      "repeated .*idx"
    )
  })

  it("errors on an empty LUT", {
    volume <- write_test_volume(cortical_sheet_volume())
    expect_error(
      lut_classify_anatomy(
        volume,
        data.frame(idx = integer(), label = character())
      ),
      "no rows to classify"
    )
  })

  it("errors on a threshold that is not a share", {
    volume <- write_test_volume(cortical_sheet_volume())
    expect_error(
      lut_classify_anatomy(volume, cortical_sheet_lut(), min_cortical = "0.6"),
      "min_cortical.*must be a single number between 0 and 1"
    )
    expect_error(
      lut_classify_anatomy(volume, cortical_sheet_lut(), min_cerebellar = 2),
      "min_cerebellar.*must be a single number between 0 and 1"
    )
  })

  it("errors when the volume does not exist", {
    expect_error(
      lut_classify_anatomy("no-such-volume.nii.gz", cortical_sheet_lut()),
      "Volume file not found"
    )
  })

  it("errors when the LUT is neither a path nor a usable data.frame", {
    volume <- write_test_volume(cortical_sheet_volume())
    expect_error(
      lut_classify_anatomy(volume, data.frame(x = 1)),
      "must be a LUT file path or a data.frame"
    )
  })
})


describe("lut_classify_anatomy() space guards", {
  it("refuses an aseg that lands outside the volume's brain", {
    arr <- array(0L, dim = c(10L, 10L, 10L))
    arr[1:4, 1:4, 1] <- 1L
    volume <- write_test_volume(arr)

    aseg <- array(0L, dim = c(10L, 10L, 10L))
    aseg[1:4, 1:4, 10] <- 1001L
    local_aseg(aseg)

    lut <- data.frame(idx = 1L, label = "somewhere_else")
    expect_error(
      lut_classify_anatomy(volume, lut, verbose = 0L),
      "not in the same space"
    )
  })

  it("refuses an aseg on a different grid", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg(array(1001L, dim = c(8L, 8L, 8L)))

    expect_error(
      lut_classify_anatomy(volume, cortical_sheet_lut(), verbose = 0L),
      "does not share the volume's grid"
    )
  })

  it("refuses an aseg with no grey matter at all", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg(array(2L, dim = c(10L, 10L, 10L)))

    expect_error(
      lut_classify_anatomy(volume, cortical_sheet_lut(), verbose = 0L),
      "no grey matter"
    )
  })

  it("refuses when no LUT label has a voxel in the volume", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_aseg()

    lut <- data.frame(idx = 99L, label = "absent")
    expect_error(
      lut_classify_anatomy(volume, lut, verbose = 0L),
      "has a single voxel"
    )
  })

  it("refuses an unreadable volume", {
    volume <- tempfile(fileext = ".nii.gz")
    file.create(volume)
    local_aseg()

    expect_error(
      lut_classify_anatomy(volume, cortical_sheet_lut(), verbose = 0L),
      "not a readable 3D volume"
    )
  })
})


describe("aparc_aseg_path()", {
  it("errors when FreeSurfer is not available", {
    local_mocked_bindings(have_fs_quietly = function() FALSE)
    expect_error(
      aparc_aseg_path("cvs_avg35_inMNI152"),
      "FreeSurfer is not available"
    )
  })

  it("errors when the freesurfer package is not installed", {
    local_mocked_bindings(have_fs_quietly = function() TRUE)
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_error(
      aparc_aseg_path("cvs_avg35_inMNI152"),
      "FreeSurfer is not available"
    )
  })

  it("errors when the subject has no aparc\\+aseg", {
    local_mocked_bindings(have_fs_quietly = function() TRUE)
    subjects <- withr::local_tempdir()
    local_mocked_bindings(
      fs_subj_dir = function() subjects,
      .package = "freesurfer"
    )
    expect_error(
      aparc_aseg_path("no_such_subject"),
      "does not exist"
    )
  })
})


describe("resample_volume_to_grid()", {
  it("returns NULL when mri_vol2vol fails", {
    # The resampler is shared with the whole-brain context pipeline, which
    # warns where this one aborts, so the failure is the caller's to report.
    local_mocked_bindings(run_cmd = function(...) stop("no freesurfer"))
    expect_null(
      resample_volume_to_grid("aseg.mgz", "target.nii.gz", verbose = 0L)
    )
  })

  it("is reported as an anatomy failure by the caller", {
    local_mocked_bindings(aparc_aseg_path = function(subject) "aseg.mgz")
    local_mocked_bindings(run_cmd = function(...) stop("no freesurfer"))
    expect_error(
      aparc_aseg_on_grid(
        "aseg.mgz",
        write_test_volume(cortical_sheet_volume()),
        c(10L, 10L, 10L),
        array(TRUE, c(10, 10, 10)),
        verbose = 0L
      ),
      "mri_vol2vol.*failed"
    )
  })
})
