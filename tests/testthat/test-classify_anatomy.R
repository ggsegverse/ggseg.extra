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

mocked_resample <- function(source_file, target, verbose) {
  copy <- tempfile(fileext = ".nii.gz")
  file.copy(source_file, copy)
  copy
}

small_atlas_data <- function(labels, vertex_counts) {
  bind_rows(mapply(
    function(lbl, n) {
      tibble(
        hemi = "left",
        region = lbl,
        label = paste0("lh_", lbl),
        colour = "#FF0000",
        vertices = list(seq_len(n) - 1L),
        source_label = lbl,
        source_idx = match(lbl, labels)
      )
    },
    labels,
    vertex_counts,
    SIMPLIFY = FALSE
  ))
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


describe("label_composition()", {
  it("measures where each label sits, not how large it is", {
    volume <- write_test_volume(cortical_sheet_volume())
    aseg_file <- write_test_volume(cortical_sheet_aseg())
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )
    lut <- data.frame(
      idx = 1:2,
      label = c("thin_sheet", "deep_blob"),
      stringsAsFactors = FALSE
    )

    comp <- label_composition(volume, lut, verbose = 0L)

    expect_identical(comp$label, c("thin_sheet", "deep_blob"))
    expect_identical(comp$cortex, c(1, 0))
    expect_identical(comp$subcortex, c(0, 1))
  })

  it("does not count ventricle voxels as grey matter", {
    arr <- array(0L, dim = c(10L, 10L, 10L))
    arr[1:8, 1, 1] <- 1L
    volume <- write_test_volume(arr)

    aseg <- array(2L, dim = c(10L, 10L, 10L))
    aseg[1:6, 1, 1] <- 4L
    aseg[7:8, 1, 1] <- 1001L
    aseg_file <- write_test_volume(aseg)
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )

    lut <- data.frame(idx = 1L, label = "beside_ventricle")
    comp <- label_composition(volume, lut, verbose = 0L)

    expect_identical(comp$subcortex, 0)
    expect_equal(comp$cortex, 0.25)
    expect_identical(
      classify_labels_by_anatomy(comp)$cortical,
      "beside_ventricle"
    )
  })

  it("refuses an aseg that lands outside the volume's brain", {
    arr <- array(0L, dim = c(10L, 10L, 10L))
    arr[1:4, 1:4, 1] <- 1L
    volume <- write_test_volume(arr)

    aseg <- array(0L, dim = c(10L, 10L, 10L))
    aseg[1:4, 1:4, 10] <- 1001L
    aseg_file <- write_test_volume(aseg)
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )

    lut <- data.frame(idx = 1L, label = "somewhere_else")
    expect_warning(
      expect_null(label_composition(volume, lut, verbose = 0L)),
      "not in the same space"
    )
  })

  it("refuses an aseg on a different grid", {
    volume <- write_test_volume(cortical_sheet_volume())
    aseg_file <- write_test_volume(array(1001L, dim = c(8L, 8L, 8L)))
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )

    lut <- data.frame(idx = 1L, label = "thin_sheet")
    expect_warning(
      expect_null(label_composition(volume, lut, verbose = 0L)),
      "does not share the volume's grid"
    )
  })

  it("refuses an aseg with no grey matter at all", {
    volume <- write_test_volume(cortical_sheet_volume())
    aseg_file <- write_test_volume(array(2L, dim = c(10L, 10L, 10L)))
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )

    lut <- data.frame(idx = 1L, label = "thin_sheet")
    expect_warning(
      expect_null(label_composition(volume, lut, verbose = 0L)),
      "no grey matter"
    )
  })

  it("returns NULL when FreeSurfer has no aparc\\+aseg to offer", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_mocked_bindings(aparc_aseg_path = function(subject) NULL)

    lut <- data.frame(idx = 1L, label = "thin_sheet")
    expect_null(label_composition(volume, lut, verbose = 0L))
  })

  it("returns NULL when no lookup-table label has any voxel", {
    volume <- write_test_volume(cortical_sheet_volume())
    aseg_file <- write_test_volume(cortical_sheet_aseg())
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )

    lut <- data.frame(idx = 99L, label = "absent")
    expect_warning(
      expect_null(label_composition(volume, lut, verbose = 0L)),
      "no lookup-table label has any voxel"
    )
  })

  it("returns NULL when the volume cannot be read", {
    volume <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(volume)
    aseg_file <- write_test_volume(cortical_sheet_aseg())
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )

    lut <- data.frame(idx = 1L, label = "thin_sheet")
    expect_warning(
      expect_null(label_composition(volume, lut, verbose = 0L)),
      "not a readable 3D volume"
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
    result <- classify_labels_by_anatomy(comp)
    expect_identical(result$cerebellar, "tentorium_straddler")
    expect_identical(result$cortical, "temporal")
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
    expect_identical(classify_labels_by_anatomy(comp)$subcortical, "deep_white")
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
    expect_identical(classify_labels_by_anatomy(comp)$subcortical, "unlabelled")
  })
})


