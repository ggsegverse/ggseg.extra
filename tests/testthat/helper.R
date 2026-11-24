library(dplyr, quietly = TRUE, warn.conflicts = FALSE)
library(ggseg3d, quietly = TRUE, warn.conflicts = FALSE)

options(
  ggseg.extra.verbose = FALSE,
  freesurfer.verbose = FALSE,
  rgl.useNULL = TRUE
)

# Tests stamp caches directly rather than always going through a pipeline, so
# the test process claims the manifests the way setup_atlas_dirs() does for a
# real run. The guard itself is tested by moving the claim, not by leaving it
# unset here.
claim_cache_manifests()

testdata_dir <- function() {
  test_path("testdata")
}

test_label_files <- function() {
  list(
    lh_region1 = file.path(testdata_dir(), "cortical", "lh.region1.label"),
    lh_region2 = file.path(testdata_dir(), "cortical", "lh.region2.label"),
    rh_region1 = file.path(testdata_dir(), "cortical", "rh.region1.label")
  )
}

test_annot_files <- function() {
  list(
    lh = file.path(testdata_dir(), "cortical", "lh.yeo7.annot"),
    rh = file.path(testdata_dir(), "cortical", "rh.yeo7.annot")
  )
}

test_mgz_file <- function() {
  file.path(testdata_dir(), "volumetric", "aseg.mgz")
}

test_lut_file <- function() {
  file.path(testdata_dir(), "volumetric", "lut.txt")
}

# ggseg3d's renderer relies on a native geometry/plotly stack that segfaults
# intermittently on the parallel Windows CI runner; the render path is not
# OS-specific, so skip it there.
skip_render_on_windows <- function() {
  skip_on_os("windows")
}

# The pipelines are tested with their atlas-building step mocked out, and the
# accessors refuse anything that is not an atlas, so the stand-in has to be a
# real one rather than a list carrying the class attribute.
stub_atlas <- function(
  regions = "a",
  labels = regions,
  hemi = NA_character_,
  type = c("subcortical", "cerebellar", "cortical", "tract"),
  atlas = "stub"
) {
  type <- match.arg(type)
  core <- data.frame(
    stringsAsFactors = FALSE,
    hemi = hemi,
    region = regions,
    label = labels,
    display = regions
  )
  ggseg.formats::ggseg_atlas(
    atlas = atlas,
    type = type,
    core = core,
    data = stub_atlas_data(type, labels)
  )
}

stub_atlas_data <- function(type, labels) {
  switch(
    type,
    cortical = ggseg.formats::ggseg_data_cortical(
      vertices = stub_vertices(labels)
    ),
    cerebellar = ggseg.formats::ggseg_data_cerebellar(
      meshes = stub_meshes(labels)
    ),
    tract = ggseg.formats::ggseg_data_tract(
      centerlines = stub_centerlines(labels)
    ),
    ggseg.formats::ggseg_data_subcortical(meshes = stub_meshes(labels))
  )
}

stub_vertices <- function(labels) {
  df <- data.frame(stringsAsFactors = FALSE, label = labels)
  df$vertices <- rep(list(0:3), length(labels))
  df
}

stub_meshes <- function(labels) {
  df <- data.frame(stringsAsFactors = FALSE, label = labels)
  df$mesh <- rep(
    list(list(
      vertices = data.frame(x = 0:2, y = 0:2, z = 0:2),
      faces = data.frame(i = 0L, j = 1L, k = 2L)
    )),
    length(labels)
  )
  df
}

stub_centerlines <- function(labels) {
  points <- matrix(
    as.numeric(1:9),
    ncol = 3,
    dimnames = list(NULL, c("x", "y", "z"))
  )
  df <- data.frame(stringsAsFactors = FALSE, label = labels)
  df$points <- rep(list(points), length(labels))
  df$tangents <- rep(list(points), length(labels))
  df
}
