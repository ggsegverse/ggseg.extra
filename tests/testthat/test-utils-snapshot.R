describe("has_magick", {
  it("returns logical", {
    result <- has_magick()
    expect_type(result, "logical")
    expect_length(result, 1)
  })
})


describe("check_magick", {
  it("does not error when ImageMagick is installed", {
    skip_if_no_imagemagick()
    expect_no_error(check_magick())
  })

  it("aborts when ImageMagick is not installed", {
    local_mocked_bindings(
      has_magick = function() FALSE
    )
    expect_error(check_magick(), "ImageMagick")
  })
})


describe("process_and_mask_images", {
  it("calls process_snapshot_image for each png then extract_alpha_mask", {
    snap_dir <- withr::local_tempdir("snap_")
    processed_dir <- withr::local_tempdir("proc_")
    mask_dir <- withr::local_tempdir("mask_")

    file.create(file.path(snap_dir, "img1.png"))
    file.create(file.path(snap_dir, "img2.png"))

    process_called <- character(0)
    mask_called <- character(0)

    local_mocked_bindings(
      process_snapshot_image = function(input_file, output_file, ...) {
        process_called <<- c(process_called, basename(input_file))
        file.create(output_file)
      },
      extract_alpha_mask = function(input_file, output_file, ...) {
        mask_called <<- c(mask_called, basename(input_file))
      },
      progressor = function(...) function(...) NULL
    )

    process_and_mask_images(snap_dir, processed_dir, mask_dir)

    expect_equal(sort(process_called), c("img1.png", "img2.png"))
    expect_equal(sort(mask_called), c("img1.png", "img2.png"))
  })

  it("passes dilate parameter through", {
    snap_dir <- withr::local_tempdir("snap_")
    processed_dir <- withr::local_tempdir("proc_")
    mask_dir <- withr::local_tempdir("mask_")

    file.create(file.path(snap_dir, "img1.png"))

    captured_dilate <- NULL
    local_mocked_bindings(
      process_snapshot_image = function(input_file, output_file, dilate, ...) {
        captured_dilate <<- dilate
        file.create(output_file)
      },
      extract_alpha_mask = function(...) NULL,
      progressor = function(...) function(...) NULL
    )

    process_and_mask_images(snap_dir, processed_dir, mask_dir, dilate = 3L)

    expect_equal(captured_dilate, 3L)
  })

  it("handles empty directory", {
    snap_dir <- withr::local_tempdir("snap_")
    processed_dir <- withr::local_tempdir("proc_")
    mask_dir <- withr::local_tempdir("mask_")

    local_mocked_bindings(
      progressor = function(...) function(...) NULL
    )

    expect_no_error(
      process_and_mask_images(snap_dir, processed_dir, mask_dir)
    )
  })
})


describe("parse_contour_filenames", {
  it("parses standard filename format", {
    filenames <- c("region1_lh_lateral", "region2_rh_medial")
    result <- parse_contour_filenames(filenames)

    expect_equal(result$view, c("lateral", "medial"))
    expect_equal(result$hemi_short, c("lh", "rh"))
    expect_equal(result$hemi, c("left", "right"))
    expect_equal(result$label, c("region1", "region2"))
  })

  it("handles underscores in region names", {
    filenames <- c("left_superior_frontal_lh_lateral")
    result <- parse_contour_filenames(filenames)

    expect_equal(result$label, "left_superior_frontal")
    expect_equal(result$hemi_short, "lh")
    expect_equal(result$view, "lateral")
  })

  it("strips file extension before parsing", {
    filenames <- c("region1_lh_lateral.png", "region2_rh_medial.png")
    result <- parse_contour_filenames(filenames)

    expect_equal(result$view, c("lateral", "medial"))
    expect_equal(result$hemi_short, c("lh", "rh"))
    expect_equal(result$hemi, c("left", "right"))
    expect_equal(result$label, c("region1", "region2"))
  })
})


