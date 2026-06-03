# Anatomical coregistration helpers ----

#' Coregister an atlas volume to a FreeSurfer subject
#'
#' Computes a rigid-plus-scale registration from a volumetric atlas onto
#' a FreeSurfer subject's T1 grid (e.g. `cvs_avg35_inMNI152`) using
#' `mri_coreg`. The resulting LTA can be reused by `mri_vol2vol` to
#' resample the atlas (or any volume in the same source space) onto the
#' target's grid, which is the first step toward producing subcortical
#' atlases that show realistic brain-outline anatomical context in their
#' 2D slices.
#'
#' Both volumes are binarised (any non-zero voxel becomes brain) before
#' coregistration so that the alignment is driven by tissue extent rather
#' than label values. To skip the binarisation and align using raw
#' intensities, set `binarise = FALSE`.
#'
#' @param input_volume Path to the atlas volume to coregister, or an
#'   `RNifti` object.
#' @param target_subject FreeSurfer subject name to register to. Defaults
#'   to `"cvs_avg35_inMNI152"`, which is in MNI152 1mm space.
#' @param target_volume Name of the volume in the subject's `mri/`
#'   directory used as the registration target. Defaults to `"brain"`
#'   (i.e. `brain.mgz`).
#' @param output_lta Path to write the resulting LTA file. Defaults to a
#'   temporary file.
#' @param dof Degrees of freedom for `mri_coreg` (`6`, `9`, or `12`).
#'   Defaults to `12` (rigid + per-axis scale + shear).
#' @param binarise Logical. If `TRUE` (default), binarise both volumes
#'   before coregistration. Set to `FALSE` to register on raw intensities.
#' @param subjects_dir FreeSurfer `SUBJECTS_DIR`. Defaults to
#'   [freesurfer::fs_subj_dir()].
#' @template skip_existing
#' @template verbose
#'
#' @return Path to the LTA file (invisibly).
#' @export
#'
#' @seealso [project_volume_anatomical()],
#'   [prepare_subcortical_anatomical()]
#'
#' @examples
#' \dontrun{
#' lta <- coregister_volume(
#'   input_volume = "shen_2mm_268_parcellation.nii.gz",
#'   target_subject = "cvs_avg35_inMNI152"
#' )
#' }
coregister_volume <- function(
  input_volume,
  target_subject = "cvs_avg35_inMNI152",
  target_volume = "brain",
  output_lta = NULL,
  dof = 12,
  binarise = TRUE,
  subjects_dir = freesurfer::fs_subj_dir(),
  skip_existing = FALSE,
  verbose = get_verbose() # nolint: object_usage_linter
) {
  check_fs(abort = TRUE)
  rlang::check_installed("RNifti", reason = "to read NIfTI volumes")

  if (!dof %in% c(6, 9, 12)) {
    cli::cli_abort("{.arg dof} must be 6, 9, or 12; got {.val {dof}}.")
  }

  in_path <- resolve_volume_path(input_volume)
  target_dir <- file.path(subjects_dir, target_subject, "mri")
  ref_mgz <- file.path(target_dir, paste0(target_volume, ".mgz"))
  if (!file.exists(ref_mgz)) {
    cli::cli_abort(c(
      "Target volume not found: {.path {ref_mgz}}",
      "i" = "Check {.arg target_subject} and {.arg target_volume}."
    ))
  }

  if (is.null(output_lta)) {
    output_lta <- tempfile(fileext = ".lta")
  }

  if (skip_existing && file.exists(output_lta)) {
    if (verbose) {
      cli::cli_alert_info(
        "Reusing existing registration: {.path {output_lta}}"
      )
    }
    return(invisible(output_lta))
  }

  if (binarise) {
    mov <- write_brain_mask(in_path, fileext = ".nii.gz")
    ref <- write_brain_mask_from_mgz(ref_mgz, fileext = ".nii.gz")
    on.exit(unlink(c(mov, ref)), add = TRUE)
  } else {
    mov <- in_path
    ref <- ref_mgz
  }

  if (verbose) {
    cli::cli_alert_info(
      "Coregistering {.path {basename(in_path)}} to \\
       {.val {target_subject}} ({dof}-DOF)"
    )
  }

  cmd <- paste(
    "mri_coreg",
    "--mov",
    shQuote(mov),
    "--ref",
    shQuote(ref),
    "--reg",
    shQuote(output_lta),
    "--dof",
    dof
  )
  run_cmd(cmd, verbose = verbose)

  invisible(output_lta)
}


