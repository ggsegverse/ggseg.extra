describe("coregister_volume validation", {
  it("errors for invalid dof", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    expect_error(
      coregister_volume(vol_file, dof = 7, verbose = FALSE),
      "dof.*must be 6, 9, or 12"
    )
  })

  it("errors when input volume does not exist", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    expect_error(
      coregister_volume("does/not/exist.nii.gz", verbose = FALSE),
      "Volume not found"
    )
  })

  it("errors when input is neither path nor RNifti", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    expect_error(
      coregister_volume(123, verbose = FALSE),
      "must be a path or an"
    )
  })

  it("errors when target subject volume is missing", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)
    fake_dir <- withr::local_tempdir()

    expect_error(
      coregister_volume(
        vol_file,
        target_subject = "no_such_subject",
        subjects_dir = fake_dir,
        verbose = FALSE
      ),
      "Target volume not found"
    )
  })
})

describe("project_volume_anatomical validation", {
  it("errors for threshold outside [0, 1]", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    for (val in list(-0.1, 1.5, "0.5")) {
      expect_error(
        project_volume_anatomical(
          vol_file,
          threshold = val,
          verbose = FALSE
        ),
        "threshold.*must be in"
      )
    }
  })

  it("errors for invalid id_offset", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)

    for (val in list(-1, 1.5, "200")) {
      expect_error(
        project_volume_anatomical(
          vol_file,
          id_offset = val,
          verbose = FALSE
        ),
        "id_offset.*must be a non-negative integer"
      )
    }
  })

  it("errors when target aparc+aseg is missing", {
    local_mocked_bindings(check_fs = function(...) TRUE)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)
    fake_dir <- withr::local_tempdir()

    expect_error(
      project_volume_anatomical(
        vol_file,
        target_subject = "no_such_subject",
        subjects_dir = fake_dir,
        verbose = FALSE
      ),
      "aparc\\+aseg not found"
    )
  })
})

describe("read_lut_arg", {
  it("accepts a data frame with idx column", {
    df <- data.frame(idx = 1:3, label = c("a", "b", "c"))
    expect_identical(read_lut_arg(df), df)
  })

  it("errors on data frame missing idx column", {
    df <- data.frame(label = c("a", "b"))
    expect_error(
      read_lut_arg(df),
      "must have an"
    )
  })

  it("reads a TSV file", {
    f <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("1\tFoo\t10\t20\t30\t0", "2\tBar\t40\t50\t60\t0"), f)
    out <- read_lut_arg(f)
    expect_identical(out$idx, c(1L, 2L))
    expect_identical(out$label, c("Foo", "Bar"))
  })

  it("errors on missing file path", {
    expect_error(
      read_lut_arg("nope.tsv"),
      "file not found"
    )
  })

  it("errors on unsupported input type", {
    expect_error(
      read_lut_arg(42),
      "must be a data frame or path"
    )
  })
})

describe("resolve_volume_path", {
  it("returns the path for an existing file", {
    f <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(f)
    expect_identical(resolve_volume_path(f), f)
  })

  it("errors for missing path", {
    expect_error(
      resolve_volume_path("does/not/exist.nii.gz"),
      "Volume not found"
    )
  })

  it("errors for non-character non-RNifti input", {
    expect_error(
      resolve_volume_path(42),
      "must be a path or an"
    )
  })
})

describe("prepare_subcortical_anatomical", {
  it("threads the registration from coregister into the projection", {
    seen <- NULL
    result <- list(volume = "merged.nii.gz", lut = NULL, id_offset = 200L)
    local_mocked_bindings(
      coregister_volume = function(...) "registration.lta",
      project_volume_anatomical = function(registration, ...) {
        seen <<- registration
        result
      }
    )

    out <- prepare_subcortical_anatomical(
      input_volume = "atlas.nii.gz",
      verbose = FALSE
    )

    expect_equal(seen, "registration.lta")
    expect_equal(out, result)
  })
})

