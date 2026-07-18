.cap <- new.env()

describe("mkdir", {
  it("creates directory", {
    tmp <- withr::local_tempdir()
    new_dir <- file.path(tmp, "test_subdir")

    expect_false(dir.exists(new_dir))
    mkdir(new_dir)
    expect_true(dir.exists(new_dir))
  })

  it("creates nested directories", {
    tmp <- withr::local_tempdir()
    nested <- file.path(tmp, "a", "b", "c")

    mkdir(nested)
    expect_true(dir.exists(nested))
  })

  it("does not error if directory exists", {
    tmp <- withr::local_tempdir()
    expect_no_error(mkdir(tmp))
  })
})


describe("as_verbosity", {
  it("converts logical to integer", {
    expect_identical(as_verbosity(FALSE), 0L)
    expect_identical(as_verbosity(TRUE), 1L)
  })

  it("clamps numeric to 0-2", {
    expect_identical(as_verbosity(0), 0L)
    expect_identical(as_verbosity(1), 1L)
    expect_identical(as_verbosity(2), 2L)
    expect_identical(as_verbosity(5), 2L)
  })

  it("defaults to 1 for invalid input", {
    expect_identical(as_verbosity(-1), 1L)
    expect_identical(as_verbosity(NA), 1L)
    expect_identical(as_verbosity("bad"), 1L)
  })
})

describe("get_verbose", {
  it("returns 1L by default", {
    withr::local_options(ggseg.extra.verbose = NULL)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = NA)
    expect_identical(get_verbose(), 1L)
  })

  it("reads from option", {
    withr::local_options(ggseg.extra.verbose = FALSE)
    expect_identical(get_verbose(), 0L)

    withr::local_options(ggseg.extra.verbose = 2)
    expect_identical(get_verbose(), 2L)
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.verbose = NULL)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "0")
    expect_identical(get_verbose(), 0L)
  })

  it("option takes precedence over envvar", {
    withr::local_options(ggseg.extra.verbose = TRUE)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "0")
    expect_identical(get_verbose(), 1L)
  })
})


describe("is_verbose", {
  it("returns integer levels", {
    expect_identical(is_verbose(1), 1L)
    expect_identical(is_verbose(TRUE), 1L)
    expect_identical(is_verbose(2), 2L)
  })

  it("returns 0 for silent", {
    expect_identical(is_verbose(0), 0L)
    expect_identical(is_verbose(FALSE), 0L)
  })

  it("delegates to get_verbose when NULL", {
    withr::local_options(ggseg.extra.verbose = FALSE)
    expect_identical(is_verbose(), 0L)

    withr::local_options(ggseg.extra.verbose = TRUE)
    expect_identical(is_verbose(), 1L)

    withr::local_options(ggseg.extra.verbose = 2)
    expect_identical(is_verbose(), 2L)
  })
})


describe("get_cleanup", {
  it("returns explicit value when provided", {
    expect_true(get_cleanup(TRUE))
    expect_false(get_cleanup(FALSE))
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.cleanup = FALSE)
    expect_false(get_cleanup())
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.cleanup = NULL)
    withr::local_envvar(GGSEG_EXTRA_CLEANUP = "false")
    expect_false(get_cleanup())

    withr::local_envvar(GGSEG_EXTRA_CLEANUP = "true")
    expect_true(get_cleanup())

    withr::local_envvar(GGSEG_EXTRA_CLEANUP = "1")
    expect_true(get_cleanup())

    withr::local_envvar(GGSEG_EXTRA_CLEANUP = "0")
    expect_false(get_cleanup())
  })

  it("returns default of TRUE when nothing is set", {
    withr::local_options(ggseg.extra.cleanup = NULL)
    withr::local_envvar(GGSEG_EXTRA_CLEANUP = NA)
    expect_true(get_cleanup())
  })
})


describe("get_skip_existing", {
  it("returns explicit value when provided", {
    expect_true(get_skip_existing(TRUE))
    expect_false(get_skip_existing(FALSE))
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.skip_existing = FALSE)
    expect_false(get_skip_existing())
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.skip_existing = NULL)
    withr::local_envvar(GGSEG_EXTRA_SKIP_EXISTING = "false")
    expect_false(get_skip_existing())
  })

  it("returns default of TRUE when nothing is set", {
    withr::local_options(ggseg.extra.skip_existing = NULL)
    withr::local_envvar(GGSEG_EXTRA_SKIP_EXISTING = NA)
    expect_true(get_skip_existing())
  })
})


