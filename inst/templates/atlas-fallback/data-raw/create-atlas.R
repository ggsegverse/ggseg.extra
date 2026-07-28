# Create ATLASNAME atlas for the ggseg ecosystem
#
# This script scaffolds the atlas creation pipeline.
# Uncomment the section matching your atlas type and follow the steps.

library(ggseg.extra)
library(dplyr)

future::plan(future::sequential)
progressr::handlers("cli")
progressr::handlers(global = TRUE)

# =============================================================================
# CORTICAL ATLAS (from FreeSurfer annotation files)
# =============================================================================
# Uncomment this section for cortical surface parcellations.

# annot_files <- c(
#   file.path(
#     freesurfer::fs_subj_dir(), "fsaverage5", "label",
#     "lh.ATLASNAME.annot"
#   ),
#   file.path(
#     freesurfer::fs_subj_dir(), "fsaverage5", "label",
#     "rh.ATLASNAME.annot"
#   )
# )
#
# ATLASNAME <- create_cortical_from_annotation(
#   input_annot = annot_files,
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )

# =============================================================================
# CORTICAL ATLAS (from label files)
# =============================================================================
# Uncomment this section if you have individual .label files.

# label_files <- list.files(
#   here::here("data-raw"), pattern = "\\.label$", full.names = TRUE
# )
#
# ATLASNAME <- create_cortical_from_labels(
#   label_files = label_files,
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )

# =============================================================================
# CORTICAL ATLAS (from GIFTI surfaces)
# =============================================================================
# Uncomment this section for GIFTI-format parcellations (.gii / .func.gii).

# ATLASNAME <- create_cortical_from_gifti(
#   gifti_files = c(
#     here::here("data-raw", "lh.ATLASNAME.gii"),
#     here::here("data-raw", "rh.ATLASNAME.gii")
#   ),
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )

# =============================================================================
# CORTICAL ATLAS (from CIFTI)
# =============================================================================
# Uncomment this section for CIFTI-format parcellations (.dlabel.nii).

# ATLASNAME <- create_cortical_from_cifti(
#   cifti_file = here::here("data-raw", "ATLASNAME.dlabel.nii"),
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )

# =============================================================================
# CORTICAL ATLAS (from neuromaps)
# =============================================================================
# Uncomment this section for parcellations available via neuromaps.
# `source` and `desc` identify the annotation; see the neuromapr package for
# the available combinations. Continuous brain maps are discretised into
# `n_bins` quantile bins, each becoming a plottable region.

# ATLASNAME <- create_cortical_from_neuromaps(
#   source = "ATLASNAME",
#   desc = "TODO-descriptor",
#   space = "fsaverage",
#   density = "10k",
#   n_bins = 10,
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )

# =============================================================================
# SUBCORTICAL ATLAS (from NIfTI volume + lookup table)
# =============================================================================
# Uncomment this section for subcortical parcellations.
# `input_lut` takes a FreeSurfer-style colour lookup table path, or a
# data.frame with a `region` column plus colour columns. Use `read_lut()` if
# you want to inspect or edit the table before passing it in.

# ATLASNAME <- create_subcortical_from_volume(
#   input_volume = here::here("data-raw", "ATLASNAME.nii.gz"),
#   input_lut = here::here("data-raw", "ATLASNAME_LUT.txt"),
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   decimate = 0.5,
#   verbose = TRUE
# )

# =============================================================================
# CEREBELLAR ATLAS (from NIfTI volume in SUIT space)
# =============================================================================
# Uncomment this section for cerebellar parcellations.
# The volume must be in SUIT template space. Use transform_mni_to_suit() first
# if yours is in MNI space.

# ATLASNAME <- create_cerebellar_from_volume(
#   input_volume = here::here("data-raw", "ATLASNAME.nii.gz"),
#   input_lut = here::here("data-raw", "ATLASNAME_LUT.txt"),
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )

# =============================================================================
# TRACT ATLAS (from tractography files)
# =============================================================================
# Uncomment this section for white-matter tract parcellations.
# `input_tracts` takes .trk/.tck paths (or a named list of Nx3 coordinate
# matrices). `input_aseg` supplies the cortex outline for the 2D views.

# ATLASNAME <- create_tract_from_tractography(
#   input_tracts = list.files(
#     here::here("data-raw", "tracts"),
#     pattern = "\\.(trk|tck)$", full.names = TRUE
#   ),
#   input_aseg = here::here("data-raw", "aseg.mgz"),
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   tube_radius = 5,
#   verbose = TRUE
# )

# =============================================================================
# WHOLEBRAIN ATLAS (cortical + subcortical from a single volume)
# =============================================================================
# Uncomment this section for whole-brain volumetric parcellations that
# contain both cortical and subcortical regions.

# ATLASNAME <- create_wholebrain_from_volume(
#   input_volume = here::here("data-raw", "ATLASNAME.nii.gz"),
#   input_lut = here::here("data-raw", "ATLASNAME_LUT.txt"),
#   atlas_name = "ATLASNAME",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )

# =============================================================================
# SMOOTH AND SIMPLIFY (optional)
# =============================================================================
# The pipelines return raw, unsmoothed polygons. Smoothing is a separate
# post-processing step, so you can tune `keep` without re-running the
# pipeline. `exclude = "cortex_"` keeps the brain outline crisp.

# ATLASNAME <- atlas_smooth(
#   ATLASNAME,
#   keep = 0.2,
#   exclude = "cortex_"
# )

# =============================================================================
# CLEAN UP REGION NAMES (optional)
# =============================================================================

# ATLASNAME$core <- ATLASNAME$core |>
#   mutate(
#     region = gsub("_L$|_R$|_lh$|_rh$", "", region),
#     region = if_else(
#       grepl("unknown|wall|\\?|corpus.callosum", region, ignore.case = TRUE),
#       NA_character_,
#       region
#     )
#   )

# =============================================================================
# VERIFY
# =============================================================================

# print(ATLASNAME)
# plot(ATLASNAME)
#
# if (interactive()) {
#   ggseg3d::ggseg3d(atlas = ATLASNAME, hemisphere = "left")
# }

# =============================================================================
# SAVE AS INTERNAL DATA
# =============================================================================

# .ATLASNAME <- ATLASNAME
# usethis::use_data(
#   .ATLASNAME,
#   internal = TRUE,
#   overwrite = TRUE,
#   compress = "xz"
# )