describe("resolve_label_ids", {
  arr <- array(c(0L, 11L, 12L, 0L, 17L, 0L, 0L, 99L), dim = c(2, 2, 2))

  it("derives labels from the lut, intersected with the volume", {
    lut <- data.frame(idx = c(11L, 12L, 17L, 500L))
    expect_identical(
      resolve_label_ids(arr, "atlas.nii.gz", lut),
      c(11L, 12L, 17L)
    )
  })

  it("errors when no lut index is present in the volume", {
    lut <- data.frame(idx = c(500L, 600L))
    expect_error(
      resolve_label_ids(arr, "atlas.nii.gz", lut),
      "None of the .* present in"
    )
  })

  it("falls back to all non-zero labels with no lut", {
    expect_identical(
      resolve_label_ids(arr, "atlas.nii.gz"),
      c(11L, 12L, 17L, 99L)
    )
  })
})

describe("project_label_argmax", {
  it("streams a per-voxel argmax with first-label tie-breaking", {
    probs <- list(
      `11` = c(0.1, 0.0, 0.5, 0.0),
      `12` = c(0.2, 0.0, 0.5, 0.0),
      `13` = c(0.0, 0.0, 0.0, 0.0)
    )
    local_mocked_bindings(
      resample_label_probability = function(id, ...) probs[[as.character(id)]]
    )

    out <- project_label_argmax(
      label_ids = c(11L, 12L, 13L),
      arr = NULL,
      vol = NULL,
      aparc_mgz = NULL,
      registration = NULL,
      n_voxels = 4L,
      verbose = FALSE
    )

    expect_identical(out$argmax_idx, c(2L, 0L, 1L, 0L))
    expect_equal(out$max_prob, c(0.2, 0.0, 0.5, 0.0))
  })
})

describe("build_merged_volume", {
  it("writes shifted ids at kept voxels and keeps aparc elsewhere", {
    arr_aparc <- matrix(c(2L, 17L, 1011L, 0L), 2, 2)
    merged <- build_merged_volume(
      arr_aparc = arr_aparc,
      keep = c(FALSE, TRUE, FALSE, TRUE),
      argmax_idx = c(1L, 1L, 2L, 2L),
      label_ids = c(11L, 12L),
      id_offset = 200L
    )
    expect_identical(as.vector(merged), c(2L, 211L, 1011L, 212L))
    expect_identical(dim(merged), c(2L, 2L))
  })
})

describe("apply_cortex_protection", {
  # 2/41 cerebral WM, 1011 cortex, 253 corpus callosum -> protected;
  # 17/50 subcortical gray -> overwritable.
  arr_aparc <- c(2L, 17L, 1011L, 41L, 50L, 253L)

  it("drops cortex, cerebral-WM, and corpus-callosum voxels", {
    keep <- apply_cortex_protection(
      rep(TRUE, 6),
      arr_aparc,
      protect_cortex = TRUE,
      verbose = FALSE
    )
    expect_identical(keep, c(FALSE, TRUE, FALSE, FALSE, TRUE, FALSE))
  })

  it("is a no-op when protect_cortex is FALSE", {
    keep <- rep(TRUE, 6)
    expect_identical(
      apply_cortex_protection(keep, arr_aparc, FALSE, FALSE),
      keep
    )
  })
})

describe("lta_dst_dims / check_registration_grid", {
  write_lta <- function(dst_volume = "256 256 256", with_dst = TRUE) {
    f <- tempfile(fileext = ".lta")
    lines <- c(
      "type      = 1",
      "nxforms   = 1",
      "1 4 4",
      "1.0 0.0 0.0 0.0",
      "0.0 1.0 0.0 0.0",
      "0.0 0.0 1.0 0.0",
      "0.0 0.0 0.0 1.0",
      "src volume info",
      "valid = 1",
      "volume = 91 109 91",
      "voxelsize = 2.0 2.0 2.0"
    )
    if (with_dst) {
      lines <- c(
        lines,
        "dst volume info",
        "valid = 1",
        paste("volume =", dst_volume),
        "voxelsize = 1.0 1.0 1.0"
      )
    }
    writeLines(lines, f)
    f
  }

  it("reads the dst dims, not the src dims", {
    expect_identical(lta_dst_dims(write_lta()), c(256L, 256L, 256L))
  })

  it("returns NULL when there is no dst block", {
    expect_null(lta_dst_dims(write_lta(with_dst = FALSE)))
  })

  it("passes when the registration grid matches", {
    expect_null(check_registration_grid(write_lta(), c(256L, 256L, 256L)))
  })

  it("is a no-op when registration is NULL", {
    expect_null(check_registration_grid(NULL, c(256L, 256L, 256L)))
  })

  it("aborts when the registration grid differs", {
    expect_error(
      check_registration_grid(write_lta("128 128 128"), c(256L, 256L, 256L)),
      "does not match the"
    )
  })
})