describe("get_tolerance", {
  it("returns explicit value when provided", {
    expect_identical(get_tolerance(0.5), 0.5)
    expect_identical(get_tolerance(1), 1)
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.tolerance = 0.75)
    expect_identical(get_tolerance(), 0.75)
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.tolerance = NULL)
    withr::local_envvar(GGSEG_EXTRA_TOLERANCE = "0.25")
    expect_identical(get_tolerance(), 0.25)
  })

  it("returns default of 0.05 when nothing is set", {
    withr::local_options(ggseg.extra.tolerance = NULL)
    withr::local_envvar(GGSEG_EXTRA_TOLERANCE = NA)
    expect_identical(get_tolerance(), 0.05)
  })
})


describe("get_smoothness", {
  it("returns explicit value when provided", {
    expect_identical(get_smoothness(10), 10)
    expect_identical(get_smoothness(2.5), 2.5)
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.smoothness = 15)
    expect_identical(get_smoothness(), 15)
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.smoothness = NULL)
    withr::local_envvar(GGSEG_EXTRA_SMOOTHNESS = "20")
    expect_identical(get_smoothness(), 20)
  })

  it("returns default of 5 when nothing is set", {
    withr::local_options(ggseg.extra.smoothness = NULL)
    withr::local_envvar(GGSEG_EXTRA_SMOOTHNESS = NA)
    expect_identical(get_smoothness(), 5)
  })
})


describe("load_or_run_step", {
  it("returns run=TRUE when step is requested and files don't exist", {
    result <- load_or_run_step(
      1L,
      1L:3L,
      files = "/nonexistent/file.rds",
      skip_existing = FALSE,
      step_name = "Test step"
    )

    expect_true(result$run)
    expect_null(result$data)
  })

  it("loads data when files exist and skip_existing=TRUE", {
    tmp <- withr::local_tempfile(fileext = ".rds")
    saveRDS(list(a = 1), tmp)

    result <- load_or_run_step(
      1L,
      1L:3L,
      files = tmp,
      skip_existing = TRUE,
      step_name = "Test step"
    )

    expect_false(result$run)
    expect_type(result$data, "list")
  })

  it("errors when step not requested and files missing", {
    expect_error(
      load_or_run_step(
        1L,
        2L:3L,
        files = "/nonexistent/file.rds",
        skip_existing = FALSE,
        step_name = "Test step"
      ),
      "missing"
    )
  })

  it("loads data when step not requested but files exist", {
    tmp <- withr::local_tempfile(fileext = ".rds")
    saveRDS(list(b = 2), tmp)

    result <- load_or_run_step(
      1L,
      2L:3L,
      files = tmp,
      skip_existing = FALSE,
      step_name = "Test step"
    )

    expect_false(result$run)
    expect_identical(result$data[[1]], list(b = 2))
  })
})


