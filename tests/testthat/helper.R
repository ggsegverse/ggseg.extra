library(dplyr, quietly = TRUE, warn.conflicts = FALSE)
library(tidyr, quietly = TRUE, warn.conflicts = FALSE)
library(ggseg, quietly = TRUE, warn.conflicts = FALSE)
library(ggseg3d, quietly = TRUE, warn.conflicts = FALSE)

# terra::describe masks testthat::describe in parallel workers
describe <- testthat::describe

options(
  ggseg.extra.verbose = FALSE,
  freesurfer.verbose = FALSE
)

# Helper to get test data directory
testdata_dir <- function() {
  testthat::test_path("testdata")
}

# Helper to skip tests if package not installed
skip_if_not_installed <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    testthat::skip(paste0("Package '", pkg, "' not installed"))
  }
}

# Helper to skip tests requiring FreeSurfer
skip_if_no_freesurfer <- function() {
  if (!freesurfer::have_fs()) {
    testthat::skip("FreeSurfer not available")
  }
}

# Helper to skip tests requiring ImageMagick
skip_if_no_imagemagick <- function() {
  if (Sys.which("convert") == "") {
    testthat::skip("ImageMagick not available")
  }
}

# Helper to get test label files
test_label_files <- function() {
  list(
    lh_region1 = file.path(testdata_dir(), "cortical", "lh.region1.label"),
    lh_region2 = file.path(testdata_dir(), "cortical", "lh.region2.label"),
    rh_region1 = file.path(testdata_dir(), "cortical", "rh.region1.label")
  )
}

# Helper to get test MGZ file
test_mgz_file <- function() {
  file.path(testdata_dir(), "volumetric", "aseg.mgz")
}

# Helper to get test LUT file
test_lut_file <- function() {
  file.path(testdata_dir(), "volumetric", "lut.txt")
}

# Helper to get test annotation files (Yeo7 networks)
test_annot_files <- function() {
  list(
    lh = file.path(testdata_dir(), "cortical", "lh.yeo7.annot"),
    rh = file.path(testdata_dir(), "cortical", "rh.yeo7.annot")
  )
}

# Helper to get test annotation name
test_annot_name <- function() {
  "yeo7"
}

mock_future_pmap <- function(.l, .f, ...) {
  do.call(Map, c(list(f = .f), .l))
}

mock_future_map2 <- function(.x, .y, .f, ...) {
  mapply(.f, .x, .y, SIMPLIFY = FALSE)
}

expect_warnings <- function(expr, regexp) {
  warnings_caught <- character()
  result <- withCallingHandlers(
    expr,
    warning = function(w) {
      if (grepl(regexp, conditionMessage(w))) {
        warnings_caught[[length(warnings_caught) + 1L]] <<-
          conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    }
  )
  testthat::expect_true(
    length(warnings_caught) > 0,
    label = paste0(
      "Expected at least one warning matching '",
      regexp,
      "'"
    )
  )
  invisible(result)
}

# Pipeline test helpers ----

mock_dirs <- function() {
  list(
    base = withr::local_tempdir(.local_envir = parent.frame()),
    snapshots = withr::local_tempdir(.local_envir = parent.frame()),
    processed = withr::local_tempdir(.local_envir = parent.frame()),
    masks = withr::local_tempdir(.local_envir = parent.frame())
  )
}

mock_components <- function(
  label = "lh_r",
  hemi = "left",
  region = "r",
  colour = "#FF0000"
) {
  list(
    core = data.frame(
      hemi = hemi,
      region = region,
      label = label,
      stringsAsFactors = FALSE
    ),
    palette = stats::setNames(colour, label),
    vertices_df = data.frame(
      label = label,
      vertices = I(list(1:5))
    )
  )
}

mock_sf_polygon <- function(label = "test", view = "lateral") {
  sf::st_sf(
    label = label,
    view = view,
    geometry = sf::st_sfc(sf::st_polygon(list(matrix(
      c(0, 0, 1, 0, 1, 1, 0, 0),
      ncol = 2,
      byrow = TRUE
    ))))
  )
}

# nolint next: object_length_linter.
mock_cortical_pipeline_bindings <- function(captured = NULL) {
  mocks <- list(
    cortical_brain_snapshots = function(...) NULL,
    cortical_isolate_regions = function(...) NULL,
    extract_contours = function(...) NULL,
    smooth_contours = function(...) NULL,
    reduce_vertex = function(...) NULL,
    cortical_build_sf = function(...) mock_sf_polygon(),
    ggseg_atlas = function(...) structure(list(...), class = "ggseg_atlas"),
    ggseg_data_cortical = function(...) list(...),
    warn_if_large_atlas = function(...) NULL,
    preview_atlas = function(...) NULL,
    log_elapsed = function(...) NULL
  )

  if (!is.null(captured)) {
    for (fn_name in names(captured)) {
      env <- captured[[fn_name]]
      mocks[[fn_name]] <- (function(e, nm) {
        function(...) {
          e[[nm]] <<- list(...)
          if (nm == "cortical_build_sf") {
            return(mock_sf_polygon())
          }
          if (nm %in% c("ggseg_atlas", "ggseg_data_cortical")) {
            return(structure(list(...), class = "ggseg_atlas"))
          }
          NULL
        }
      })(env, fn_name)
    }
  }

  mocks
}

mock_subcort_dirs <- function() {
  pf <- parent.frame()
  list(
    base = withr::local_tempdir(.local_envir = pf),
    snapshots = withr::local_tempdir(.local_envir = pf),
    processed = withr::local_tempdir(.local_envir = pf),
    masks = withr::local_tempdir(.local_envir = pf),
    meshes = withr::local_tempdir(.local_envir = pf)
  )
}

# Helper to skip tests requiring internet
skip_if_offline <- function() {
  tryCatch(
    {
      con <- url("https://ggsegverse.r-universe.dev/api/packages", open = "r")
      close(con)
    },
    error = function(e) {
      testthat::skip("No internet connection available")
    }
  )
}