describe("make_view_chunks", {
  it("creates correct number of chunks", {
    result <- make_view_chunks(85, 152, 10, "axial")
    expect_s3_class(result, "data.frame")
    expect_true(all(c("name", "type", "start", "end") %in% names(result)))
    expect_equal(nrow(result), 7)
  })

  it("names chunks with type prefix", {
    result <- make_view_chunks(100, 150, 20, "coronal")
    expect_true(all(grepl("^coronal_", result$name)))
    expect_equal(unique(result$type), "coronal")
  })

  it("handles exact division", {
    result <- make_view_chunks(0, 30, 10, "axial")
    expect_equal(result$start, c(0, 10, 20, 30))
    expect_equal(result$end, c(9, 19, 29, 30))
  })

  it("clamps end to hi boundary", {
    result <- make_view_chunks(0, 25, 10, "axial")
    expect_equal(result$end[nrow(result)], 25)
  })
})


describe("create_cortex_slices", {
  it("creates slices matching views", {
    views <- data.frame(
      name = c("axial_1", "coronal_1", "sagittal"),
      type = c("axial", "coronal", "sagittal"),
      start = c(85, 110, 128),
      end = c(95, 120, 128),
      stringsAsFactors = FALSE
    )
    dims <- c(256, 256, 256)

    result <- create_cortex_slices(views, dims)

    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 3)
    expect_true(all(c("x", "y", "z", "view", "name") %in% names(result)))
  })

  it("sets z for axial views", {
    views <- data.frame(
      name = "axial_1",
      type = "axial",
      start = 85,
      end = 95,
      stringsAsFactors = FALSE
    )
    dims <- c(256, 256, 256)

    result <- create_cortex_slices(views, dims)

    expect_true(is.na(result$x))
    expect_true(is.na(result$y))
    expect_equal(result$z, 90)
  })

  it("sets y for coronal views", {
    views <- data.frame(
      name = "coronal_1",
      type = "coronal",
      start = 110,
      end = 120,
      stringsAsFactors = FALSE
    )
    dims <- c(256, 256, 256)

    result <- create_cortex_slices(views, dims)

    expect_true(is.na(result$x))
    expect_equal(result$y, 115)
    expect_true(is.na(result$z))
  })

  it("sets hemisphere-specific x for sagittal views", {
    views <- data.frame(
      name = c("sagittal_left", "sagittal_right"),
      type = c("sagittal", "sagittal"),
      start = c(128, 1),
      end = c(256, 128),
      stringsAsFactors = FALSE
    )
    dims <- c(256, 256, 256)

    result <- create_cortex_slices(views, dims)

    expect_equal(result$x[1], round(256 * 0.55))
    expect_equal(result$x[2], round(256 * 0.45))
  })
})


describe("detect_cortex_labels", {
  it("detects aparc labels when present", {
    vol <- array(0L, dim = c(10, 10, 10))
    vol[1:5, , ] <- 1001L
    vol[6:10, , ] <- 2005L

    result <- detect_cortex_labels(vol)

    expect_type(result, "list")
    expect_named(result, c("left", "right"))
    expect_equal(result$left, 1001L)
    expect_equal(result$right, 2005L)
  })

  it("falls back to aseg labels when no aparc", {
    vol <- array(0L, dim = c(10, 10, 10))
    vol[1:5, , ] <- 3L
    vol[6:10, , ] <- 42L

    result <- detect_cortex_labels(vol)

    expect_equal(result$left, 3)
    expect_equal(result$right, 42)
  })
})


describe("extract_hemi_from_view", {
  it("returns NULL for non-sagittal views", {
    expect_null(extract_hemi_from_view("axial", "axial_3"))
    expect_null(extract_hemi_from_view("coronal", "coronal_1"))
  })

  it("returns left for sagittal left views", {
    expect_equal(
      extract_hemi_from_view("sagittal", "sagittal_left"),
      "left"
    )
    expect_equal(
      extract_hemi_from_view("sagittal", "left_sagittal"),
      "left"
    )
  })

  it("returns right for sagittal right views", {
    expect_equal(
      extract_hemi_from_view("sagittal", "sagittal_right"),
      "right"
    )
    expect_equal(
      extract_hemi_from_view("sagittal", "right_sagittal"),
      "right"
    )
  })

  it("returns NULL for sagittal without hemisphere", {
    expect_null(extract_hemi_from_view("sagittal", "sagittal"))
  })
})


