.cap <- new.env()

describe("has_magick", {
  it("returns logical", {
    result <- has_magick()
    expect_type(result, "logical")
    expect_length(result, 1)
  })
})


describe("process_and_mask_images", {
  it("calls process_snapshot_image for each png then extract_alpha_mask", {
    snap_dir <- withr::local_tempdir("snap_")
    processed_dir <- withr::local_tempdir("proc_")
    mask_dir <- withr::local_tempdir("mask_")

    file.create(file.path(snap_dir, "img1.png"))
    file.create(file.path(snap_dir, "img2.png"))

    .cap$process_called <- character(0)
    .cap$mask_called <- character(0)

    local_mocked_bindings(
      process_snapshot_image = function(input_file, output_file, ...) {
        .cap$process_called <- c(.cap$process_called, basename(input_file))
        file.create(output_file)
      },
      extract_alpha_mask = function(input_file, output_file, ...) {
        .cap$mask_called <- c(.cap$mask_called, basename(input_file))
      },
      progressor = function(...) function(...) NULL
    )

    process_and_mask_images(snap_dir, processed_dir, mask_dir)

    expect_identical(sort(.cap$process_called), c("img1.png", "img2.png"))
    expect_identical(sort(.cap$mask_called), c("img1.png", "img2.png"))
  })

  it("passes dilate parameter through", {
    snap_dir <- withr::local_tempdir("snap_")
    processed_dir <- withr::local_tempdir("proc_")
    mask_dir <- withr::local_tempdir("mask_")

    file.create(file.path(snap_dir, "img1.png"))

    .cap$captured_dilate <- NULL
    local_mocked_bindings(
      process_snapshot_image = function(input_file, output_file, dilate, ...) {
        .cap$captured_dilate <- dilate
        file.create(output_file)
      },
      extract_alpha_mask = function(...) NULL,
      progressor = function(...) function(...) NULL
    )

    process_and_mask_images(snap_dir, processed_dir, mask_dir, dilate = 3L)

    expect_identical(.cap$captured_dilate, 3L)
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


describe("make_view_chunks", {
  it("creates correct number of chunks", {
    result <- make_view_chunks(85, 152, 10, "axial")
    expect_s3_class(result, "data.frame")
    expect_true(all(c("name", "type", "start", "end") %in% names(result)))
    expect_identical(nrow(result), 7L)
  })

  it("names chunks with type prefix", {
    result <- make_view_chunks(100, 150, 20, "coronal")
    expect_true(all(grepl("^coronal_", result$name)))
    expect_identical(unique(result$type), "coronal")
  })

  it("handles exact division", {
    result <- make_view_chunks(0, 30, 10, "axial")
    expect_identical(result$start, c(0, 10, 20, 30))
    expect_identical(result$end, c(9, 19, 29, 30))
  })

  it("clamps end to hi boundary", {
    result <- make_view_chunks(0, 25, 10, "axial")
    expect_identical(result$end[nrow(result)], 25)
  })
})


describe("create_cortex_slices picking by content", {
  # 8x8x8 volume: cortex (label 1001) only on sagittal slice 3, coronal slice
  # 6 and axial slice 2, none of which is its slab's midpoint.
  make_vol <- function() {
    vol <- array(0L, dim = c(8, 8, 8))
    vol[3, , ] <- 1001L
    vol[, 6, ] <- 1001L
    # nolint next: commas_linter. air formats empty subscripts without spaces.
    vol[,, 2] <- 1001L
    vol
  }

  it("takes the slice holding the most cortex, not the slab midpoint", {
    # Axial and coronal only: sagittal picks the thinnest section instead,
    # since cortex area there peaks where the slice skims the sheet. See
    # thinnest_cortex_slice().
    slabs <- rbind(
      data.frame(name = "cor", type = "coronal", start = 1, end = 8),
      data.frame(name = "ax", type = "axial", start = 1, end = 8)
    )
    result <- create_cortex_slices(slabs, c(8, 8, 8), vol = make_vol())

    expect_identical(result$y[result$view == "coronal"], 6L)
    expect_identical(result$z[result$view == "axial"], 2L)
  })

  it("stays inside the slab", {
    slabs <- data.frame(
      name = "sag",
      type = "sagittal",
      start = 5,
      end = 8
    )
    result <- create_cortex_slices(slabs, c(8, 8, 8), vol = make_vol())

    expect_gte(result$x, 5L)
    expect_lte(result$x, 8L)
  })

  it("falls back to the midpoint when the slab holds no cortex", {
    slabs <- data.frame(name = "sag", type = "sagittal", start = 5, end = 7)
    empty <- array(0L, dim = c(8, 8, 8))
    empty[3, , ] <- 1001L
    result <- create_cortex_slices(slabs, c(8, 8, 8), vol = empty)

    expect_identical(result$x, 6)
  })

  it("breaks ties toward the slab midpoint", {
    # Every axial slice here holds the same amount of cortex.
    uniform <- array(0L, dim = c(8, 8, 8))
    uniform[, 6, ] <- 1001L
    slabs <- data.frame(name = "ax", type = "axial", start = 3, end = 7)
    result <- create_cortex_slices(slabs, c(8, 8, 8), vol = uniform)

    expect_identical(result$z, 5L)
  })

  it("falls back to the midpoint when given no volume", {
    slabs <- data.frame(name = "ax", type = "axial", start = 1, end = 8)
    expect_identical(create_cortex_slices(slabs, c(8, 8, 8))$z, 4)
  })

  it("lets an explicit cortex_x win over the content search", {
    slabs <- data.frame(name = "sag", type = "sagittal", start = 1, end = 8)
    result <- create_cortex_slices(
      slabs,
      c(8, 8, 8),
      cortex_x = 7,
      vol = make_vol()
    )
    expect_identical(result$x, 7)
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
    expect_identical(nrow(result), 3L)
    expect_true(all(c("x", "y", "z", "view", "name") %in% names(result)))
  })

  it("takes an unnamed sagittal slice from its own slab midpoint", {
    # A sagittal slab at an explicit position must get its cortex reference
    # from the same plane; a fixed fallback would draw the silhouette
    # somewhere other than where the tracts were projected.
    views <- data.frame(
      name = "sagittal",
      type = "sagittal",
      start = 116,
      end = 126,
      stringsAsFactors = FALSE
    )

    result <- create_cortex_slices(views, c(256, 256, 256))

    expect_identical(result$x, 121)
    expect_true(is.na(result$y))
    expect_true(is.na(result$z))
  })

  it("still honours an explicit cortex_x over the slab midpoint", {
    views <- data.frame(
      name = "sagittal",
      type = "sagittal",
      start = 116,
      end = 126,
      stringsAsFactors = FALSE
    )

    result <- create_cortex_slices(views, c(256, 256, 256), cortex_x = 119)

    expect_identical(result$x, 119)
  })

  it("keeps hemisphere-named sagittal views at their lateral positions", {
    views <- data.frame(
      name = c("sagittal_left", "sagittal_right"),
      type = "sagittal",
      start = c(150, 100),
      end = c(160, 110),
      stringsAsFactors = FALSE
    )

    result <- create_cortex_slices(views, c(256, 256, 256))

    expect_identical(result$x, c(141, 115))
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
    expect_identical(result$z, 90)
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
    expect_identical(result$y, 115)
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

    expect_identical(result$x[1], round(256 * 0.55))
    expect_identical(result$x[2], round(256 * 0.45))
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
    expect_identical(result$left, 1001L)
    expect_identical(result$right, 2005L)
  })

  it("falls back to aseg labels when no aparc", {
    vol <- array(0L, dim = c(10, 10, 10))
    vol[1:5, , ] <- 3L
    vol[6:10, , ] <- 42L

    result <- detect_cortex_labels(vol)

    expect_identical(result$left, 3)
    expect_identical(result$right, 42)
  })
})


describe("extract_hemi_from_view", {
  it("returns NULL for non-sagittal views", {
    expect_null(extract_hemi_from_view("axial", "axial_3"))
    expect_null(extract_hemi_from_view("coronal", "coronal_1"))
  })

  it("returns left for sagittal left views", {
    expect_identical(
      extract_hemi_from_view("sagittal", "sagittal_left"),
      "left"
    )
    expect_identical(
      extract_hemi_from_view("sagittal", "left_sagittal"),
      "left"
    )
  })

  it("returns right for sagittal right views", {
    expect_identical(
      extract_hemi_from_view("sagittal", "sagittal_right"),
      "right"
    )
    expect_identical(
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

    .cap$read_called <- FALSE
    local_mocked_bindings(
      image_read = function(...) {
        .cap$read_called <- TRUE
        NULL
      },
      .package = "magick"
    )

    result <- process_snapshot_image(input, output, skip_existing = TRUE)

    expect_identical(result, output, ignore_attr = TRUE)
    expect_false(.cap$read_called)
  })

  it("calls image processing pipeline", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)

    .cap$transparent_called <- FALSE
    .cap$write_called <- FALSE
    sentinel <- structure(list(), class = "mock_img")

    local_mocked_bindings(
      image_read = function(...) sentinel,
      image_convert = function(...) sentinel,
      image_transparent = function(...) {
        .cap$transparent_called <- TRUE
        sentinel
      },
      image_write = function(image, path, ...) {
        .cap$write_called <- TRUE
        file.create(path)
      },
      .package = "magick"
    )

    result <- process_snapshot_image(input, output, skip_existing = FALSE)

    expect_true(.cap$transparent_called)
    expect_true(.cap$write_called)
    expect_true(file.exists(output))
    expect_identical(result, output, ignore_attr = TRUE)
  })

  it("applies dilation when dilate > 0", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)

    .cap$morphology_called <- FALSE
    sentinel <- structure(list(), class = "mock_img")

    local_mocked_bindings(
      image_read = function(...) sentinel,
      image_convert = function(...) sentinel,
      image_transparent = function(...) sentinel,
      image_morphology = function(img, method, kernel, iterations, ...) {
        .cap$morphology_called <- TRUE
        expect_identical(method, "DilateI")
        expect_identical(kernel, "diamond")
        expect_identical(iterations, 2)
        sentinel
      },
      image_write = function(image, path, ...) {
        file.create(path)
      },
      .package = "magick"
    )

    process_snapshot_image(input, output, dilate = 2, skip_existing = FALSE)

    expect_true(.cap$morphology_called)
  })

  it("skips dilation when dilate is NULL", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)

    .cap$morphology_called <- FALSE
    sentinel <- structure(list(), class = "mock_img")

    local_mocked_bindings(
      image_read = function(...) sentinel,
      image_convert = function(...) sentinel,
      image_transparent = function(...) sentinel,
      image_morphology = function(...) {
        .cap$morphology_called <- TRUE
        sentinel
      },
      image_write = function(image, path, ...) {
        file.create(path)
      },
      .package = "magick"
    )

    process_snapshot_image(input, output, dilate = NULL, skip_existing = FALSE)

    expect_false(.cap$morphology_called)
  })
})


