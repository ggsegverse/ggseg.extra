# aseg cortical ribbon ----
#
# Whether the FreeSurfer `aseg` can supply the grey-brain backdrop for a
# whole-brain atlas, and the volume it becomes. Pure array geometry: it
# asks whether the cortical ribbon is resolved or has been filled solid,
# and builds the context volume accordingly. Separate from the pipeline
# that consumes it because the calibration story stands on its own.

#' FreeSurfer `aseg` indices for the left and right cortical ribbon
#' @noRd
aseg_cortex_idx <- function() {
  c(left = 3L, right = 42L)
}


#' `aseg` indices that fill the posterior fossa behind the structures
#'
#' Cortex alone stops at the tentorium, so a subcortical atlas that reaches
#' below it - or one whose cerebellum has been split off into an atlas of its
#' own, as `ggsegMcalt`'s has - is drawn against empty space where the
#' cerebellum and brain stem should be.
#'
#' Cerebellar white matter (7, 46) is deliberately left out. Filling it makes
#' the cerebellum a solid lump that merges with the occipital lobe in
#' sagittal views and reads as more subcortex; the cortex alone comes through
#' as the foliated shell it is, which is what makes it recognisable as
#' cerebellum. [detect_context_labels()] excludes it for the same reason.
#' @noRd
aseg_fossa_idx <- function() {
  c(cerebellum_left = 8L, cerebellum_right = 47L, brainstem = 16L)
}


#' Every `aseg` index the context silhouette is drawn from
#' @noRd
aseg_context_idx <- function() {
  c(aseg_cortex_idx(), aseg_fossa_idx())
}


#' Is the atlas's own cortical mask a solid mantle rather than a ribbon?
#'
#' Not every parcellation needs this fix. One derived from a surface, such as
#' `MarsAtlas`, is already a cortical ribbon in the volume and draws a
#' silhouette with sulci of its own, which the `aseg`'s would only replace
#' with another brain's. One that covers both banks of every sulcus does not.
#'
#' The two are told apart by how many voxels the mask holds against the
#' resampled ribbon in the same grid, which is the same anatomy measured the
#' thin way. Measured: `MarsAtlas` 0.78, Julich 1.96, Hammersmith 2.23. The
#' threshold sits between them with room on both sides, and both ways of
#' being wrong leave the atlas exactly as it was.
#'
#' @param cortical_mask Logical array of the atlas's cortical voxels.
#' @param aseg The resampled `aseg` context volume. Only its cortical ribbon
#'   counts here; the posterior fossa labels are not cortex.
#' @param verbose Report the decision, either way.
#' @param factor How many ribbons' worth of voxels counts as solid.
#' @noRd
cortex_mask_is_solid <- function(
  cortical_mask,
  aseg,
  verbose = get_verbose(),
  factor = 1.5
) {
  ratio <- sum(cortical_mask) / max(1L, sum(aseg %in% aseg_cortex_idx()))
  solid <- ratio >= factor
  if (verbose) {
    log_cortex_mask_decision(solid, round(ratio, 2))
  }
  solid
}


#' Say which silhouette the cortical mask's own thickness argues for
#' @noRd
log_cortex_mask_decision <- function(solid, ratio) {
  if (solid) {
    cli::cli_alert_info(
      "Cortical labels are a solid mantle ({ratio} times the {.field aseg}
      ribbon); looking to the {.field aseg} ribbon for the silhouette.",
      wrap = TRUE
    )
    return(invisible(NULL))
  }
  cli::cli_alert_info(
    "Cortical labels are already a ribbon ({ratio} times the {.field aseg}
    ribbon); keeping them as the context silhouette.",
    wrap = TRUE
  )
  invisible(NULL)
}


