describe("build_contour_sf", {
  it("produces sf with label and view columns", {
    contours_file <- withr::local_tempfile(fileext = ".rda")

    contours <- sf::st_sf(
      filenm = c("axial_1_regionA", "coronal_1_regionB"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 0, 3, 0, 3, 1, 2, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = contours_file)

    views <- data.frame(
      name = c("axial_1", "coronal_1"),
      type = c("axial", "coronal"),
      start = c(85, 110),
      end = c(95, 120),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      make_multipolygon = function(f) {
        env <- new.env()
        load(f, envir = env)
        env$contours
      },
      layout_volumetric_views = function(df) df
    )

    result <- build_contour_sf(contours_file, views)

    expect_s3_class(result, "sf")
    expect_true(all(c("label", "view") %in% names(result)))
    expect_equal(nrow(result), 2)
  })

  it("assigns views from filename prefix", {
    contours_file <- withr::local_tempfile(fileext = ".rda")

    contours <- sf::st_sf(
      filenm = c("axial_1_regionA", "axial_1_regionB", "coronal_1_regionC"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 0, 3, 0, 3, 1, 2, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(4, 0, 5, 0, 5, 1, 4, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = contours_file)

    views <- data.frame(
      name = c("axial_1", "coronal_1"),
      type = c("axial", "coronal"),
      start = c(85, 110),
      end = c(95, 120),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      make_multipolygon = function(f) {
        env <- new.env()
        load(f, envir = env)
        env$contours
      },
      layout_volumetric_views = function(df) df
    )

    result <- build_contour_sf(contours_file, views)

    expect_equal(sort(unique(result$view)), c("axial_1", "coronal_1"))
  })

  it("strips view prefix from label", {
    contours_file <- withr::local_tempfile(fileext = ".rda")

    contours <- sf::st_sf(
      filenm = c("axial_1_Left-Putamen"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = contours_file)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 85,
      end = 95,
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      make_multipolygon = function(f) {
        env <- new.env()
        load(f, envir = env)
        env$contours
      },
      layout_volumetric_views = function(df) df
    )

    result <- build_contour_sf(contours_file, views)

    expect_equal(result$label, "Left-Putamen")
  })

  it("appends cortex_slices view names when provided", {
    contours_file <- withr::local_tempfile(fileext = ".rda")

    contours <- sf::st_sf(
      filenm = c("axial_1_regionA", "cortex_1_cortex"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 0, 3, 0, 3, 1, 2, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = contours_file)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 85,
      end = 95,
      stringsAsFactors = FALSE
    )
    cortex_slices <- data.frame(
      name = "cortex_1",
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      make_multipolygon = function(f) {
        env <- new.env()
        load(f, envir = env)
        env$contours
      },
      layout_volumetric_views = function(df) df
    )

    result <- build_contour_sf(contours_file, views, cortex_slices)

    expect_s3_class(result, "sf")
    expect_true("cortex_1" %in% result$view)
  })

  it("uses filename as label when view is NA", {
    contours_file <- withr::local_tempfile(fileext = ".rda")

    contours <- sf::st_sf(
      filenm = c("unmatched_region"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = contours_file)

    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 85,
      end = 95,
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      make_multipolygon = function(f) {
        env <- new.env()
        load(f, envir = env)
        env$contours
      },
      layout_volumetric_views = function(df) df
    )

    result <- build_contour_sf(contours_file, views)

    expect_equal(result$label, "unmatched_region")
    expect_true(is.na(result$view))
  })
})


describe("extract_contours", {
  it("scans for max value and processes regions", {
    input_dir <- withr::local_tempdir("masks_")
    output_dir <- withr::local_tempdir("output_")
    file.create(file.path(input_dir, "region1.png"))
    file.create(file.path(input_dir, "region2.png"))

    local_mocked_bindings(
      rast = function(f) list(file = f),
      global = function(r, ...) data.frame(max = 255),
      get_contours = function(r, max_val, ...) {
        sf::st_sf(
          geometry = sf::st_sfc(sf::st_polygon(list(matrix(
            c(0, 0, 1, 0, 1, 1, 0, 0),
            ncol = 2,
            byrow = TRUE
          ))))
        )
      },
      progressor = function(...) function(...) NULL
    )
    local_mocked_bindings(
      future_map = function(.x, .f, ...) lapply(.x, .f),
      .package = "furrr"
    )

    result <- extract_contours(input_dir, output_dir, verbose = FALSE)

    expect_s3_class(result, "sf")
    expect_true(file.exists(file.path(output_dir, "contours.rda")))
  })

  it("defaults max_val to 1 when all rasters have max 0", {
    input_dir <- withr::local_tempdir("masks_")
    output_dir <- withr::local_tempdir("output_")
    file.create(file.path(input_dir, "region1.png"))

    captured_max_val <- NULL
    local_mocked_bindings(
      rast = function(f) list(file = f),
      global = function(r, ...) data.frame(max = 0),
      get_contours = function(r, max_val, ...) {
        captured_max_val <<- max_val
        sf::st_sf(
          geometry = sf::st_sfc(sf::st_polygon(list(matrix(
            c(0, 0, 1, 0, 1, 1, 0, 0),
            ncol = 2,
            byrow = TRUE
          ))))
        )
      },
      progressor = function(...) function(...) NULL
    )
    local_mocked_bindings(
      future_map = function(.x, .f, ...) lapply(.x, .f),
      .package = "furrr"
    )

    result <- extract_contours(input_dir, output_dir, verbose = FALSE)
    expect_s3_class(result, "sf")
    expect_equal(captured_max_val, 1)
  })

  it("logs progress when verbose is TRUE", {
    input_dir <- withr::local_tempdir("masks_")
    output_dir <- withr::local_tempdir("output_")
    file.create(file.path(input_dir, "region1.png"))

    local_mocked_bindings(
      rast = function(f) list(file = f),
      global = function(r, ...) data.frame(max = 255),
      get_contours = function(...) {
        sf::st_sf(
          geometry = sf::st_sfc(sf::st_polygon(list(matrix(
            c(0, 0, 1, 0, 1, 1, 0, 0),
            ncol = 2,
            byrow = TRUE
          ))))
        )
      },
      progressor = function(...) function(...) NULL
    )
    local_mocked_bindings(
      future_map = function(.x, .f, ...) lapply(.x, .f),
      .package = "furrr"
    )

    expect_message(
      extract_contours(input_dir, output_dir, verbose = TRUE),
      "contour"
    )
  })
})


describe("filter_valid_geometries", {
  it("removes empty geometries", {
    sf_obj <- sf::st_sf(
      id = c("a", "b"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon()
      )
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 1)
    expect_equal(result$id, "a")
  })

  it("returns empty sf for all-invalid input", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(sf::st_polygon())
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 0)
  })

  it("handles already empty sf object", {
    sf_obj <- sf::st_sf(
      id = character(0),
      geometry = sf::st_sfc()
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 0)
  })

  it("preserves valid geometries", {
    sf_obj <- sf::st_sf(
      id = c("a", "b"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 0, 3, 0, 3, 1, 2, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 2)
    expect_equal(result$id, c("a", "b"))
  })

  it("removes geometries with non-finite coordinates", {
    sf_obj <- sf::st_sf(
      id = c("good", "bad"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 0, 3, 0, 3, 1, 2, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    call_count <- 0L
    orig_st_coordinates <- sf::st_coordinates
    local_mocked_bindings(
      st_coordinates = function(...) {
        call_count <<- call_count + 1L
        if (call_count == 2L) {
          res <- orig_st_coordinates(...)
          res[1, 1] <- Inf
          return(res)
        }
        orig_st_coordinates(...)
      }
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 1)
    expect_equal(result$id, "good")
  })

  it("removes geometries where st_coordinates errors", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    local_mocked_bindings(
      st_coordinates = function(...) stop("coords error")
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 0)
  })

  it("removes geometries where st_bbox errors", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    local_mocked_bindings(
      st_bbox = function(...) stop("bbox error")
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 0)
  })

  it("removes geometries where st_bbox has non-finite values", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    local_mocked_bindings(
      st_bbox = function(...) c(xmin = 0, ymin = 0, xmax = Inf, ymax = 1)
    )

    result <- filter_valid_geometries(sf_obj)

    expect_equal(nrow(result), 0)
  })
})


describe("smooth_contours", {
  it("smooths contour geometry", {
    outdir <- withr::local_tempdir("smooth_test_")

    contours <- sf::st_sf(
      region = c("test1", "test2"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = file.path(outdir, "contours.rda"))

    result <- smooth_contours(outdir, smoothness = 5, step = "")

    expect_s3_class(result, "sf")
    expect_true(file.exists(file.path(outdir, "contours_smoothed.rda")))
  })

  it("warns and saves empty when all contours are invalid", {
    outdir <- withr::local_tempdir("smooth_empty_")

    contours <- sf::st_sf(
      filenm = "test",
      geometry = sf::st_sfc(sf::st_polygon())
    )
    save(contours, file = file.path(outdir, "contours.rda"))

    expect_warning(
      result <- smooth_contours(outdir, smoothness = 5, step = ""),
      "No valid contours"
    )
    expect_equal(nrow(result), 0)
    expect_true(file.exists(file.path(outdir, "contours_smoothed.rda")))
  })
})


describe("reduce_vertex", {
  it("simplifies contour geometry", {
    outdir <- withr::local_tempdir("reduce_test_")

    contours <- sf::st_sf(
      region = "test",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(
            0,
            0,
            0.1,
            0.01,
            0.2,
            0,
            1,
            0,
            1,
            1,
            0,
            1,
            0,
            0
          ),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = file.path(outdir, "contours_smoothed.rda"))

    result <- reduce_vertex(outdir, tolerance = 0.5, step = "")

    expect_s3_class(result, "sf")
    expect_true(file.exists(file.path(outdir, "contours_reduced.rda")))
  })

  it("warns and saves empty when all contours are invalid", {
    outdir <- withr::local_tempdir("reduce_empty_")

    contours <- sf::st_sf(
      filenm = "test",
      geometry = sf::st_sfc(sf::st_polygon())
    )
    save(contours, file = file.path(outdir, "contours_smoothed.rda"))

    expect_warning(
      result <- reduce_vertex(outdir, tolerance = 0.5, step = ""),
      "No valid contours"
    )
    expect_equal(nrow(result), 0)
    expect_true(file.exists(file.path(outdir, "contours_reduced.rda")))
  })
})


describe("make_multipolygon", {
  it("combines contours into multipolygons", {
    outdir <- withr::local_tempdir("multipoly_test_")

    contours <- sf::st_sf(
      filenm = c("region1", "region1", "region2"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon(list(matrix(
          c(4, 0, 5, 0, 5, 1, 4, 1, 4, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    contourfile <- file.path(outdir, "contours_reduced.rda")
    save(contours, file = contourfile)

    result <- make_multipolygon(contourfile)

    expect_s3_class(result, "sf")
    expect_equal(nrow(result), 2)
    expect_equal(result$filenm, c("region1", "region2"))
  })
})


describe("smooth_contours verbose output", {
  it("emits progress message when verbose is TRUE", {
    outdir <- withr::local_tempdir("smooth_verbose_")

    contours <- sf::st_sf(
      region = "test",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = file.path(outdir, "contours.rda"))

    expect_message(
      smooth_contours(outdir, smoothness = 5, step = "1/3", verbose = TRUE),
      "Smoothing contours"
    )
  })
})


describe("reduce_vertex verbose output", {
  it("emits progress message when verbose is TRUE", {
    outdir <- withr::local_tempdir("reduce_verbose_")

    contours <- sf::st_sf(
      region = "test",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = file.path(outdir, "contours_smoothed.rda"))

    expect_message(
      reduce_vertex(outdir, tolerance = 0.5, step = "2/3", verbose = TRUE),
      "Reducing vertices"
    )
  })
})
