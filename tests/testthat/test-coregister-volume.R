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
    local_mocked_bindings(
      coregister_volume = function(...) "registration.lta",
      project_volume_anatomical = function(registration, ...) {
        seen <<- registration
        "merged.nii.gz"
      }
    )

    out <- prepare_subcortical_anatomical(
      input_volume = "atlas.nii.gz",
      label_ids = 1:3,
      verbose = FALSE
    )

    expect_equal(seen, "registration.lta")
    expect_equal(out, "merged.nii.gz")
  })
})
