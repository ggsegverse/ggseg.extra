# Fixtures shared by the whole-brain pipeline, its context declaration and
# the surface dilation tests, which live in three files now.

.cap <- new.env()

local_fake_fsaverage <- function(
  n_vertices,
  faces,
  cortex,
  env = parent.frame()
) {
  tmp_dir <- withr::local_tempdir(.local_envir = env)
  subj_dir <- file.path(tmp_dir, "fsaverage5")
  dir.create(file.path(subj_dir, "surf"), recursive = TRUE)
  dir.create(file.path(subj_dir, "label"), recursive = TRUE)
  for (hemi in c("lh", "rh")) {
    writeLines(
      "placeholder",
      file.path(subj_dir, "surf", paste0(hemi, ".white"))
    )
    file.create(file.path(subj_dir, "label", paste0(hemi, ".cortex.label")))
  }
  local_mocked_bindings(
    fs_subj_dir = function() tmp_dir,
    .package = "freesurfer",
    .env = env
  )
  local_mocked_bindings(
    read.fs.surface = function(f) {
      list(vertices = matrix(0, nrow = n_vertices, ncol = 3), faces = faces)
    },
    .package = "freesurferformats",
    .env = env
  )
  local_mocked_bindings(
    read_label_vertices = function(...) cortex,
    .env = env
  )
  tmp_dir
}

# Capture the arguments the pipeline passes to mri_vol2surf, writing a
# stand-in overlay so the caller can read it back. Returns an environment
# whose `args` holds the arguments after `output_file`.
local_mock_mri_vol2surf <- function(overlay = c(1L, 2L), env = parent.frame()) {
  cap <- new.env()
  local_mocked_bindings(
    mri_vol2surf = function(input_file, output_file, ...) {
      cap$args <- list(...)
      RNifti::writeNifti(
        array(overlay, dim = c(length(overlay), 1, 1)),
        output_file
      )
    },
    .env = env
  )
  cap
}


# Write `arr` to a temporary NIfTI whose world x = 0 falls on the 1-based
# voxel `midline`, which is the plane the hemisphere split reads.
local_volume_at_midline <- function(arr, midline, env = parent.frame()) {
  file <- withr::local_tempfile(fileext = ".nii.gz", .local_envir = env)
  img <- RNifti::asNifti(
    arr,
    reference = list(
      sform_code = 1L,
      srow_x = c(1, 0, 0, 1 - midline),
      srow_y = c(0, 1, 0, 0),
      srow_z = c(0, 0, 1, 0)
    )
  )
  RNifti::writeNifti(img, file)
  file
}
