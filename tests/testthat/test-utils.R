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
    expect_equal(as_verbosity(FALSE), 0L)
    expect_equal(as_verbosity(TRUE), 1L)
  })

  it("clamps numeric to 0-2", {
    expect_equal(as_verbosity(0), 0L)
    expect_equal(as_verbosity(1), 1L)
    expect_equal(as_verbosity(2), 2L)
    expect_equal(as_verbosity(5), 2L)
  })

  it("defaults to 1 for invalid input", {
    expect_equal(as_verbosity(-1), 1L)
    expect_equal(as_verbosity(NA), 1L)
    expect_equal(as_verbosity("bad"), 1L)
  })
})

describe("get_verbose", {
  it("returns 1L by default", {
    withr::local_options(ggseg.extra.verbose = NULL)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = NA)
    expect_equal(get_verbose(), 1L)
  })

  it("reads from option", {
    withr::local_options(ggseg.extra.verbose = FALSE)
    expect_equal(get_verbose(), 0L)

    withr::local_options(ggseg.extra.verbose = 2)
    expect_equal(get_verbose(), 2L)
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.verbose = NULL)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "0")
    expect_equal(get_verbose(), 0L)
  })

  it("option takes precedence over envvar", {
    withr::local_options(ggseg.extra.verbose = TRUE)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "0")
    expect_equal(get_verbose(), 1L)
  })
})


describe("is_verbose", {
  it("returns integer levels", {
    expect_equal(is_verbose(1), 1L)
    expect_equal(is_verbose(TRUE), 1L)
    expect_equal(is_verbose(2), 2L)
  })

  it("returns 0 for silent", {
    expect_equal(is_verbose(0), 0L)
    expect_equal(is_verbose(FALSE), 0L)
  })

  it("delegates to get_verbose when NULL", {
    withr::local_options(ggseg.extra.verbose = FALSE)
    expect_equal(is_verbose(), 0L)

    withr::local_options(ggseg.extra.verbose = TRUE)
    expect_equal(is_verbose(), 1L)

    withr::local_options(ggseg.extra.verbose = 2)
    expect_equal(is_verbose(), 2L)
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
    expect_equal(get_tolerance(0.5), 0.5)
    expect_equal(get_tolerance(1), 1)
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.tolerance = 0.75)
    expect_equal(get_tolerance(), 0.75)
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.tolerance = NULL)
    withr::local_envvar(GGSEG_EXTRA_TOLERANCE = "0.25")
    expect_equal(get_tolerance(), 0.25)
  })

  it("returns default of 1 when nothing is set", {
    withr::local_options(ggseg.extra.tolerance = NULL)
    withr::local_envvar(GGSEG_EXTRA_TOLERANCE = NA)
    expect_equal(get_tolerance(), 1)
  })
})


describe("get_smoothness", {
  it("returns explicit value when provided", {
    expect_equal(get_smoothness(10), 10)
    expect_equal(get_smoothness(2.5), 2.5)
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.smoothness = 15)
    expect_equal(get_smoothness(), 15)
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.smoothness = NULL)
    withr::local_envvar(GGSEG_EXTRA_SMOOTHNESS = "20")
    expect_equal(get_smoothness(), 20)
  })

  it("returns default of 5 when nothing is set", {
    withr::local_options(ggseg.extra.smoothness = NULL)
    withr::local_envvar(GGSEG_EXTRA_SMOOTHNESS = NA)
    expect_equal(get_smoothness(), 5)
  })
})


describe("get_snapshot_dim", {
  it("returns explicit value when provided", {
    expect_equal(get_snapshot_dim(1024), 1024)
    expect_equal(get_snapshot_dim(400), 400)
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.snapshot_dim = 512)
    expect_equal(get_snapshot_dim(), 512)
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.snapshot_dim = NULL)
    withr::local_envvar(GGSEG_EXTRA_SNAPSHOT_DIM = "1200")
    expect_equal(get_snapshot_dim(), 1200)
  })

  it("returns default of 800 when nothing is set", {
    withr::local_options(ggseg.extra.snapshot_dim = NULL)
    withr::local_envvar(GGSEG_EXTRA_SNAPSHOT_DIM = NA)
    expect_equal(get_snapshot_dim(), 800)
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
    expect_equal(result$data[[1]], list(b = 2))
  })
})