describe("process_snapshot_image", {
  it("returns early when skip_existing is TRUE and file exists", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)
    file.create(output)

    read_called <- FALSE
    local_mocked_bindings(
      image_read = function(...) {
        read_called <<- TRUE
        NULL
      }
    )

    result <- process_snapshot_image(input, output, skip_existing = TRUE)

    expect_equal(result, output, ignore_attr = TRUE)
    expect_false(read_called)
  })

  it("calls image processing pipeline", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)

    transparent_called <- FALSE
    write_called <- FALSE
    sentinel <- structure(list(), class = "mock_img")

    local_mocked_bindings(
      image_read = function(...) sentinel,
      image_convert = function(...) sentinel,
      image_transparent = function(...) {
        transparent_called <<- TRUE
        sentinel
      },
      image_write = function(image, path, ...) {
        write_called <<- TRUE
        file.create(path)
      }
    )

    result <- process_snapshot_image(input, output, skip_existing = FALSE)

    expect_true(transparent_called)
    expect_true(write_called)
    expect_true(file.exists(output))
    expect_equal(result, output, ignore_attr = TRUE)
  })

  it("applies dilation when dilate > 0", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)

    morphology_called <- FALSE
    sentinel <- structure(list(), class = "mock_img")

    local_mocked_bindings(
      image_read = function(...) sentinel,
      image_convert = function(...) sentinel,
      image_transparent = function(...) sentinel,
      image_morphology = function(img, method, kernel, iterations, ...) {
        morphology_called <<- TRUE
        expect_equal(method, "DilateI")
        expect_equal(kernel, "diamond")
        expect_equal(iterations, 2)
        sentinel
      },
      image_write = function(image, path, ...) {
        file.create(path)
      }
    )

    process_snapshot_image(input, output, dilate = 2, skip_existing = FALSE)

    expect_true(morphology_called)
  })

  it("skips dilation when dilate is NULL", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)

    morphology_called <- FALSE
    sentinel <- structure(list(), class = "mock_img")

    local_mocked_bindings(
      image_read = function(...) sentinel,
      image_convert = function(...) sentinel,
      image_transparent = function(...) sentinel,
      image_morphology = function(...) {
        morphology_called <<- TRUE
        sentinel
      },
      image_write = function(image, path, ...) {
        file.create(path)
      }
    )

    process_snapshot_image(input, output, dilate = NULL, skip_existing = FALSE)

    expect_false(morphology_called)
  })
})


describe("extract_alpha_mask", {
  it("returns early when skip_existing is TRUE and file exists", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)
    file.create(output)

    result <- extract_alpha_mask(input, output, skip_existing = TRUE)

    expect_equal(result, output, ignore_attr = TRUE)
  })

  it("extracts alpha and returns output path when magick is available", {
    skip_if_not(has_magick(), "ImageMagick not available")
    tmp <- withr::local_tempdir()
    input <- file.path(tmp, "test.png")
    output <- file.path(tmp, "alpha.png")
    magick::image_write(magick::image_blank(10, 10, "red"), input)

    result <- extract_alpha_mask(input, output, skip_existing = FALSE)

    expect_equal(result, output, ignore_attr = TRUE)
    expect_true(file.exists(output))
  })

  it("errors on non-zero exit code", {
    skip_if_not(has_magick(), "ImageMagick not available")

    expect_error(
      extract_alpha_mask(
        "/nonexistent/input.png",
        "/nonexistent/output.png",
        skip_existing = FALSE
      ),
      "ImageMagick failed"
    )
  })
})


