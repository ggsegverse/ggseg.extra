describe("setup_sitrep", {
  it("returns list of results invisibly", {
    local_mocked_bindings(
      have_fs = function() TRUE,
      fs_sitrep = function() invisible(NULL),
      .package = "freesurfer"
    )

    expect_message(result <- setup_sitrep("simple"))

    expect_type(result, "list")
    expect_true("freesurfer" %in% names(result))
    expect_true("system" %in% names(result))
    expect_true("fsaverage" %in% names(result))
  })

  it("accepts detail parameter", {
    local_mocked_bindings(
      have_fs = function() TRUE,
      fs_sitrep = function() invisible(NULL),
      .package = "freesurfer"
    )

    expect_no_error(expect_message(setup_sitrep("simple")))
    expect_no_error(expect_message(setup_sitrep("full")))
  })

  it("validates detail argument", {
    expect_error(setup_sitrep("invalid"), "arg")
  })
})


describe("check_freesurfer", {
  it("returns list with available field", {
    local_mocked_bindings(
      have_fs = function() TRUE,
      .package = "freesurfer"
    )

    expect_message(result <- check_freesurfer("simple"))

    expect_type(result, "list")
    expect_true("available" %in% names(result))
    expect_type(result$available, "logical")
  })
})


describe("check_other_system_deps", {
  it("returns list with imagemagick and chrome fields", {
    expect_message(result <- check_other_system_deps("simple"))

    expect_type(result, "list")
    expect_true("imagemagick" %in% names(result))
    expect_true("chrome" %in% names(result))
    expect_type(result$imagemagick, "logical")
    expect_type(result$chrome, "logical")
  })
})


describe("check_fsaverage", {
  it("returns list with fsaverage5 field", {
    expect_message(result <- check_fsaverage("simple"))

    expect_type(result, "list")
    expect_true("fsaverage5" %in% names(result))
    expect_type(result$fsaverage5, "logical")
  })
})


describe("check_freesurfer", {
  it("alerts danger when FreeSurfer not configured in simple mode", {
    local_mocked_bindings(
      have_fs = function() FALSE,
      .package = "freesurfer"
    )
    expect_message(check_freesurfer("simple"), "not configured")
  })
})


describe("check_other_system_deps", {
  it("shows install URL when ImageMagick missing in full detail", {
    local_mocked_bindings(
      has_magick = function() FALSE
    )
    local_mocked_bindings(
      find_chrome_path = function() "/usr/bin/chromium"
    )
    expect_message(check_other_system_deps("full"), "imagemagick.org")
  })

  it("shows help text when Chrome missing in full detail", {
    local_mocked_bindings(
      has_magick = function() TRUE,
      find_chrome_path = function() NULL
    )
    expect_message(check_other_system_deps("full"), "Install Chrome")
  })
})


describe("check_fsaverage", {
  it("alerts when fsaverage5 not found", {
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent/path",
      .package = "freesurfer"
    )
    expect_message(check_fsaverage("simple"), "not found")
  })
})


describe("summarize_pipelines", {
  make_results <- function(
    fs = TRUE, fsavg = TRUE, gifti = TRUE, fsf = TRUE,
    rnifti = TRUE, cifti = TRUE, neuromapr = TRUE,
    flatmap = TRUE, surface_3d = TRUE
  ) {
    list(
      freesurfer = list(available = fs),
      system = list(imagemagick = TRUE, chrome = TRUE),
      fsaverage = list(fsaverage5 = fsavg),
      packages = list(
        freesurferformats = fsf, gifti = gifti, ciftiTools = cifti,
        RNifti = rnifti, smoothr = TRUE, Rvcg = TRUE, neuromapr = neuromapr
      ),
      suit = list(flatmap = flatmap, surface_3d = surface_3d)
    )
  }

  it("shows all pipelines ready when deps are met", {
    expect_message(
      summarize_pipelines(make_results(), "simple"),
      "All 12 pipelines ready"
    )
  })

  it("shows missing deps per pipeline", {
    expect_message(
      summarize_pipelines(
        make_results(gifti = FALSE, cifti = FALSE),
        "simple"
      ),
      "pipelines ready"
    )
  })

  it("minimal collapses ready groups", {
    expect_message(
      summarize_pipelines(make_results(), "minimal"),
      "All 12 pipelines ready"
    )
  })

  it("full shows install hints for missing deps", {
    out <- capture.output(
      summarize_pipelines(
        make_results(gifti = FALSE),
        "full"
      ),
      type = "message"
    )
    combined <- paste(out, collapse = "\n")
    expect_true(grepl("install.packages", combined))
  })
})


describe("find_chrome_path", {
  it("returns path from Sys.which when chrome is found", {
    local_mocked_bindings(
      Sys.which = function(name) {
        if (name == "google-chrome") "/usr/bin/google-chrome" else ""
      },
      .package = "base"
    )

    result <- find_chrome_path()
    expect_equal(result, "/usr/bin/google-chrome")
  })

  it("returns NULL when no chrome found anywhere", {
    local_mocked_bindings(
      Sys.which = function(name) "",
      .package = "base"
    )
    local_mocked_bindings(
      file.exists = function(path) {
        if (any(grepl("Chrome|Chromium|chrome", path))) return(FALSE)
        base::file.exists(path)
      },
      .package = "base"
    )

    result <- find_chrome_path()
    expect_null(result)
  })
})
