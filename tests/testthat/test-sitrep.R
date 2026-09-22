.cap <- new.env()

# setup_sitrep() reports on whatever is installed on the machine. Pin every
# environment-dependent input so its output is the same everywhere.
local_ready_environment <- function(env = parent.frame()) {
  local_test_workdir(env)
  subjects_dir <- "subjects"
  dir.create(file.path(subjects_dir, "fsaverage5"), recursive = TRUE)
  local_mocked_bindings(
    is_installed = function(pkg, ...) TRUE,
    .package = "rlang",
    .env = env
  )
  local_mocked_bindings(
    have_fs = function() TRUE,
    fs_sitrep = function() invisible(NULL),
    fs_subj_dir = function() subjects_dir,
    .package = "freesurfer",
    .env = env
  )
  withr::local_options(
    ggseg.extra.verbose = FALSE,
    ggseg.extra.cleanup = TRUE,
    ggseg.extra.skip_existing = TRUE,
    ggseg.extra.tolerance = 0.05,
    ggseg.extra.smoothness = 5,
    ggseg.extra.output_dir = "/atlas-output",
    .local_envir = env
  )
}

describe("setup_sitrep", {
  it("returns list of results invisibly", {
    local_ready_environment()

    expect_snapshot(
      result <- setup_sitrep("simple")
    )

    expect_type(result, "list")
    expect_true("freesurfer" %in% names(result))
    expect_true("fsaverage" %in% names(result))
  })

  it("reports paths and options in full detail", {
    local_ready_environment()

    expect_snapshot(setup_sitrep("full"))
  })

  it("validates detail argument", {
    expect_error(setup_sitrep("invalid"), "arg")
  })
})


describe("check_freesurfer", {
  it("returns list with available field", {
    local_ready_environment()

    expect_message(result <- check_freesurfer("simple"), "FreeSurfer")

    expect_type(result, "list")
    expect_true("available" %in% names(result))
    expect_type(result$available, "logical")
  })
})


describe("check_fsaverage", {
  it("returns list with fsaverage5 field", {
    local_ready_environment()

    expect_message(result <- check_fsaverage("simple"), "fsaverage5")

    expect_type(result, "list")
    expect_true("fsaverage5" %in% names(result))
    expect_type(result$fsaverage5, "logical")
  })
})


describe("check_freesurfer", {
  it("alerts danger when FreeSurfer not configured in simple mode", {
    local_ready_environment()
    local_mocked_bindings(
      have_fs = function() FALSE,
      .package = "freesurfer"
    )
    expect_message(check_freesurfer("simple"), "not configured")
  })
})


describe("check_fsaverage", {
  it("alerts when fsaverage5 not found", {
    local_ready_environment()
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent/path",
      .package = "freesurfer"
    )
    expect_message(check_fsaverage("simple"), "not found")
  })
})


describe("summarize_pipelines", {
  make_results <- function(gifti = TRUE, cifti = TRUE) {
    list(
      freesurfer = list(available = TRUE),
      fsaverage = list(fsaverage5 = TRUE),
      packages = list(
        freesurferformats = TRUE,
        gifti = gifti,
        ciftiTools = cifti,
        RNifti = TRUE,
        Rvcg = TRUE,
        neuromapr = TRUE
      ),
      suit = list(flatmap = TRUE, surface_3d = TRUE)
    )
  }

  it("shows all pipelines ready when deps are met", {
    expect_snapshot(summarize_pipelines(make_results(), "simple"))
  })

  it("shows missing deps per pipeline", {
    expect_snapshot(
      summarize_pipelines(
        make_results(gifti = FALSE, cifti = FALSE),
        "simple"
      )
    )
  })

  it("minimal collapses ready groups", {
    expect_snapshot(summarize_pipelines(make_results(), "minimal"))
  })

  it("lists only failing pipelines and hints setup_sitrep in minimal mode", {
    expect_snapshot(
      summarize_pipelines(make_results(gifti = FALSE), "minimal")
    )
  })

  it("full shows install hints for missing deps", {
    expect_snapshot(
      summarize_pipelines(make_results(gifti = FALSE), "full")
    )
  })
})