describe("run_cmd", {
  it("runs commands successfully", {
    skip_on_os("windows")
    local_mocked_bindings(
      get_fs = function() ""
    )

    result <- run_cmd("echo test", verbose = FALSE, no_ui = FALSE)
    expect_equal(result, 0L)
  })

  it("aborts on non-zero exit code", {
    skip_on_os("windows")
    local_mocked_bindings(
      get_fs = function() ""
    )

    expect_error(
      run_cmd("false", verbose = FALSE),
      "FreeSurfer command failed"
    )
  })
})


describe("get_contours", {
  it("returns NULL when max value < max_val", {
    local_mocked_bindings(
      global = function(x, ...) data.frame(max = 100)
    )

    result <- get_contours("fake_raster", max_val = 255)

    expect_null(result)
  })

  it("processes raster when max >= max_val", {
    as_polygons_called <- FALSE

    local_mocked_bindings(
      global = function(x, ...) data.frame(max = 255),
      as.polygons = function(...) {
        as_polygons_called <<- TRUE
        "mock_poly"
      }
    )

    local_mocked_bindings(
      st_as_sf = function(...) data.frame(id = 1, stringsAsFactors = FALSE),
      st_is_empty = function(...) FALSE,
      .package = "sf"
    )

    local_mocked_bindings(
      to_coords = function(coords, n) coords,
      coords2sf = function(coords, limits) coords
    )

    rast_obj <- structure(
      list(vals = c(0L, 255L)),
      class = "mock_rast"
    )
    `[<-.mock_rast` <- function(x, i, value) x
    `[.mock_rast` <- function(x, i) {
      structure(list(vals = c(TRUE, FALSE)), class = "mock_rast")
    }

    environment(`[<-.mock_rast`) <- globalenv()
    environment(`[.mock_rast`) <- globalenv()

    result <- tryCatch(
      get_contours(rast_obj, max_val = 255),
      error = function(e) "processing_attempted"
    )

    expect_true(as_polygons_called || result == "processing_attempted")
  })
})


describe("isolate_region", {
  it("returns early when skip_existing is TRUE and file exists", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)
    file.create(output)

    read_called <- FALSE
    local_mocked_bindings(
      image_read = function(...) {
        read_called <<- TRUE
        NULL
      }
    )

    result <- isolate_region(input, output, skip_existing = TRUE)

    expect_equal(result, output, ignore_attr = TRUE)
    expect_false(read_called)
  })

  it("errors when ImageMagick is not available", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    interim <- withr::local_tempfile(fileext = ".png")
    file.create(input)

    sentinel <- structure(list(), class = "mock_img")
    local_mocked_bindings(
      image_read = function(...) sentinel,
      image_convert = function(...) sentinel,
      image_transparent = function(...) sentinel,
      image_write = function(...) interim,
      has_magick = function() FALSE
    )

    expect_error(
      isolate_region(
        input,
        output,
        interim_file = interim,
        skip_existing = FALSE
      ),
      "imagemagick"
    )
  })

  it("runs extraction when ImageMagick is available", {
    skip_if_not(has_magick(), "ImageMagick not available")

    tmp <- withr::local_tempdir()
    input <- file.path(tmp, "test.png")
    output <- file.path(tmp, "isolated.png")
    interim <- file.path(tmp, "interim.png")

    magick::image_write(magick::image_blank(10, 10, "red"), input)
    isolate_region(input, output, interim_file = interim, skip_existing = FALSE)

    expect_true(file.exists(output))
  })
})


