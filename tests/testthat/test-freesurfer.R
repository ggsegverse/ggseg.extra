describe("check_fs", {
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

    expect_message(
      result <- check_fs(abort = FALSE),
      "Freesurfer"
    )
    expect_false(result)
  })

  it("does not abort when abort = FALSE", {
    result <- check_fs(abort = FALSE)
    expect_type(result, "logical")
  })
})


describe("mri_vol2surf", {
  it("constructs correct command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
        invisible(NULL)
      }
    )

    mri_vol2surf(
      input_file = "input.mgz",
      output_file = "output.mgz",
      hemisphere = "lh",
      verbose = FALSE
    )

    expect_match(captured_cmd, "mri_vol2surf")
    expect_match(captured_cmd, paste("--mov", shQuote("input.mgz")))
    expect_match(captured_cmd, paste("--o", shQuote("output.mgz")))
    expect_match(captured_cmd, "--hemi lh")
    expect_match(captured_cmd, "--projfrac 0.5")
  })
})


describe("mri_pretess", {
  it("constructs correct command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
        invisible(NULL)
      }
    )

    mri_pretess(
      template = "vol.mgz",
      label = 10,
      output_file = "pretess.mgz",
      verbose = FALSE
    )

    expect_match(captured_cmd, "mri_pretess")
    expect_match(captured_cmd, "vol.mgz")
    expect_match(captured_cmd, "10")
    expect_match(captured_cmd, "pretess.mgz")
  })

  it("appends opts to command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
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

    expect_match(captured_cmd, "--keep")
  })
})


describe("mri_tessellate", {
  it("constructs correct command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
        invisible(NULL)
      }
    )

    mri_tessellate(
      input_file = "pretess.mgz",
      label = 10,
      output_file = "tess",
      verbose = FALSE
    )

    expect_match(captured_cmd, "mri_tessellate")
    expect_match(captured_cmd, "pretess.mgz")
    expect_match(captured_cmd, "10")
    expect_match(captured_cmd, "tess")
  })

  it("appends opts to command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
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

    expect_match(captured_cmd, "--extra-flag")
  })
})


describe("mri_smooth", {
  it("constructs correct command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
        invisible(NULL)
      }
    )

    mri_smooth(
      input_file = "tess",
      output_file = "smooth",
      verbose = FALSE
    )

    expect_match(captured_cmd, "mris_smooth")
    expect_match(captured_cmd, "-nw")
  })

  it("appends opts to command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
        invisible(NULL)
      }
    )

    mri_smooth(
      input_file = "tess",
      output_file = "smooth",
      opts = "--seed 42",
      verbose = FALSE
    )

    expect_match(captured_cmd, "--seed 42")
  })
})


describe("mri_vol2surf with opts", {
  it("appends opts to command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
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

    expect_match(captured_cmd, "--interp trilinear")
  })
})


describe("mri_surf2surf_rereg", {
  it("constructs correct command", {
    captured_cmd <- NULL
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      run_cmd = function(cmd, verbose = FALSE) {
        captured_cmd <<- cmd
        invisible(NULL)
      }
    )

    tmp <- withr::local_tempdir()

    mri_surf2surf_rereg(
      subject = "bert",
      annot = "aparc.DKTatlas",
      hemi = "lh",
      output_dir = tmp,
      verbose = FALSE
    )

    expect_match(captured_cmd, "mri_surf2surf")
    expect_match(captured_cmd, paste("--srcsubject", shQuote("bert")))
    expect_match(captured_cmd, paste("--sval-annot", shQuote("aparc.DKTatlas")))
    expect_match(captured_cmd, "--hemi lh")
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
      result <- surf2asc("/nonexistent/file", "output.dpv", verbose = TRUE),
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
})
