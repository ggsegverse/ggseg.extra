# Capture the command mri_vol2surf (and friends) would run, without a
# FreeSurfer install. Returns an environment whose `cmd` holds the last
# command built.
local_mock_vol2surf <- function(env = parent.frame()) {
  cap <- new.env()
  local_mocked_bindings(
    check_fs = function(abort = FALSE) invisible(TRUE),
    run_cmd = function(cmd, verbose = FALSE) {
      cap$cmd <- cmd
      invisible(NULL)
    },
    .env = env
  )
  cap
}

describe("check_fs", {
  it("returns logical", {
    skip_if_not_installed("freesurfer")
    result <- check_fs()
    expect_type(result, "logical")
  })

  it("aborts when abort = TRUE and FS not installed", {
    local_mocked_bindings(
      have_fs = function() FALSE,
      .package = "freesurfer"
    )

    expect_error(check_fs(abort = TRUE), "Freesurfer")
  })

  it("shows danger message when abort = FALSE and FS not installed", {
    local_mocked_bindings(
      have_fs = function() FALSE,
      .package = "freesurfer"
    )

    expect_message(result <- check_fs(abort = FALSE), "Freesurfer")
    expect_false(result)
  })

  it("does not abort when abort = FALSE", {
    skip_if_not_installed("freesurfer")
    result <- check_fs(abort = FALSE)
    expect_type(result, "logical")
  })

  it("errors when freesurfer is older than the minimum version", {
    local_mocked_bindings(freesurfer_min_version = function() "999.0.0")

    expect_error(check_fs(), class = "rlib_error_package_not_found")
  })
})

describe("freesurfer_min_version", {
  it("matches the Suggests constraint in DESCRIPTION", {
    suggests <- gsub(
      "\\s+",
      " ",
      utils::packageDescription("ggseg.extra", fields = "Suggests")
    )

    expect_match(
      suggests,
      paste0("freesurfer (>= ", freesurfer_min_version(), ")"),
      fixed = TRUE
    )
  })
})


describe("mri_vol2surf", {
  it("constructs correct command", {
    cap <- local_mock_vol2surf()

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      verbose = FALSE
    )

    expect_match(cap$cmd, "mri_vol2surf")
    expect_match(cap$cmd, paste("--mov", shQuote("input.mgz")))
    expect_match(cap$cmd, paste("--o", shQuote("output.mgz")))
    expect_match(cap$cmd, "--hemi lh")
    expect_match(cap$cmd, "--projfrac 0.5")
  })

  it("emits no registration flags when none are given", {
    cap <- local_mock_vol2surf()

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      verbose = FALSE
    )

    expect_no_match(cap$cmd, "--reg ")
    expect_no_match(cap$cmd, "--regheader")
    expect_no_match(cap$cmd, "--srcsubject")
  })

  it("passes a registration file together with its source subject", {
    cap <- local_mock_vol2surf()

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      reg = "mni152.register.dat",
      srcsubject = "fsaverage5",
      verbose = FALSE
    )

    expect_match(
      cap$cmd,
      paste(
        "--reg",
        shQuote("mni152.register.dat"),
        "--srcsubject",
        shQuote("fsaverage5")
      ),
      fixed = TRUE
    )
    expect_no_match(cap$cmd, "--regheader")
  })

  it("passes --regheader for volumes in the subject's own space", {
    cap <- local_mock_vol2surf()

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      regheader = "fsaverage5",
      verbose = FALSE
    )

    expect_match(
      cap$cmd,
      paste("--regheader", shQuote("fsaverage5")),
      fixed = TRUE
    )
    expect_no_match(cap$cmd, "--reg ")
    expect_no_match(cap$cmd, "--srcsubject")
  })
})


describe("mni152_register_path", {
  it("points at the transform in the FreeSurfer installation", {
    local_mocked_bindings(
      fs_dir = function(...) "/opt/freesurfer",
      .package = "freesurfer"
    )

    expect_identical(
      mni152_register_path(),
      "/opt/freesurfer/average/mni152.register.dat"
    )
  })
})


describe("vol2vol_registration", {
  it("asks mri_vol2vol to trust the header", {
    expect_identical(
      vol2vol_registration("header", mov = "m.nii", targ = "t.mgz"),
      "header"
    )
  })

  it("hands an LTA over untouched", {
    # An LTA already states its geometry, so converting it would be a
    # round trip that can only lose something.
    lta <- withr::local_tempfile(fileext = ".lta")
    file.create(lta)

    expect_identical(
      vol2vol_registration(lta, mov = "m.nii", targ = "t.mgz"),
      lta
    )
  })

  it("converts a tkregister matrix against this call's volumes", {
    # FreeSurfer 8 refuses a REGISTER_DAT whose source geometry it cannot
    # establish and writes no output, so the matrix becomes an LTA first.
    reg_file <- withr::local_tempfile(fileext = ".dat")
    file.create(reg_file)
    local_mocked_bindings(
      lta_from_register_dat = function(path, mov, targ, ...) {
        paste0(path, "|", mov, "|", targ, ".lta")
      }
    )

    expect_identical(
      vol2vol_registration(reg_file, mov = "m.nii", targ = "t.mgz"),
      paste0(reg_file, "|m.nii|t.mgz.lta")
    )
  })
})