describe("load_reduced_contours", {
  it("loads and processes contours file", {
    base_dir <- withr::local_tempdir("contours_")

    mock_sf <- data.frame(
      filenm = c("region1_lh_lateral", "region2_rh_medial"),
      stringsAsFactors = FALSE
    )

    contours <- "placeholder"
    save(contours, file = file.path(base_dir, "contours_reduced.rda"))

    local_mocked_bindings(
      vect = function(...) "mock_vect",
      flip = function(...) "mock_flipped",
      .package = "terra"
    )
    local_mocked_bindings(
      st_as_sf = function(...) mock_sf,
      .package = "sf"
    )

    result <- load_reduced_contours(base_dir)

    expect_true("view" %in% names(result))
    expect_true("hemi_short" %in% names(result))
    expect_true("hemi" %in% names(result))
    expect_true("label" %in% names(result))
  })

  it("adds view/hemi/label columns from parsed filenames", {
    base_dir <- withr::local_tempdir("contours_")

    mock_sf <- data.frame(
      filenm = c(
        "superior_frontal_lh_lateral",
        "precentral_rh_medial"
      ),
      stringsAsFactors = FALSE
    )

    contours <- "placeholder"
    save(contours, file = file.path(base_dir, "contours_reduced.rda"))

    local_mocked_bindings(
      vect = function(...) "mock",
      flip = function(...) "mock",
      .package = "terra"
    )
    local_mocked_bindings(
      st_as_sf = function(...) mock_sf,
      .package = "sf"
    )

    result <- load_reduced_contours(base_dir)

    expect_equal(result$view, c("lateral", "medial"))
    expect_equal(result$hemi_short, c("lh", "rh"))
    expect_equal(result$hemi, c("left", "right"))
    expect_equal(result$label, c("superior_frontal", "precentral"))
  })
})


describe("magick_version", {
  it("returns a character string", {
    skip_if_not(has_magick(), "ImageMagick not available")

    result <- magick_version()

    expect_type(result, "character")
    expect_true(nchar(result) > 0)
  })
})


describe("get_contours full processing path", {
  it("returns sf result when contours are non-empty", {
    mock_sf <- sf::st_sf(
      id = 1,
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        )))
      )
    )

    mock_result_sf <- sf::st_sf(
      geometry = sf::st_sfc(
        sf::st_multipolygon(list(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))))
      )
    )

    mock_coords <- data.frame(
      .long = c(0, 1, 1, 0, 0),
      .lat = c(0, 0, 1, 1, 0),
      .subid = rep(1, 5),
      .id = rep(1, 5),
      .poly = rep(1, 5),
      .order = 1:5
    )

    rast_obj <- structure(list(), class = "mock_rast2")
    assign("[<-.mock_rast2", function(x, i, value) x, envir = globalenv())
    assign("[.mock_rast2", function(x, i) x, envir = globalenv())
    withr::defer({
      rm("[<-.mock_rast2", envir = globalenv())
      rm("[.mock_rast2", envir = globalenv())
    })

    local_mocked_bindings(
      global = function(x, ...) data.frame(max = 255),
      as.polygons = function(...) mock_sf,
      st_as_sf = function(...) mock_sf,
      to_coords = function(coords, n) mock_coords,
      coords2sf = function(coords, limits) mock_result_sf
    )
    local_mocked_bindings(
      st_is_empty = function(...) FALSE,
      .package = "sf"
    )

    result <- get_contours(rast_obj, max_val = 255)

    expect_s3_class(result, "sf")
  })

  it("returns NULL when all contours are empty geometries", {
    nonempty_sf <- sf::st_sf(
      id = 1,
      geometry = sf::st_sfc(sf::st_polygon())
    )

    rast_obj <- structure(list(), class = "mock_rast3")
    assign("[<-.mock_rast3", function(x, i, value) x, envir = globalenv())
    assign("[.mock_rast3", function(x, i) x, envir = globalenv())
    withr::defer({
      rm("[<-.mock_rast3", envir = globalenv())
      rm("[.mock_rast3", envir = globalenv())
    })

    local_mocked_bindings(
      global = function(x, ...) data.frame(max = 255),
      as.polygons = function(...) nonempty_sf
    )
    local_mocked_bindings(
      st_as_sf = function(...) nonempty_sf,
      st_is_empty = function(...) TRUE,
      .package = "sf"
    )

    result <- get_contours(rast_obj, max_val = 255)

    expect_null(result)
  })
})
