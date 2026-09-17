# Anatomy-based label classification ----

#' Classify lookup-table labels as cortical, subcortical, or cerebellar
#'
#' Fills in a lookup table's `type` column by reading where each label sits
#' in FreeSurfer's `aparc+aseg`, rather than by matching label names. This is
#' an authoring tool: run it once while building an atlas, write the `type`
#' column it returns into the lookup table, and commit that. A declared
#' classification is reviewable in a diff and reproducible without
#' FreeSurfer; the vertex-count fallback in
#' [create_wholebrain_from_volume()] is neither.
#'
#' `aparc+aseg` is resampled onto the volume's own grid with
#' `mri_vol2vol --regheader --nearest`, which goes through the two headers
#' and invents no transform. Each label is then judged on the share of the
#' *labelled grey matter* it touches - cortical ribbon, deep grey,
#' cerebellar cortex or brainstem - ignoring white matter and the voxels
#' `aparc+aseg` does not label at all. That normalisation is what makes the
#' test independent of a label's size: a volume clustered on EPI data
#' reaches past the edge of FreeSurfer's brain, so a superficial parcel can
#' be mostly unlabelled and still unambiguously cortical in the grey it does
#' touch.
#'
#' Cerebellum is separated first, because a label straddling the tentorium
#' reads as part cortical. A label that touches no labelled grey matter at
#' all, and one whose winning tissue is under `min_fraction` of its own
#' voxels, are both called subcortical: the share alone would let a single
#' stray ribbon voxel decide an otherwise unlabelled label.
#'
#' @param volume Path to the labelled atlas volume (`.nii`, `.nii.gz` or
#'   `.mgz`), in the space its header claims.
#' @param lut A lookup table: a path to a LUT file, or a data.frame with
#'   `idx` and `label` columns. Any existing `type` column is replaced.
#' @param subject FreeSurfer subject to take the `aparc+aseg` from. The
#'   default sits in MNI152 space, which is where most published
#'   parcellations are distributed.
#' @param min_cortical Minimum share of a label's labelled grey matter that
#'   must be cortical ribbon for the label to be called cortical.
#' @param min_cerebellar Minimum share of a label's labelled grey matter
#'   that must be cerebellar cortex for the label to be called cerebellar.
#' @param min_fraction Minimum share of a label's *own voxels* that must sit
#'   on the winning tissue, whatever the grey-matter share says. This is what
#'   stops one ribbon voxel from making a white-matter label cortical.
#' @template verbose
#'
#' @return The lookup table as a data.frame, with a `type` column of
#'   `"cortical"`, `"subcortical"` or `"cerebellar"`. Labels the volume does
#'   not carry are typed `"subcortical"`, matching how
#'   [create_wholebrain_from_volume()] treats a label that never reaches the
#'   surface, and warned about. The background label `idx = 0` is left
#'   `NA`.
#'
#' @seealso [create_wholebrain_from_volume()], which consumes the `type`
#'   column; [read_lut()] and [write_lut()] to read and write the table.
#' @export
#' @examples
#' \dontrun{
#' # Authoring an atlas: classify once, then commit the column.
#' lut <- read_lut("julich_LUT.txt")
#' lut <- lut_classify_anatomy("julich_mpm.nii.gz", lut)
#' table(lut$type)
#' write_lut(lut, "julich_LUT.txt")
#'
#' # create_wholebrain_from_volume() then reads the column instead of
#' # falling back to counting surface vertices.
#' create_wholebrain_from_volume(
#'   input_volume = "julich_mpm.nii.gz",
#'   input_lut = "julich_LUT.txt"
#' )
#' }
lut_classify_anatomy <- function(
  volume,
  lut,
  subject = "cvs_avg35_inMNI152",
  min_cortical = 0.6,
  min_cerebellar = 0.5,
  min_fraction = 0.05,
  verbose = get_verbose()
) {
  lut <- as_classifiable_lut(lut)
  verbose <- as_verbosity(verbose)
  check_share(min_cortical, "min_cortical")
  check_share(min_cerebellar, "min_cerebellar")
  check_share(min_fraction, "min_fraction")
  if (!file.exists(volume)) {
    cli::cli_abort("Volume file not found: {.path {volume}}")
  }

  composition <- label_composition(volume, lut, subject, verbose)
  verdict <- classify_labels_by_anatomy(
    composition,
    min_cortical = min_cortical,
    min_cerebellar = min_cerebellar,
    min_fraction = min_fraction
  )

  lut$type <- lut_type_column(lut, composition$idx, verdict)
  warn_absent_labels(lut, composition$idx)
  if (verbose > 0L) {
    report_anatomy_split(lut$type)
  }
  lut
}


