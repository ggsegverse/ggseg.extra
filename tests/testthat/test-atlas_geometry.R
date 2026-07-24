.cap <- new.env()

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

    slabs <- data.frame(
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

    result <- build_contour_sf(contours_file, slabs)

    expect_s3_class(result, "sf")
    expect_true(all(c("label", "view") %in% names(result)))
    expect_identical(nrow(result), 2L)
  })

  it("assigns slabs from filename prefix", {
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

    slabs <- data.frame(
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

    result <- build_contour_sf(contours_file, slabs)

    expect_identical(sort(unique(result$view)), c("axial_1", "coronal_1"))
  })

  it("strips view prefix from label", {
    contours_file <- withr::local_tempfile(fileext = ".rda")

    contours <- sf::st_sf(
      filenm = "axial_1_Left-Putamen",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = contours_file)

    slabs <- data.frame(
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

    result <- build_contour_sf(contours_file, slabs)

    expect_identical(result$label, "Left-Putamen")
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

    slabs <- data.frame(
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

    result <- build_contour_sf(contours_file, slabs, cortex_slices)

    expect_s3_class(result, "sf")
    expect_true("cortex_1" %in% result$view)
  })

  it("uses filename as label when view is NA", {
    contours_file <- withr::local_tempfile(fileext = ".rda")

    contours <- sf::st_sf(
      filenm = "unmatched_region",
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )
    save(contours, file = contours_file)

    slabs <- data.frame(
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

    result <- build_contour_sf(contours_file, slabs)

    expect_identical(result$label, "unmatched_region")
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
      .package = "terra"
    )
    local_mocked_bindings(
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

    .cap$captured_max_val <- NULL
    local_mocked_bindings(
      rast = function(f) list(file = f),
      global = function(r, ...) data.frame(max = 0),
      .package = "terra"
    )
    local_mocked_bindings(
      get_contours = function(r, max_val, ...) {
        .cap$captured_max_val <- max_val
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
    expect_identical(.cap$captured_max_val, 1)
  })

  it("logs progress when verbose is TRUE", {
    input_dir <- withr::local_tempdir("masks_")
    output_dir <- withr::local_tempdir("output_")
    file.create(file.path(input_dir, "region1.png"))

    local_mocked_bindings(
      rast = function(f) list(file = f),
      global = function(r, ...) data.frame(max = 255),
      .package = "terra"
    )
    local_mocked_bindings(
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

    expect_messages(
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

    expect_identical(nrow(result), 1L)
    expect_identical(result$id, "a")
  })

  it("returns empty sf for all-invalid input", {
    sf_obj <- sf::st_sf(
      id = "a",
      geometry = sf::st_sfc(sf::st_polygon())
    )

    result <- filter_valid_geometries(sf_obj)

    expect_identical(nrow(result), 0L)
  })

  it("handles already empty sf object", {
    sf_obj <- sf::st_sf(
      id = character(0),
      geometry = sf::st_sfc()
    )

    result <- filter_valid_geometries(sf_obj)

    expect_identical(nrow(result), 0L)
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

    expect_identical(nrow(result), 2L)
    expect_identical(result$id, c("a", "b"))
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

    .cap$call_count <- 0L
    orig_st_coordinates <- sf::st_coordinates
    local_mocked_bindings(
      st_coordinates = function(...) {
        .cap$call_count <- .cap$call_count + 1L
        if (.cap$call_count == 2L) {
          res <- orig_st_coordinates(...)
          res[1, 1] <- Inf
          return(res)
        }
        orig_st_coordinates(...)
      }
    )

    result <- filter_valid_geometries(sf_obj)

    expect_identical(nrow(result), 1L)
    expect_identical(result$id, "good")
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

    expect_identical(nrow(result), 0L)
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

    expect_identical(nrow(result), 0L)
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

    expect_identical(nrow(result), 0L)
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
      {
        result <- smooth_contours(outdir, smoothness = 5, step = "")
      },
      "No valid contours"
    )
    expect_identical(nrow(result), 0L)
    expect_true(file.exists(file.path(outdir, "contours_smoothed.rda")))
  })
})


describe("reduce_vertex", {
  it("passes contour geometry through unchanged", {
    outdir <- withr::local_tempdir("reduce_test_")

    coords <- matrix(
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
    )
    contours <- sf::st_sf(
      region = "test",
      geometry = sf::st_sfc(sf::st_polygon(list(coords)))
    )
    save(contours, file = file.path(outdir, "contours_smoothed.rda"))

    result <- reduce_vertex(outdir, tolerance = 0.5, step = "")

    expect_s3_class(result, "sf")
    expect_true(file.exists(file.path(outdir, "contours_reduced.rda")))
    expect_identical(
      nrow(sf::st_coordinates(result)),
      nrow(sf::st_coordinates(contours))
    )
  })

  it("warns and saves empty when all contours are invalid", {
    outdir <- withr::local_tempdir("reduce_empty_")

    contours <- sf::st_sf(
      filenm = "test",
      geometry = sf::st_sfc(sf::st_polygon())
    )
    save(contours, file = file.path(outdir, "contours_smoothed.rda"))

    expect_warning(
      {
        result <- reduce_vertex(outdir, tolerance = 0.5, step = "")
      },
      "No valid contours"
    )
    expect_identical(nrow(result), 0L)
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
    expect_identical(nrow(result), 2L)
    expect_identical(result$filenm, c("region1", "region2"))
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

    expect_no_message(
      smooth_contours(outdir, smoothness = 5, step = "1/3", verbose = TRUE)
    )
  })
})


describe("reduce_vertex verbose output", {
  it("is silent now that simplification has moved post-creation", {
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

    expect_no_message(
      reduce_vertex(outdir, tolerance = 0.5, step = "2/3", verbose = TRUE)
    )
  })
})


describe("simplify_sf_topology", {
  it("reduces vertices while preserving shared boundaries", {
    angles_a <- seq(0, 2 * pi, length.out = 21)[-21]
    coords_a <- cbind(cos(angles_a), sin(angles_a))
    coords_a <- rbind(coords_a, coords_a[1, ])
    poly_a <- sf::st_polygon(list(coords_a))

    coords_b <- coords_a
    coords_b[, 1] <- coords_b[, 1] + 2
    poly_b <- sf::st_polygon(list(coords_b))

    sf_data <- sf::st_sf(
      label = c("a", "b"),
      geometry = sf::st_sfc(poly_a, poly_b)
    )

    result <- simplify_sf_topology(sf_data, keep = 0.3)

    expect_s3_class(result, "sf")
    expect_identical(nrow(result), 2L)
    expect_true(all(sf::st_is_valid(result)))

    n_before <- nrow(sf::st_coordinates(sf_data))
    n_after <- nrow(sf::st_coordinates(result))
    expect_lt(n_after, n_before)
  })

  it("simplifies per-view group when view column exists", {
    poly_a <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    poly_b <- sf::st_polygon(list(matrix(
      c(10, 10, 11, 10, 11, 11, 10, 11, 10, 10),
      ncol = 2,
      byrow = TRUE
    )))
    sf_data <- sf::st_sf(
      label = c("a", "b"),
      view = c("lateral", "medial"),
      geometry = sf::st_sfc(poly_a, poly_b)
    )

    result <- simplify_sf_topology(sf_data, keep = 0.5)

    expect_s3_class(result, "sf")
    expect_identical(nrow(result), 2L)
    expect_true(all(c("lateral", "medial") %in% result$view))
  })

  it("handles single-view data without grouping", {
    poly <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    sf_data <- sf::st_sf(
      label = "a",
      view = "flatmap",
      geometry = sf::st_sfc(poly)
    )

    result <- simplify_sf_topology(sf_data, keep = 0.5)

    expect_s3_class(result, "sf")
    expect_identical(nrow(result), 1L)
  })

  it("groups by filenm prefix when no view column exists", {
    poly_a <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    poly_b <- sf::st_polygon(list(matrix(
      c(10, 10, 11, 10, 11, 11, 10, 11, 10, 10),
      ncol = 2,
      byrow = TRUE
    )))
    poly_c <- sf::st_polygon(list(matrix(
      c(20, 20, 21, 20, 21, 21, 20, 21, 20, 20),
      ncol = 2,
      byrow = TRUE
    )))
    sf_data <- sf::st_sf(
      label = c("a", "b", "c"),
      filenm = c("lateral_1.png", "lateral_2.png", "medial_1.png"),
      geometry = sf::st_sfc(poly_a, poly_b, poly_c)
    )

    result <- simplify_sf_topology(sf_data, keep = 0.5)

    expect_s3_class(result, "sf")
    expect_identical(nrow(result), 3L)
    expect_false(".view_group" %in% names(result))
  })
})


describe("smooth_sf_light", {
  it("returns the input unchanged when smoothness is zero or negative", {
    poly <- sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    sf_data <- sf::st_sf(label = "a", geometry = sf::st_sfc(poly))

    expect_identical(smooth_sf_light(sf_data, smoothness = 0), sf_data)
    expect_identical(smooth_sf_light(sf_data, smoothness = -1), sf_data)
  })

  it("rounds polygon edges when smoothness is positive", {
    poly <- sf::st_polygon(list(matrix(
      c(0, 0, 4, 0, 4, 4, 0, 4, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    sf_data <- sf::st_sf(label = "a", geometry = sf::st_sfc(poly))

    result <- smooth_sf_light(sf_data, smoothness = 0.5)

    expect_s3_class(result, "sf")
    expect_true(all(sf::st_is_valid(result)))
  })
})


describe("atlas_smooth", {
  it("warns when atlas has no 2D geometry", {
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

    expect_warning(
      {
        result <- atlas_smooth(atlas)
      },
      "no 2D geometry"
    )
    expect_null(ggseg.formats::atlas_geom(result))
  })

  it("simplifies atlas sf data", {
    poly <- sf::st_polygon(list(matrix(
      c(0, 0, 0.5, 0.01, 1, 0, 1, 1, 0.5, 0.99, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    sf_obj <- sf::st_sf(
      label = "a",
      view = "v1",
      geometry = sf::st_sfc(poly)
    )
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "subcortical",
      palette = c(a = "#000000"),
      core = data.frame(label = "a", region = "a", stringsAsFactors = FALSE),
      data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
    )

    result <- atlas_smooth(atlas, keep = 0.5)

    expect_s3_class(ggseg.formats::atlas_geom(result), "sf")
    expect_true(all(sf::st_is_valid(ggseg.formats::atlas_geom(result))))
  })

  it("smooths a polygon-backed atlas and preserves the representation", {
    poly <- sf::st_polygon(list(matrix(
      c(0, 0, 0.5, 0.01, 1, 0, 1, 1, 0.5, 0.99, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    sf_obj <- sf::st_sf(label = "a", view = "v1", geometry = sf::st_sfc(poly))
    atlas <- ggseg.formats::as_polygon_atlas(
      ggseg.formats::ggseg_atlas(
        atlas = "t",
        type = "subcortical",
        palette = c(a = "#000000"),
        core = data.frame(label = "a", region = "a", stringsAsFactors = FALSE),
        data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
      )
    )
    expect_true(ggseg.formats::is_atlas_polygon(atlas))

    result <- atlas_smooth(atlas, keep = 0.5)

    # representation round-trips back to polygons, not sf
    expect_true(ggseg.formats::is_atlas_polygon(result))
    expect_true(all(sf::st_is_valid(ggseg.formats::atlas_sf(result))))
    expect_identical(ggseg.formats::atlas_geom(result)$label, "a")
  })

  it("smooths a legacy sf-slot atlas into a compliant sf atlas", {
    poly <- sf::st_polygon(list(matrix(
      c(0, 0, 0.5, 0.01, 1, 0, 1, 1, 0.5, 0.99, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    sf_obj <- sf::st_sf(label = "a", view = "v1", geometry = sf::st_sfc(poly))
    atlas <- ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "subcortical",
      palette = c(a = "#000000"),
      core = data.frame(label = "a", region = "a", stringsAsFactors = FALSE),
      data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
    )
    # simulate a released atlas whose geometry lives in the legacy $sf slot
    atlas$data$sf <- atlas$data$geom
    atlas$data$geom <- NULL

    result <- atlas_smooth(atlas, keep = 0.5)

    expect_true(ggseg.formats::is_ggseg_atlas(result))
    expect_true(ggseg.formats::is_atlas_sf(result))
    expect_identical(ggseg.formats::atlas_geom(result)$label, "a")
    expect_true(all(sf::st_is_valid(ggseg.formats::atlas_sf(result))))
  })

  two_region_atlas <- function(label_order = c("region_a", "region_b")) {
    jagged <- sf::st_polygon(list(matrix(
      c(0, 0, 0.5, 0.01, 1, 0, 1, 1, 0.5, 0.99, 0, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    )))
    square <- sf::st_polygon(list(matrix(
      c(10, 10, 11, 10, 11, 11, 10, 11, 10, 10),
      ncol = 2,
      byrow = TRUE
    )))
    polys <- list(region_a = jagged, region_b = square)[label_order]

    sf_obj <- sf::st_sf(
      label = label_order,
      view = "v1",
      geometry = sf::st_sfc(polys[[1]], polys[[2]])
    )
    ggseg.formats::ggseg_atlas(
      atlas = "t",
      type = "subcortical",
      palette = c(region_a = "#000000", region_b = "#111111"),
      core = data.frame(
        label = label_order,
        region = label_order,
        stringsAsFactors = FALSE
      ),
      data = ggseg.formats::ggseg_data_subcortical(geom = sf_obj)
    )
  }

  it("errors when both labels and exclude are specified", {
    atlas <- two_region_atlas()
    expect_error(
      atlas_smooth(atlas, labels = "region_a", exclude = "region_b"),
      "only one of"
    )
  })

  it("closes jagged edges with smoothness, independent of simplification", {
    atlas <- two_region_atlas()
    before <- ggseg.formats::atlas_geom(atlas)
    n_before <- nrow(sf::st_coordinates(
      before$geometry[before$label == "region_a"]
    ))

    result <- atlas_smooth(atlas, keep = NULL, smoothness = 3)
    geom <- ggseg.formats::atlas_geom(result)

    expect_true(all(sf::st_is_valid(geom)))
    expect_false(
      nrow(sf::st_coordinates(
        geom$geometry[geom$label == "region_a"]
      )) ==
        n_before
    )
  })

  it("only smooths labels matched by `labels`, leaving the rest untouched", {
    atlas <- two_region_atlas()
    before <- ggseg.formats::atlas_geom(atlas)

    result <- atlas_smooth(atlas, keep = 0.3, labels = "region_a")
    geom <- ggseg.formats::atlas_geom(result)

    n_before_a <- nrow(sf::st_coordinates(
      before$geometry[before$label == "region_a"]
    ))
    n_after_a <- nrow(sf::st_coordinates(
      geom$geometry[geom$label == "region_a"]
    ))
    expect_lt(n_after_a, n_before_a)

    expect_true(isTRUE(sf::st_equals(
      geom$geometry[geom$label == "region_b"][[1]],
      before$geometry[before$label == "region_b"][[1]],
      sparse = FALSE
    )[1, 1]))
  })

  it("only smooths labels not matched by `exclude`", {
    atlas <- two_region_atlas()
    before <- ggseg.formats::atlas_geom(atlas)

    result <- atlas_smooth(atlas, keep = 0.3, exclude = "region_b")
    geom <- ggseg.formats::atlas_geom(result)

    n_before_a <- nrow(sf::st_coordinates(
      before$geometry[before$label == "region_a"]
    ))
    n_after_a <- nrow(sf::st_coordinates(
      geom$geometry[geom$label == "region_a"]
    ))
    expect_lt(n_after_a, n_before_a)

    expect_true(isTRUE(sf::st_equals(
      geom$geometry[geom$label == "region_b"][[1]],
      before$geometry[before$label == "region_b"][[1]],
      sparse = FALSE
    )[1, 1]))
  })

  it("preserves the caller's row order when subsetting by label", {
    atlas <- two_region_atlas(label_order = c("region_b", "region_a"))

    result <- atlas_smooth(atlas, keep = 0.3, exclude = "region_a")
    geom <- ggseg.formats::atlas_geom(result)

    expect_identical(geom$label, c("region_b", "region_a"))
  })

  it("returns the atlas unchanged when keep is NULL and smoothness is 0", {
    atlas <- two_region_atlas()
    result <- atlas_smooth(atlas, keep = NULL, smoothness = 0)
    expect_identical(result, atlas)
  })
})


describe("atlas_simplify (deprecated)", {
  it("warns about deprecation and delegates to atlas_smooth", {
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

    lifecycle::expect_deprecated(
      expect_warning(atlas_simplify(atlas), "no 2D geometry")
    )
  })
})
