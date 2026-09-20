.cap <- new.env()

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

  it("errors when a shifted label id collides with surviving context", {
    fake_dir <- withr::local_tempdir()
    subj_dir <- fs::path(fake_dir, "cvs_avg35_inMNI152", "mri")
    fs::dir_create(subj_dir)
    file.create(fs::path(subj_dir, "aparc+aseg.mgz"))

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      resolve_volume_path = function(x) x,
      project_load_volumes = function(...) {
        list(
          vol = NULL,
          arr = NULL,
          lut_df = NULL,
          label_ids = c(51L, 52L),
          aparc_mgz = "aparc.nii.gz",
          aparc = NULL,
          arr_aparc = array(c(251L, 0L, 0L, 0L), dim = c(2, 2, 1))
        )
      },
      project_label_argmax = function(...) {
        list(
          argmax_idx = c(2L, 2L, 2L, 2L),
          max_prob = c(0.1, 0.9, 0.9, 0.9)
        )
      }
    )

    # 51 + 200 = 251, and voxel 1 falls below threshold so the aparc's own
    # 251 survives the merge under the same id.
    expect_error(
      project_volume_anatomical(
        "atlas.nii.gz",
        id_offset = 200L,
        subjects_dir = fake_dir,
        protect_cortex = FALSE,
        verbose = FALSE
      ),
      "also kept as context"
    )
  })
})

describe("validate_ids_clear_of_context", {
  clear_of <- function(...) {
    args <- list(...)
    do.call(
      validate_ids_clear_of_context,
      utils::modifyList(
        list(
          parcel_ids = c(11L, 12L),
          shifted_ids = c(211L, 212L),
          context_array = c(0L, 2L, 17L, 1011L),
          blanked_ids = integer(),
          remedy = "Shift them."
        ),
        args
      )
    )
  }

  it("passes when no parcel id is also surviving context", {
    expect_true(clear_of())
  })

  it("aborts when a shifted id is also surviving context", {
    expect_error(
      clear_of(shifted_ids = c(211L, 17L)),
      "also kept as context"
    )
  })

  it("names both the parcel id and the id it shifted onto", {
    err <- expect_error(clear_of(shifted_ids = c(211L, 17L)))

    expect_match(conditionMessage(err), "12")
    expect_match(conditionMessage(err), "17")
  })

  it("does not report a shift when the ids were never shifted", {
    err <- expect_error(
      clear_of(parcel_ids = c(11L, 17L), shifted_ids = c(11L, 17L))
    )

    expect_no_match(conditionMessage(err), "Shifted onto")
  })

  it("treats a blanked context id as clear", {
    expect_true(clear_of(shifted_ids = c(211L, 17L), blanked_ids = 17L))
  })

  it("treats background as clear", {
    expect_true(clear_of(shifted_ids = c(211L, 0L)))
  })

  it("reads a float context array as the ids it rounds to", {
    expect_error(
      clear_of(shifted_ids = c(211L, 17L), context_array = c(0, 17.0001)),
      "also kept as context"
    )
  })

  it("refuses parcel and shifted id vectors that are not parallel", {
    expect_error(clear_of(shifted_ids = 17L), "length")
  })
})

