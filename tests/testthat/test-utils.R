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

  it("falls back rather than erroring on input that is not length 1", {
    expect_identical(as_verbosity(c(0, 2)), 1L)
    expect_identical(as_verbosity(c("true", "false")), 1L)
    expect_identical(as_verbosity(NULL), 1L)
    expect_identical(as_verbosity(character()), 1L)
  })

  it("reads a factor by its label, not its level index", {
    expect_identical(as_verbosity(factor("2")), 2L)
    expect_identical(as_verbosity(factor("0")), 0L)
  })

  it("accepts spelled-out boolean strings", {
    expect_identical(as_verbosity("false"), 0L)
    expect_identical(as_verbosity("FALSE"), 0L)
    expect_identical(as_verbosity("off"), 0L)
    expect_identical(as_verbosity("true"), 1L)
    expect_identical(as_verbosity("on"), 1L)
  })

  it("still reads numeric strings as levels", {
    expect_identical(as_verbosity("0"), 0L)
    expect_identical(as_verbosity("2"), 2L)
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

  it("parses spelled-out boolean env vars as silent/standard", {
    withr::local_options(ggseg.extra.verbose = NULL)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "false")
    expect_identical(get_verbose(), 0L)

    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "true")
    expect_identical(get_verbose(), 1L)
  })

  it("option takes precedence over envvar", {
    withr::local_options(ggseg.extra.verbose = TRUE)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "0")
    expect_identical(get_verbose(), 1L)
  })

  it("takes an explicit level over the option and the envvar", {
    withr::local_options(ggseg.extra.verbose = 0)
    withr::local_envvar(GGSEG_EXTRA_VERBOSE = "0")
    expect_identical(get_verbose(2), 2L)
    expect_identical(get_verbose(FALSE), 0L)
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

  it("accepts string spellings from explicit and option channels", {
    expect_true(get_cleanup("yes"))
    expect_false(get_cleanup("no"))

    withr::local_options(ggseg.extra.cleanup = "1")
    expect_true(get_cleanup())

    withr::local_options(ggseg.extra.cleanup = "off")
    expect_false(get_cleanup())
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

  it("defaults to not reusing a cache", {
    # A step cache records which ggseg.extra wrote it, not what it was built
    # from, so reuse cannot tell that the volume has changed. Running the step
    # costs time; reusing it can cost correctness.
    withr::local_options(ggseg.extra.skip_existing = NULL)
    withr::local_envvar(GGSEG_EXTRA_SKIP_EXISTING = NA)
    expect_false(get_skip_existing())
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
    tmp <- local_cache_file(list(a = 1))

    # Reuse is reported: the cache was not checked against current inputs.
    expect_warning(
      result <- load_or_run_step(
        1L,
        1L:3L,
        files = tmp,
        skip_existing = TRUE,
        step_name = "Test step"
      ),
      "without checking it"
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
    tmp <- local_cache_file(list(b = 2))

    expect_warning(
      result <- load_or_run_step(
        1L,
        2L:3L,
        files = tmp,
        skip_existing = FALSE,
        step_name = "Test step"
      ),
      "without checking it"
    )

    expect_false(result$run)
    expect_identical(result$data[[1]], list(b = 2))
  })

  it("aborts when a cache predates the format version and step is not run", {
    tmp <- local_cache_file(list(a = 1), stamped = FALSE)

    expect_error(
      load_or_run_step(
        1L,
        2L:3L,
        files = tmp,
        skip_existing = TRUE,
        step_name = "Step 1 (Project to surface)"
      ),
      "Include step 1"
    )
  })

  it("recomputes a stale cache when its step was requested", {
    tmp <- local_cache_file(list(a = 1), stamped = FALSE)

    expect_message(
      result <- load_or_run_step(
        1L,
        1L:3L,
        files = tmp,
        skip_existing = TRUE,
        step_name = "Step 1"
      ),
      "recomputing"
    )

    expect_true(result$run)
    expect_null(result$data)
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

    expect_message(preview_atlas(atlas), "malformed")
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

    expect_output(result <- preview_atlas(atlas), "mock_3d")
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

    expect_output(result <- preview_atlas(atlas), "mock_3d")
    expect_identical(result, atlas)
    expect_length(.cap$prompts, 1)
    expect_match(.cap$prompts[1], "3D preview")
  })

  it("warns on 3D errors instead of failing silently", {
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

    expect_message(
      result <- preview_atlas(atlas),
      "3D preview failed"
    )
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

    expect_message(result <- preview_atlas(atlas), "malformed")
    expect_identical(result, atlas)
  })
})


describe("log_elapsed", {
  it("reports the elapsed time in cli's duration format", {
    expect_message(log_elapsed(Sys.time() - 75), "Pipeline completed")
  })
})


describe("absolute_path", {
  it("makes a relative path that does not exist yet absolute", {
    local_test_workdir()
    expect_identical(
      absolute_path("not_yet"),
      as.character(fs::path(fs::path_abs("."), "not_yet"))
    )
  })

  it("expands a leading tilde", {
    expect_false(startsWith(absolute_path("~/x"), "~"))
  })
})


describe("format_duration", {
  it("matches cli's progress step timings", {
    expect_identical(format_duration(0.04), "40ms")
    expect_identical(format_duration(2.5), "2.5s")
    expect_identical(format_duration(75), "1m 15s")
    expect_identical(format_duration(3725), "1h 2m 5s")
  })

  it("leaves out units that are zero", {
    expect_identical(format_duration(90000), "1d 1h")
    expect_identical(format_duration(120), "2m")
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


describe("with_safe_plan", {
  it("evaluates the expression under a non-multicore plan", {
    expect_identical(with_safe_plan(1 + 1), 2)
  })

  it("leaves a multicore plan alone", {
    skip_if_not(future::supportsMulticore())
    old <- future::plan(future::multicore, workers = 2)
    withr::defer(future::plan(old))

    expect_no_message(expect_identical(with_safe_plan(42), 42))
    expect_s3_class(future::plan(), "multicore")
  })

  it("muffles the known furrr globals warning", {
    expect_no_warning(
      with_safe_plan(warning("globals may not be available when loading"))
    )
  })

  it("lets unrelated warnings propagate", {
    expect_warning(
      with_safe_plan(warning("some unrelated warning")),
      "unrelated"
    )
  })
})


describe("load_rda", {
  it("loads objects from an rda into the target environment", {
    tmp <- withr::local_tempfile(fileext = ".rda")
    demo_obj <- list(a = 1, b = 2)
    save(demo_obj, file = tmp)

    env <- new.env()
    load_rda(tmp, envir = env)
    expect_identical(get("demo_obj", envir = env), list(a = 1, b = 2))
  })

  it("errors when the file does not exist", {
    expect_error(load_rda("/no/such/file.rda"), "not found")
  })
})


describe("load_or_run_step reuse reporting", {
  a_cache <- function() {
    dir <- withr::local_tempdir(.local_envir = parent.frame(2))
    file <- file.path(dir, "step.rds")
    saveRDS(list(1), file)
    stamp_cache_files(file)
    file
  }

  it("reports a reuse the caller asked for with skip_existing", {
    # The pipeline tests all mock load_or_run_step, so this is the only level
    # at which the reporting is exercised at all.
    expect_warning(
      result <- load_or_run_step(1L, 1L:3L, a_cache(), TRUE, "Step 1"),
      "without checking it against the current inputs"
    )
    expect_false(result$run)
  })

  it("reports a reuse that happened because the step was left out", {
    # How the documented two-phase workflow continues a build, and the one
    # reuse path that skip_existing = FALSE does not close.
    expect_warning(
      result <- load_or_run_step(1L, 2L:3L, a_cache(), FALSE, "Step 1"),
      "without checking it against the current inputs"
    )
    expect_false(result$run)
  })

  it("stays quiet when it runs the step instead of reusing", {
    expect_no_warning(
      result <- load_or_run_step(1L, 1L:3L, a_cache(), FALSE, "Step 1")
    )
    expect_true(result$run)
  })

  it("stays quiet when there is no cache to reuse", {
    expect_no_warning(
      result <- load_or_run_step(
        1L,
        1L:3L,
        file.path(withr::local_tempdir(), "absent.rds"),
        TRUE,
        "Step 1"
      )
    )
    expect_true(result$run)
  })
})
