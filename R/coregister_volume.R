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
  target_dir <- as.character(fs::path(subjects_dir, target_subject, "mri"))
  ref_mgz <- as.character(fs::path(target_dir, paste0(target_volume, ".mgz")))
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
    return(coreg_reuse_lta(output_lta, verbose))
  }

  if (binarise) {
    mov <- write_brain_mask(in_path, fileext = ".nii.gz")
    ref <- write_brain_mask_from_mgz(ref_mgz, fileext = ".nii.gz")
    on.exit(unlink(c(mov, ref)), add = TRUE)
  } else {
    mov <- in_path
    ref <- ref_mgz
  }

  run_mri_coreg(mov, ref, output_lta, in_path, target_subject, dof, verbose)

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
#' @param lut Optional colour LUT (data frame with at least an `idx`
#'   column, or path to a TSV with `idx, label, R, G, B, A`). When
#'   provided, its `idx` (intersected with the volume) selects which labels
#'   to project, and it is returned alongside the volume with `idx` shifted
#'   by `id_offset` to match. With no `lut`, every non-zero label is
#'   projected. To project a subset, subset the `lut`.
#' @param registration Path to an LTA file (typically from
#'   [coregister_volume()]). If `NULL`, `mri_vol2vol` falls back to
#'   `--regheader` and trusts the volume's xform. The LTA must be registered
#'   to a volume on the same subject's conformed grid as `aparc+aseg.mgz`
#'   (true for any `recon-all` output); a mismatch is caught and aborted.
#' @param target_subject FreeSurfer subject providing the anatomical grid
#'   and `aparc+aseg.mgz`. Defaults to `"cvs_avg35_inMNI152"`.
#' @param threshold Numeric in `[0, 1]`. Voxels whose argmax probability
#'   does not exceed this threshold are kept as the source `aparc+aseg`
#'   label. Defaults to `0.3`.
#' @param id_offset Integer added to every input label ID when writing
#'   the merged volume to avoid collisions with FreeSurfer `aparc+aseg`
#'   labels. Defaults to `200L`. Set to `0L` if you have already remapped
#'   your IDs (or if you've verified there are no collisions).
#' @param protect_cortex Logical. If `TRUE` (default), the cerebral outline
#'   in `aparc+aseg` is never overwritten by user labels even when argmax
#'   wins above `threshold`: the cortical ribbon (aparc labels `1000-2999`)
#'   plus cerebral white matter (`2`, `41`) and the corpus callosum
#'   (`251-255`). This preserves the brain-outline geometry the subcortical
#'   pipeline renders as context. Cerebellar structures are not protected
#'   here (they are handled downstream by [aseg_context()]). Disable only if
#'   you intentionally want user labels to overwrite the cerebrum.
#' @param output_file Path for the merged volume. Defaults to a temp file.
#' @param subjects_dir FreeSurfer `SUBJECTS_DIR`. Defaults to
#'   [freesurfer::fs_subj_dir()].
#' @template verbose
#'
#' @return Invisibly, a list with three elements ready to feed
#'   [create_subcortical_from_volume()]:
#'   \describe{
#'     \item{`volume`}{Path to the merged anatomical-context volume.}
#'     \item{`lut`}{A colour table matching the merged volume one-to-one:
#'       FreeSurfer names for the surviving `aparc+aseg` context labels,
#'       plus the user's atlas labels with `idx` shifted by `id_offset`.
#'       When `lut` is `NULL`, the user labels get generic `region_XXXX`
#'       names and no colours.}
#'     \item{`id_offset`}{The offset applied to the user's label IDs.}
#'   }
#' @export
#'
#' @seealso [coregister_volume()], [prepare_subcortical_anatomical()]
#'
#' @examples
#' \dontrun{
#' lta <- coregister_volume("atlas.nii.gz")
#' merged <- project_volume_anatomical(
#'   "atlas.nii.gz",
#'   lut = my_lut,
#'   registration = lta
#' )
#' atlas <- create_subcortical_from_volume(merged)
#' }
project_volume_anatomical <- function(
  input_volume,
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

  validate_projection_args(threshold, id_offset)
  id_offset <- as.integer(id_offset)

  in_path <- resolve_volume_path(input_volume)
  target_dir <- as.character(fs::path(subjects_dir, target_subject, "mri"))
  aparc_mgz <- as.character(fs::path(target_dir, "aparc+aseg.mgz"))
  if (!file.exists(aparc_mgz)) {
    cli::cli_abort(c(
      "aparc+aseg not found: {.path {aparc_mgz}}",
      "i" = "Provide a {.arg target_subject} that has cortical parcellation."
    ))
  }

  aparc_nii <- tempfile(fileext = ".nii.gz")
  on.exit(unlink(aparc_nii), add = TRUE)

  prep <- project_load_volumes(in_path, lut, aparc_mgz, aparc_nii)

  check_registration_grid(registration, dim(prep$arr_aparc), dim(prep$arr))
  validate_offset_no_collision(prep$label_ids, id_offset)

  project_start_message(prep$label_ids, target_subject, verbose)

  merged <- project_merged_labels(
    prep,
    registration,
    threshold,
    protect_cortex,
    id_offset,
    verbose
  )

  invisible(project_finalize(merged, prep, output_file, id_offset, verbose))
}

