mock_future_pmap <- function(.l, .f, ...) {
  do.call(Map, c(list(f = .f), .l))
}

mock_future_map2 <- function(.x, .y, .f, ...) {
  mapply(.f, .x, .y, SIMPLIFY = FALSE)
}

# Real directories from the real setup_atlas_dirs(), not a hand-built list.
# These used to return two or three unrelated tempdirs, a shape the pipeline
# never sees: production nests snapshots/ and meshes/ under base/, which is why
# finalize_atlas() can clear the intermediates with a single recursive unlink()
# of base. Siblings survive that, so a test using the old shape could not tell
# cleanup from a no-op.
local_atlas_dirs <- function() {
  setup_atlas_dirs(
    withr::local_tempdir(.local_envir = parent.frame()),
    type = "cortical"
  )
}

local_subcort_dirs <- function() {
  setup_atlas_dirs(
    withr::local_tempdir(.local_envir = parent.frame()),
    type = "subcortical"
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

mock_context_sf <- function(labels, view = "lateral") {
  do.call(rbind, lapply(labels, mock_sf_polygon, view = view))
}

expect_unknown_is_context <- function(atlas, unknown_labels) {
  expect_true(all(unknown_labels %in% atlas_geom(atlas)$label))
  expect_false(any(unknown_labels %in% atlas_labels(atlas)))
  expect_false(any(unknown_labels %in% names(atlas_palette(atlas))))
  expect_false(any(unknown_labels %in% atlas_vertices(atlas)$label))
}

local_cache_file <- function(
  content = 1,
  name = "step.rds",
  stamped = TRUE,
  env = parent.frame()
) {
  dir <- withr::local_tempdir("cache_", .local_envir = env)
  file <- file.path(dir, name)
  saveRDS(content, file)
  if (stamped) {
    stamp_cache_files(file)
  }
  file
}

# Runs the calling test from a fresh temp directory, with pipeline output
# going to a relative "out" directory. Inputs created there by relative name
# are reported by that name, so pipeline messages read the same on every run
# and machine. Resolve test_path() fixtures before calling this: they are
# relative to tests/testthat.
local_test_workdir <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_dir(dir, .local_envir = env)
  withr::local_options(ggseg.extra.output_dir = "out", .local_envir = env)
  invisible(dir)
}

# Pipelines report their output directory as an absolute path, which under
# local_test_workdir() starts with the test's own working directory.
scrub_workdir <- function(lines) {
  gsub(as.character(fs::path_abs(".")), "<workdir>", lines, fixed = TRUE)
}

#' Drop the blank lines cli emits around headings
#'
#' cli omits the blank before an app's *first* heading and emits one after
#' that, and each blank arrives as its own message. Whether a snapshot
#' records them therefore depends on what printed earlier in the same file --
#' and a FreeSurfer-gated test sits above some of them, so it prints on a
#' developer machine and skips on a runner. Verified against the runner's own
#' `.new.md`: a single blank line was the entire difference.
#'
#' This drops blank-only lines, so the snapshot pins the messages, warnings
#' and info lines and not cli's vertical spacing. Use it only where that
#' spacing is environment-dependent; `scrub_workdir()` alone is right
#' elsewhere.
scrub_cli_spacing <- function(lines) {
  lines[nzchar(trimws(lines))]
}

#' `scrub_workdir()` with cli's blank lines dropped
scrub_snapshot <- function(lines) {
  scrub_cli_spacing(scrub_workdir(lines))
}

#' `RNifti::asNifti()` with the 1 mm RAS+ affine a real volume would carry
#'
#' A bare array leaves both xform codes zero, which means "this header
#' declares no orientation"; readers must not take it for RAS.
as_oriented_nifti <- function(values) {
  image <- RNifti::asNifti(values)
  ras_grid <- structure(diag(4), code = 2L)
  RNifti::sform(image) <- ras_grid
  RNifti::qform(image) <- ras_grid
  image
}

#' The sform origin at which a volume of this extent shares the reference
#' tkreg frame
#'
#' A tkregister frame is centred on each volume's OWN field of view, so a
#' small fixture sits on the grid `mni152.register.dat` was built for only at
#' a particular origin: `o_ref + LAS %*% ((reference FOV - this FOV) / 2)`.
#' Left at `(0, 0, 0)` a 2x2x2 fixture is displaced about 25 mm, which
#' `check_mni152_grid()` refuses.
mni152_frame_origin <- function(dim, voxel = 1) {
  reference_dim <- c(182, 218, 182)
  as.vector(
    c(90, -126, -72) +
      diag(c(-1, 1, 1)) %*% ((reference_dim - dim * voxel) / 2)
  )
}

#' A small NIfTI volume holding `values`, removed with the calling test
#'
#' On a 1 mm left-handed (LAS) grid sharing the reference tkreg frame, which
#' is what the MNI152 registration check accepts.
local_nifti_volume <- function(values = c(0, 1, 2), env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".nii.gz", .local_envir = env)
  image <- RNifti::asNifti(array(rep_len(values, 8L), dim = c(2L, 2L, 2L)))
  las_grid <- diag(c(-1, 1, 1, 1))
  las_grid[1:3, 4] <- mni152_frame_origin(c(2, 2, 2))
  las_grid <- structure(las_grid, code = 2L)
  RNifti::sform(image) <- las_grid
  RNifti::qform(image) <- las_grid
  RNifti::writeNifti(image, path)
  path
}


#' A stand-in for ggseg.formats::ggseg_atlas() that enforces its contract
#'
#' The pipelines are tested with the constructor mocked, and the mock used to
#' be `function(...) structure(list(...), class = "ggseg_atlas")`: a stub whose
#' class the test then asserted. That assertion could only ever pass -- it was
#' the mock being checked against itself, so a pipeline that stopped passing a
#' `core`, or keyed its palette on something other than `label`, still went
#' green.
#'
#' Taking the real constructor's named arguments and validating them makes the
#' mock itself the assertion, at every site that installs it.
#'
#' @param returns Optional object to return instead of the stub, for tests that
#'   need a specific atlas downstream.
#' @return A function with `ggseg_atlas()`'s signature.
mock_ggseg_atlas <- function(returns = NULL) {
  function(atlas, type, core, data, palette = NULL, provenance = NULL) {
    testthat::expect_type(atlas, "character")
    testthat::expect_length(atlas, 1L)
    testthat::expect_true(
      type %in% c("cortical", "subcortical", "cerebellar", "tract")
    )
    testthat::expect_s3_class(core, "data.frame")
    testthat::expect_true(all(c("label", "region", "hemi") %in% names(core)))
    testthat::expect_gt(nrow(core), 0L)
    testthat::expect_false(anyNA(core$label))
    if (!is.null(palette)) {
      # `label` is the key a palette is built on ecosystem-wide, so a palette
      # naming anything else cannot colour the atlas it ships with.
      testthat::expect_true(all(names(palette) %in% core$label))
    }

    if (!is.null(returns)) {
      return(returns)
    }
    structure(
      list(
        atlas = atlas,
        type = type,
        core = core,
        data = data,
        palette = palette,
        provenance = provenance
      ),
      class = "ggseg_atlas"
    )
  }
}