#' Is this one number between 0 and 1?
#' @noRd
is_share <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x) && x >= 0 && x <= 1
}


#' A threshold has to be one number between 0 and 1
#' @noRd
check_share <- function(x, arg) {
  if (!is_share(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a single number between 0 and 1, not {.val {x}}"
    )
  }
  invisible(x)
}


#' Accept a LUT as a path or a data.frame, or abort
#' @noRd
as_classifiable_lut <- function(lut) {
  if (is.character(lut) && length(lut) == 1L) {
    lut <- read_lut(lut)
  }
  if (!is.data.frame(lut) || !all(c("idx", "label") %in% names(lut))) {
    cli::cli_abort(c(
      "{.arg lut} must be a LUT file path or a data.frame",
      "i" = "A data.frame needs at least {.field idx} and {.field label}
      columns."
    ))
  }
  if (nrow(lut) == 0L) {
    cli::cli_abort("{.arg lut} has no rows to classify")
  }
  # Every verdict is computed per index and written back per row, so a
  # repeated index or name would hand one label's anatomy to another.
  check_lut_unique(lut$idx, "idx")
  check_lut_unique(lut$label, "label")
  lut
}


#' A LUT column that identifies rows cannot repeat itself
#' @noRd
check_lut_unique <- function(values, column) {
  duplicated_values <- unique(values[duplicated(values)])
  if (length(duplicated_values) > 0) {
    cli::cli_abort(c(
      "{.arg lut} has {length(duplicated_values)} repeated
      {.field {column}} value{?s}",
      "x" = "Repeated: {.val {duplicated_values}}",
      "i" = "Each row must name a distinct label, or one label's anatomy
      would be written onto another."
    ))
  }
  invisible(values)
}


#' The `type` value for every row of the lookup table
#'
#' Keyed on `idx`, which is what the composition was measured per. A label
#' the volume does not carry has no composition to judge, so it takes the
#' same verdict `create_wholebrain_from_volume()` gives a label that never
#' reaches the surface.
#' @noRd
lut_type_column <- function(lut, classified_idx, verdict) {
  type <- rep("subcortical", nrow(lut))
  row <- match(lut$idx, classified_idx)
  type[!is.na(row)] <- verdict[row[!is.na(row)]]
  # Index 0 is the background, not a structure; it has no anatomy and the
  # pipeline never asks about it.
  type[lut$idx == 0L] <- NA_character_
  type
}