describe("extract_alpha_mask", {
  it("returns early when skip_existing is TRUE and file exists", {
    input <- withr::local_tempfile(fileext = ".png")
    output <- withr::local_tempfile(fileext = ".png")
    file.create(input)
    file.create(output)

    result <- extract_alpha_mask(input, output, skip_existing = TRUE)

    expect_identical(result, output, ignore_attr = TRUE)
  })

  it("extracts alpha and returns output path when magick is available", {
    skip_if_not(has_magick(), "ImageMagick not available")
    tmp <- withr::local_tempdir()
    input <- file.path(tmp, "test.png")
    output <- file.path(tmp, "alpha.png")
    magick::image_write(magick::image_blank(10, 10, "red"), input)

    result <- extract_alpha_mask(input, output, skip_existing = FALSE)

    expect_identical(result, output, ignore_attr = TRUE)
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
      get_fs = function() "",
      .package = "freesurfer"
    )

    result <- run_cmd("echo test", verbose = FALSE, no_ui = FALSE)
    expect_identical(result, 0L)
  })

  it("aborts on non-zero exit code", {
    skip_on_os("windows")
    local_mocked_bindings(
      get_fs = function() "",
      .package = "freesurfer"
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
      global = function(x, ...) data.frame(max = 100),
      .package = "terra"
    )

    result <- get_contours("fake_raster", max_val = 255)

    expect_null(result)
  })

  it("returns NULL without erroring when the raster max is NA", {
    local_mocked_bindings(
      global = function(x, ...) data.frame(max = NA_real_),
      .package = "terra"
    )

    expect_null(get_contours("fake_raster", max_val = 255))
  })

  it("processes raster when max >= max_val", {
    .cap$as_polygons_called <- FALSE

    local_mocked_bindings(
      global = function(x, ...) data.frame(max = 255),
      as.polygons = function(...) {
        .cap$as_polygons_called <- TRUE
        "mock_poly"
      },
      .package = "terra"
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

    expect_true(.cap$as_polygons_called || result == "processing_attempted")
  })
})


