# Fixtures shared by the whole-brain pipeline, its aseg ribbon context
# and the surface dilation tests, which live in three files now.

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


# Pretend no FreeSurfer aseg is available, so the cortical context falls back
# to the solid silhouette without shelling out or warning.
local_no_aseg_ribbon <- function(env = parent.frame()) {
  local_mocked_bindings(
    aseg_context_volume = function(...) NULL,
    .env = env
  )
}

# A context volume in the shape aseg_context_volume() returns: left cortex
# where `left` is TRUE, right cortex where `right` is TRUE, 0 elsewhere.
mock_cortex_ribbon <- function(left, right) {
  ribbon <- array(0L, dim = dim(left))
  ribbon[left] <- 3L
  ribbon[right] <- 42L
  ribbon
}