#' Warn about lookup-table labels the volume does not carry
#' @noRd
warn_absent_labels <- function(lut, classified_idx) {
  absent <- setdiff(lut$idx[lut$idx != 0L], classified_idx)
  if (length(absent) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_warn(c(
    "{length(absent)} label{?s} {?is/are} not in the volume, and {?is/are}
    typed {.val subcortical}.",
    "i" = "Absent: {.val {lut$label[match(absent, lut$idx)]}}"
  ))
  invisible(NULL)
}


#' Report the classification split
#' @noRd
report_anatomy_split <- function(type) {
  # nolint next: object_usage_linter.
  counts <- table(factor(
    type[!is.na(type)],
    levels = c("cortical", "subcortical", "cerebellar")
  ))
  cli::cli_alert_info(
    "{counts[['cortical']]} cortical, {counts[['subcortical']]} subcortical,
    {counts[['cerebellar']]} cerebellar labels",
    wrap = TRUE
  )
  invisible(NULL)
}


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
#' that is cortex. The range is specific to `aparc+aseg`; the Destrieux
#' `aparc.a2009s+aseg` numbers its parcels from 11100 and would need its own.
#' @noRd
cortical_parcel_range <- function() {
  c(1000L, 2999L)
}


#' `aseg` label ids that make up deep (subcortical) grey matter
#'
#' Thalamus, caudate, putamen, pallidum, hippocampus, amygdala, accumbens and
#' ventral DC, per hemisphere. The ventricles are deliberately absent: they
#' are CSF, not grey matter, and counting them inflates the deep-grey share of
#' every label that borders a ventricle.
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
#' cerebellar and brainstem grey matter.
#'
#' Aborts whenever the composition cannot be trusted - FreeSurfer missing,
#' the subject's `aparc+aseg` missing, the resampling failing, a grid
#' mismatch, or grey matter that does not land inside the volume's own brain,
#' which is what a volume in some other space looks like.
#'
#' @param volume Path to the labelled atlas volume.
#' @param lut Data frame with `idx` and `label` columns.
#' @param subject FreeSurfer subject to take the `aparc+aseg` from.
#' @template verbose
#' @return Data frame with `idx`, `label`, `cortex`, `subcortex`,
#'   `cerebellum` and `brainstem` columns.
#' @noRd
label_composition <- function(
  volume,
  lut,
  subject = "cvs_avg35_inMNI152",
  verbose = get_verbose()
) {
  source_file <- aparc_aseg_path(subject)
  parcellation <- read_label_volume(volume)

  aseg <- aparc_aseg_on_grid(
    source_file,
    volume,
    dim(parcellation),
    parcellation > 0L,
    verbose
  )

  label_ids <- intersect(lut$idx, sort(unique(parcellation[parcellation > 0L])))
  if (length(label_ids) == 0L) {
    abort_anatomy_unavailable(
      "no label in {.arg lut} has a single voxel in {.path {volume}}"
    )
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
#' @param composition Data frame from `label_composition()`.
#' @param min_cortical Minimum cortical share of labelled grey for a label to
#'   be cortical.
#' @param min_cerebellar Minimum cerebellar share of labelled grey for a label
#'   to be cerebellar.
#' @param min_fraction Minimum raw fraction of a label's voxels on the
#'   winning tissue, whatever the share.
#' @return Character vector of `"cortical"`, `"subcortical"` or
#'   `"cerebellar"`, one per row of `composition`.
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
    composition$cerebellum >= composition$subcortex &
    composition$cerebellum >= composition$brainstem
  is_cortical <- !is_cerebellar &
    share(composition$cortex) >= min_cortical &
    composition$cortex >= min_fraction

  verdict <- rep("subcortical", nrow(composition))
  verdict[is_cortical] <- "cortical"
  verdict[is_cerebellar] <- "cerebellar"
  verdict
}


#' Resample `aparc+aseg` onto a volume's own grid
#'
#' `mri_vol2vol --regheader` resamples through the two headers, so no new
#' transform is invented: the atlas volume is taken to be in the space its
#' header claims, exactly as the rest of the pipeline takes it. Nearest
#' neighbour keeps the label values intact.
#'
#' @param source_file Path to the subject's `aparc+aseg.mgz`.
#' @param volume Path to the atlas volume, used as the target grid.
#' @param dims Dimensions of the parcellation being classified, which the
#'   resampled `aparc+aseg` has to match.
#' @param brain_mask Logical array, `TRUE` wherever the volume is non-zero.
#' @template verbose
#' @return Integer array of `aseg` label values.
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
    abort_anatomy_unavailable("{.code mri_vol2vol} failed")
  }
  on.exit(unlink(resampled), add = TRUE)

  aseg <- read_label_volume(resampled)
  if (!identical(dim(aseg), dims)) {
    abort_anatomy_unavailable(
      "the resampled {.field aparc+aseg} does not share the volume's grid"
    )
  }

  check_grey_lands_on_volume(aseg, brain_mask)
  aseg
}


