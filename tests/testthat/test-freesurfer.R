.cap <- new.env()

testthat::describe("check_fs", {
  it("returns logical", {
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

    expect_messages(
      {
        result <- check_fs(abort = FALSE)
      },
      "Freesurfer"
    )
    expect_false(result)
  })

  it("does not abort when abort = FALSE", {
    result <- check_fs(abort = FALSE)
    expect_type(result, "logical")
  })

  it("errors when freesurfer is older than the minimum version", {
    local_mocked_bindings(freesurfer_min_version = function() "999.0.0")

    expect_error(check_fs(), class = "rlib_error_package_not_found")
  })
})

testthat::describe("freesurfer_repos", {
  it("puts the ggsegverse r-universe ahead of the configured repos", {
    withr::local_options(repos = c(CRAN = "https://cloud.r-project.org"))

    expect_identical(
      freesurfer_repos(),
      c(
        ggsegverse = "https://ggsegverse.r-universe.dev",
        CRAN = "https://cloud.r-project.org"
      )
    )
  })
})

testthat::describe("freesurfer_min_version", {
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


testthat::describe("mri_vol2surf", {
  it("constructs correct command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "mri_vol2surf")
    expect_match(.cap$captured_cmd, paste("--mov", shQuote("input.mgz")))
    expect_match(.cap$captured_cmd, paste("--o", shQuote("output.mgz")))
    expect_match(.cap$captured_cmd, "--hemi lh")
    expect_match(.cap$captured_cmd, "--projfrac 0.5")
  })

  it("emits no registration flags when none are given", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      verbose = FALSE
    )

    expect_no_match(.cap$captured_cmd, "--reg ")
    expect_no_match(.cap$captured_cmd, "--regheader")
    expect_no_match(.cap$captured_cmd, "--srcsubject")
  })

  it("passes a registration file together with its source subject", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      reg = "mni152.register.dat",
      srcsubject = "fsaverage5",
      verbose = FALSE
    )

    expect_match(
      .cap$captured_cmd,
      paste(
        "--reg",
        shQuote("mni152.register.dat"),
        "--srcsubject fsaverage5"
      ),
      fixed = TRUE
    )
    expect_no_match(.cap$captured_cmd, "--regheader")
  })

  it("passes --regheader for volumes in the subject's own space", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      regheader = "fsaverage5",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "--regheader fsaverage5")
    expect_no_match(.cap$captured_cmd, "--reg ")
    expect_no_match(.cap$captured_cmd, "--srcsubject")
  })

  it("refuses a registration without a source subject", {
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) invisible(NULL)
    )

    expect_error(
      mri_vol2surf(
        input_file = "input.mgz",
        output_file = "output.mgz",
        hemisphere = "lh",
        reg = "mni152.register.dat",
        verbose = FALSE
      ),
      "srcsubject"
    )
  })
})


testthat::describe("mni152_register_path", {
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


testthat::describe("resolve_vol2surf_registration", {
  it("maps 'mni152' to FreeSurfer's transform and a source subject", {
    reg_file <- withr::local_tempfile(fileext = ".dat")
    file.create(reg_file)
    local_mocked_bindings(mni152_register_path = function() reg_file)

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


testthat::describe("mri_pretess", {
  it("constructs correct command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_pretess(
      template = "vol.mgz",
      label = 10,
      output_file = "pretess.mgz",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "mri_pretess")
    expect_match(.cap$captured_cmd, "vol.mgz")
    expect_match(.cap$captured_cmd, "10")
    expect_match(.cap$captured_cmd, "pretess.mgz")
  })

  it("appends opts to command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_pretess(
      template = "vol.mgz",
      label = 10,
      output_file = "pretess.mgz",
      opts = "--keep",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "--keep")
  })
})


testthat::describe("mri_tessellate", {
  it("constructs correct command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_tessellate(
      input_file = "pretess.mgz",
      label = 10,
      output_file = "tess",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "mri_tessellate")
    expect_match(.cap$captured_cmd, "pretess.mgz")
    expect_match(.cap$captured_cmd, "10")
    expect_match(.cap$captured_cmd, "tess")
  })

  it("appends opts to command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_tessellate(
      input_file = "pretess.mgz",
      label = 10,
      output_file = "tess",
      opts = "--extra-flag",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "--extra-flag")
  })
})


testthat::describe("mri_smooth", {
  it("constructs correct command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_smooth(
      input_file = "tess",
      output_file = "smooth",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "mris_smooth")
    expect_match(.cap$captured_cmd, "-nw")
  })

  it("appends opts to command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_smooth(
      input_file = "tess",
      output_file = "smooth",
      opts = "--seed 42",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "--seed 42")
  })
})


testthat::describe("mri_vol2surf with opts", {
  it("appends opts to command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      opts = "--interp trilinear",
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "--interp trilinear")
  })
})


testthat::describe("mri_vol2surf with projfrac_range", {
  it("uses --projfrac-max for multi-depth projection", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      projfrac_range = c(0, 1, 0.1),
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "--projfrac-max 0 1 0.1")
    expect_false(
      grepl("--projfrac 0.5", .cap$captured_cmd, fixed = TRUE)
    )
  })
})


testthat::describe("mri_surf2surf_rereg", {
  it("constructs correct command", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    tmp <- withr::local_tempdir()

    mri_surf2surf_rereg(
      subject = "bert",
      annot = "aparc.DKTatlas",
      hemisphere = "lh",
      output_dir = tmp,
      verbose = FALSE
    )

    expect_match(.cap$captured_cmd, "mri_surf2surf")
    expect_match(.cap$captured_cmd, paste("--srcsubject", shQuote("bert")))
    expect_match(
      .cap$captured_cmd,
      paste("--sval-annot", shQuote("aparc.DKTatlas"))
    )
    expect_match(.cap$captured_cmd, "--hemi lh")
  })

  it("warns about deprecated hemi argument and delegates to hemisphere", {
    .cap$captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        .cap$captured_cmd <- cmd
        invisible(NULL)
      }
    )

    tmp <- withr::local_tempdir()

    lifecycle::expect_deprecated(
      mri_surf2surf_rereg(
        subject = "bert",
        annot = "aparc.DKTatlas",
        hemi = "rh",
        output_dir = tmp,
        verbose = FALSE
      )
    )

    expect_match(.cap$captured_cmd, "--hemi rh")
  })
})


testthat::describe("surf2asc", {
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
      suppressWarnings(surf2asc(input, output, verbose = FALSE)),
      "Failed to rename"
    )
  })
})
