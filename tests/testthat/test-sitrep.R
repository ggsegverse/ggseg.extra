describe("setup_sitrep", {
  it("returns list of results invisibly", {
    local_mocked_bindings(
      have_fs = function() TRUE,
      fs_sitrep = function() invisible(NULL),
      .package = "freesurfer"
    )

    expect_messages(result <- setup_sitrep("simple"))

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

    expect_no_error(expect_messages(setup_sitrep("simple")))
    expect_no_error(expect_messages(setup_sitrep("full")))
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

    expect_messages(result <- check_freesurfer("simple"))

    expect_type(result, "list")
    expect_true("available" %in% names(result))
    expect_type(result$available, "logical")
  })
})


describe("check_other_system_deps", {
  it("returns list with imagemagick and chrome fields", {
    expect_messages(result <- check_other_system_deps("simple"))

    expect_type(result, "list")
    expect_true("imagemagick" %in% names(result))
    expect_true("chrome" %in% names(result))
    expect_type(result$imagemagick, "logical")
    expect_type(result$chrome, "logical")
  })
})


describe("check_fsaverage", {
  it("returns list with fsaverage5 field", {
    expect_messages(result <- check_fsaverage("simple"))

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
    expect_messages(check_freesurfer("simple"), "not configured")
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
    expect_messages(check_other_system_deps("full"), "imagemagick.org")
  })

  it("shows help text when Chrome missing in full detail", {
    local_mocked_bindings(
      has_magick = function() TRUE,
      find_chrome_path = function() NULL
    )
    expect_messages(check_other_system_deps("full"), "Install Chrome")
  })
})


describe("check_fsaverage", {
  it("alerts when fsaverage5 not found", {
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent/path",
      .package = "freesurfer"
    )
    expect_messages(check_fsaverage("simple"), "not found")
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
        RNifti = rnifti, Rvcg = TRUE, neuromapr = neuromapr
      ),
      suit = list(flatmap = flatmap, surface_3d = surface_3d)
    )
  }

  it("shows all pipelines ready when deps are met", {
    expect_messages(
      summarize_pipelines(make_results(), "simple"),
      "All 12 pipelines ready"
    )
  })

  it("shows missing deps per pipeline", {
    expect_messages(
      summarize_pipelines(
        make_results(gifti = FALSE, cifti = FALSE),
        "simple"
      ),
      "pipelines ready"
    )
  })

  it("minimal collapses ready groups", {
    expect_messages(
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


describe("check_freesurfer when freesurfer package absent", {
  it("returns available=FALSE in minimal detail silently", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    msgs <- character()
    result <- withCallingHandlers(
      check_freesurfer("minimal"),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    expect_false(result$available)
    expect_length(msgs, 0)
  })

  it("returns available=FALSE with danger message in simple detail", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_messages(
      result <- check_freesurfer("simple"),
      "not installed"
    )
    expect_false(result$available)
  })

  it("shows install command in full detail", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_messages(
      check_freesurfer("full"),
      "install.packages"
    )
  })
})


describe("check_fsaverage additional branches", {
  it("handles missing freesurfer package gracefully", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_messages(
      result <- check_fsaverage("simple"),
      "not found"
    )
    expect_false(result$fsaverage5)
  })

  it("shows path in full detail when fsaverage5 exists", {
    tmp <- withr::local_tempdir()
    dir.create(file.path(tmp, "fsaverage5"))
    local_mocked_bindings(
      fs_subj_dir = function() tmp,
      .package = "freesurfer"
    )
    expect_messages(
      check_fsaverage("full"),
      "fsaverage5"
    )
  })

  it("shows Ships-with-FreeSurfer hint in full detail when absent", {
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent",
      .package = "freesurfer"
    )
    expect_messages(
      check_fsaverage("full"),
      "Ships with FreeSurfer"
    )
  })
})


describe("check_optional_packages additional branches", {
  it("returns results silently in minimal detail", {
    msgs <- character()
    result <- withCallingHandlers(
      check_optional_packages("minimal"),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    expect_length(msgs, 0)
    expect_type(result, "list")
  })

  it("shows install command in full detail for missing packages", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) pkg == "RNifti",
      .package = "rlang"
    )
    expect_messages(
      check_optional_packages("full"),
      "install.packages"
    )
  })
})


describe("check_suit_surfaces additional branches", {
  it("runs silently in minimal detail", {
    msgs <- character()
    withCallingHandlers(
      check_suit_surfaces("minimal"),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    expect_length(msgs, 0)
  })

  it("alerts only flatmap missing when 3D exists", {
    local_mocked_bindings(
      suit_flatmap_path = function() "",
      suit_3d_path = function() system.file(
        "suit", "SUIT.surf.gii", package = "ggseg.extra"
      )
    )
    expect_messages(
      check_suit_surfaces("simple"),
      "flatmap surface missing"
    )
  })

  it("alerts only 3D surface missing when flatmap exists", {
    local_mocked_bindings(
      suit_3d_path = function() "",
      suit_flatmap_path = function() system.file(
        "suit", "SUIT_flatmap.surf.gii", package = "ggseg.extra"
      )
    )
    expect_messages(
      check_suit_surfaces("simple"),
      "3D surface missing"
    )
  })

  it("shows reinstall hint in full detail when missing", {
    local_mocked_bindings(
      suit_flatmap_path = function() "",
      suit_3d_path = function() ""
    )
    expect_messages(
      check_suit_surfaces("full"),
      "remotes::install_github"
    )
  })
})


describe("summarize_pipelines additional branches", {
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
        RNifti = rnifti, Rvcg = TRUE, neuromapr = neuromapr
      ),
      suit = list(flatmap = flatmap, surface_3d = surface_3d)
    )
  }

  it("prints group-level all-ready in minimal mode", {
    expect_messages(
      summarize_pipelines(make_results(), "minimal"),
      "all.*ready"
    )
  })

  it("prints Run setup_sitrep hint in minimal when not all ready", {
    expect_messages(
      summarize_pipelines(make_results(gifti = FALSE), "minimal"),
      "Run.*setup_sitrep"
    )
  })

  it("skips ready pipelines in minimal when group has failures", {
    expect_messages(
      summarize_pipelines(make_results(gifti = FALSE), "minimal"),
      "needs"
    )
  })

  it("prints setup_sitrep full hint in simple when not all ready", {
    expect_messages(
      summarize_pipelines(make_results(gifti = FALSE), "simple"),
      'setup_sitrep\\("full"\\)'
    )
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