describe("check_freesurfer when freesurfer package absent", {
  it("returns available=FALSE in minimal detail silently", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_silent(result <- check_freesurfer("minimal"))
    expect_false(result$available)
  })

  it("returns available=FALSE with danger message in simple detail", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_message(result <- check_freesurfer("simple"), "not installed")
    expect_false(result$available)
  })

  it("shows install command in full detail", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_snapshot(invisible(check_freesurfer("full")))
  })

  it("treats a freesurfer older than the minimum version as not installed", {
    local_mocked_bindings(
      is_installed = function(pkg, version = NULL) is.null(version),
      .package = "rlang"
    )
    expect_message(
      result <- check_freesurfer("simple"),
      freesurfer_min_version()
    )
    expect_false(result$available)
  })
})


describe("check_fsaverage additional branches", {
  it("handles missing freesurfer package gracefully", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) FALSE,
      .package = "rlang"
    )
    expect_message(result <- check_fsaverage("simple"), "not found")
    expect_false(result$fsaverage5)
  })

  it("does not query an outdated freesurfer for the subjects dir", {
    local_mocked_bindings(
      is_installed = function(pkg, version = NULL) is.null(version),
      .package = "rlang"
    )
    .cap$queried <- FALSE
    local_mocked_bindings(
      fs_subj_dir = function() {
        .cap$queried <- TRUE
        ""
      },
      .package = "freesurfer"
    )
    expect_message(result <- check_fsaverage("simple"), "not found")
    expect_false(result$fsaverage5)
    expect_false(.cap$queried)
  })

  it("shows path in full detail when fsaverage5 exists", {
    local_ready_environment()
    expect_message(check_fsaverage("full"), "fsaverage5: ")
  })

  it("shows Ships-with-FreeSurfer hint in full detail when absent", {
    local_ready_environment()
    local_mocked_bindings(
      fs_subj_dir = function() "/nonexistent",
      .package = "freesurfer"
    )
    expect_snapshot(invisible(check_fsaverage("full")))
  })
})


describe("check_optional_packages additional branches", {
  it("returns results silently in minimal detail", {
    expect_silent(result <- check_optional_packages("minimal"))
    expect_type(result, "list")
  })

  it("shows install command in full detail for missing packages", {
    local_mocked_bindings(
      is_installed = function(pkg, ...) pkg == "RNifti",
      .package = "rlang"
    )
    expect_snapshot(invisible(check_optional_packages("full")))
  })
})


describe("check_suit_surfaces additional branches", {
  it("runs silently in minimal detail", {
    expect_silent(check_suit_surfaces("minimal"))
  })

  it("alerts only flatmap missing when 3D exists", {
    surface_3d <- suit_3d_path()
    local_mocked_bindings(
      suit_flatmap_path = function() "",
      suit_3d_path = function() surface_3d
    )
    expect_message(
      check_suit_surfaces("simple"),
      "flatmap surface missing"
    )
  })

  it("alerts only 3D surface missing when flatmap exists", {
    flatmap <- suit_flatmap_path()
    local_mocked_bindings(
      suit_3d_path = function() "",
      suit_flatmap_path = function() flatmap
    )
    expect_message(
      check_suit_surfaces("simple"),
      "3D surface missing"
    )
  })

  it("shows reinstall hint in full detail when missing", {
    local_mocked_bindings(
      suit_flatmap_path = function() "",
      suit_3d_path = function() ""
    )
    expect_snapshot(invisible(check_suit_surfaces("full")))
  })
})


describe("check_optional_packages minimum versions", {
  it("treats a ciftiTools older than the minimum version as missing", {
    local_mocked_bindings(
      is_installed = function(pkg, version = NULL) {
        !(pkg == "ciftiTools" && identical(version, ciftitools_min_version()))
      },
      .package = "rlang"
    )

    results <- check_optional_packages("minimal")

    expect_false(results$ciftiTools)
    expect_true(results$gifti)
  })
})