describe("vol2vol_registration_opt", {
  it("asks mri_vol2vol to trust the header", {
    expect_identical(
      vol2vol_registration_opt("header", mov = "m.nii", targ = "t.mgz"),
      "--regheader"
    )
  })

  it("hands an LTA over untouched", {
    # An LTA already states its geometry, so converting it would be a
    # round trip that can only lose something.
    lta <- withr::local_tempfile(fileext = ".lta")
    file.create(lta)

    expect_identical(
      vol2vol_registration_opt(lta, mov = "m.nii", targ = "t.mgz"),
      paste("--reg", shQuote(lta))
    )
  })

  it("converts a tkregister matrix against this call's volumes", {
    # FreeSurfer 8 refuses a REGISTER_DAT whose source geometry it cannot
    # establish and writes no output, so the matrix becomes an LTA first.
    reg_file <- withr::local_tempfile(fileext = ".dat")
    file.create(reg_file)
    local_mocked_bindings(
      lta_from_register_dat = function(path, mov, targ, ...) {
        paste0(path, "|", mov, "|", targ, ".lta")
      }
    )

    expect_identical(
      vol2vol_registration_opt(reg_file, mov = "m.nii", targ = "t.mgz"),
      paste("--reg", shQuote(paste0(reg_file, "|m.nii|t.mgz.lta")))
    )
  })
})


# Stand in for lta_convert: write the file the command asks for, and
# report the command so its shape can be checked.
local_mock_lta_convert <- function(write = TRUE, env = parent.frame()) {
  seen <- new.env()
  local_mocked_bindings(
    run_cmd = function(cmd, ...) {
      seen$cmd <- cmd
      if (write) {
        # `--outlta` is the last argument, so everything after it is the
        # path. Taking the tail and stripping quotes rather than matching
        # them: shQuote() uses single quotes on Unix and double on
        # Windows, and a pattern for one silently fails on the other.
        out <- gsub('^["\']|["\']$', "", sub(".*--outlta ", "", cmd))
        writeLines("lta", out)
      }
      invisible(0L)
    },
    .env = env
  )
  seen
}


describe("lta_from_register_dat", {
  it("names the source and target volumes the geometry comes from", {
    seen <- local_mock_lta_convert()

    lta <- lta_from_register_dat("reg.dat", mov = "m.nii", targ = "t.mgz")

    expect_match(seen$cmd, "^lta_convert ")
    # Quoted with shQuote() rather than written out, for the same reason the
    # mock does not match quotes: they differ by platform.
    expect_match(
      seen$cmd,
      paste("--inreg", shQuote("reg.dat")),
      fixed = TRUE
    )
    expect_match(seen$cmd, paste("--src", shQuote("m.nii")), fixed = TRUE)
    expect_match(seen$cmd, paste("--trg", shQuote("t.mgz")), fixed = TRUE)
    expect_true(file.exists(lta))
  })

  it("aborts when lta_convert writes nothing", {
    # The failure this whole change exists to stop being silent.
    local_mock_lta_convert(write = FALSE)

    expect_error(
      lta_from_register_dat("reg.dat", mov = "m.nii", targ = "t.mgz"),
      "lta_convert"
    )
  })

  it("does not leave the LTA behind when its caller returns", {
    seen <- local_mock_lta_convert()

    lta <- local({
      lta_from_register_dat("reg.dat", mov = "m.nii", targ = "t.mgz")
    })

    expect_false(file.exists(lta))
  })
})

describe("vol2vol_registration_opt lifetime", {
  # `vol2vol_registration_opt()` now reaches `lta_from_register_dat()` through
  # `vol2vol_registration()`, so the LTA's lifetime depends on `envir` being
  # forwarded across that hop. Dropping the forward deletes the file the
  # moment the opt helper returns, and the command then names a path that is
  # already gone -- on the default `registration = "mni152"` path.
  it("keeps the LTA alive until its own caller returns, not its callee", {
    local_mock_lta_convert()
    reg_dat <- withr::local_tempfile(fileext = ".dat")
    file.create(reg_dat)

    alive_inside <- NULL
    path <- local({
      opt <- vol2vol_registration_opt(
        reg_dat,
        mov = "m.nii",
        targ = "t.mgz"
      )
      p <- gsub('^["\']|["\']$', "", sub("^--reg ", "", opt))
      alive_inside <<- file.exists(p)
      p
    })

    expect_true(alive_inside)
    expect_false(file.exists(path))
  })
})