#' Project atlas labels onto FreeSurfer anatomical context
#'
#' For each label in an atlas volume, resamples a binary indicator with
#' trilinear interpolation onto the target FreeSurfer subject's
#' `aparc+aseg` grid, takes the argmax across labels at every voxel, and
#' returns a merged volume that combines the source `aparc+aseg`
#' (providing anatomical brain-outline context) with the user's atlas
#' labels (replacing `aparc+aseg` voxels wherever a label wins above
#' `threshold`).
#'
#' The merged volume is what
#' [create_subcortical_from_volume()]
#' needs to render 2D slices that show real brain outlines around the
#' atlas regions, instead of a generic shape.
#'
#' Atlas IDs that collide with FreeSurfer `aparc+aseg` labels (e.g. an
#' atlas where `11` means "Putamen" while FS uses `11` for "Caudate")
#' would cause the subcortical pipeline to extract leftover `aparc+aseg`
#' voxels of a different anatomical structure as if they belonged to the
#' user's region. To prevent this, the function shifts every input label
#' ID by `id_offset` (default `200`) when writing the merged volume, so
#' that the user's IDs sit in a range that doesn't overlap any
#' `aparc+aseg` label. The `lut` argument is shifted in the same way so
#' it matches the merged volume.
#'
#' @param input_volume Path to the atlas volume, or an `RNifti` object.
#' @param label_ids Integer vector of labels to project. Defaults to all
#'   non-zero labels in `input_volume`.
#' @param lut Optional colour LUT (data frame with at least an `idx`
#'   column, or path to a TSV with `idx, label, R, G, B, A`). If
#'   provided, returned alongside the volume with `idx` shifted by
#'   `id_offset` to match.
#' @param registration Path to an LTA file (typically from
#'   [coregister_volume()]). If `NULL`, `mri_vol2vol` falls back to
#'   `--regheader` and trusts the volume's xform.
#' @param target_subject FreeSurfer subject providing the anatomical grid
#'   and `aparc+aseg.mgz`. Defaults to `"cvs_avg35_inMNI152"`.
#' @param threshold Numeric in `[0, 1]`. Voxels whose argmax probability
#'   does not exceed this threshold are kept as the source `aparc+aseg`
#'   label. Defaults to `0.3`.
#' @param id_offset Integer added to every input label ID when writing
#'   the merged volume to avoid collisions with FreeSurfer `aparc+aseg`
#'   labels. Defaults to `200L`. Set to `0L` if you have already remapped
#'   your IDs (or if you've verified there are no collisions).
#' @param protect_cortex Logical. If `TRUE` (default), cortex voxels in
#'   `aparc+aseg` (aparc labels `1000-2999`, plus cortical white matter
#'   `2` and `41`) are never overwritten by user labels, even when argmax
#'   wins above `threshold`. This preserves the brain-outline geometry
#'   that the subcortical pipeline renders as context. Disable only if
#'   you intentionally want user labels to overwrite cortex.
#' @param output_file Path for the merged volume. Defaults to a temp file.
#' @param subjects_dir FreeSurfer `SUBJECTS_DIR`. Defaults to
#'   [freesurfer::fs_subj_dir()].
#' @template verbose
#'
#' @return If `lut` is `NULL`, the path to the merged anatomical-context
#'   volume (invisibly), with the `id_offset` used recorded as an
#'   attribute. If `lut` is supplied, a list with `output_file`, `lut`
#'   (the input LUT with `idx` shifted by `id_offset`), and `id_offset`.
#' @export
#'
#' @seealso [coregister_volume()], [prepare_subcortical_anatomical()]
#'
#' @examples
#' \dontrun{
#' lta <- coregister_volume("atlas.nii.gz")
#' merged <- project_volume_anatomical(
#'   "atlas.nii.gz",
#'   label_ids = c(11, 12, 13, 17, 18, 26),
#'   registration = lta
#' )
#' }
project_volume_anatomical <- function(
  input_volume,
  label_ids = NULL,
  lut = NULL,
  registration = NULL,
  target_subject = "cvs_avg35_inMNI152",
  threshold = 0.3,
  id_offset = 200L,
  protect_cortex = TRUE,
  output_file = NULL,
  subjects_dir = freesurfer::fs_subj_dir(),
  verbose = get_verbose() # nolint: object_usage_linter
) {
  check_fs(abort = TRUE)
  rlang::check_installed("RNifti", reason = "to read NIfTI volumes")

  if (!is.numeric(threshold) || threshold < 0 || threshold > 1) {
    cli::cli_abort(
      "{.arg threshold} must be in [0, 1]; got {.val {threshold}}."
    )
  }
  if (
    !is.numeric(id_offset) ||
      length(id_offset) != 1L ||
      id_offset != as.integer(id_offset) ||
      id_offset < 0
  ) {
    cli::cli_abort(
      "{.arg id_offset} must be a non-negative integer; \\
       got {.val {id_offset}}."
    )
  }
  id_offset <- as.integer(id_offset)

  in_path <- resolve_volume_path(input_volume)
  target_dir <- file.path(subjects_dir, target_subject, "mri")
  aparc_mgz <- file.path(target_dir, "aparc+aseg.mgz")
  if (!file.exists(aparc_mgz)) {
    cli::cli_abort(c(
      "aparc+aseg not found: {.path {aparc_mgz}}",
      "i" = "Provide a {.arg target_subject} that has cortical parcellation."
    ))
  }

  vol <- RNifti::readNifti(in_path)
  arr <- as.array(vol)

  if (is.null(label_ids)) {
    label_ids <- sort(unique(as.integer(arr[arr != 0])))
  }
  label_ids <- as.integer(label_ids)
  if (!length(label_ids)) {
    cli::cli_abort("No labels found in {.path {in_path}}.")
  }

  aparc_nii <- tempfile(fileext = ".nii.gz")
  on.exit(unlink(aparc_nii), add = TRUE)
  run_cmd(
    paste("mri_convert", shQuote(aparc_mgz), shQuote(aparc_nii)),
    verbose = 0L
  )
  aparc <- RNifti::readNifti(aparc_nii)
  arr_aparc <- as.array(aparc)
  storage.mode(arr_aparc) <- "integer"

  if (verbose) {
    cli::cli_alert_info(
      "Projecting {length(label_ids)} label{?s} onto \\
       {.val {target_subject}} aparc+aseg grid"
    )
  }

  prob_stack <- array(
    0,
    dim = c(prod(dim(arr_aparc)), length(label_ids))
  )
  for (i in seq_along(label_ids)) {
    id <- label_ids[i]
    mov_tmp <- tempfile(fileext = ".nii.gz")
    out_tmp <- tempfile(fileext = ".nii.gz")
    mask_arr <- (arr == id) * 1.0
    RNifti::writeNifti(RNifti::asNifti(mask_arr, reference = vol), mov_tmp)

    cmd <- paste(
      "mri_vol2vol",
      "--mov",
      shQuote(mov_tmp),
      "--targ",
      shQuote(aparc_mgz),
      if (is.null(registration)) {
        "--regheader"
      } else {
        paste(
          "--reg",
          shQuote(registration)
        )
      },
      "--interp",
      "trilin",
      "--o",
      shQuote(out_tmp)
    )
    run_cmd(cmd, verbose = max(0L, verbose - 1L))

    prob_stack[, i] <- as.numeric(as.array(RNifti::readNifti(out_tmp)))
    unlink(c(mov_tmp, out_tmp))
  }

  argmax_idx <- max.col(prob_stack, ties.method = "first")
  max_prob <- prob_stack[
    cbind(seq_len(nrow(prob_stack)), argmax_idx)
  ]
  keep <- max_prob > threshold

  if (protect_cortex) {
    arr_flat <- as.vector(arr_aparc)
    is_cortex <- arr_flat >= 1000 & arr_flat < 3000
    is_cortical_wm <- arr_flat %in% c(2L, 41L)
    keep <- keep & !is_cortex & !is_cortical_wm
    if (verbose) {
      cli::cli_alert_info(
        "Protected {sum(is_cortex)} cortex and \\
         {sum(is_cortical_wm)} cortical-WM voxels from overwrite."
      )
    }
  }

  shifted_ids <- label_ids + id_offset
  merged <- arr_aparc
  new_labels <- integer(length(merged))
  new_labels[keep] <- shifted_ids[argmax_idx[keep]]
  dim(new_labels) <- dim(merged)
  for (id in shifted_ids) {
    merged[new_labels == id] <- id
  }
  storage.mode(merged) <- "integer"

  if (is.null(output_file)) {
    output_file <- tempfile(fileext = ".nii.gz")
  }
  out_vol <- RNifti::asNifti(merged, reference = aparc)
  if (RNifti::orientation(out_vol) != "RAS") {
    RNifti::orientation(out_vol) <- "RAS"
  }
  RNifti::writeNifti(out_vol, output_file)

  if (verbose) {
    cli::cli_alert_success(
      "Wrote anatomical-context volume: {.path {output_file}} \\
       (id_offset = {id_offset})"
    )
  }

  if (is.null(lut)) {
    attr(output_file, "id_offset") <- id_offset
    return(invisible(output_file))
  }

  lut_df <- read_lut_arg(lut)
  lut_df$idx <- as.integer(lut_df$idx) + id_offset

  invisible(list(
    output_file = output_file,
    lut = lut_df,
    id_offset = id_offset
  ))
}