#' Is the grid fine enough for the resampled ribbon to hold together?
#'
#' A cortical ribbon is 2.5-3 mm thick. Sampled on a grid whose step is
#' coarser than that, it cannot keep a voxel across itself everywhere, and
#' the silhouette traced from it breaks into disconnected islands - which is
#' worse than the solid mantle it replaces: anatomically right and illegible.
#' The ratio in `cortex_mask_is_solid()` does not see this; Craddock 200
#' (1.58) and ADHD-200 400 (2.82) sit at opposite ends of it and fragment
#' alike, because what they share is a 4 mm grid.
#'
#' What is measured is the ribbon itself rather than the voxel size, so an
#' anisotropic grid, an oblique volume, or anything else the resampling does
#' to the ribbon is caught by the same number: the share of ribbon voxels
#' whose six face neighbours are all ribbon too. That share is what having
#' more than one voxel across the ribbon means.
#'
#' Calibrated by resampling the `cvs_avg35_inMNI152` ribbon to a range of
#' isotropic grids: 1.0 mm 0.49, 1.5 mm 0.29, 2.0 mm 0.18, 2.5 mm 0.11,
#' 3.0 mm 0.06, 4.0 mm 0.03. The threshold is the value at a 2.5 mm step,
#' the thin end of the ribbon and the coarsest grid that can still hold one.
#' The atlases either side of it are not close to it: the 1.5 mm `Mcalt`
#' measures 0.29, the 4 mm parcellations 0.028 to 0.031.
#'
#' @param aseg The resampled `aseg` context volume.
#' @param verbose Report the decision, either way.
#' @param min_interior Share of ribbon voxels that must have a full ribbon
#'   neighbourhood.
#' @noRd
ribbon_is_resolved <- function(
  aseg,
  verbose = get_verbose(),
  min_interior = 0.1
) {
  ribbon <- array(aseg %in% aseg_cortex_idx(), dim = dim(aseg))
  interior <- ribbon_interior_fraction(ribbon)
  resolved <- interior >= min_interior
  if (verbose) {
    log_ribbon_resolution(resolved, round(interior, 3), min_interior)
  }
  resolved
}


#' Say whether the resampled ribbon survived the grid it landed on
#' @noRd
log_ribbon_resolution <- function(resolved, interior, min_interior) {
  if (resolved) {
    cli::cli_alert_info(
      "Taking the silhouette from the resampled {.field aseg} ribbon
      ({interior} of its voxels are a full ribbon thick).",
      wrap = TRUE
    )
    return(invisible(NULL))
  }
  cli::cli_alert_info(
    "The grid is too coarse to carry a ribbon ({interior} of the resampled
    {.field aseg} ribbon's voxels are a full ribbon thick, against
    {min_interior}); keeping the atlas's own cortical labels as the context
    silhouette.",
    wrap = TRUE
  )
  invisible(NULL)
}


#' Share of a mask's voxels whose six face neighbours are all mask too
#'
#' The three-dimensional mask eroded by one voxel, over the mask. Voxels on
#' the volume's own face are never interior, since what lies beyond them is
#' not mask.
#' @noRd
ribbon_interior_fraction <- function(mask) {
  total <- sum(mask)
  if (total == 0L) {
    return(0)
  }
  interior <- mask
  for (axis in seq_len(3L)) {
    for (step in c(-1L, 1L)) {
      interior <- interior & shift_mask(mask, axis, step)
    }
  }
  sum(interior) / total
}


#' A logical array shifted one voxel along an axis, filling with `FALSE`
#' @noRd
shift_mask <- function(mask, axis, step) {
  dims <- dim(mask)
  shifted <- array(FALSE, dim = dims)
  if (dims[axis] < 2L) {
    return(shifted)
  }
  from <- lapply(dims, seq_len)
  to <- from
  keep_low <- seq_len(dims[axis] - 1L)
  keep_high <- seq.int(2L, dims[axis])
  from[[axis]] <- if (step > 0L) keep_low else keep_high
  to[[axis]] <- if (step > 0L) keep_high else keep_low
  shifted[to[[1]], to[[2]], to[[3]]] <- mask[from[[1]], from[[2]], from[[3]]]
  shifted
}