describe("wholebrain_classify_labels() anatomy priority", {
  it("calls a thin cortical sheet cortical even below min_vertices", {
    volume <- write_test_volume(cortical_sheet_volume())
    aseg_file <- write_test_volume(cortical_sheet_aseg())
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )
    ad <- small_atlas_data(c("thin_sheet", "deep_blob"), c(20, 19))
    ct <- data.frame(
      idx = 1:2,
      label = c("thin_sheet", "deep_blob"),
      stringsAsFactors = FALSE
    )

    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      volume = volume,
      min_vertices = 50L
    )

    expect_identical(result$cortical_labels, "thin_sheet")
    expect_identical(result$subcortical_labels, "deep_blob")
  })

  it("leaves labels with no voxels of their own subcortical", {
    volume <- write_test_volume(cortical_sheet_volume())
    aseg_file <- write_test_volume(cortical_sheet_aseg())
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )
    ad <- small_atlas_data("thin_sheet", 20)
    ct <- data.frame(
      idx = c(1L, 99L),
      label = c("thin_sheet", "never_drawn"),
      stringsAsFactors = FALSE
    )

    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      volume = volume,
      min_vertices = 50L
    )

    expect_identical(result$cortical_labels, "thin_sheet")
    expect_identical(result$subcortical_labels, "never_drawn")
  })

  it("never overrides an explicit type column", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_mocked_bindings(
      label_composition = function(...) {
        cli::cli_abort("Anatomy must not run when the LUT declares a type")
      }
    )
    ad <- small_atlas_data(c("thin_sheet", "deep_blob"), c(20, 19))
    ct <- data.frame(
      idx = 1:2,
      label = c("thin_sheet", "deep_blob"),
      type = c("subcortical", "cortical"),
      stringsAsFactors = FALSE
    )

    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      volume = volume,
      min_vertices = 50L
    )

    expect_identical(result$cortical_labels, "deep_blob")
    expect_identical(result$subcortical_labels, "thin_sheet")
  })

  it("never overrides explicit label vectors", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_mocked_bindings(
      label_composition = function(...) {
        cli::cli_abort("Anatomy must not run when labels are given explicitly")
      }
    )
    ad <- small_atlas_data(c("thin_sheet", "deep_blob"), c(20, 19))
    ct <- data.frame(
      idx = 1:2,
      label = c("thin_sheet", "deep_blob"),
      stringsAsFactors = FALSE
    )

    result <- wholebrain_classify_labels(
      ad,
      colortable = ct,
      volume = volume,
      min_vertices = 50L,
      subcortical_labels = "thin_sheet",
      cortical_labels = "deep_blob"
    )

    expect_identical(result$cortical_labels, "deep_blob")
    expect_identical(result$subcortical_labels, "thin_sheet")
  })

  it("reports the anatomical classification when verbose", {
    volume <- write_test_volume(cortical_sheet_volume())
    aseg_file <- write_test_volume(cortical_sheet_aseg())
    local_mocked_bindings(
      aparc_aseg_path = function(subject) aseg_file,
      resample_volume_to_grid = mocked_resample
    )
    ad <- small_atlas_data(c("thin_sheet", "deep_blob"), c(20, 19))
    ct <- data.frame(
      idx = 1:2,
      label = c("thin_sheet", "deep_blob"),
      stringsAsFactors = FALSE
    )

    expect_messages(
      wholebrain_classify_labels(
        ad,
        colortable = ct,
        volume = volume,
        min_vertices = 50L,
        verbose = TRUE
      ),
      "Classified 2 labels by aparc\\+aseg anatomy"
    )
  })
})