describe("resolve_vol2surf_registration", {
  it("maps 'mni152' to FreeSurfer's transform and a source subject", {
    reg_file <- local_mock_mni152_path()

    expect_identical(
      resolve_vol2surf_registration("mni152", "fsaverage5"),
      list(reg = reg_file, srcsubject = "fsaverage5", regheader = NULL)
    )
  })

  it("maps 'header' to --regheader with no source subject", {
    expect_identical(
      resolve_vol2surf_registration("header", "fsaverage5"),
      list(reg = NULL, srcsubject = NULL, regheader = "fsaverage5")
    )
  })

  it("accepts a path to a registration file", {
    reg_file <- withr::local_tempfile(fileext = ".lta")
    file.create(reg_file)

    expect_identical(
      resolve_vol2surf_registration(reg_file, "fsaverage6"),
      list(reg = reg_file, srcsubject = "fsaverage6", regheader = NULL)
    )
  })

  it("rejects a directory given as a registration", {
    reg_dir <- withr::local_tempdir()

    expect_error(
      resolve_vol2surf_registration(reg_dir, "fsaverage5"),
      "Registration file not found"
    )
  })

  it("errors when the given registration file does not exist", {
    expect_error(
      resolve_vol2surf_registration("no/such/registration.dat", "fsaverage5"),
      "Registration file not found"
    )
  })

  it("errors when FreeSurfer's own transform is missing", {
    local_mocked_bindings(
      mni152_register_path = function() "no/such/mni152.register.dat"
    )

    expect_error(
      resolve_vol2surf_registration("mni152", "fsaverage5"),
      "FREESURFER_HOME"
    )
  })

  it("errors on a specification that is not a single string", {
    expect_error(
      resolve_vol2surf_registration(TRUE, "fsaverage5"),
      "single string"
    )
    expect_error(
      resolve_vol2surf_registration(c("mni152", "header"), "fsaverage5"),
      "single string"
    )
  })
})


describe("mri_pretess", {
  it("constructs correct command", {
    cap <- local_mock_vol2surf()

    mri_pretess(
      template = "vol.mgz",
      label = 10,
      output_file = "pretess.mgz",
      verbose = FALSE
    )

    expect_match(cap$cmd, "mri_pretess")
    expect_match(cap$cmd, "vol.mgz")
    expect_match(cap$cmd, "10")
    expect_match(cap$cmd, "pretess.mgz")
  })

  it("appends opts to command", {
    cap <- local_mock_vol2surf()

    mri_pretess(
      template = "vol.mgz",
      label = 10,
      output_file = "pretess.mgz",
      opts = "--keep",
      verbose = FALSE
    )

    expect_match(cap$cmd, "--keep")
  })
})


describe("mri_tessellate", {
  it("constructs correct command", {
    cap <- local_mock_vol2surf()

    mri_tessellate(
      input_file = "pretess.mgz",
      label = 10,
      output_file = "tess",
      verbose = FALSE
    )

    expect_match(cap$cmd, "mri_tessellate")
    expect_match(cap$cmd, "pretess.mgz")
    expect_match(cap$cmd, "10")
    expect_match(cap$cmd, "tess")
  })

  it("appends opts to command", {
    cap <- local_mock_vol2surf()

    mri_tessellate(
      input_file = "pretess.mgz",
      label = 10,
      output_file = "tess",
      opts = "--extra-flag",
      verbose = FALSE
    )

    expect_match(cap$cmd, "--extra-flag")
  })
})


describe("mri_smooth", {
  it("constructs correct command", {
    cap <- local_mock_vol2surf()

    mri_smooth(
      input_file = "tess",
      output_file = "smooth",
      verbose = FALSE
    )

    expect_match(cap$cmd, "mris_smooth")
    expect_match(cap$cmd, "-nw")
  })

  it("appends opts to command", {
    cap <- local_mock_vol2surf()

    mri_smooth(
      input_file = "tess",
      output_file = "smooth",
      opts = "--seed 42",
      verbose = FALSE
    )

    expect_match(cap$cmd, "--seed 42")
  })
})


describe("mri_vol2surf with opts", {
  it("appends opts to command", {
    cap <- local_mock_vol2surf()

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      opts = "--interp trilinear",
      verbose = FALSE
    )

    expect_match(cap$cmd, "--interp trilinear")
  })
})


describe("mri_vol2surf with projfrac_range", {
  it("uses --projfrac-max for multi-depth projection", {
    cap <- local_mock_vol2surf()

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      projfrac_range = c(0, 1, 0.1),
      verbose = FALSE
    )

    expect_match(cap$cmd, "--projfrac-max 0 1 0.1")
    expect_false(
      grepl("--projfrac 0.5", cap$cmd, fixed = TRUE)
    )
  })
})


describe("mri_surf2surf_rereg", {
  it("constructs correct command", {
    cap <- local_mock_vol2surf()

    tmp <- withr::local_tempdir()

    mri_surf2surf_rereg(
      subject = "fsaverage5",
      annot = "aparc.DKTatlas",
      hemisphere = "lh",
      output_dir = tmp,
      verbose = FALSE
    )

    expect_match(cap$cmd, "mri_surf2surf")
    expect_match(cap$cmd, paste("--srcsubject", shQuote("fsaverage5")))
    expect_match(
      cap$cmd,
      paste("--sval-annot", shQuote("aparc.DKTatlas"))
    )
    expect_match(cap$cmd, "--hemi lh")
  })

  it("builds the right-hemisphere command too", {
    cap <- local_mock_vol2surf()
    tmp <- withr::local_tempdir()

    mri_surf2surf_rereg(
      subject = "fsaverage5",
      annot = "aparc.DKTatlas",
      hemisphere = "rh",
      output_dir = tmp,
      verbose = FALSE
    )

    expect_match(cap$cmd, "--hemi rh")
  })

  it("refuses a hemisphere that is neither lh nor rh", {
    local_mocked_bindings(check_fs = function(...) invisible(TRUE))

    expect_error(
      mri_surf2surf_rereg(
        subject = "fsaverage5",
        annot = "aparc.DKTatlas",
        hemisphere = "left",
        output_dir = withr::local_tempdir(),
        verbose = FALSE
      ),
      "should be one of"
    )
  })
})