describe("warn_if_large_atlas", {
  it("warns when atlas has many vertices", {
    coords <- matrix(runif(200), ncol = 2)
    coords <- rbind(coords, coords[1, ])
    sf_obj <- sf::st_sf(
      label = "test",
      view = "v1",
      geometry = sf::st_sfc(sf::st_polygon(list(coords)))
    )
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "subcortical",
      palette = c(test = "#000000"),
      core = data.frame(
        label = "test",
        region = "test",
        stringsAsFactors = FALSE
      ),
      data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
    )

    expect_warning(
      warn_if_large_atlas(atlas, max_vertices = 5),
      "vertices"
    )
  })

  it("counts vertices on a polygon-backed atlas", {
    coords <- matrix(runif(200), ncol = 2)
    coords <- rbind(coords, coords[1, ])
    sf_obj <- sf::st_sf(
      label = "test",
      view = "v1",
      geometry = sf::st_sfc(sf::st_polygon(list(coords)))
    )
    atlas <- ggseg.formats::as_polygon_atlas(
      ggseg.formats::ggseg_atlas(
        atlas = "t",
        type = "subcortical",
        palette = c(test = "#000000"),
        core = data.frame(
          label = "test",
          region = "test",
          stringsAsFactors = FALSE
        ),
        data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
      )
    )
    expect_true(ggseg.formats::is_atlas_polygon(atlas))

    expect_warning(
      warn_if_large_atlas(atlas, max_vertices = 5),
      "vertices"
    )
  })

  it("does not warn when atlas is small", {
    sf_obj <- sf::st_sf(
      label = "test",
      view = "v1",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "subcortical",
      palette = c(test = "#000000"),
      core = data.frame(
        label = "test",
        region = "test",
        stringsAsFactors = FALSE
      ),
      data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
    )

    expect_no_warning(warn_if_large_atlas(atlas, max_vertices = 10000))
  })

  it("does nothing when atlas has no 2D geometry", {
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "cortical",
      palette = c(a = "#000000"),
      core = data.frame(label = "a", region = "a", stringsAsFactors = FALSE),
      data = ggseg.formats::ggseg_data_cortical(
        vertices = data.frame(
          stringsAsFactors = FALSE,
          label = "a",
          vertices = I(list(1:3))
        )
      )
    )
    expect_no_warning(warn_if_large_atlas(atlas))
  })

  it("scales threshold with region count via per_region", {
    coords <- matrix(runif(200), ncol = 2)
    coords <- rbind(coords, coords[1, ])
    labels <- paste0("r", 1:10)
    sf_obj <- sf::st_sf(
      label = labels,
      view = "v1",
      geometry = sf::st_sfc(rep(
        list(sf::st_polygon(list(coords))),
        length(labels)
      ))
    )
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "subcortical",
      palette = stats::setNames(rep("#000000", 10), labels),
      core = data.frame(
        label = labels,
        region = labels,
        stringsAsFactors = FALSE
      ),
      data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
    )

    expect_no_warning(
      warn_if_large_atlas(atlas, max_vertices = 50, per_region = 200)
    )
    expect_warning(
      warn_if_large_atlas(atlas, max_vertices = 50, per_region = 5),
      "vertices"
    )
  })
})


describe("preview_atlas", {
  it("returns invisible atlas in non-interactive sessions", {
    atlas <- list(data = list(sf = TRUE))
    local_mocked_bindings(is_interactive = function() FALSE)

    result <- preview_atlas(atlas)
    expect_identical(result, atlas)
  })

  it("alerts when atlas has no compatible data", {
    atlas <- list(data = list(sf = NULL, vertices = NULL, meshes = NULL))
    local_mocked_bindings(is_interactive = function() TRUE)

    expect_messages(preview_atlas(atlas), "malformed")
  })

  it("shows 3D cortical preview for both hemispheres", {
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "cortical",
      core = data.frame(
        hemi = "left",
        region = "r",
        label = "lh_r",
        stringsAsFactors = FALSE
      ),
      palette = c(lh_r = "#FF0000"),
      data = ggseg.formats::ggseg_data_cortical(
        vertices = data.frame(
          stringsAsFactors = FALSE,
          label = "lh_r",
          vertices = I(list(0:3))
        )
      )
    )

    .cap$prompts <- character()
    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(msg) {
        .cap$prompts <- c(.cap$prompts, msg)
        ""
      }
    )
    local_mocked_bindings(
      ggseg3d = function(...) structure(list(), class = "mock_3d"),
      pan_camera = function(x, ...) x,
      set_legend = function(x, ...) x,
      .package = "ggseg3d"
    )

    invisible(capture.output({
      result <- preview_atlas(atlas)
    }))
    expect_identical(result, atlas)
    expect_length(.cap$prompts, 2)
    expect_match(.cap$prompts[1], "left")
    expect_match(.cap$prompts[2], "right")
  })

  it("shows 3D subcortical preview", {
    atlas <- list(
      type = "subcortical",
      data = list(sf = NULL, vertices = TRUE, meshes = NULL)
    )

    .cap$prompts <- character()
    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(msg) {
        .cap$prompts <- c(.cap$prompts, msg)
        ""
      }
    )
    local_mocked_bindings(
      ggseg3d = function(...) structure(list(), class = "mock_3d"),
      set_legend = function(x, ...) x,
      .package = "ggseg3d"
    )

    invisible(capture.output({
      result <- preview_atlas(atlas)
    }))
    expect_identical(result, atlas)
    expect_length(.cap$prompts, 1)
    expect_match(.cap$prompts[1], "3D preview")
  })

  it("handles 3D errors gracefully", {
    atlas <- list(
      type = "cortical",
      data = list(sf = NULL, vertices = TRUE, meshes = NULL)
    )

    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(...) ""
    )
    local_mocked_bindings(
      ggseg3d = function(...) stop("3D rendering failed"),
      .package = "ggseg3d"
    )

    invisible(capture.output({
      result <- preview_atlas(atlas)
    }))
    expect_identical(result, atlas)
  })

  it("reports malformed atlas when only sf data present", {
    sf_data <- sf::st_sf(
      label = "test",
      geometry = sf::st_sfc(sf::st_polygon(list(matrix(
        c(0, 0, 1, 0, 1, 1, 0, 0),
        ncol = 2,
        byrow = TRUE
      ))))
    )
    atlas <- list(
      data = list(sf = sf_data, vertices = NULL, meshes = NULL),
      palette = NULL
    )

    local_mocked_bindings(is_interactive = function() TRUE)

    expect_messages(
      {
        result <- preview_atlas(atlas)
      },
      "malformed"
    )
    expect_identical(result, atlas)
  })
})


