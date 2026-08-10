#' Lumped aseg subcortical structures a parcellation typically subdivides
#'
#' The FreeSurfer `aseg` ids for the bilateral subcortical structures that a
#' finer subcortical parcellation replaces: thalamus, caudate, putamen,
#' pallidum, hippocampus, amygdala and nucleus accumbens (left and right). Use
#' as (or extend) the `replace_labels` argument of
#' [prepare_subcortical_mni152()] — for example add `16L` (brain-stem) when a
#' parcel covers it.
#'
#' @return An integer vector of 14 `aseg` label ids.
#' @seealso [prepare_subcortical_mni152()]
#' @export
#' @examples
#' aseg_subcortical_labels()
#' c(aseg_subcortical_labels(), 16L) # add brain-stem
aseg_subcortical_labels <- function() {
  c(10L, 49L, 11L, 50L, 12L, 51L, 13L, 52L, 17L, 53L, 18L, 54L, 26L, 58L)
}

#' Embed MNI152 subcortical parcels in a FreeSurfer aseg for grey-brain context
#'
#' @description
#' Registers a subcortical parcellation supplied in fixed FSL-MNI152 space into
#' a FreeSurfer subject's `aseg`, replacing the lumped aseg structures the
#' parcels subdivide, so [create_subcortical_from_volume()] can render the
#' parcels as coloured structures inside a grey brain silhouette (cortex, white
#' matter, cerebellum and brain-stem context).
#'
#' This is the *fixed-registration* counterpart to
#' [prepare_subcortical_anatomical()]. Use this when the atlas already lives in
#' a standard MNI152 template: the registration is the known
#' `mni152.register.dat` transform (no `mri_coreg` search needed) and the
#' context is taken from `fsaverage5`, matching the rest of the ecosystem. Use
#' [prepare_subcortical_anatomical()] instead when the registration must be
#' computed from an arbitrary volume (it targets `cvs_avg35_inMNI152` via
#' `mri_coreg`).
#'
#' @param input_volume Path or `RNifti` image of the parcellation in FSL-MNI152
#'   space. Only voxels whose value is in `labels` are embedded.
#' @param labels Integer ids of the parcels to embed. Defaults to every non-zero
#'   id in `input_volume`. Ids must not collide with the surviving `aseg`
#'   context ids; remap them upstream (e.g. add a fixed offset) if they do.
#' @param lut Optional colour table (`data.frame` with `idx, label, R, G, B, A`)
#'   naming the parcels. When `NULL`, generic `region_XXXX` names and an HCL
#'   palette are generated.
#' @param replace_labels Integer `aseg` ids the parcels subdivide, blanked
#'   before the parcels are stamped in. Defaults to [aseg_subcortical_labels()].
#' @param target_subject FreeSurfer subject whose `aseg` supplies the grey-brain
#'   context. Defaults to `"fsaverage5"`.
#' @param registration Path to the MNI152 registration `.dat`. Defaults to
#'   `mni152.register.dat` under `FREESURFER_HOME/average`.
#' @param output_file Optional path for the merged volume; defaults to a
#'   tempfile.
#' @param subjects_dir FreeSurfer subjects directory.
#' @param verbose Verbosity, passed to the FreeSurfer command runner.
#'
#' @return Invisibly, `list(volume, lut)`: the merged volume path and a matching
#'   colour table, ready to pass straight to [create_subcortical_from_volume()]
#'   (optionally with `context = list(focus = ...)`).
#' @seealso [prepare_subcortical_anatomical()] for the computed-registration
#'   (`cvs_avg35_inMNI152`, `mri_coreg`) counterpart;
#'   [create_subcortical_from_volume()] which consumes the result.
#' @export
#' @examples
#' \dontrun{
#' merged <- prepare_subcortical_mni152(
#'   input_volume = "BN_Atlas_subcortical_1mm.nii.gz",
#'   labels = 211:246
#' )
#' atlas <- create_subcortical_from_volume(
#'   input_volume = merged,
#'   context = list(focus = "region_", match_on = "label")
#' )
#' }
prepare_subcortical_mni152 <- function(
  input_volume,
  labels = NULL,
  lut = NULL,
  replace_labels = aseg_subcortical_labels(),
  target_subject = "fsaverage5",
  registration = NULL,
  output_file = NULL,
  subjects_dir = freesurfer::fs_subj_dir(),
  verbose = get_verbose() # nolint: object_usage_linter
) {
  check_fs(abort = TRUE)
  rlang::check_installed("RNifti", reason = "to read NIfTI volumes")

  in_path <- resolve_volume_path(input_volume)
  if (is.null(registration)) {
    registration <- as.character(
      fs::path(freesurfer::fs_dir(), "average", "mni152.register.dat")
    )
  }
  if (!file.exists(registration)) {
    cli::cli_abort("Registration not found: {.path {registration}}")
  }
  aseg_mgz <- as.character(
    fs::path(subjects_dir, target_subject, "mri", "aseg.mgz")
  )
  if (!file.exists(aseg_mgz)) {
    cli::cli_abort(c(
      "aseg not found: {.path {aseg_mgz}}",
      "i" = "Provide a {.arg target_subject} with an {.file aseg.mgz}."
    ))
  }

  vol <- RNifti::readNifti(in_path)
  arr <- as.array(vol)
  if (is.null(labels)) {
    labels <- setdiff(unique(as.integer(arr)), 0L)
  }
  labels <- sort(as.integer(labels))

  parcels_mni <- tempfile(fileext = ".nii.gz")
  on.exit(unlink(parcels_mni), add = TRUE)
  keep <- array(0L, dim = dim(arr))
  sel <- arr %in% labels
  keep[sel] <- as.integer(arr[sel])
  RNifti::writeNifti(RNifti::asNifti(keep, reference = vol), parcels_mni)

  registered <- tempfile(fileext = ".nii.gz")
  on.exit(unlink(registered), add = TRUE)
  run_cmd(
    paste(
      "mri_vol2vol",
      "--mov",
      shQuote(parcels_mni),
      "--targ",
      shQuote(aseg_mgz),
      "--reg",
      shQuote(registration),
      "--interp",
      "nearest",
      "--o",
      shQuote(registered)
    ),
    verbose = max(0L, as.integer(verbose) - 1L)
  )

  aseg_nii <- tempfile(fileext = ".nii.gz")
  on.exit(unlink(aseg_nii), add = TRUE)
  run_cmd(
    paste("mri_convert", shQuote(aseg_mgz), shQuote(aseg_nii)),
    verbose = 0L
  )
  aseg_img <- RNifti::readNifti(aseg_nii)
  merged <- embed_labels_in_aseg(
    as.array(aseg_img),
    as.array(RNifti::readNifti(registered)),
    replace_labels
  )

  if (is.null(output_file)) {
    output_file <- tempfile(fileext = ".nii.gz")
  }
  RNifti::writeNifti(
    RNifti::asNifti(
      array(merged, dim = dim(aseg_img)),
      reference = aseg_img
    ),
    output_file,
    datatype = "int32"
  )

  combined <- build_anatomical_lut(merged, labels, id_offset = 0L, lut = lut)

  if (isTRUE(verbose) || (is.numeric(verbose) && verbose > 0)) {
    cli::cli_alert_success(
      "Embedded {length(labels)} parcel{?s} in {.val {target_subject}} aseg."
    )
  }
  invisible(list(volume = output_file, lut = combined))
}

#' Zero the replaced aseg structures and stamp non-zero parcels on top
#'
#' Pure array step of [prepare_subcortical_mni152()]: blanks the lumped aseg
#' structures the parcels subdivide, then writes the parcels wherever they are
#' non-zero, leaving the remaining aseg (cortex, white matter, cerebellum,
#' brain-stem, ventricles) as grey context.
#'
#' @param aseg Integer array of aseg labels.
#' @param parcels Integer array of parcel labels on the same grid.
#' @param replace_labels Integer aseg ids to blank before stamping.
#' @return An integer array of the merged volume.
#' @noRd
embed_labels_in_aseg <- function(aseg, parcels, replace_labels) {
  out <- as.integer(round(aseg))
  dim(out) <- dim(aseg)
  out[out %in% as.integer(replace_labels)] <- 0L
  p <- as.integer(round(parcels))
  hit <- p > 0L
  out[hit] <- p[hit]
  out
}
