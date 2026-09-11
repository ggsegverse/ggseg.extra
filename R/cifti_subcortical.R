#' Extract subcortical labels from a CIFTI file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' CIFTI dense label files in grayordinate space (such as fsLR 91k) store
#' subcortical parcels as voxels rather than surface vertices, so
#' [read_cifti_annotation()] and [create_cortical_from_cifti()] cannot use
#' them. `read_cifti_subcortical()` writes those voxels to a NIfTI label volume
#' and builds the matching colour table from the CIFTI label table.
#'
#' The volume keeps the CIFTI's voxel grid and transform. Grayordinate files
#' are in MNI152NLin6Asym (FSL's MNI152), at 2 mm for 91k and 1.6 mm for 170k,
#' so the result can go to [prepare_subcortical_mni152()] for grey-brain
#' context, or straight to [create_subcortical_from_volume()]. Label ids that
#' reuse FreeSurfer `aseg` ids (as HCP-style files often do) must be shifted
#' before [prepare_subcortical_mni152()], which refuses colliding ids.
#'
#' @param cifti_file Path to a `.dlabel.nii` CIFTI file with subcortical
#'   voxels.
#' @param output_file Path for the NIfTI label volume. Defaults to a temporary
#'   `.nii.gz` file.
#'
#' @return A list with `volume`, the path to the written NIfTI, and `lut`, a
#'   data.frame with columns `idx`, `label`, `R`, `G`, `B` and `A` covering the
#'   labels present in the volume. `A` is 0 (opaque), following the FreeSurfer
#'   colour table convention rather than the CIFTI alpha.
#' @seealso [prepare_subcortical_mni152()], [create_subcortical_from_volume()]
#' @export
#' @examples
#' \dontrun{
#' subcortex <- read_cifti_subcortical("atlas.dlabel.nii")
#' merged <- prepare_subcortical_mni152(
#'   input_volume = subcortex$volume,
#'   labels = subcortex$lut$idx,
#'   lut = subcortex$lut
#' )
#' atlas <- create_subcortical_from_volume(input_volume = merged)
#' }
read_cifti_subcortical <- function(
  cifti_file,
  output_file = tempfile(fileext = ".nii.gz")
) {
  rlang::check_installed("RNifti", reason = "to write NIfTI label volumes")
  cii <- read_cifti_file(
    cifti_file,
    reason = "to extract subcortical labels from CIFTI files"
  )

  if (is.null(cii$data$subcort)) {
    cli::cli_abort(c(
      "{.path {cifti_file}} has no subcortical voxels.",
      "i" = "Use {.fn create_cortical_from_cifti} for surface-only files."
    ))
  }

  write_cifti_label_volume(
    cifti_subcortical_volume(cii),
    cii$meta$subcort$trans_mat,
    output_file
  )

  list(volume = output_file, lut = cifti_subcortical_lut(cii))
}

# Before 0.17.4, read_cifti() did not default to reading every brain structure
# in the file, so subcortical voxels could be skipped without a trace.
#' @noRd
ciftitools_min_version <- function() {
  "0.17.4"
}

#' @noRd
cifti_subcortical_volume <- function(cii) {
  mask <- cii$meta$subcort$mask
  values <- cii$data$subcort[, 1]
  if (sum(mask) != length(values)) {
    cli::cli_abort(
      "CIFTI subcortical data has {length(values)} voxel{?s} but its mask \\
       has {sum(mask)}."
    )
  }

  volume <- array(0L, dim = dim(mask))
  volume[mask] <- as.integer(values)
  volume
}

# FreeSurfer reads voxel size from pixdim and prefers the qform, so setting
# only the sform leaves a 2 mm volume read as 1 mm and shifted.
#' @noRd
write_cifti_label_volume <- function(volume, trans_mat, output_file) {
  xform <- structure(trans_mat, code = 4L)
  image <- RNifti::asNifti(volume)
  RNifti::pixdim(image) <- sqrt(colSums(trans_mat[1:3, 1:3]^2))
  RNifti::pixunits(image) <- "mm"
  RNifti::qform(image) <- xform
  RNifti::sform(image) <- xform
  RNifti::writeNifti(image, output_file, datatype = "int32")
}

#' @noRd
cifti_subcortical_lut <- function(cii) {
  keys <- setdiff(unique(as.integer(cii$data$subcort[, 1])), 0L)
  regions <- cifti_label_regions(cii)
  regions <- regions[regions$code %in% keys, ]
  rgb_values <- col2rgb(regions$colour)

  data.frame(
    idx = regions$code,
    label = regions$name,
    R = rgb_values["red", ],
    G = rgb_values["green", ],
    B = rgb_values["blue", ],
    A = 0L
  )
}

#' @noRd
warn_dropped_cifti_subcortex <- function(cii, cifti_file) {
  subcort <- cii$data$subcort
  n_labelled <- if (is.null(subcort)) 0L else sum(subcort[, 1] != 0)

  if (n_labelled > 0) {
    cli::cli_warn(c(
      "{.path {cifti_file}} has {n_labelled} labelled subcortical \\
       voxel{?s}, which the cortical pipeline ignores.",
      "i" = "Extract them with {.fn read_cifti_subcortical} and build a \\
             subcortical atlas with {.fn create_subcortical_from_volume}."
    ))
  }
}
