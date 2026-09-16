# Anatomy-based label classification ----

#' `aseg` label ids that make up cortical grey matter
#'
#' The undivided `Left-/Right-Cerebral-Cortex` ids, which is what a subject
#' with no parcellation falls back to. The `aparc` parcels are a range rather
#' than a list, and live in `cortical_parcel_range()`.
#' @noRd
cortical_grey_idx <- function() {
  c(3L, 42L)
}


#' Range of `aparc` cortical parcel ids
#'
#' `aparc+aseg` numbers the cortical parcels 1000-1035 on the left and
#' 2000-2035 on the right. The upper bound matters: `wmparc` carries white
#' matter at 3000-4035 and unsegmented white matter at 5001/5002, and none of
#' that is cortex.
#' @noRd
cortical_parcel_range <- function() {
  c(1000L, 2999L)
}


#' `aseg` label ids that make up deep (subcortical) grey matter
#'
#' Thalamus, caudate, putamen, pallidum, hippocampus, amygdala, accumbens and
#' ventral DC, per hemisphere. The ventricles are deliberately absent: they
#' are CSF, not grey matter, and counting them inflates the deep-grey share of
#' every parcel that borders a ventricle.
#' @noRd
subcortical_grey_idx <- function() {
  c(
    10L,
    11L,
    12L,
    13L,
    17L,
    18L,
    26L,
    28L,
    49L,
    50L,
    51L,
    52L,
    53L,
    54L,
    58L,
    60L
  )
}


#' `aseg` label ids that make up cerebellar grey matter
#'
#' Cerebellar cortex only. The cerebellar white matter ids (7, 46) are
#' excluded for the same reason the cerebral white matter is: the predicate
#' compares grey against grey.
#' @noRd
cerebellar_grey_idx <- function() {
  c(8L, 47L)
}


#' `aseg` label id for the brainstem
#' @noRd
brainstem_idx <- function() {
  16L
}


#' Every `aseg` label id this predicate counts as grey matter
#' @noRd
grey_matter_idx <- function() {
  c(
    cortical_grey_idx(),
    subcortical_grey_idx(),
    cerebellar_grey_idx(),
    brainstem_idx()
  )
}


#' Tissue composition of every label in a volume, from FreeSurfer's `aparc+aseg`
#'
#' Resamples `aparc+aseg` onto the atlas volume's own grid and measures, for
#' each label, the fraction of its voxels that fall on cortical, deep,
#' cerebellar and brainstem grey matter. This is an anatomical measurement:
#' it reads where a label sits, not how large it is.
#'
#' Returns `NULL`, with a warning, whenever the composition cannot be
#' trusted - FreeSurfer missing, the subject's `aparc+aseg` missing, the
#' resampling failing, a grid mismatch, or grey matter that does not land
#' inside the volume's own brain, which is what a volume in some other space
#' looks like.
#'
#' @param volume Path to the labelled atlas volume.
#' @param lut Data frame with `idx` and `label` columns naming the volume's
#'   labels.
#' @param subject FreeSurfer subject to take the `aparc+aseg` from.
#' @template verbose
#' @return Data frame with `idx`, `label`, `cortex`, `subcortex`,
#'   `cerebellum` and `brainstem` columns, or `NULL`.
#' @noRd
label_composition <- function(
  volume,
  lut,
  subject = "cvs_avg35_inMNI152",
  verbose = get_verbose()
) {
  source_file <- aparc_aseg_path(subject)
  if (is.null(source_file)) {
    return(NULL)
  }

  parcellation <- read_label_volume(volume)
  if (is.null(parcellation)) {
    return(NULL)
  }

  aseg <- aparc_aseg_on_grid(
    source_file,
    volume,
    dim(parcellation),
    parcellation > 0L,
    verbose
  )
  if (is.null(aseg)) {
    return(NULL)
  }

  label_ids <- intersect(lut$idx, sort(unique(parcellation[parcellation > 0L])))
  if (length(label_ids) == 0L) {
    warn_anatomy_unavailable("no lookup-table label has any voxel")
    return(NULL)
  }

  data.frame(
    idx = label_ids,
    label = lut$label[match(label_ids, lut$idx)],
    tissue_fractions(parcellation, aseg, label_ids),
    stringsAsFactors = FALSE
  )
}