describe("warn_if_large_atlas", {
  it("warns when atlas has many vertices", {
    coords <- matrix(runif(200), ncol = 2)
    coords <- rbind(coords, coords[1, ])
    sf_obj <- sf::st_sf(
      label = "test",
      geometry = sf::st_sfc(sf::st_polygon(list(coords)))
    )
    atlas <- list(data = list(sf = sf_obj))

    expect_warning(
      warn_if_large_atlas(atlas, max_vertices = 5),
      "vertices"
    )
  })

  it("does not warn when atlas is small", {
    sf_obj <- sf::st_sf(
      label = "test",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    atlas <- list(data = list(sf = sf_obj))

    expect_no_warning(warn_if_large_atlas(atlas, max_vertices = 10000))
  })

  it("does nothing when atlas has no sf data", {
    atlas <- list(data = list(sf = NULL))
    expect_no_warning(warn_if_large_atlas(atlas))
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

    expect_message(preview_atlas(atlas), "malformed")
  })

  it("shows 3D cortical preview for both hemispheres", {
    atlas <- list(
      type = "cortical",
      data = list(sf = NULL, vertices = TRUE, meshes = NULL)
    )

    prompts <- character()
    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(msg) {
        prompts <<- c(prompts, msg)
        ""
      }
    )
    local_mocked_bindings(
      ggseg3d = function(...) structure(list(), class = "mock_3d"),
      pan_camera = function(x, ...) x,
      set_legend = function(x, ...) x,
      .package = "ggseg3d"
    )

    invisible(capture.output(result <- preview_atlas(atlas)))
    expect_identical(result, atlas)
    expect_length(prompts, 2)
    expect_match(prompts[1], "left")
    expect_match(prompts[2], "right")
  })

  it("shows 3D subcortical preview", {
    atlas <- list(
      type = "subcortical",
      data = list(sf = NULL, vertices = TRUE, meshes = NULL)
    )

    prompts <- character()
    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(msg) {
        prompts <<- c(prompts, msg)
        ""
      }
    )
    local_mocked_bindings(
      ggseg3d = function(...) structure(list(), class = "mock_3d"),
      set_legend = function(x, ...) x,
      .package = "ggseg3d"
    )

    invisible(capture.output(result <- preview_atlas(atlas)))
    expect_identical(result, atlas)
    expect_length(prompts, 1)
    expect_match(prompts[1], "3D preview")
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

    invisible(capture.output(result <- preview_atlas(atlas)))
    expect_identical(result, atlas)
  })

  it("shows 2D preview with geom_brain", {
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

    prompts <- character()
    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(msg) {
        prompts <<- c(prompts, msg)
        ""
      }
    )
    local_mocked_bindings(
      geom_brain = function(...) ggplot2::geom_blank(),
      position_brain = function(...) ggplot2::position_identity(),
      .package = "ggseg"
    )

    result <- preview_atlas(atlas)
    expect_identical(result, atlas)
    expect_length(prompts, 1)
    expect_match(prompts[1], "2D preview")
  })

  it("applies palette when available", {
    sf_data <- sf::st_sf(
      label = c("a", "b"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 2, 3, 2, 3, 3, 2, 2),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    atlas <- list(
      data = list(sf = sf_data, vertices = NULL, meshes = NULL),
      palette = c(a = "red", b = "blue")
    )

    prompts <- character()
    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(msg) {
        prompts <<- c(prompts, msg)
        ""
      }
    )
    local_mocked_bindings(
      geom_brain = function(...) ggplot2::geom_blank(),
      position_brain = function(...) ggplot2::position_identity(),
      .package = "ggseg"
    )

    suppressWarnings(result <- preview_atlas(atlas))
    expect_identical(result, atlas)
    expect_length(prompts, 1)
  })

  it("falls back to base plot when geom_brain errors", {
    sf_data <- sf::st_sf(
      label = "test",
      geometry = sf::st_sfc(sf::st_polygon(list(matrix(
        c(0, 0, 1, 0, 1, 1, 0, 0),
        ncol = 2,
        byrow = TRUE
      ))))
    )
    atlas <- list(
      data = list(sf = sf_data, vertices = NULL, meshes = NULL)
    )

    prompts <- character()
    local_mocked_bindings(
      is_interactive = function() TRUE,
      prompt_user = function(msg) {
        prompts <<- c(prompts, msg)
        ""
      }
    )
    local_mocked_bindings(
      geom_brain = function(...) stop("geom_brain failed"),
      position_brain = function(...) ggplot2::position_identity(),
      .package = "ggseg"
    )

    result <- preview_atlas(atlas)
    expect_identical(result, atlas)
    expect_length(prompts, 0)
  })
})


describe("log_elapsed", {
  it("logs elapsed time as cli message", {
    start <- Sys.time() - 60
    expect_message(log_elapsed(start), "Pipeline completed in")
  })
})


describe("get_output_dir", {
  it("returns explicit value when provided", {
    expect_equal(get_output_dir("/tmp/my_dir"), "/tmp/my_dir")
  })

  it("reads from option when explicit value is NULL", {
    withr::local_options(ggseg.extra.output_dir = "/opt/atlases")
    expect_equal(get_output_dir(), "/opt/atlases")
  })

  it("reads from environment variable when option is NULL", {
    withr::local_options(ggseg.extra.output_dir = NULL)
    withr::local_envvar(GGSEG_EXTRA_OUTPUT_DIR = "/env/path")
    expect_equal(get_output_dir(), "/env/path")
  })

  it("returns tempdir when nothing is set", {
    withr::local_options(ggseg.extra.output_dir = NULL)
    withr::local_envvar(GGSEG_EXTRA_OUTPUT_DIR = NA)
    expect_equal(get_output_dir(), tempdir(check = TRUE))
  })
})


describe("get_numeric_option", {
  it("falls back to default when env var is not numeric", {
    withr::local_options(ggseg.extra.tolerance = NULL)
    withr::local_envvar(GGSEG_EXTRA_TOLERANCE = "not_a_number")
    expect_equal(get_tolerance(), 1)
  })
})


describe("prompt_user", {
  it("is a function that wraps readline", {
    expect_true(is.function(prompt_user))
  })

  it("calls readline with the provided message", {
    local_mocked_bindings(
      readline = function(prompt) paste0("echo:", prompt),
      .package = "base"
    )
    result <- prompt_user("test message")
    expect_equal(result, "echo:test message")
  })
})