describe("log_elapsed", {
  it("logs elapsed time as cli message", {
    start <- Sys.time() - 60
    expect_messages(log_elapsed(start), "Pipeline completed in")
  })
})


describe("get_output_dir", {
  it("returns explicit value when provided", {
    expect_identical(get_output_dir("/tmp/my_dir"), "/tmp/my_dir")
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.output_dir = "/opt/atlases")
    expect_identical(get_output_dir(), "/opt/atlases")
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.output_dir = NULL)
    withr::local_envvar(GGSEG_EXTRA_OUTPUT_DIR = "/env/path")
    expect_identical(get_output_dir(), "/env/path")
  })

  it("returns tempdir when nothing is set", {
    withr::local_options(ggseg.extra.output_dir = NULL)
    withr::local_envvar(GGSEG_EXTRA_OUTPUT_DIR = NA)
    expect_identical(get_output_dir(), tempdir(check = TRUE))
  })
})


describe("get_numeric_option", {
  it("falls back to default when env var is not numeric", {
    withr::local_options(ggseg.extra.tolerance = NULL)
    withr::local_envvar(GGSEG_EXTRA_TOLERANCE = "not_a_number")
    expect_identical(get_tolerance(), 0.05)
  })
})


describe("prompt_user", {
  it("is a function that wraps readline", {
    expect_type(prompt_user, "closure")
  })

  it("calls readline with the provided message", {
    local_mocked_bindings(
      readline = function(prompt) paste0("echo:", prompt),
      .package = "base"
    )
    result <- prompt_user("test message")
    expect_identical(result, "echo:test message")
  })
})


describe("warn_deprecated_sf_smoothing", {
  it("is a no-op when nothing is supplied", {
    expect_no_warning(warn_deprecated_sf_smoothing())
  })

  it("warns when tolerance is supplied", {
    withr::local_options(lifecycle_verbosity = "warning")
    expect_warnings(
      warn_deprecated_sf_smoothing(tolerance = 0.1),
      "tolerance"
    )
  })

  it("warns when smoothness is supplied", {
    withr::local_options(lifecycle_verbosity = "warning")
    expect_warnings(
      warn_deprecated_sf_smoothing(smoothness = 2),
      "smoothness"
    )
  })

  it("warns when smooth_refinements is supplied", {
    withr::local_options(lifecycle_verbosity = "warning")
    expect_warnings(
      warn_deprecated_sf_smoothing(smooth_refinements = 3),
      "smooth_refinements"
    )
  })

  it("warns once per supplied argument when several are passed together", {
    withr::local_options(lifecycle_verbosity = "warning")
    n_warnings <- 0L
    withCallingHandlers(
      warn_deprecated_sf_smoothing(tolerance = 0.1, smoothness = 2),
      warning = function(w) {
        n_warnings <<- n_warnings + 1L
        invokeRestart("muffleWarning")
      }
    )
    expect_identical(n_warnings, 2L)
  })

  it("includes the calling function name in the message when supplied", {
    withr::local_options(lifecycle_verbosity = "warning")
    expect_warnings(
      warn_deprecated_sf_smoothing(
        tolerance = 0.1,
        fn = "create_cortical_from_gifti"
      ),
      "create_cortical_from_gifti"
    )
  })
})