#' Prepare an atlas for the subcortical pipeline with anatomical context
#'
#' Convenience wrapper that runs [coregister_volume()] followed by
#' [project_volume_anatomical()] in one call, producing a merged volume
#' on a FreeSurfer subject's `aparc+aseg` grid that's ready to feed
#' [create_subcortical_from_volume()].
#'
#' @inheritParams coregister_volume
#' @inheritParams project_volume_anatomical
#'
#' @return Path to the merged anatomical-context volume (invisibly).
#' @export
#'
#' @examples
#' \dontrun{
#' merged <- prepare_subcortical_anatomical(
#'   input_volume = "shen_2mm_268_parcellation.nii.gz",
#'   label_ids = subcortical_ids
#' )
#' atlas <- create_subcortical_from_volume(
#'   input_volume = merged,
#'   input_lut = subcortical_lut
#' )
#' }
prepare_subcortical_anatomical <- function(
  input_volume,
  label_ids = NULL,
  lut = NULL,
  target_subject = "cvs_avg35_inMNI152",
  target_volume = "brain",
  threshold = 0.3,
  id_offset = 200L,
  protect_cortex = TRUE,
  dof = 12,
  output_file = NULL,
  output_lta = NULL,
  binarise = TRUE,
  subjects_dir = freesurfer::fs_subj_dir(),
  skip_existing = FALSE,
  verbose = get_verbose() # nolint: object_usage_linter
) {
  lta <- coregister_volume(
    input_volume = input_volume,
    target_subject = target_subject,
    target_volume = target_volume,
    output_lta = output_lta,
    dof = dof,
    binarise = binarise,
    subjects_dir = subjects_dir,
    skip_existing = skip_existing,
    verbose = verbose
  )

  project_volume_anatomical(
    input_volume = input_volume,
    label_ids = label_ids,
    lut = lut,
    registration = lta,
    target_subject = target_subject,
    threshold = threshold,
    id_offset = id_offset,
    protect_cortex = protect_cortex,
    output_file = output_file,
    subjects_dir = subjects_dir,
    verbose = verbose
  )
}