#' Fraction of each label's voxels on each kind of grey matter
#'
#' Crosstabulated in a single pass over the voxels, rather than once per
#' label: a fine parcellation has hundreds of labels and a millimetre grid
#' has millions of voxels.
#' @noRd
tissue_fractions <- function(parcellation, aseg, label_ids) {
  keep <- parcellation %in% label_ids
  counts <- table(
    factor(parcellation[keep], levels = label_ids),
    tissue_class(aseg[keep])
  )
  fractions <- as.data.frame.matrix(counts / rowSums(counts))
  fractions[, c("cortex", "subcortex", "cerebellum", "brainstem")]
}


#' Which kind of grey matter, if any, each `aseg` value is
#' @noRd
tissue_class <- function(hit) {
  parcels <- cortical_parcel_range()
  class <- rep("other", length(hit))
  class[
    (hit >= parcels[1] & hit <= parcels[2]) | hit %in% cortical_grey_idx()
  ] <- "cortex"
  class[hit %in% subcortical_grey_idx()] <- "subcortex"
  class[hit %in% cerebellar_grey_idx()] <- "cerebellum"
  class[hit == brainstem_idx()] <- "brainstem"
  factor(
    class,
    levels = c("cortex", "subcortex", "cerebellum", "brainstem", "other")
  )
}


#' Classify labels from their `aparc+aseg` composition
#'
#' Each label is judged on the share of the *labelled grey matter* it touches,
#' ignoring white matter and voxels `aparc+aseg` does not label at all. That
#' normalisation is what makes the test independent of parcel size: a volume
#' drawn on EPI data reaches past the edge of FreeSurfer's brain, so a
#' superficial parcel can be two-thirds unlabelled and still unambiguously
#' cortical in the grey it does touch.
#'
#' Cerebellum is separated first, because a label straddling the tentorium
#' reads as part cortical.
#'
#' @param composition Data frame from `label_composition()`.
#' @param min_cortical Minimum cortical share of labelled grey for a label to
#'   be cortical.
#' @param min_cerebellar Minimum cerebellar share of labelled grey for a label
#'   to be cerebellar.
#' @param min_fraction Minimum raw fraction of a label's voxels on the
#'   winning tissue, whatever the share.
#' @return Named list of `cortical`, `subcortical` and `cerebellar` label
#'   character vectors.
#' @noRd
classify_labels_by_anatomy <- function(
  composition,
  min_cortical = 0.6,
  min_cerebellar = 0.5,
  min_fraction = 0.05
) {
  grey <- composition$cortex +
    composition$subcortex +
    composition$cerebellum +
    composition$brainstem
  share <- function(x) ifelse(grey > 0, x / grey, 0)

  # A stray voxel or two of the winning tissue should not decide a label that
  # is otherwise unlabelled, hence the floor on the raw fraction as well as
  # the share.
  is_cerebellar <- share(composition$cerebellum) >= min_cerebellar &
    composition$cerebellum >= min_fraction &
    composition$cerebellum >= composition$cortex &
    composition$cerebellum >= composition$subcortex
  is_cortical <- !is_cerebellar &
    share(composition$cortex) >= min_cortical &
    composition$cortex >= min_fraction

  list(
    cortical = composition$label[is_cortical],
    subcortical = composition$label[!is_cortical & !is_cerebellar],
    cerebellar = composition$label[is_cerebellar]
  )
}


#' Resample `aparc+aseg` onto a volume's own grid, or `NULL`
#'
#' `mri_vol2vol --regheader` resamples through the two headers, so no new
#' transform is invented: the atlas volume is taken to be in the space its
#' header claims, exactly as the rest of the pipeline takes it. Nearest
#' neighbour keeps the label values intact.
#'
#' @param source_file Path to the subject's `aparc+aseg.mgz`.
#' @param volume Path to the atlas volume, used as the target grid.
#' @param dims Expected dimensions of the resampled volume.
#' @param brain_mask Logical array, `TRUE` wherever the volume is non-zero.
#' @template verbose
#' @return Integer array of `aseg` label values, or `NULL`.
#' @noRd
aparc_aseg_on_grid <- function(
  source_file,
  volume,
  dims,
  brain_mask,
  verbose
) {
  resampled <- resample_volume_to_grid(source_file, volume, verbose)
  if (is.null(resampled)) {
    return(NULL)
  }
  on.exit(unlink(resampled), add = TRUE)

  aseg <- read_label_volume(resampled)
  if (is.null(aseg)) {
    return(NULL)
  }
  if (!identical(dim(aseg), dims)) {
    warn_anatomy_unavailable(
      "the resampled {.field aparc+aseg} does not share the volume's grid"
    )
    return(NULL)
  }

  if (!grey_lands_on_volume(aseg, brain_mask)) {
    return(NULL)
  }
  aseg
}