describe("wholebrain_classify_labels() vertex-count fallback", {
  it("falls back to the vertex count without a volume, and warns", {
    ad <- small_atlas_data(c("big", "small"), c(100, 10))

    expect_warning(
      result <- wholebrain_classify_labels(ad, min_vertices = 50L),
      "Classified 2 labels by surface vertex count, not by anatomy"
    )

    expect_identical(result$cortical_labels, "big")
    expect_identical(result$subcortical_labels, "small")
  })

  it("falls back when the colortable has no idx column", {
    volume <- write_test_volume(cortical_sheet_volume())
    ad <- small_atlas_data(c("big", "small"), c(100, 10))
    ct <- data.frame(label = c("big", "small"), stringsAsFactors = FALSE)

    expect_warning(
      result <- wholebrain_classify_labels(
        ad,
        colortable = ct,
        volume = volume,
        min_vertices = 50L
      ),
      "by surface vertex count"
    )
    expect_identical(result$cortical_labels, "big")
  })

  it("falls back when FreeSurfer cannot supply an aparc\\+aseg", {
    volume <- write_test_volume(cortical_sheet_volume())
    local_mocked_bindings(have_fs_quietly = function() FALSE)
    ad <- small_atlas_data(c("big", "small"), c(100, 10))
    ct <- data.frame(
      idx = 1:2,
      label = c("big", "small"),
      stringsAsFactors = FALSE
    )

    expect_warning(
      expect_warning(
        result <- wholebrain_classify_labels(
          ad,
          colortable = ct,
          volume = volume,
          min_vertices = 50L
        ),
        "FreeSurfer is not available"
      ),
      "by surface vertex count"
    )
    expect_identical(result$cortical_labels, "big")
  })

  it("stays quiet when nothing is left for it to guess at", {
    ad <- small_atlas_data(c("big", "small"), c(100, 10))
    expect_no_warning(
      wholebrain_classify_labels(
        ad,
        min_vertices = 50L,
        cortical_labels = "big",
        subcortical_labels = "small"
      )
    )
  })
})


describe("aparc_aseg_path()", {
  it("warns when FreeSurfer is not available", {
    local_mocked_bindings(have_fs_quietly = function() FALSE)
    expect_warning(
      expect_null(aparc_aseg_path("cvs_avg35_inMNI152")),
      "FreeSurfer is not available"
    )
  })

  it("warns when the subject has no aparc\\+aseg", {
    local_mocked_bindings(have_fs_quietly = function() TRUE)
    local_mocked_bindings(
      fs_subj_dir = function() {
        withr::local_tempdir(.local_envir = parent.frame(2))
      },
      .package = "freesurfer"
    )
    expect_warning(
      expect_null(aparc_aseg_path("no_such_subject")),
      "does not exist"
    )
  })
})


describe("resample_volume_to_grid()", {
  it("warns and returns NULL when mri_vol2vol fails", {
    local_mocked_bindings(run_cmd = function(...) stop("no freesurfer"))
    expect_warning(
      expect_null(
        resample_volume_to_grid("aseg.mgz", "target.nii.gz", verbose = 0L)
      ),
      "mri_vol2vol.*failed"
    )
  })
})
