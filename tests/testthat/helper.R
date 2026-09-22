library(dplyr, quietly = TRUE, warn.conflicts = FALSE)
library(ggseg, quietly = TRUE, warn.conflicts = FALSE)
library(ggseg3d, quietly = TRUE, warn.conflicts = FALSE)

options(
  ggseg.extra.verbose = FALSE,
  freesurfer.verbose = FALSE,
  rgl.useNULL = TRUE
)

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