#' Resample the FreeSurfer `aseg` context labels onto a volume's own grid
#'
#' `mri_vol2vol --regheader` resamples through the two headers, so no new
#' transform is invented: the atlas volume is taken to be in the space its
#' header claims, exactly as the rest of the pipeline takes it. Nearest
#' neighbour keeps the label values intact.
#'
#' Returns `NULL`, with a warning, whenever the result cannot be trusted:
#' FreeSurfer missing, the subject's `aseg` missing, the resampling failing,
#' a grid mismatch, or labels that do not land inside the volume's own brain
#' - the last being what a volume in some other space looks like.
#'
#' @param input_volume Path to the atlas volume, used as the target grid.
#' @param subject FreeSurfer subject to take the `aseg` from.
#' @param dims Dimensions of the atlas volume's own grid, which the
#'   resampled `aseg` has to match for the two to be talking about the same
#'   voxels.
#' @param brain_mask Logical array, `TRUE` wherever the atlas volume is
#'   non-zero.
#' @template verbose
#' @return Integer array of the [aseg_context_idx()] values and 0, or `NULL`.
#' @noRd
aseg_context_volume <- function(
  input_volume,
  subject,
  dims,
  brain_mask,
  verbose = get_verbose()
) {
  aseg <- aseg_volume_path(subject)
  if (is.null(aseg)) {
    return(NULL)
  }

  resampling <- resample_volume_to_grid(aseg, input_volume, verbose)
  if (is.null(resampling$file)) {
    warn_solid_cortex_context(resampling$reason, parent = resampling$cnd)
    return(NULL)
  }
  resampled <- resampling$file
  on.exit(unlink(resampled), add = TRUE)

  context <- as.array(read_volume(resampled, reorient = FALSE))
  if (!identical(dim(context), dims)) {
    warn_solid_cortex_context(
      "the resampled {.field aseg} does not share the volume's grid"
    )
    return(NULL)
  }

  context[!context %in% aseg_context_idx()] <- 0L

  # The gate asks whether the two volumes are in the same space, and only the
  # cortical ribbon can answer: the posterior fossa labels are wanted precisely
  # where the atlas has nothing, so counting them makes an atlas that labels
  # grey matter only look mis-spaced.
  ribbon <- context
  ribbon[!ribbon %in% aseg_cortex_idx()] <- 0L
  if (!ribbon_lands_on_volume(ribbon, brain_mask)) {
    return(NULL)
  }
  storage.mode(context) <- "integer"
  context
}


#' Locate a subject's `aseg.mgz`, or `NULL` when it cannot be used
#' @noRd
aseg_volume_path <- function(subject) {
  if (
    !rlang::is_installed("freesurfer") ||
      !isTRUE(have_fs_quietly())
  ) {
    warn_solid_cortex_context("FreeSurfer is not available")
    return(NULL)
  }

  aseg <- as.character(fs::path(
    freesurfer::fs_subj_dir(),
    subject,
    "mri",
    "aseg.mgz"
  ))
  if (!file.exists(aseg)) {
    warn_solid_cortex_context(
      "{.path {aseg}} does not exist"
    )
    return(NULL)
  }
  aseg
}


#' Is the resampled ribbon actually sitting on this volume's brain?
#'
#' A volume in a space its header does not describe still resamples without
#' error; the ribbon simply lands somewhere else. Requiring most of it to
#' fall on non-zero voxels catches that, and catches an empty ribbon.
#' @noRd
ribbon_lands_on_volume <- function(ribbon, brain_mask, min_overlap = 0.5) {
  overlap <- resampled_overlap(ribbon > 0L, brain_mask)

  if (is.na(overlap)) {
    warn_solid_cortex_context("the resampled {.field aseg} has no cortex")
    return(FALSE)
  }
  if (overlap < min_overlap) {
    # nolint next: object_usage_linter.
    pct <- round(100 * overlap)
    warn_solid_cortex_context(
      "only {pct}% of the {.field aseg} cortex lands inside the volume,
      so the two are not in the same space"
    )
    return(FALSE)
  }
  TRUE
}


#' Warn that the context silhouette falls back to the solid cortical mask
#' @noRd
warn_solid_cortex_context <- function(
  reason,
  parent = NULL,
  .envir = parent.frame()
) {
  reason <- cli::format_inline(reason, .envir = .envir)
  cli::cli_warn(
    c(
      "Drawing the cortical context as a solid silhouette: {reason}.",
      "i" = "With a FreeSurfer {.field aseg} the context keeps its sulci
      and gyri instead."
    ),
    parent = parent,
    wrap = TRUE
  )
}