#' Prepare an atlas for the subcortical pipeline with anatomical context
#'
#' Convenience wrapper that runs [coregister_volume()] followed by
#' [project_volume_anatomical()] in one call, producing a merged volume
#' on a FreeSurfer subject's `aparc+aseg` grid together with a matching
#' colour table, ready to feed [create_subcortical_from_volume()].
#'
#' @inheritParams coregister_volume
#' @inheritParams project_volume_anatomical
#'
#' @return Invisibly, the `list(volume, lut, id_offset)` returned by
#'   [project_volume_anatomical()]. Pass it straight to
#'   [create_subcortical_from_volume()], which unpacks `volume` and `lut`.
#' @export
#'
#' @examples
#' \dontrun{
#' merged <- prepare_subcortical_anatomical(
#'   input_volume = "shen_2mm_268_parcellation.nii.gz",
#'   lut = subcortical_lut
#' )
#' atlas <- create_subcortical_from_volume(
#'   input_volume = merged,
#'   context = list(focus = "my-structures")
#' )
#' }
prepare_subcortical_anatomical <- function(
  input_volume,
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


#' Report and return a cached registration
#' @noRd
coreg_reuse_lta <- function(output_lta, verbose) {
  if (verbose) {
    cli::cli_alert_info(
      "Reusing existing registration: {.path {output_lta}}"
    )
  }
  invisible(output_lta)
}


# nocov start
#' Run mri_coreg on the (optionally binarised) moving and reference volumes
#' @noRd
run_mri_coreg <- function(
  mov,
  ref,
  output_lta,
  in_path,
  target_subject,
  dof,
  verbose
) {
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
}
# nocov end

# nocov start
#' Read the atlas volume, its labels, and the target aparc+aseg grid
#' @noRd
project_load_volumes <- function(in_path, lut, aparc_mgz, aparc_nii) {
  vol <- RNifti::readNifti(in_path)
  arr <- as.array(vol)

  lut_df <- if (is.null(lut)) NULL else read_lut_arg(lut)
  label_ids <- resolve_label_ids(arr, in_path, lut_df)

  run_cmd(
    paste("mri_convert", shQuote(aparc_mgz), shQuote(aparc_nii)),
    verbose = 0L
  )
  aparc <- RNifti::readNifti(aparc_nii)
  arr_aparc <- as.array(aparc)
  storage.mode(arr_aparc) <- "integer"

  list(
    vol = vol,
    arr = arr,
    lut_df = lut_df,
    label_ids = label_ids,
    aparc_mgz = aparc_mgz,
    aparc = aparc,
    arr_aparc = arr_aparc
  )
}
# nocov end

#' Announce the projection about to run
#' @noRd
project_start_message <- function(label_ids, target_subject, verbose) {
  if (verbose) {
    cli::cli_alert_info(
      "Projecting {length(label_ids)} label{?s} onto \\
       {.val {target_subject}} aparc+aseg grid"
    )
  }
  invisible(NULL)
}


#' Argmax the resampled label probabilities into the aparc+aseg volume
#' @noRd
project_merged_labels <- function(
  prep,
  registration,
  threshold,
  protect_cortex,
  id_offset,
  verbose
) {
  am <- project_label_argmax(
    label_ids = prep$label_ids,
    arr = prep$arr,
    vol = prep$vol,
    aparc_mgz = prep$aparc_mgz,
    registration = registration,
    n_voxels = prod(dim(prep$arr_aparc)),
    verbose = verbose
  )

  argmax_idx <- am$argmax_idx
  keep <- am$max_prob > threshold

  kept_before <- keep
  keep <- apply_cortex_protection(keep, prep$arr_aparc, protect_cortex, verbose)
  warn_labels_lost_to_protection(
    kept_before,
    keep,
    argmax_idx,
    prep$label_ids,
    prep$lut_df
  )

  build_merged_volume(
    prep$arr_aparc,
    keep,
    argmax_idx,
    prep$label_ids,
    id_offset
  )
}


#' Write the merged volume and build the colour table that matches it
#' @noRd
project_finalize <- function(merged, prep, output_file, id_offset, verbose) {
  output_file <- write_merged_volume(merged, prep$aparc, output_file)

  combined_lut <- build_anatomical_lut(
    merged,
    prep$label_ids,
    id_offset,
    prep$lut_df
  )

  if (verbose) {
    cli::cli_alert_success(
      "Wrote anatomical-context volume: {.path {output_file}} \\
       (id_offset = {id_offset}, {nrow(combined_lut)} label{?s})"
    )
  }

  list(
    volume = output_file,
    lut = combined_lut,
    id_offset = id_offset
  )
}


# Internal helpers ----

#' @noRd
validate_threshold <- function(threshold) {
  if (!is.numeric(threshold) || threshold < 0 || threshold > 1) {
    cli::cli_abort(
      "{.arg threshold} must be in [0, 1]; got {.val {threshold}}."
    )
  }
  invisible(TRUE)
}

#' @noRd
validate_id_offset <- function(id_offset) {
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
  invisible(TRUE)
}

#' @noRd
validate_projection_args <- function(threshold, id_offset) {
  validate_threshold(threshold)
  validate_id_offset(id_offset)
  invisible(TRUE)
}

#' Abort when a shifted label ID collides with a protected FreeSurfer label
#'
#' `id_offset` exists to keep the user's label IDs clear of `aparc+aseg`
#' labels (see [project_volume_anatomical()]). If the shift still lands on
#' one of the reserved cerebral white-matter / corpus-callosum IDs, the
#' collision is invisible downstream: `build_anatomical_lut()` excludes any
#' FreeSurfer ID that matches a shifted user ID from its context table
#' before checking for duplicates, so the shared ID silently gets the
#' user's label name and colour, swallowing the FreeSurfer structure into
#' it wherever the two overlap.
#' @noRd
validate_offset_no_collision <- function(label_ids, id_offset) {
  shifted <- as.integer(label_ids) + id_offset
  reserved <- cerebral_white_matter_labels()
  collide <- shifted %in% reserved
  n <- sum(collide)
  if (n > 0L) {
    cli::cli_abort(c(
      "{.arg id_offset} = {id_offset} shifts {cli::qty(n)} label{?s} \\
       {.val {label_ids[collide]}} onto reserved FreeSurfer \\
       {cli::qty(n)} ID{?s} {.val {shifted[collide]}}.",
      "i" = "Choose an {.arg id_offset} that keeps shifted IDs clear of \\
             {.val {reserved}}."
    ))
  }
  invisible(TRUE)
}

#' Resolve which atlas labels to project
#'
#' The labels come from `lut`'s `idx` (the colour table is the source of
#' truth, as in the pre-projection builders), intersected with what's
#' actually in the volume. With no `lut`, every non-zero label is used.
#' @noRd
resolve_label_ids <- function(arr, in_path, lut = NULL) {
  vol_ids <- sort(unique(as.integer(arr[arr != 0])))

  if (is.null(lut)) {
    if (!length(vol_ids)) {
      cli::cli_abort("No labels found in {.path {in_path}}.")
    }
    return(vol_ids)
  }

  label_ids <- intersect(as.integer(lut$idx), vol_ids)
  if (!length(label_ids)) {
    cli::cli_abort(c(
      "None of the {nrow(lut)} {.arg lut} label{?s} are present in \\
       {.path {in_path}}.",
      "i" = "Check that {.arg lut} indices match the volume's labels."
    ))
  }
  label_ids
}

#' Per-voxel argmax of resampled label probabilities, computed by streaming
#'
#' Resampling every label into one `n_voxels x n_labels` matrix is fatal at
#' atlas scale (a 256^3 grid x 268 labels x 8 bytes is ~36 GB). Instead we
#' keep only the running winner: two `n_voxels` vectors updated one label at a
#' time, so peak memory is independent of the label count. Strict `>` makes
#' the first label win ties, matching `max.col(ties.method = "first")`;
#' voxels no label reaches keep `argmax_idx = 0` (never read, since `keep`
#' is false there).
#' @noRd
project_label_argmax <- function(
  label_ids,
  arr,
  vol,
  aparc_mgz,
  registration,
  n_voxels,
  verbose
) {
  max_prob <- numeric(n_voxels)
  argmax_idx <- integer(n_voxels)
  for (i in seq_along(label_ids)) {
    prob_i <- resample_label_probability(
      arr = arr,
      id = label_ids[i],
      vol = vol,
      aparc_mgz = aparc_mgz,
      registration = registration,
      verbose = verbose
    )
    win <- prob_i > max_prob
    max_prob[win] <- prob_i[win]
    argmax_idx[win] <- i
  }
  list(argmax_idx = argmax_idx, max_prob = max_prob)
}

#' Volume dims recorded under one `*** volume info` block of an LTA file
#'
#' Shared by `lta_dst_dims()` and `lta_src_dims()`: finds `block_label`,
#' then the first `volume = a b c` line after it. Returns an integer
#' length-3 vector, or `NULL` when the block isn't found (an unexpected LTA
#' layout), in which case the caller skips the check.
#' @noRd
lta_block_dims <- function(lines, block_label) {
  block_start <- grep(block_label, lines, fixed = TRUE)
  if (!length(block_start)) {
    return(NULL)
  }
  tail_lines <- lines[block_start[1]:length(lines)]
  vol_line <- grep("^\\s*volume\\s*=", tail_lines, value = TRUE)
  if (!length(vol_line)) {
    return(NULL)
  }
  nums <- suppressWarnings(as.integer(
    strsplit(trimws(sub(".*=", "", vol_line[1])), "\\s+")[[1]]
  ))
  if (length(nums) != 3L || anyNA(nums)) {
    return(NULL)
  }
  nums
}

#' Destination grid dimensions recorded in an LTA file
#'
#' `mri_coreg` stores the registration's destination ("dst") volume geometry
#' in the LTA. Reusing that LTA against `aparc+aseg.mgz` is only valid if the
#' two share a grid, so we read the dst `volume = a b c` dims to compare.
#' @noRd
lta_dst_dims <- function(lta_path) {
  lta_block_dims(readLines(lta_path, warn = FALSE), "dst volume info")
}

#' Source grid dimensions recorded in an LTA file
#'
#' `mri_coreg` also stores the registration's source ("src") volume
#' geometry — the volume the LTA was actually computed from. Comparing this
#' to `input_volume`'s own dims catches an LTA reused from a different atlas
#' or resolution, which `lta_dst_dims()` alone cannot: a destination-grid
#' match says nothing about whether the *source* side of the transform ever
#' corresponded to this `input_volume`.
#' @noRd
lta_src_dims <- function(lta_path) {
  lta_block_dims(readLines(lta_path, warn = FALSE), "src volume info")
}

#' Abort when a reused LTA doesn't match aparc+aseg or the input volume
#'
#' The LTA from [coregister_volume()] is registered from `input_volume` (the
#' "src") to the subject's `target_volume` (the "dst", e.g. `brain.mgz`);
#' reusing it in [project_volume_anatomical()] assumes the dst sits on that
#' subject's conformed grid (true for `recon-all` output) *and* that the src
#' still matches the `input_volume` being projected now. Checking only the
#' destination misses the real footgun of reusing an LTA computed for a
#' different atlas or resolution, which resamples silently onto the wrong
#' voxels without ever erroring.
#' @noRd
check_registration_grid <- function(registration, aparc_dim, input_dim = NULL) {
  if (is.null(registration)) {
    return(invisible(NULL))
  }

  dst_dim <- lta_dst_dims(registration)
  aparc_dim <- as.integer(aparc_dim[1:3])
  if (!is.null(dst_dim) && !identical(dst_dim, aparc_dim)) {
    cli::cli_abort(c(
      "Registration grid does not match the {.file aparc+aseg.mgz} grid.",
      "x" = "LTA destination is {dst_dim[1]}x{dst_dim[2]}x{dst_dim[3]}, \\
             aparc+aseg is {aparc_dim[1]}x{aparc_dim[2]}x{aparc_dim[3]}.",
      "i" = "Reuse an LTA registered to the same {.arg target_subject} on its \\
             conformed grid; re-run {.fn coregister_volume} if unsure."
    ))
  }

  if (!is.null(input_dim)) {
    src_dim <- lta_src_dims(registration)
    input_dim <- as.integer(input_dim[1:3])
    if (!is.null(src_dim) && !identical(src_dim, input_dim)) {
      cli::cli_abort(c(
        "Registration grid does not match {.arg input_volume}.",
        "x" = "LTA source is {src_dim[1]}x{src_dim[2]}x{src_dim[3]}, \\
               {.arg input_volume} is \\
               {input_dim[1]}x{input_dim[2]}x{input_dim[3]}.",
        "i" = "Reuse the LTA {.fn coregister_volume} produced for this exact \\
               {.arg input_volume}; re-run it if unsure."
      ))
    }
  }
  invisible(NULL)
}

# nocov start
#' Resample one label's binary mask onto the aparc+aseg grid (trilinear)
#' @noRd
resample_label_probability <- function(
  arr,
  id,
  vol,
  aparc_mgz,
  registration,
  verbose
) {
  mov_tmp <- tempfile(fileext = ".nii.gz")
  out_tmp <- tempfile(fileext = ".nii.gz")
  on.exit(unlink(c(mov_tmp, out_tmp)), add = TRUE)

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

  as.numeric(as.array(RNifti::readNifti(out_tmp)))
}
# nocov end

#' FreeSurfer `aparc+aseg` cerebral white-matter labels
#'
#' Cerebral hemispheric white matter (`2`, `41`) plus the corpus callosum
#' (`251:255`) — the interhemispheric commissure is cerebral white matter and
#' sits directly against the deep-gray nuclei a subcortical atlas targets, so
#' it shares their protection. Cerebellar white matter (`7`, `46`) is
#' deliberately excluded: it belongs to a different structure, not the
#' cerebral outline this guard preserves, and is handled downstream by
#' [aseg_context()] / [aseg_hidden_labels()].
#' @noRd
cerebral_white_matter_labels <- function() {
  c(2L, 41L, 251L, 252L, 253L, 254L, 255L)
}

#' @noRd
apply_cortex_protection <- function(keep, arr_aparc, protect_cortex, verbose) {
  if (!protect_cortex) {
    return(keep)
  }
  arr_flat <- as.vector(arr_aparc)
  # Standard aparc+aseg (DKT) cortical ribbon labels span 1000-2999.
  is_cortex <- arr_flat >= 1000 & arr_flat < 3000
  is_cerebral_wm <- arr_flat %in% cerebral_white_matter_labels()
  keep <- keep & !is_cortex & !is_cerebral_wm
  if (verbose) {
    cli::cli_alert_info(
      "Protected {sum(is_cortex)} cortex and \\
       {sum(is_cerebral_wm)} cerebral-WM voxels from overwrite."
    )
  }
  keep
}

#' Warn about labels that cortex protection removed entirely
#'
#' `protect_cortex` blocks the atlas from overwriting the cortical ribbon and
#' cerebral white matter. That is right for deep grey structures, but a
#' white-matter atlas lives in exactly the tissue being protected, and a label
#' can be erased down to nothing without any sign that it happened -- JHU's
#' ICBM-DTI-81 shipped for a release with its right superior longitudinal
#' fasciculus silently missing. Losing a whole structure is worth a warning
#' even when the guard is doing what it was asked to.
#' @noRd
warn_labels_lost_to_protection <- function(
  kept_before,
  kept_after,
  argmax_idx,
  label_ids,
  lut_df
) {
  if (identical(kept_before, kept_after)) {
    return(invisible(NULL))
  }

  # argmax_idx indexes into label_ids, and is NA wherever no label won the
  # voxel, so those have to go before they index label_ids as NA.
  had <- unique(argmax_idx[kept_before])
  left <- unique(argmax_idx[kept_after])
  lost <- setdiff(had[!is.na(had)], left[!is.na(left)])
  if (!length(lost)) {
    return(invisible(NULL))
  }

  lost_ids <- label_ids[lost]
  # Used in the cli glue string below, which lintr does not parse.
  # nolint next: object_usage_linter.
  names_lost <- if (is.null(lut_df)) {
    as.character(lost_ids)
  } else {
    matched <- lut_df$label[match(lost_ids, lut_df$idx)]
    ifelse(is.na(matched), as.character(lost_ids), matched)
  }

  cli::cli_warn(c(
    "{length(lost_ids)} label{?s} removed entirely by cortex protection: \\
     {.val {names_lost}}",
    "i" = "Set {.code protect_cortex = FALSE} if the atlas describes cortex \\
           or cerebral white matter."
  ))
  invisible(NULL)
}


#' @noRd
build_merged_volume <- function(
  arr_aparc,
  keep,
  argmax_idx,
  label_ids,
  id_offset
) {
  shifted_ids <- as.integer(label_ids) + id_offset
  merged <- arr_aparc
  merged[keep] <- shifted_ids[argmax_idx[keep]]
  storage.mode(merged) <- "integer"
  merged
}

#' @noRd
write_merged_volume <- function(merged, aparc, output_file) {
  if (is.null(output_file)) {
    output_file <- tempfile(fileext = ".nii.gz")
  }
  out_vol <- RNifti::asNifti(merged, reference = aparc)
  if (RNifti::orientation(out_vol) != "RAS") {
    RNifti::orientation(out_vol) <- "RAS"
  }
  RNifti::writeNifti(out_vol, output_file)
  output_file
}

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

# nocov start
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
# nocov end

#' Read the FreeSurfer colour table that names aparc+aseg context labels
#' @noRd
read_fs_color_lut <- function() {
  fs_home <- freesurfer::fs_dir()
  lut_path <- as.character(fs::path(fs_home, "FreeSurferColorLUT.txt"))
  if (!nzchar(fs_home) || !file.exists(lut_path)) {
    cli::cli_abort(c(
      "FreeSurfer colour table not found: {.path {lut_path}}",
      "i" = "Ensure {.envvar FREESURFER_HOME} points at a FreeSurfer install."
    ))
  }
  ctab <- read_lut(lut_path)
  ctab$type <- NULL
  ctab
}

#' Resolve the user-supplied atlas labels into a shifted colour table
#'
#' Returns colour-table rows for the projected labels with `idx` shifted by
#' `id_offset` so they line up with the merged volume. When no `lut` is
#' given, generic `region_XXXX` names are generated with no colours.
#' @noRd
resolve_user_lut <- function(lut, label_ids, id_offset) {
  label_ids <- as.integer(label_ids)
  shifted_ids <- label_ids + id_offset

  if (is.null(lut)) {
    return(data.frame(
      idx = shifted_ids,
      label = sprintf("region_%04d", label_ids),
      R = NA_integer_,
      G = NA_integer_,
      B = NA_integer_,
      A = 0L,
      stringsAsFactors = FALSE
    ))
  }

  tbl <- read_lut_arg(lut)
  if (!is_lut(tbl)) {
    cli::cli_abort(c(
      "{.arg lut} must be a colour table with columns idx, label, R, G, B, A.",
      "i" = "See {.fn is_lut}."
    ))
  }
  tbl <- tbl[as.integer(tbl$idx) %in% label_ids, , drop = FALSE]
  tbl$idx <- as.integer(tbl$idx) + id_offset
  tbl
}

#' Build the colour table that matches a merged anatomical-context volume
#'
#' Combines the FreeSurfer colour names for the aparc+aseg context labels
#' surviving in `merged` with the user's atlas labels shifted by
#' `id_offset`, trimmed to the labels actually present. The result lines up
#' one-to-one with the merged volume so it can be passed straight to
#' [create_subcortical_from_volume()].
#' @noRd
build_anatomical_lut <- function(merged, label_ids, id_offset, lut) {
  shifted_ids <- as.integer(label_ids) + id_offset
  present <- sort(unique(as.integer(merged)))
  present <- present[present != 0L]
  context_ids <- setdiff(present, shifted_ids)

  context_lut <- read_fs_color_lut()
  context_lut <- context_lut[context_lut$idx %in% context_ids, , drop = FALSE]

  user_tbl <- resolve_user_lut(lut, label_ids, id_offset)

  out <- lut_combine(context_lut, user_tbl)
  out <- out[out$idx %in% present, , drop = FALSE]
  rownames(out) <- NULL
  out
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