describe("read_lut_arg", {
  it("accepts a data frame with idx column", {
    df <- data.frame(
      stringsAsFactors = FALSE,
      idx = 1:3,
      label = c("a", "b", "c")
    )
    expect_identical(read_lut_arg(df), df)
  })

  it("errors on data frame missing idx column", {
    df <- data.frame(stringsAsFactors = FALSE, label = c("a", "b"))
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
    .cap$seen <- NULL
    result <- list(volume = "merged.nii.gz", lut = NULL, id_offset = 200L)
    local_mocked_bindings(
      coregister_volume = function(...) "registration.lta",
      project_volume_anatomical = function(registration, ...) {
        .cap$seen <- registration
        result
      }
    )

    out <- prepare_subcortical_anatomical(
      input_volume = "atlas.nii.gz",
      verbose = FALSE
    )

    expect_identical(.cap$seen, "registration.lta")
    expect_identical(out, result)
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
      registration = "header",
      n_voxels = 4L,
      verbose = FALSE
    )

    expect_identical(out$argmax_idx, c(2L, 0L, 1L, 0L))
    expect_identical(out$max_prob, c(0.2, 0.0, 0.5, 0.0))
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

describe("lta_dst_dims / lta_src_dims / check_registration_grid", {
  write_lta <- function(
    dst_volume = "256 256 256",
    with_dst = TRUE,
    src_volume = "91 109 91"
  ) {
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
      paste("volume =", src_volume),
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

  it("reads the src dims, not the dst dims", {
    expect_identical(lta_src_dims(write_lta()), c(91L, 109L, 91L))
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

  it("passes when input_dim matches the LTA source grid", {
    expect_null(
      check_registration_grid(
        write_lta(),
        c(256L, 256L, 256L),
        c(91L, 109L, 91L)
      )
    )
  })

  it("is a no-op on the source check when input_dim is not supplied", {
    expect_null(
      check_registration_grid(write_lta(), c(256L, 256L, 256L))
    )
  })

  it("aborts when the LTA source grid does not match input_dim", {
    expect_error(
      check_registration_grid(
        write_lta(),
        c(256L, 256L, 256L),
        c(64L, 64L, 64L)
      ),
      "does not match .{0,5}input_volume"
    )
  })
})

describe("resolve_user_lut", {
  it("shifts supplied label ids and drops unprojected rows", {
    lut <- data.frame(
      stringsAsFactors = FALSE,
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
    expect_true(is_lut(out))
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
      stringsAsFactors = FALSE,
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
      stringsAsFactors = FALSE,
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
    expect_true(is_lut(out))
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

describe("coregister_volume execution", {
  make_subject <- function(dir, volume = "brain") {
    mri <- fs::path(dir, "cvs_avg35_inMNI152", "mri")
    fs::dir_create(mri)
    file.create(fs::path(mri, paste0(volume, ".mgz")))
    invisible(dir)
  }

  it("reuses an existing LTA when skip_existing and the file exists", {
    fake_dir <- withr::local_tempdir()
    make_subject(fake_dir)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)
    lta <- withr::local_tempfile(fileext = ".lta")
    file.create(lta)

    local_mocked_bindings(check_fs = function(...) TRUE)

    out <- coregister_volume(
      vol_file,
      output_lta = lta,
      subjects_dir = fake_dir,
      skip_existing = TRUE,
      verbose = FALSE
    )
    expect_identical(out, lta)
  })

  it("binarises both volumes, defaults the LTA path, then runs mri_coreg", {
    fake_dir <- withr::local_tempdir()
    make_subject(fake_dir)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)
    .cap$coreg <- NULL

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      write_brain_mask = function(volume_path, ...) {
        p <- tempfile(fileext = ".nii.gz")
        file.create(p)
        p
      },
      write_brain_mask_from_mgz = function(mgz_path, ...) {
        p <- tempfile(fileext = ".nii.gz")
        file.create(p)
        p
      },
      run_mri_coreg = function(mov, ref, output_lta, ...) {
        .cap$coreg <- list(mov = mov, ref = ref, lta = output_lta)
        invisible(output_lta)
      }
    )

    out <- coregister_volume(
      vol_file,
      subjects_dir = fake_dir,
      binarise = TRUE,
      verbose = FALSE
    )
    expect_match(out, "\\.lta$")
    expect_identical(.cap$coreg$lta, out)
  })

  it("passes raw volumes to mri_coreg when binarise is FALSE", {
    fake_dir <- withr::local_tempdir()
    make_subject(fake_dir)
    vol_file <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol_file)
    .cap$coreg <- NULL

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      run_mri_coreg = function(mov, ref, output_lta, ...) {
        .cap$coreg <- list(mov = mov, ref = ref)
        invisible(output_lta)
      }
    )

    coregister_volume(
      vol_file,
      subjects_dir = fake_dir,
      binarise = FALSE,
      verbose = FALSE
    )
    expect_identical(.cap$coreg$mov, vol_file)
    expect_match(.cap$coreg$ref, "brain\\.mgz$")
  })
})

describe("coreg_reuse_lta", {
  it("reports and returns the path invisibly when verbose", {
    expect_messages(
      out <- coreg_reuse_lta("cached.lta", verbose = TRUE),
      "Reusing existing registration"
    )
    expect_identical(out, "cached.lta")
  })
})

describe("project_start_message", {
  it("announces the projection and returns NULL invisibly when verbose", {
    expect_messages(
      out <- project_start_message(c(11L, 12L), "subjX", verbose = TRUE),
      "Projecting 2 labels"
    )
    expect_null(out)
  })
})

describe("project_merged_labels", {
  it("thresholds, protects cortex, and writes shifted ids", {
    prep <- list(
      label_ids = c(11L, 12L),
      arr = NULL,
      vol = NULL,
      aparc_mgz = NULL,
      arr_aparc = array(c(2L, 17L, 1011L, 50L), dim = c(2, 2, 1))
    )
    local_mocked_bindings(
      project_label_argmax = function(...) {
        list(
          argmax_idx = c(1L, 2L, 1L, 2L),
          max_prob = c(0.9, 0.9, 0.9, 0.1)
        )
      }
    )
    # Label 11 wins voxels 1 and 3, and protection takes both, so it is
    # removed entirely -- exactly the case the warning exists to surface.
    expect_warning(
      merged <- project_merged_labels(
        prep,
        registration = "header",
        threshold = 0.3,
        protect_cortex = TRUE,
        id_offset = 200L,
        verbose = FALSE
      ),
      "removed entirely by cortex protection"
    )
    # voxel 1 aparc = 2 (cerebral WM) -> protected, stays 2
    # voxel 2 aparc = 17, prob .9 > .3, not protected -> 12 + 200 = 212
    # voxel 3 aparc = 1011 (cortex) -> protected, stays 1011
    # voxel 4 prob .1 < .3 -> not kept, stays 50
    expect_identical(as.vector(merged), c(2L, 212L, 1011L, 50L))
  })

  it("aborts when a shifted id lands on cortex that protection keeps", {
    prep <- list(
      label_ids = c(11L, 811L),
      arr = NULL,
      vol = NULL,
      aparc_mgz = NULL,
      arr_aparc = array(c(2L, 17L, 1011L, 50L), dim = c(2, 2, 1))
    )
    local_mocked_bindings(
      project_label_argmax = function(...) {
        list(
          argmax_idx = c(1L, 2L, 2L, 1L),
          max_prob = c(0.9, 0.9, 0.9, 0.9)
        )
      }
    )

    # 811 + 200 = 1011, and protect_cortex keeps voxel 3 as cortex 1011, so
    # the parcel and the ribbon would share an id in the merged volume.
    # 811 also takes voxel 2, so it is not lost to protection entirely --
    # this is the collision on its own, not the protection warning.
    expect_error(
      project_merged_labels(
        prep,
        registration = "header",
        threshold = 0.3,
        protect_cortex = TRUE,
        id_offset = 200L,
        verbose = FALSE
      ),
      "also kept as context"
    )
  })

  it("aborts when id_offset is 0 and a parcel id matches the aparc", {
    prep <- list(
      label_ids = c(17L, 12L),
      arr = NULL,
      vol = NULL,
      aparc_mgz = NULL,
      arr_aparc = array(c(2L, 17L, 1011L, 50L), dim = c(2, 2, 1))
    )
    local_mocked_bindings(
      project_label_argmax = function(...) {
        list(
          argmax_idx = c(2L, 2L, 2L, 2L),
          max_prob = c(0.9, 0.1, 0.9, 0.9)
        )
      }
    )

    # Voxel 2 keeps aparc 17 (below threshold), which parcel 17 also claims.
    expect_error(
      project_merged_labels(
        prep,
        registration = "header",
        threshold = 0.3,
        protect_cortex = FALSE,
        id_offset = 0L,
        verbose = FALSE
      ),
      "also kept as context"
    )
  })

  it("accepts a parcel id that overwrites its context id completely", {
    prep <- list(
      label_ids = c(17L, 12L),
      arr = NULL,
      vol = NULL,
      aparc_mgz = NULL,
      arr_aparc = array(c(2L, 17L, 50L, 50L), dim = c(2, 2, 1))
    )
    local_mocked_bindings(
      project_label_argmax = function(...) {
        list(
          argmax_idx = c(2L, 1L, 2L, 2L),
          max_prob = c(0.9, 0.9, 0.9, 0.9)
        )
      }
    )

    # Parcel 17 takes the only voxel aparc 17 had, so nothing survives to be
    # mislabelled and the shared id is not a collision.
    merged <- project_merged_labels(
      prep,
      registration = "header",
      threshold = 0.3,
      protect_cortex = FALSE,
      id_offset = 0L,
      verbose = FALSE
    )

    expect_identical(as.vector(merged), c(12L, 17L, 12L, 12L))
  })
})

describe("project_volume_anatomical execution", {
  it("projects labels end-to-end with FreeSurfer steps mocked", {
    skip_if_not_installed("RNifti")
    fake_dir <- withr::local_tempdir()
    subj_dir <- fs::path(fake_dir, "cvs_avg35_inMNI152", "mri")
    fs::dir_create(subj_dir)
    file.create(fs::path(subj_dir, "aparc+aseg.mgz"))

    aparc_arr <- array(
      c(2L, 17L, 1011L, 50L, 0L, 0L, 0L, 0L),
      dim = c(2, 2, 2)
    )
    aparc_nii <- RNifti::asNifti(aparc_arr)

    merged_arr <- aparc_arr
    merged_arr[1] <- 211L
    storage.mode(merged_arr) <- "integer"

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      resolve_volume_path = function(x) x,
      project_load_volumes = function(...) {
        list(
          vol = aparc_nii,
          arr = aparc_arr,
          lut_df = NULL,
          label_ids = c(11L, 12L),
          aparc_mgz = "aparc.mgz",
          aparc = aparc_nii,
          arr_aparc = aparc_arr
        )
      },
      project_merged_labels = function(...) merged_arr,
      read_fs_color_lut = function() {
        data.frame(
          stringsAsFactors = FALSE,
          idx = c(2L, 17L, 50L, 1011L),
          label = c("wm", "hipp", "put", "ctx"),
          R = 1L,
          G = 1L,
          B = 1L,
          A = 0L
        )
      }
    )

    result <- expect_messages(
      project_volume_anatomical(
        "atlas.nii.gz",
        registration = "header",
        subjects_dir = fake_dir,
        id_offset = 200L,
        verbose = TRUE
      ),
      "Projecting",
      "anatomical-context volume"
    )

    expect_true(file.exists(result$volume))
    expect_true(is_lut(result$lut))
    expect_identical(result$id_offset, 200L)
    expect_true(211L %in% result$lut$idx)
  })
})

describe("resolve_label_ids all-zero volume", {
  it("errors when the volume is all zero and no lut is given", {
    zero <- array(0L, dim = c(2, 2, 2))
    expect_error(
      resolve_label_ids(zero, "atlas.nii.gz"),
      "No labels found"
    )
  })
})

describe("lta_block_dims", {
  it("returns NULL when the block has no volume line", {
    lines <- c("dst volume info", "valid = 1", "voxelsize = 1 1 1")
    expect_null(lta_block_dims(lines, "dst volume info"))
  })

  it("returns NULL when the parsed dims are not length three", {
    lines <- c("dst volume info", "volume = 256 256")
    expect_null(lta_block_dims(lines, "dst volume info"))
  })

  it("returns NULL when the parsed dims contain NA", {
    lines <- c("dst volume info", "volume = 256 abc 256")
    expect_null(lta_block_dims(lines, "dst volume info"))
  })
})

describe("apply_cortex_protection verbose", {
  it("reports the protected voxel counts when verbose", {
    arr_aparc <- c(2L, 17L, 1011L, 41L, 50L, 253L)
    expect_messages(
      apply_cortex_protection(
        rep(TRUE, 6),
        arr_aparc,
        protect_cortex = TRUE,
        verbose = TRUE
      ),
      "Protected"
    )
  })
})

describe("protected_context_ids", {
  it("returns the cortex and cerebral-WM ids present in the aparc", {
    arr_aparc <- array(c(2L, 17L, 1011L, 50L, 253L, 41L), dim = c(3, 2, 1))

    expect_setequal(
      protected_context_ids(arr_aparc, protect_cortex = TRUE),
      c(2L, 1011L, 253L, 41L)
    )
  })

  it("protects nothing when protect_cortex is FALSE", {
    arr_aparc <- array(c(2L, 17L, 1011L, 50L), dim = c(2, 2, 1))

    expect_identical(
      protected_context_ids(arr_aparc, protect_cortex = FALSE),
      integer()
    )
  })

  it("agrees with what apply_cortex_protection actually protects", {
    arr_aparc <- c(0L, 2L, 17L, 41L, 50L, 999L, 1000L, 2999L, 3000L, 253L)

    kept <- apply_cortex_protection(
      rep(TRUE, length(arr_aparc)),
      arr_aparc,
      protect_cortex = TRUE,
      verbose = FALSE
    )

    expect_setequal(
      protected_context_ids(arr_aparc, protect_cortex = TRUE),
      unique(arr_aparc[!kept])
    )
  })
})

describe("project_volume_anatomical early collision check", {
  it("aborts before registration when a shifted id hits protected cortex", {
    fake_dir <- withr::local_tempdir()
    subj_dir <- fs::path(fake_dir, "cvs_avg35_inMNI152", "mri")
    fs::dir_create(subj_dir)
    file.create(fs::path(subj_dir, "aparc+aseg.mgz"))

    local_mocked_bindings(
      check_fs = function(...) TRUE,
      resolve_volume_path = function(x) x,
      project_load_volumes = function(...) {
        list(
          vol = NULL,
          arr = NULL,
          lut_df = NULL,
          label_ids = c(11L, 811L),
          aparc_mgz = "aparc.nii.gz",
          aparc = NULL,
          arr_aparc = array(c(2L, 17L, 1011L, 50L), dim = c(2, 2, 1))
        )
      },
      project_label_argmax = function(...) {
        cli::cli_abort("Registration must not run before the id check.")
      }
    )

    # 811 + 200 = 1011, which protect_cortex shields, so this is decidable
    # without resampling anything.
    expect_error(
      project_volume_anatomical(
        "atlas.nii.gz",
        id_offset = 200L,
        subjects_dir = fake_dir,
        verbose = FALSE
      ),
      "also kept as context"
    )
  })

  it("leaves the late check to catch what protection does not shield", {
    fake_dir <- withr::local_tempdir()
    subj_dir <- fs::path(fake_dir, "cvs_avg35_inMNI152", "mri")
    fs::dir_create(subj_dir)
    file.create(fs::path(subj_dir, "aparc+aseg.mgz"))

    calls <- new.env(parent = emptyenv())
    calls$argmax <- FALSE
    local_mocked_bindings(
      check_fs = function(...) TRUE,
      resolve_volume_path = function(x) x,
      project_load_volumes = function(...) {
        list(
          vol = NULL,
          arr = NULL,
          lut_df = NULL,
          label_ids = c(51L, 52L),
          aparc_mgz = "aparc.nii.gz",
          aparc = NULL,
          arr_aparc = array(c(251L, 0L, 0L, 0L), dim = c(2, 2, 1))
        )
      },
      project_label_argmax = function(...) {
        calls$argmax <- TRUE
        list(
          argmax_idx = c(2L, 2L, 2L, 2L),
          max_prob = c(0.1, 0.9, 0.9, 0.9)
        )
      }
    )

    # 251 is cerebral-WM, but protect_cortex = FALSE leaves it unshielded, so
    # nothing is decidable up front and the merge has to be computed first.
    expect_error(
      project_volume_anatomical(
        "atlas.nii.gz",
        id_offset = 200L,
        subjects_dir = fake_dir,
        protect_cortex = FALSE,
        verbose = FALSE
      ),
      "also kept as context"
    )
    expect_true(calls$argmax)
  })
})

describe("write_merged_volume", {
  it("writes a readable RAS nifti, flipping a non-RAS reference", {
    skip_if_not_installed("RNifti")
    merged <- array(
      c(2L, 17L, 211L, 0L, 41L, 0L, 1011L, 5L),
      dim = c(2, 2, 2)
    )
    storage.mode(merged) <- "integer"
    ref <- RNifti::asNifti(array(0L, dim = dim(merged)))
    las_affine <- rbind(
      c(-1, 0, 0, 0),
      c(0, 1, 0, 0),
      c(0, 0, 1, 0),
      c(0, 0, 0, 1)
    )
    RNifti::sform(ref) <- structure(las_affine, code = 2L)
    expect_identical(RNifti::orientation(ref), "LAS")

    out <- write_merged_volume(merged, ref, output_file = NULL)
    withr::defer(unlink(out))

    expect_true(file.exists(out))
    back <- RNifti::readNifti(out)
    expect_identical(RNifti::orientation(back), "RAS")
    expect_setequal(
      sort(unique(as.integer(as.array(back)))),
      sort(unique(as.integer(merged)))
    )
  })
})

describe("write_brain_mask", {
  it("produces a 0/1 mask nifti from a volume on disk", {
    skip_if_not_installed("RNifti")
    src <- withr::local_tempfile(fileext = ".nii.gz")
    arr <- array(c(0L, 5L, 0L, 9L, 0L, 0L, 3L, 0L), dim = c(2, 2, 2))
    RNifti::writeNifti(RNifti::asNifti(arr), src)

    out <- write_brain_mask(src)
    withr::defer(unlink(out))

    m <- as.array(RNifti::readNifti(out))
    expect_setequal(sort(unique(as.vector(m))), c(0, 1))
    expect_identical(as.integer(m > 0), as.integer(arr > 0))
  })
})

describe("resolve_volume_path RNifti object", {
  it("writes an RNifti object to a temp nifti path", {
    skip_if_not_installed("RNifti")
    img <- RNifti::asNifti(array(1L, dim = c(2, 2, 2)))
    p <- resolve_volume_path(img)
    withr::defer(unlink(p))
    expect_true(file.exists(p))
    expect_match(p, "\\.nii\\.gz$")
  })
})

describe("read_fs_color_lut", {
  it("reads the FreeSurfer colour table and drops the type column", {
    dir <- withr::local_tempdir()
    writeLines(
      c(
        "2  Left-Cerebral-White-Matter  245 245 245 0",
        "41 Right-Cerebral-White-Matter 20 30 40 0"
      ),
      fs::path(dir, "FreeSurferColorLUT.txt")
    )
    local_mocked_bindings(
      fs_dir = function(...) as.character(dir),
      .package = "freesurfer"
    )
    out <- read_fs_color_lut()
    expect_true(all(c("idx", "label", "R", "G", "B", "A") %in% names(out)))
    expect_null(out$type)
    expect_true(all(c(2L, 41L) %in% out$idx))
  })

  it("aborts when the colour table file is missing", {
    dir <- withr::local_tempdir()
    local_mocked_bindings(
      fs_dir = function(...) as.character(dir),
      .package = "freesurfer"
    )
    expect_error(read_fs_color_lut(), "colour table not found")
  })
})


describe("warn_labels_lost_to_protection", {
  lut <- data.frame(
    idx = c(1L, 2L),
    label = c("lh_slf", "rh_slf"),
    R = 0L,
    G = 0L,
    B = 0L,
    A = 0L
  )

  it("warns naming a label protection removed entirely", {
    # Voxels 1-2 belong to label 1, voxel 3 to label 2. Protection keeps only
    # voxel 3, so label 1 is erased.
    expect_warning(
      warn_labels_lost_to_protection(
        kept_before = c(TRUE, TRUE, TRUE),
        kept_after = c(FALSE, FALSE, TRUE),
        argmax_idx = c(1L, 1L, 2L),
        label_ids = c(1L, 2L),
        lut_df = lut
      ),
      "lh_slf"
    )
  })

  it("stays quiet when every label keeps some voxels", {
    expect_silent(
      warn_labels_lost_to_protection(
        kept_before = c(TRUE, TRUE, TRUE),
        kept_after = c(TRUE, FALSE, TRUE),
        argmax_idx = c(1L, 1L, 2L),
        label_ids = c(1L, 2L),
        lut_df = lut
      )
    )
  })

  it("ignores voxels no label won", {
    expect_silent(
      warn_labels_lost_to_protection(
        kept_before = c(TRUE, TRUE),
        kept_after = c(NA_integer_ > 0, TRUE),
        argmax_idx = c(NA_integer_, 2L),
        label_ids = c(1L, 2L),
        lut_df = lut
      )
    )
  })

  it("stays quiet when protection removed nothing", {
    keep <- c(TRUE, FALSE, TRUE)
    expect_silent(
      warn_labels_lost_to_protection(keep, keep, c(1L, 1L, 2L), c(1L, 2L), lut)
    )
  })

  it("falls back to the label id when no LUT is available", {
    expect_warning(
      warn_labels_lost_to_protection(
        kept_before = c(TRUE, TRUE),
        kept_after = c(FALSE, TRUE),
        argmax_idx = c(1L, 2L),
        label_ids = c(70L, 80L),
        lut_df = NULL
      ),
      "70"
    )
  })
})