describe("surf2asc", {
  it("errors when output_file doesn't end with dpv", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE)
    )
    expect_error(
      surf2asc("input", "output.txt", verbose = FALSE),
      "dpv"
    )
  })

  it("returns NULL when input_file doesn't exist", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE)
    )
    result <- surf2asc("/nonexistent/file", "output.dpv", verbose = FALSE)
    expect_null(result)
  })

  it("warns when input_file doesn't exist and verbose is TRUE", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE)
    )
    expect_warning(
      {
        result <- surf2asc("/nonexistent/file", "output.dpv", verbose = TRUE)
      },
      "Input file does not exist"
    )
    expect_null(result)
  })

  it("converts surface file when verbose is TRUE and file exists", {
    tmp <- withr::local_tempdir()
    input <- file.path(tmp, "lh.white")
    writeLines("fake surface", input)
    output <- file.path(tmp, "lh.white.dpv")

    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      read_dpv = function(path) data.frame(x = 1)
    )
    local_mocked_bindings(
      mris_convert = function(infile, outfile, verbose = FALSE) {
        writeLines(
          c(
            "#!ascii",
            "2 1",
            "0.0 0.0 0.0 0",
            "1.0 1.0 1.0 0",
            "0 1 0 0"
          ),
          outfile
        )
      },
      .package = "freesurfer"
    )

    result <- surf2asc(input, output, verbose = 1L)
    expect_s3_class(result, "data.frame")
  })

  it("calls mris_convert with correct args when file exists", {
    tmp <- withr::local_tempdir()
    input <- file.path(tmp, "lh.white")
    writeLines("fake surface", input)
    output <- file.path(tmp, "lh.white.dpv")

    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      read_dpv = function(path) data.frame(x = 1)
    )
    local_mocked_bindings(
      mris_convert = function(infile, outfile, verbose = FALSE) {
        writeLines(
          c(
            "#!ascii",
            "2 1",
            "0.0 0.0 0.0 0",
            "1.0 1.0 1.0 0",
            "0 1 0 0"
          ),
          outfile
        )
      },
      .package = "freesurfer"
    )

    result <- surf2asc(input, output, verbose = FALSE)
    expect_s3_class(result, "data.frame")
  })

  it("errors when the converted asc file cannot be renamed", {
    tmp <- withr::local_tempdir()
    input <- file.path(tmp, "lh.white")
    writeLines("fake surface", input)
    output <- file.path(tmp, "lh.white.dpv")

    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE)
    )
    local_mocked_bindings(
      mris_convert = function(infile, outfile, verbose = FALSE) {
        invisible(NULL)
      },
      .package = "freesurfer"
    )

    expect_error(
      expect_warning(
        surf2asc(input, output, verbose = FALSE),
        "cannot rename file"
      ),
      "Failed to rename"
    )
  })
})

describe("check_mni152_subject", {
  it("accepts a subject sharing fsaverage's geometry", {
    local_mocked_bindings(subject_vox2ras = function(...) diag(4))

    expect_true(check_mni152_subject("fsaverage5"))
  })

  it("aborts for a subject on a different geometry", {
    local_mocked_bindings(
      subject_vox2ras = function(subject, ...) {
        if (identical(subject, "fsaverage")) diag(4) else diag(c(1, 1, 1, 2))
      }
    )

    expect_error(
      check_mni152_subject("fsaverage5"),
      "does not apply to subject"
    )
  })

  it("warns when the geometry cannot be read", {
    local_mocked_bindings(subject_vox2ras = function(...) NULL)

    expect_warning(check_mni152_subject("fsaverage5"), "Could not confirm")
  })
})


describe("warn_if_subject_space_volume", {
  it("warns when the volume sits on the subject's own voxel grid", {
    local_mocked_bindings(
      volume_vox2ras = function(...) diag(4),
      subject_vox2ras = function(...) diag(4)
    )

    expect_warning(
      warn_if_subject_space_volume("volume.mgz", "fsaverage5"),
      "own voxel grid"
    )
  })

  it("stays silent for a volume on a different voxel grid", {
    local_mocked_bindings(
      volume_vox2ras = function(...) diag(c(1.5, 1.5, 1.5, 1)),
      subject_vox2ras = function(...) diag(4)
    )

    result <- expect_no_warning(
      warn_if_subject_space_volume("volume.nii", "fsaverage5")
    )
    expect_false(result)
  })

  it("stays silent when the geometry cannot be read", {
    local_mocked_bindings(
      volume_vox2ras = function(...) NULL,
      subject_vox2ras = function(...) diag(4)
    )

    result <- expect_no_warning(
      warn_if_subject_space_volume("volume.nii", "fsaverage5")
    )
    expect_false(result)
  })
})