#' Locate a subject's `aparc+aseg.mgz`, or `NULL` when it cannot be used
#' @noRd
aparc_aseg_path <- function(subject) {
  if (!rlang::is_installed("freesurfer") || !isTRUE(have_fs_quietly())) {
    warn_anatomy_unavailable("FreeSurfer is not available")
    return(NULL)
  }

  aseg <- as.character(fs::path(
    freesurfer::fs_subj_dir(),
    subject,
    "mri",
    "aparc+aseg.mgz"
  ))
  if (!file.exists(aseg)) {
    warn_anatomy_unavailable("{.path {aseg}} does not exist")
    return(NULL)
  }
  aseg
}


#' Read a labelled volume as an integer array, or `NULL` when unreadable
#'
#' Anatomical classification is an improvement on a fallback that always
#' works, so an unreadable volume has to degrade into that fallback rather
#' than break the pipeline.
#' @noRd
read_label_volume <- function(file) {
  arr <- tryCatch(
    as.array(read_volume(file, reorient = FALSE)),
    # RNifti warns before it errors on a truncated header, so a warning here
    # means the same thing an error does: no usable volume came back.
    error = function(e) NULL,
    warning = function(w) NULL
  )
  if (is.null(arr) || length(dim(arr)) != 3L) {
    warn_anatomy_unavailable("{.path {file}} is not a readable 3D volume")
    return(NULL)
  }
  storage.mode(arr) <- "integer"
  arr
}


#' `freesurfer::have_fs()` without letting its failures escape
#' @noRd
have_fs_quietly <- function() {
  tryCatch(freesurfer::have_fs(), error = function(e) FALSE)
}


#' Run `mri_vol2vol --regheader --nearest`, or `NULL` on failure
#' @noRd
resample_volume_to_grid <- function(source_file, target, verbose) {
  out_file <- tempfile(fileext = paste0(".", volume_ext(target)))
  cmd <- paste(
    "mri_vol2vol",
    "--mov",
    shQuote(source_file),
    "--targ",
    shQuote(target),
    "--regheader",
    "--nearest",
    "--o",
    shQuote(out_file)
  )
  ok <- tryCatch(
    {
      run_cmd(cmd, verbose = max(0L, as.integer(verbose) - 1L))
      file.exists(out_file)
    },
    error = function(e) FALSE
  )
  if (!ok) {
    unlink(out_file)
    warn_anatomy_unavailable("{.code mri_vol2vol} failed")
    return(NULL)
  }
  out_file
}


#' Is the resampled grey matter actually sitting on this volume's brain?
#'
#' A volume in a space its header does not describe still resamples without
#' error; the grey matter simply lands somewhere else. Requiring most of it
#' to fall on non-zero voxels catches that, and catches an empty result.
#' @noRd
grey_lands_on_volume <- function(aseg, brain_mask, min_overlap = 0.5) {
  parcels <- cortical_parcel_range()
  inside <- (aseg >= parcels[1] & aseg <= parcels[2]) |
    aseg %in% grey_matter_idx()
  n <- sum(inside)
  if (n == 0L) {
    warn_anatomy_unavailable(
      "the resampled {.field aparc+aseg} has no grey matter"
    )
    return(FALSE)
  }

  overlap <- sum(inside & brain_mask) / n
  if (overlap < min_overlap) {
    # nolint next: object_usage_linter.
    pct <- round(100 * overlap)
    warn_anatomy_unavailable(
      "only {pct}% of the {.field aparc+aseg} grey matter lands inside the
      volume, so the two are not in the same space"
    )
    return(FALSE)
  }
  TRUE
}


#' Warn that anatomical classification is unavailable
#' @noRd
warn_anatomy_unavailable <- function(reason, .envir = parent.frame()) {
  # nolint next: object_usage_linter.
  detail <- cli::format_inline(reason, .envir = .envir)
  cli::cli_warn(
    c(
      "Cannot classify labels by anatomy: {detail}.",
      "i" = "Falling back to the surface vertex count, which measures label
      area rather than depth."
    ),
    wrap = TRUE
  )
  invisible(NULL)
}
