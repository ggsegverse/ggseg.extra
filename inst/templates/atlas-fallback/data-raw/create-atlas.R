# Create {GGSEG} atlas for the ggseg ecosystem
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
#     "lh.{GGSEG}.annot"
#   ),
#   file.path(
#     freesurfer::fs_subj_dir(), "fsaverage5", "label",
#     "rh.{GGSEG}.annot"
#   )
# )
#
# {GGSEG} <- create_cortical_from_annotation(
#   input_annot = annot_files,
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   tolerance = 0.5,
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
# {GGSEG} <- create_cortical_from_labels(
#   label_files = label_files,
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   tolerance = 0.5,
#   verbose = TRUE
# )


# =============================================================================
# CORTICAL ATLAS (from GIFTI surfaces)
# =============================================================================
# Uncomment this section for GIFTI-format parcellations (.gii / .func.gii).

# gifti_files <- c(
#   here::here("data-raw", "lh.{GGSEG}.gii"),
#   here::here("data-raw", "rh.{GGSEG}.gii")
# )
#
# {GGSEG} <- create_cortical_from_gifti(
#   input_gifti = gifti_files,
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   tolerance = 0.5,
#   verbose = TRUE
# )


# =============================================================================
# CORTICAL ATLAS (from CIFTI)
# =============================================================================
# Uncomment this section for CIFTI-format parcellations (.dlabel.nii).

# {GGSEG} <- create_cortical_from_cifti(
#   input_cifti = here::here("data-raw", "{GGSEG}.dlabel.nii"),
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   tolerance = 0.5,
#   verbose = TRUE
# )


# =============================================================================
# CORTICAL ATLAS (from neuromaps)
# =============================================================================
# Uncomment this section for parcellations available via neuromaps.

# {GGSEG} <- create_cortical_from_neuromaps(
#   atlas_name = "{GGSEG}",
#   space = "fsaverage5",
#   output_dir = here::here("data-raw"),
#   tolerance = 0.5,
#   verbose = TRUE
# )


# =============================================================================
# SUBCORTICAL ATLAS (from NIfTI volume + lookup table)
# =============================================================================
# Uncomment this section for subcortical parcellations.
# Requires a NIfTI volume and a lookup table (LUT) with label indices,
# region names, and colours.

# lut <- read_freesurfer_lut(here::here("data-raw", "{GGSEG}_LUT.txt"))
#
# {GGSEG} <- create_subcortical_from_volume(
#   input_volume = here::here("data-raw", "{GGSEG}.nii.gz"),
#   color_lut = lut,
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )


# =============================================================================
# CEREBELLAR ATLAS (from NIfTI volume in SUIT space)
# =============================================================================
# Uncomment this section for cerebellar parcellations.
# Requires a NIfTI volume in SUIT template space and a lookup table.

# lut <- read_freesurfer_lut(here::here("data-raw", "{GGSEG}_LUT.txt"))
#
# {GGSEG} <- create_cerebellar_from_volume(
#   input_volume = here::here("data-raw", "{GGSEG}.nii.gz"),
#   color_lut = lut,
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )


# =============================================================================
# TRACT ATLAS (from tractography volume)
# =============================================================================
# Uncomment this section for white-matter tract parcellations.

# {GGSEG} <- create_tract_from_tractography(
#   input_volume = here::here("data-raw", "{GGSEG}.nii.gz"),
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )


# =============================================================================
# WHOLEBRAIN ATLAS (cortical + subcortical from a single volume)
# =============================================================================
# Uncomment this section for whole-brain volumetric parcellations that
# contain both cortical and subcortical regions.

# lut <- read_freesurfer_lut(here::here("data-raw", "{GGSEG}_LUT.txt"))
#
# {GGSEG} <- create_wholebrain_from_volume(
#   input_volume = here::here("data-raw", "{GGSEG}.nii.gz"),
#   color_lut = lut,
#   atlas_name = "{GGSEG}",
#   output_dir = here::here("data-raw"),
#   verbose = TRUE
# )


# =============================================================================
# CLEAN UP REGION NAMES (optional)
# =============================================================================

# {GGSEG}$core <- {GGSEG}$core |>
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

# print({GGSEG})
# plot({GGSEG})
#
# if (interactive()) {
#   ggseg3d::ggseg3d(atlas = {GGSEG}, hemisphere = "left")
# }


# =============================================================================
# SAVE AS INTERNAL DATA
# =============================================================================

# .{GGSEG} <- {GGSEG}
# usethis::use_data(.{GGSEG}, internal = TRUE, overwrite = TRUE, compress = "xz")