describe("volume_grid", {
  it("rejects a grid with a missing dimension", {
    # A 2-D mgz gives dim(mgh$data)[1:3] = c(x, y, NA). Without the anyNA
    # screen that reaches `if (NA)` as "missing value where TRUE/FALSE
    # needed" instead of the clean no-grid refusal.
    volume <- withr::local_tempfile(fileext = ".mgz")
    file.create(volume)
    local_mocked_bindings(
      read_volume_grid = function(...) {
        list(vox2ras = diag(c(-1, 1, 1, 1)), dim = c(74L, 56L, NA_integer_))
      }
    )
    expect_null(volume_grid(volume))
  })

  it("rejects a grid with fewer than three dimensions", {
    volume <- withr::local_tempfile(fileext = ".mgz")
    file.create(volume)
    local_mocked_bindings(
      read_volume_grid = function(...) {
        list(vox2ras = diag(c(-1, 1, 1, 1)), dim = c(74L, 56L))
      }
    )
    expect_null(volume_grid(volume))
  })

  it("rejects a grid whose dimensions are unusable", {
    # tkreg depends on dim * voxel size, so a missing or nonsense extent
    # leaves the field of view unknown just as surely as a missing affine.
    volume <- withr::local_tempfile(fileext = ".mgz")
    file.create(volume)
    local_mocked_bindings(
      read_volume_grid = function(...) {
        list(vox2ras = diag(c(-1, 1, 1, 1)), dim = c(4L, 0L, 4L))
      }
    )
    expect_null(volume_grid(volume))
  })

  it("returns a usable grid unchanged", {
    volume <- withr::local_tempfile(fileext = ".mgz")
    file.create(volume)
    grid <- list(vox2ras = diag(c(-1, 1, 1, 1)), dim = c(4L, 4L, 4L))
    local_mocked_bindings(read_volume_grid = function(...) grid)
    expect_identical(volume_grid(volume), grid)
    expect_identical(volume_vox2ras(volume), grid$vox2ras)
  })
})


describe("scanner_to_tkreg", {
  it("is independent of voxel size for a fixed field of view", {
    # The voxel sizes cancel out of vox2tkr %*% solve(vox2ras), which is why
    # keying the grid check on voxel size was wrong: 1 mm and 2 mm volumes of
    # the same extent have the SAME tkreg frame.
    las <- function(d, n, origin) {
      a <- cbind(c(-d, 0, 0), c(0, d, 0), c(0, 0, d))
      list(vox2ras = rbind(cbind(a, origin), c(0, 0, 0, 1)), dim = n)
    }
    fine <- las(1, c(182, 218, 182), c(90, -126, -72))
    coarse <- las(2, c(91, 109, 91), c(90, -126, -72))

    expect_equal(scanner_to_tkreg(coarse), scanner_to_tkreg(fine))
  })
})


describe("scanner_to_tkreg against freesurferformats", {
  it("agrees with mghheader.scanner2tkreg on a real mgz", {
    # The LIA `mdc` constant is an orthogonal LEFT factor of both maps that
    # tkreg_mismatch() compares, so it cancels out of every difference: the
    # sign flips could be anything and no consumer would notice. This is the
    # only assertion that the function really is a scanner-to-tkreg
    # transform rather than an arbitrary shared basis.
    skip_if_not_installed("freesurferformats")
    mgz <- test_path("testdata/volumetric/aseg.mgz")
    header <- freesurferformats::read.fs.mgh(mgz, with_header = TRUE)$header

    expect_equal(
      scanner_to_tkreg(read_volume_grid(mgz)),
      freesurferformats::mghheader.scanner2tkreg(header),
      ignore_attr = TRUE
    )
  })
})