#' Locate a subject's `aparc+aseg.mgz`
#' @noRd
aparc_aseg_path <- function(subject) {
  installed <- rlang::is_installed(
    "freesurfer",
    version = freesurfer_min_version()
  )
  if (!installed || !isTRUE(have_fs_quietly())) {
    abort_anatomy_unavailable("FreeSurfer is not available")
  }

  aseg <- as.character(fs::path(
    freesurfer::fs_subj_dir(),
    subject,
    "mri",
    "aparc+aseg.mgz"
  ))
  if (!file.exists(aseg)) {
    abort_anatomy_unavailable(
      "{.path {aseg}} does not exist, so {.val {subject}} cannot be the
      reference"
    )
  }
  aseg
}


#' Read a labelled volume as an integer array
#' @noRd
read_label_volume <- function(file) {
  arr <- withCallingHandlers(
    tryCatch(
      as.array(read_volume(file, reorient = FALSE)),
      error = function(e) NULL
    ),
    # RNifti warns on its way to erroring on a truncated header. The error is
    # the signal; the warning would only duplicate it, less clearly.
    warning = function(w) invokeRestart("muffleWarning")
  )
  if (is.null(arr) || length(dim(arr)) != 3L) {
    abort_anatomy_unavailable("{.path {file}} is not a readable 3D volume")
  }
  if (is.integer(arr)) {
    return(arr)
  }
  # Label ids stored as float must round, not truncate: 2.9999 is label 3.
  # Done in one pass because a 1mm grid is millions of voxels per copy.
  dims <- dim(arr)
  arr <- as.integer(round(as.double(arr)))
  dim(arr) <- dims
  arr
}


#' `freesurfer::have_fs()` without letting its failures escape
#' @noRd
have_fs_quietly <- function() {
  tryCatch(freesurfer::have_fs(), error = function(e) FALSE)
}


#' Run `mri_vol2vol --regheader --nearest`
#'
#' Returns the output path, or `NULL` when the command fails. Shared with the
#' whole-brain context pipeline, which warns and carries on where this
#' caller aborts, so the failure is reported by the caller rather than here.
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
check_grey_lands_on_volume <- function(aseg, brain_mask, min_overlap = 0.5) {
  parcels <- cortical_parcel_range()
  inside <- (aseg >= parcels[1] & aseg <= parcels[2]) |
    aseg %in% grey_matter_idx()
  overlap <- resampled_overlap(inside, brain_mask)

  if (is.na(overlap)) {
    abort_anatomy_unavailable(
      "the resampled {.field aparc+aseg} has no grey matter"
    )
  }
  if (overlap < min_overlap) {
    # nolint next: object_usage_linter.
    pct <- round(100 * overlap)
    abort_anatomy_unavailable(
      "only {pct}% of the {.field aparc+aseg} grey matter lands inside the
      volume, so the two are not in the same space"
    )
  }
  invisible(TRUE)
}


#' Fraction of a resampled volume's voxels that land on the target's brain
#'
#' A volume in a space its header does not describe still resamples without
#' error; it simply lands somewhere else. `NA` when nothing was selected at
#' all, which each caller reports in its own words.
#' @noRd
resampled_overlap <- function(inside, brain_mask) {
  n <- sum(inside)
  if (n == 0L) {
    return(NA_real_)
  }
  sum(inside & brain_mask) / n
}


#' Abort because the labels cannot be classified by anatomy
#' @noRd
abort_anatomy_unavailable <- function(reason, .envir = parent.frame()) {
  cli::cli_abort(
    c(
      paste0("Cannot classify labels by anatomy: ", reason, "."),
      "i" = "Classifying by anatomy needs FreeSurfer and a volume in the
      space its header claims."
    ),
    .envir = .envir,
    wrap = TRUE
  )
}