# Internal helpers ----

#' @noRd
resolve_volume_path <- function(x) {
  if (inherits(x, "niftiImage") || inherits(x, "internalImage")) {
    p <- tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(x, p)
    return(p)
  }
  if (!is.character(x) || length(x) != 1L) {
    cli::cli_abort(
      "{.arg input_volume} must be a path or an {.cls RNifti} object."
    )
  }
  if (!file.exists(x)) {
    cli::cli_abort("Volume not found: {.path {x}}")
  }
  x
}

#' @noRd
write_brain_mask <- function(volume_path, fileext = ".nii.gz") {
  v <- RNifti::readNifti(volume_path)
  m <- (as.array(v) > 0) * 1L
  storage.mode(m) <- "integer"
  out <- tempfile(fileext = fileext)
  RNifti::writeNifti(RNifti::asNifti(m, reference = v), out)
  out
}

#' @noRd
write_brain_mask_from_mgz <- function(mgz_path, fileext = ".nii.gz") {
  tmp_nii <- tempfile(fileext = ".nii.gz")
  on.exit(unlink(tmp_nii), add = TRUE)
  run_cmd(
    paste("mri_convert", shQuote(mgz_path), shQuote(tmp_nii)),
    verbose = 0L
  )
  write_brain_mask(tmp_nii, fileext = fileext)
}

#' @noRd
read_lut_arg <- function(x) {
  if (is.data.frame(x)) {
    if (!"idx" %in% names(x)) {
      cli::cli_abort("{.arg lut} data frame must have an {.field idx} column.")
    }
    return(x)
  }
  if (is.character(x) && length(x) == 1L) {
    if (!file.exists(x)) {
      cli::cli_abort("{.arg lut} file not found: {.path {x}}")
    }
    df <- utils::read.table(
      x,
      header = FALSE,
      sep = "\t",
      stringsAsFactors = FALSE
    )
    names(df) <- c(
      "idx",
      "label",
      "R",
      "G",
      "B",
      "A"
    )[seq_len(min(6, ncol(df)))]
    return(df)
  }
  cli::cli_abort(
    "{.arg lut} must be a data frame or path to a TSV file."
  )
}