describe("tkreg_mismatch", {
  # A mirror differs in the axes with the translations EQUAL, and a shifted
  # field of view differs only in position. Measuring one without the other
  # lets the other through silently.
  las <- function(d, n, origin, mdc) {
    a <- mdc %*% diag(rep(d, 3))
    list(vox2ras = rbind(cbind(a, origin), c(0, 0, 0, 1)), dim = n)
  }
  las_mdc <- cbind(c(-1, 0, 0), c(0, 1, 0), c(0, 0, 1))
  ras_mdc <- diag(3)
  lia_mdc <- cbind(c(-1, 0, 0), c(0, 0, -1), c(0, 1, 0))

  rotated_about_z <- function(deg) {
    t <- deg * pi / 180
    rot <- matrix(c(cos(t), sin(t), 0, -sin(t), cos(t), 0, 0, 0, 1), 3, 3)
    list(
      vox2ras = rbind(
        cbind(rot %*% las_mdc, rot %*% c(90, -126, -72)),
        c(0, 0, 0, 1)
      ),
      dim = c(182L, 218L, 182L)
    )
  }

  it("calls a mirror an axis difference", {
    m <- tkreg_mismatch(las(1, c(182, 218, 182), c(-90, -126, -72), ras_mdc))
    expect_true(m$axes_differ)
  })

  it("sees a conformed LIA volume, which the determinant sign cannot", {
    conformed <- las(1, c(256, 256, 256), c(128, -128, -128), lia_mdc)
    expect_lt(det(conformed$vox2ras[1:3, 1:3]), 0)
    expect_true(tkreg_mismatch(conformed)$axes_differ)
  })

  it("sees a shifted field of view as displacement, not an axis difference", {
    m <- tkreg_mismatch(las(1, c(4, 4, 4), c(0, 0, 0), las_mdc))
    expect_false(m$axes_differ)
    expect_equal(round(m$displacement_mm, 2), 25.51)
  })

  it("reports no mismatch for the grid the transform was built for", {
    m <- tkreg_mismatch(mni152_1mm_grid())
    expect_false(m$axes_differ)
    expect_equal(m$displacement_mm, 0)
  })

  it("does not call a fraction of a degree of rotation an axis difference", {
    # A rotated sform is NOT an axis-order error -- the permutation is
    # identical. Comparing the linear parts unrounded made a 0.01 degree
    # rotation (float32 sform noise, or an ANTs/FLIRT composed affine) abort
    # as though it had been through mri_convert --conform.
    expect_false(tkreg_mismatch(rotated_about_z(0.01))$axes_differ)
    expect_false(tkreg_mismatch(rotated_about_z(1))$axes_differ)
  })

  it("measures a rotation that the translation parts cannot see", {
    # Rotating about the field-of-view centre leaves BOTH translations
    # identical, so a translation-only measure reported 0.0 mm while the edge
    # of the brain moved millimetres. Over the reference corners it shows up.
    grid <- rotated_about_z(1)
    a <- scanner_to_tkreg(grid)
    b <- scanner_to_tkreg(mni152_1mm_grid())

    expect_equal(a[1:3, 4], b[1:3, 4])
    expect_gt(tkreg_mismatch(grid)$displacement_mm, 2)
  })
})


