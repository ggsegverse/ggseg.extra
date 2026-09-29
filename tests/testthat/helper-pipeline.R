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
  expect_true(all(unknown_labels %in% atlas$data$geom$label))
  expect_false(any(unknown_labels %in% atlas$core$label))
  expect_false(any(unknown_labels %in% names(atlas$palette)))
  expect_false(any(unknown_labels %in% atlas$data$vertices$label))
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