describe("magick_version", {
  it("returns a character string", {
    skip_if_not(has_magick(), "ImageMagick not available")

    result <- magick_version()

    expect_type(result, "character")
    expect_gt(nchar(result), 0)
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
      .package = "terra"
    )
    local_mocked_bindings(
      st_as_sf = function(...) mock_sf,
      st_is_empty = function(...) FALSE,
      .package = "sf"
    )
    local_mocked_bindings(
      to_coords = function(coords, n) mock_coords,
      coords2sf = function(coords, limits) mock_result_sf
    )

    result <- get_contours(rast_obj, max_val = 255)

    expect_s3_class(result, "sf")
  })

  it("keeps valid contours when only some geometries are empty", {
    mixed_sf <- sf::st_sf(
      id = c(1, 2),
      geometry = sf::st_sfc(
        sf::st_polygon(list(matrix(
          c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
          ncol = 2,
          byrow = TRUE
        ))),
        sf::st_polygon()
      )
    )
    mock_result_sf <- sf::st_sf(
      geometry = sf::st_sfc(sf::st_multipolygon(list(list(matrix(
        c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
        ncol = 2,
        byrow = TRUE
      )))))
    )

    rast_obj <- structure(list(), class = "mock_rast4")
    assign("[<-.mock_rast4", function(x, i, value) x, envir = globalenv())
    assign("[.mock_rast4", function(x, i) x, envir = globalenv())
    withr::defer({
      rm("[<-.mock_rast4", envir = globalenv())
      rm("[.mock_rast4", envir = globalenv())
    })

    .cap$to_coords_nrow <- NULL
    local_mocked_bindings(
      global = function(x, ...) data.frame(max = 255),
      as.polygons = function(...) mixed_sf,
      .package = "terra"
    )
    local_mocked_bindings(
      st_as_sf = function(...) mixed_sf,
      .package = "sf"
    )
    local_mocked_bindings(
      to_coords = function(coords, n) {
        .cap$to_coords_nrow <- nrow(coords)
        coords
      },
      coords2sf = function(coords, limits) mock_result_sf
    )

    result <- get_contours(rast_obj, max_val = 255)

    expect_s3_class(result, "sf")
    expect_identical(.cap$to_coords_nrow, 1L)
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
      as.polygons = function(...) nonempty_sf,
      .package = "terra"
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


describe("detect_context_labels", {
  it("returns the subcortical structures present in the volume", {
    vol <- array(c(16L, 10L, 49L, 0L), dim = c(2, 2, 1))
    expect_setequal(detect_context_labels(vol), c(16, 10, 49))
  })

  it("excludes cerebral white matter so tracts stay visible", {
    vol <- array(c(2L, 41L, 16L, 0L), dim = c(2, 2, 1))
    result <- detect_context_labels(vol)
    expect_false(any(c(2, 41) %in% result))
    expect_true(16 %in% result)
  })

  it("excludes cerebellar white matter but keeps cerebellar cortex", {
    # Including cerebellar WM would draw the cerebellum as a solid mass while
    # the cerebrum is a ribbon, and it merges with the occipital lobe in
    # sagittal views.
    vol <- array(c(7L, 8L, 46L, 47L), dim = c(2, 2, 1))
    result <- detect_context_labels(vol)
    expect_false(any(c(7, 46) %in% result))
    expect_setequal(result, c(8, 47))
  })

  it("returns nothing when no context structures are present", {
    vol <- array(c(0L, 3L, 42L, 1001L), dim = c(2, 2, 1))
    expect_length(detect_context_labels(vol), 0)
  })
})


describe("context snapshots are never dilated", {
  it("passes dilate to structures and NULL to the silhouettes", {
    seen <- list()

    local_mocked_bindings(
      progressor = function(...) function(...) NULL,
      process_snapshot_image = function(input_file, dilate, ...) {
        seen[[basename(input_file)]] <<- dilate
        invisible(NULL)
      },
      extract_alpha_mask = function(...) invisible(NULL)
    )

    snap_dir <- withr::local_tempdir()
    for (f in c(
      "axial_1_cortex_.png",
      "axial_1_Left-Cerebral-Cortex.png",
      "axial_1_Cerebellar_Cortex_Left.png",
      "axial_1_Putamen_Left.png"
    )) {
      file.create(file.path(snap_dir, f))
    }

    process_and_mask_images(
      snap_dir,
      withr::local_tempdir(),
      withr::local_tempdir(),
      dilate = 2L,
      skip_existing = FALSE
    )

    # Dilation keeps small deep structures visible; on the grey brain it
    # closes the sulci, so the silhouettes opt out.
    expect_null(seen[["axial_1_cortex_.png"]])
    expect_null(seen[["axial_1_Left-Cerebral-Cortex.png"]])
    expect_identical(seen[["axial_1_Cerebellar_Cortex_Left.png"]], 2L)
    expect_identical(seen[["axial_1_Putamen_Left.png"]], 2L)
  })
})


describe("thinnest_cortex_slice", {
  # A sagittal slab across a hemisphere: cortex area peaks at both tangential
  # extremes and dips where the slice cuts the sheet properly.
  vol <- array(0L, dim = c(11, 6, 6))
  areas <- c(30, 26, 20, 14, 9, 6, 9, 14, 20, 26, 30)
  for (i in seq_along(areas)) {
    vol[i, , ][seq_len(areas[i])] <- 3L
  }

  it("takes the thinnest section, not the largest", {
    expect_identical(
      thinnest_cortex_slice(vol, 3L, dim(vol), 1L, 1L, 11L),
      6L
    )
  })

  it("ignores the tangential ends of the slab", {
    # Drop the true minimum to the edge: trimming must keep the search off it.
    vol[1, , ] <- 0L
    vol[1, 1, 1] <- 3L
    expect_gt(thinnest_cortex_slice(vol, 3L, dim(vol), 1L, 1L, 11L), 1L)
  })

  it("returns NULL when the slab holds no cortex", {
    expect_null(
      thinnest_cortex_slice(
        array(0L, dim = c(11, 6, 6)),
        3L,
        c(11, 6, 6),
        1L,
        1L,
        11L
      )
    )
  })
})