describe("check_mni152_grid", {
  grid_of <- function(d, n, origin, mdc) {
    a <- mdc %*% diag(rep(d, 3))
    list(vox2ras = rbind(cbind(a, origin), c(0, 0, 0, 1)), dim = n)
  }
  las_mdc <- cbind(c(-1, 0, 0), c(0, 1, 0), c(0, 0, 1))
  ras_mdc <- diag(3)
  lia_mdc <- cbind(c(-1, 0, 0), c(0, 0, -1), c(0, 1, 0))
  mni_origin <- c(90, -126, -72)

  reference <- mni152_1mm_grid()
  grayordinate_2mm <- grid_of(2, c(91, 109, 91), mni_origin, las_mdc)
  mirrored <- grid_of(1, c(182, 218, 182), c(-90, -126, -72), ras_mdc)
  conformed <- grid_of(1, c(256, 256, 256), c(128, -128, -128), lia_mdc)

  it("accepts the grid the transform was built for", {
    local_mocked_bindings(volume_grid = function(...) reference)
    expect_true(check_mni152_grid("volume.nii"))
  })

  it("accepts the 2 mm grayordinate grid in silence", {
    # The motivating case, and the one the old voxel-size test got backwards:
    # this grid shares the reference 182x218x182 mm extent, so the transform
    # is exact and there is nothing to warn about.
    local_mocked_bindings(volume_grid = function(...) grayordinate_2mm)
    expect_no_condition(
      expect_true(check_mni152_grid("volume.nii")),
      class = "ggseg_extra_mni152_displacement_warning"
    )
  })

  it("refuses a right-handed volume, which reflects an anatomical axis", {
    local_mocked_bindings(volume_grid = function(...) mirrored)
    expect_error(check_mni152_grid("volume.nii"), "right-handed")
  })

  it("refuses a conformed volume, which a determinant test lets through", {
    # mri_convert --conform yields LIA at 1 mm: left-handed and 1 mm, so the
    # old handedness-plus-voxel-size test passed it in total silence while
    # the parcels were displaced by hundreds of millimetres.
    local_mocked_bindings(volume_grid = function(...) conformed)
    expect_error(check_mni152_grid("volume.nii"), "wrong axes")
  })

  it("refuses a shift past the tolerable ceiling", {
    # A shift is not categorical, but it is not harmless without limit
    # either: past about a gyrus the label lands on another structure, so
    # warning and continuing would be the same silence this check replaced.
    shifted <- grid_of(1, c(4, 4, 4), c(0, 0, 0), las_mdc)
    expect_gt(tkreg_mismatch(shifted)$displacement_mm, mni152_max_shift_mm())

    local_mocked_bindings(volume_grid = function(...) shifted)
    expect_error(check_mni152_grid("volume.nii"), "neighbouring structures")
  })

  it("warns about a tolerable shift and carries on, naming the millimetres", {
    # Just inside the ceiling: must warn and return, not abort.
    nudged <- grid_of(1, c(182, 218, 182), mni_origin + c(4, 0, 0), las_mdc)
    expect_lt(tkreg_mismatch(nudged)$displacement_mm, mni152_max_shift_mm())

    local_mocked_bindings(volume_grid = function(...) nudged)
    expect_warning(
      result <- check_mni152_grid("volume.nii"),
      class = "ggseg_extra_mni152_displacement_warning"
    )
    expect_true(result)
    local_mocked_bindings(volume_grid = function(...) nudged)
    expect_warning(check_mni152_grid("volume.nii"), "4 mm")
  })

  it("stays silent when the shift is below one voxel", {
    # Hammersmith is 181x217x181: under a millimetre out on a 1 mm grid,
    # which is indistinguishable from resampling and must not warn.
    local_mocked_bindings(
      volume_grid = function(...) {
        grid_of(1, c(181, 217, 181), mni_origin, las_mdc)
      }
    )
    expect_no_condition(
      check_mni152_grid("volume.nii"),
      class = "ggseg_extra_mni152_displacement_warning"
    )
  })

  it("accepts a tiny volume that shares the reference frame", {
    # Guards the fixture arithmetic the call-site tests depend on: a 4x4x4
    # volume is on the reference tkreg frame at origin (1, -19, 17), and
    # displaced 25.5 mm at (0, 0, 0).
    local_mocked_bindings(
      volume_grid = function(...) {
        grid_of(1, c(4, 4, 4), mni152_frame_origin(c(4, 4, 4)), las_mdc)
      }
    )
    expect_no_condition(
      expect_true(check_mni152_grid("volume.nii")),
      class = "ggseg_extra_mni152_displacement_warning"
    )
  })

  it("takes the smallest voxel as the tolerance, not the largest", {
    # A thick-slice volume must not get millimetres of silent in-plane error
    # on the strength of its slice thickness.
    anisotropic <- list(
      vox2ras = rbind(
        cbind(diag(c(-1, 1, 3)), mni_origin + c(2, 0, 0)),
        c(0, 0, 0, 1)
      ),
      dim = c(182L, 218L, 61L)
    )
    expect_equal(min(sqrt(colSums(anisotropic$vox2ras[1:3, 1:3]^2))), 1)

    local_mocked_bindings(volume_grid = function(...) anisotropic)
    expect_warning(
      check_mni152_grid("volume.nii"),
      class = "ggseg_extra_mni152_displacement_warning"
    )
  })

  it("reports the reflection, not the shift, when a volume is wrong in both", {
    # Order matters: the reflection is categorical and the shift is not.
    local_mocked_bindings(
      volume_grid = function(...) grid_of(1, c(4, 4, 4), c(0, 0, 0), ras_mdc)
    )
    # expect_error() alone is indifferent to a warning raised BEFORE the abort,
    # so it has to be nested this way round. The inversion
    # expect_error(expect_no_warning(...)) does not work: the outer
    # expect_error swallows the inner expectation's failure.
    expect_no_warning(
      expect_error(check_mni152_grid("volume.nii"), "right-handed"),
      class = "ggseg_extra_mni152_displacement_warning"
    )
  })

  it("accepts a real conformant volume on disk, in silence", {
    # Everything else here mocks volume_grid(), so no test proved that a
    # conformant FILE is accepted: fabricating the dimensions in
    # read_nifti_grid() left every test in this block green. This writes the
    # real FSL 2 mm grayordinate grid (91x109x91, LAS, MNI origin) and drives
    # the check through the reader.
    skip_if_not_installed("RNifti")
    path <- withr::local_tempfile(fileext = ".nii.gz")
    img <- RNifti::asNifti(array(0L, dim = c(91L, 109L, 91L)))
    RNifti::pixdim(img) <- c(2, 2, 2)
    RNifti::sform(img) <- structure(
      rbind(
        c(-2, 0, 0, 90),
        c(0, 2, 0, -126),
        c(0, 0, 2, -72),
        c(0, 0, 0, 1)
      ),
      code = 2L
    )
    RNifti::writeNifti(img, path)

    expect_no_condition(
      expect_true(check_mni152_grid(path)),
      class = "ggseg_extra_mni152_displacement_warning"
    )
  })

  it("warns on a real off-centre volume, blaming the caller", {
    # The warn verdict driven from a file rather than a mock, and the only
    # assertion that `call` reaches the condition: without it the warning is
    # attributed to this internal helper instead of the caller.
    skip_if_not_installed("RNifti")
    path <- withr::local_tempfile(fileext = ".nii.gz")
    img <- RNifti::asNifti(array(0L, dim = c(91L, 109L, 91L)))
    RNifti::pixdim(img) <- c(2, 2, 2)
    RNifti::sform(img) <- structure(
      rbind(
        c(-2, 0, 0, 94),
        c(0, 2, 0, -126),
        c(0, 0, 2, -72),
        c(0, 0, 0, 1)
      ),
      code = 2L
    )
    RNifti::writeNifti(img, path)

    caller <- function(volume) check_mni152_grid(volume)
    condition <- tryCatch(
      caller(path),
      ggseg_extra_mni152_displacement_warning = identity
    )

    expect_s3_class(condition, "ggseg_extra_mni152_displacement_warning")
    expect_match(conditionMessage(condition), "4 mm")
    expect_identical(conditionCall(condition), quote(caller(path)))
  })

  it("refuses when no grid can be read, rather than passing silently", {
    # Orientation is exactly what this transform depends on and exactly what
    # an unreadable header does not state, so silence here was strictly
    # weaker than the abort it replaced.
    local_mocked_bindings(volume_grid = function(...) NULL)
    expect_error(check_mni152_grid("volume.nii"), "orientation is unknown")
  })

  it("is reached by validate_registration for mni152 only", {
    local_mocked_bindings(volume_grid = function(...) mirrored)
    expect_error(
      validate_registration("mni152", "fsaverage5", "volume.nii"),
      "does not apply"
    )
    expect_null(validate_registration("header", "fsaverage5", "volume.nii"))
  })
})