describe("resolve_user_lut", {
  it("shifts supplied label ids and drops unprojected rows", {
    lut <- data.frame(
      idx = c(11L, 12L, 13L),
      label = c("Foo", "Bar", "Baz"),
      R = c(1L, 2L, 3L),
      G = c(1L, 2L, 3L),
      B = c(1L, 2L, 3L),
      A = 0L
    )
    out <- resolve_user_lut(lut, label_ids = c(11L, 12L), id_offset = 200L)
    expect_identical(out$idx, c(211L, 212L))
    expect_identical(out$label, c("Foo", "Bar"))
  })

  it("generates generic names and a palette when lut is NULL", {
    out <- resolve_user_lut(NULL, label_ids = c(11L, 12L), id_offset = 200L)
    expect_identical(out$idx, c(211L, 212L))
    expect_identical(out$label, c("region_0011", "region_0012"))
    expect_true(is_ctab(out))
    expect_type(out$R, "integer")
  })

  it("errors when the supplied lut is not a colour table", {
    expect_error(
      resolve_user_lut(data.frame(idx = 1L), label_ids = 1L, id_offset = 0L),
      "must be a colour table"
    )
  })
})

describe("build_anatomical_lut", {
  fs_lut <- function() {
    data.frame(
      idx = c(2L, 41L, 17L, 1011L),
      label = c(
        "Left-Cerebral-White-Matter",
        "Right-Cerebral-White-Matter",
        "Left-Hippocampus",
        "ctx-lh-precuneus"
      ),
      R = c(10L, 20L, 30L, 40L),
      G = c(10L, 20L, 30L, 40L),
      B = c(10L, 20L, 30L, 40L),
      A = 0L
    )
  }

  it("combines context names with shifted user labels, trimmed to present", {
    local_mocked_bindings(read_fs_color_lut = fs_lut)
    merged <- c(0L, 2L, 41L, 1011L, 211L, 212L)
    user <- data.frame(
      idx = c(11L, 12L),
      label = c("Foo", "Bar"),
      R = 1L,
      G = 1L,
      B = 1L,
      A = 0L
    )

    out <- build_anatomical_lut(merged, c(11L, 12L), 200L, user)

    expect_setequal(out$idx, c(2L, 41L, 1011L, 211L, 212L))
    expect_false(17L %in% out$idx)
    expect_identical(out$label[out$idx == 211L], "Foo")
    expect_identical(out$label[out$idx == 2L], "Left-Cerebral-White-Matter")
    expect_true(is_ctab(out))
  })

  it("falls back to generic user names when no lut is given", {
    local_mocked_bindings(read_fs_color_lut = fs_lut)
    merged <- c(2L, 211L)
    out <- build_anatomical_lut(merged, 11L, 200L, NULL)
    expect_setequal(out$idx, c(2L, 211L))
    expect_identical(out$label[out$idx == 211L], "region_0011")
  })
})

describe("unpack_anatomical_input", {
  it("unpacks a {volume, lut} list into volume and lut", {
    lut <- data.frame(idx = 1L)
    out <- unpack_anatomical_input(
      list(volume = "v.nii.gz", lut = lut, id_offset = 200L),
      input_lut = NULL
    )
    expect_identical(out$input_volume, "v.nii.gz")
    expect_identical(out$input_lut, lut)
  })

  it("lets an explicit input_lut win over the bundled one", {
    bundled <- data.frame(idx = 1L)
    explicit <- data.frame(idx = 2L)
    out <- unpack_anatomical_input(
      list(volume = "v.nii.gz", lut = bundled),
      input_lut = explicit
    )
    expect_identical(out$input_volume, "v.nii.gz")
    expect_identical(out$input_lut, explicit)
  })

  it("passes a plain path through unchanged", {
    out <- unpack_anatomical_input("x.nii.gz", input_lut = NULL)
    expect_identical(out$input_volume, "x.nii.gz")
    expect_null(out$input_lut)
  })
})