describe("validate_registration", {
  it("checks subject and volume space for mni152", {
    checked <- new.env()
    local_mocked_bindings(have_fs = function(...) TRUE, .package = "freesurfer")
    local_mocked_bindings(
      volume_grid = function(...) mni152_1mm_grid(),
      check_mni152_subject = function(subject) {
        checked$subject <- subject
        invisible(TRUE)
      },
      warn_if_subject_space_volume = function(input_volume, subject) {
        checked$volume <- input_volume
        invisible(FALSE)
      }
    )

    expect_null(validate_registration("mni152", "fsaverage5", "volume.nii"))
    expect_identical(checked$subject, "fsaverage5")
    expect_identical(checked$volume, "volume.nii")
  })

  it("skips the space checks for other registrations", {
    local_mocked_bindings(
      check_mni152_subject = function(...) cli::cli_abort("should not run"),
      warn_if_subject_space_volume = function(...) {
        cli::cli_abort("should not run")
      }
    )

    expect_null(validate_registration("header", "fsaverage5", "volume.nii"))
  })

  it("skips the space checks when FreeSurfer is absent", {
    local_mocked_bindings(
      have_fs = function(...) FALSE,
      .package = "freesurfer"
    )
    local_mocked_bindings(
      volume_grid = function(...) mni152_1mm_grid(),
      check_mni152_subject = function(...) cli::cli_abort("should not run"),
      warn_if_subject_space_volume = function(...) {
        cli::cli_abort("should not run")
      }
    )

    expect_null(validate_registration("mni152", "fsaverage5", "volume.nii"))
  })
})


describe("mni152_register_path without FreeSurfer", {
  it("says FreeSurfer is missing instead of building an NA path", {
    local_mocked_bindings(
      fs_dir = function(...) NA_character_,
      .package = "freesurfer"
    )

    expect_error(mni152_register_path(), "Cannot locate FreeSurfer")
    expect_error(mni152_register_path(), "FREESURFER_HOME")
    expect_error(registration_file("mni152"), "Cannot locate FreeSurfer")
  })

  it("never interpolates NA into a path", {
    local_mocked_bindings(
      fs_dir = function(...) NA_character_,
      .package = "freesurfer"
    )

    message <- tryCatch(
      mni152_register_path(),
      error = function(e) cli::ansi_strip(conditionMessage(e))
    )

    expect_no_match(message, "NA/", fixed = TRUE)
    expect_no_match(message, "'NA'", fixed = TRUE)
  })
})


describe("validate_registration without FreeSurfer", {
  it("defers FreeSurfer's transform to the projection step", {
    local_mocked_bindings(
      fs_dir = function(...) NA_character_,
      have_fs = function(...) FALSE,
      .package = "freesurfer"
    )
    local_mocked_bindings(
      volume_grid = function(...) mni152_1mm_grid(),
      check_mni152_subject = function(...) cli::cli_abort("should not run"),
      warn_if_subject_space_volume = function(...) {
        cli::cli_abort("should not run")
      }
    )

    expect_null(validate_registration("mni152", "fsaverage5", "volume.nii"))
  })

  it("still rejects a bad user-supplied path without FreeSurfer", {
    local_mocked_bindings(
      have_fs = function(...) FALSE,
      .package = "freesurfer"
    )

    expect_error(
      validate_registration("no/such/registration.dat", "fsaverage5"),
      "Registration file not found"
    )
  })

  it("still rejects a specification that is not a single string", {
    expect_error(
      validate_registration(TRUE, "fsaverage5"),
      "single string"
    )
  })
})


describe("registration = NULL", {
  it("is refused by project_volume_anatomical() before any command runs", {
    skip_if_not_installed("RNifti")
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      resolve_volume_path = function(...) {
        cli::cli_abort("should not be reached")
      }
    )

    expect_error(
      project_volume_anatomical("vol.nii.gz", registration = NULL),
      "must be a single string"
    )
  })

  it("is refused by prepare_subcortical_mni152()", {
    skip_if_not_installed("RNifti")
    vol <- withr::local_tempfile(fileext = ".nii.gz")
    file.create(vol)
    local_mocked_bindings(
      check_fs = function(...) invisible(TRUE),
      resolve_volume_path = function(...) vol
    )

    expect_error(
      prepare_subcortical_mni152(vol, registration = NULL),
      "must be a single string"
    )
  })
})
