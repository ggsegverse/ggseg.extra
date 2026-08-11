# White matter tract atlas from a label volume ----

#' Create a white matter tract atlas from a label volume
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build a tract atlas from a volumetric white-matter tract *label map* — one
#' integer label per tract — rather than from streamlines. Each tract's voxel
#' cloud is reduced to an ordered centerline with a principal curve, and the
#' centerlines are handed to [create_tract_from_tractography()], which builds
#' the 3D tubes and 2D projection. This suits probabilistic tract atlases
#' distributed as NIfTI label volumes (e.g. AtlasTrack).
#'
#' @param input_volume Path or `RNifti` image of the tract label volume.
#' @param input_lut Path to a colour lookup table, or a data.frame with `idx`,
#'   `label` (or `region`) and colour columns (`R`, `G`, `B`). Supplies tract
#'   names and colours; labels absent from the volume are ignored.
#' @param input_aseg Path to a segmentation volume in the same space, used to
#'   draw the grey-brain cortex outline in the 2D views. Required for the 2D
#'   projection (see `steps`).
#' @param exclude Integer label ids to drop (for example aggregate whole-brain
#'   fibre masks). Labels with fewer than `min_voxels` voxels, or for which a
#'   centerline cannot be fit, are dropped automatically with a message.
#' @param n_points Number of points along each tract centerline.
#' @param min_voxels Minimum voxel count for a tract to be kept.
#' @param smoother Principal-curve smoother, passed to
#'   [princurve::principal_curve()].
#' @template atlas_name
#' @template output_dir
#' @param ... Passed to [create_tract_from_tractography()] (for example
#'   `tube_radius`, `tube_segments`, `steps`).
#' @template verbose
#'
#' @return A `ggseg_atlas` of type `"tract"`, as returned by
#'   [create_tract_from_tractography()].
#' @seealso [create_tract_from_tractography()] for the streamline-based
#'   counterpart.
#' @export
#'
#' @examples
#' \dontrun{
#' atlas <- create_tract_from_volume(
#'   input_volume = "AtlasTrack_labels.nii.gz",
#'   input_lut = "AtlasTrack_LUT.txt",
#'   input_aseg = "fsaverage/mri/aseg.mgz",
#'   exclude = c(2000, 2001, 2002, 2003, 2004),
#'   tube_radius = 3
#' )
#' }
create_tract_from_volume <- function(
  input_volume,
  input_lut,
  input_aseg = NULL,
  exclude = NULL,
  n_points = 50L,
  min_voxels = 30L,
  smoother = "smooth_spline",
  atlas_name = NULL,
  output_dir = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  ...
) {
  rlang::check_installed(
    "princurve",
    reason = "to fit tract centerlines from a label volume"
  )
  rlang::check_installed("RNifti", reason = "to read NIfTI volumes")

  in_path <- resolve_volume_path(input_volume)
  vol <- RNifti::readNifti(in_path)
  arr <- as.array(vol)
  xf <- RNifti::xform(vol)

  lut <- if (is.character(input_lut) && length(input_lut) == 1L) {
    read_lut(input_lut)
  } else {
    read_lut_arg(input_lut)
  }
  keep <- !(as.integer(lut$idx) %in% as.integer(exclude))
  lut <- lut[keep, , drop = FALSE]

  centerlines <- list()
  colours <- list()
  dropped <- character(0)
  for (i in seq_len(nrow(lut))) {
    lab <- as.integer(lut$idx[i])
    nm <- as.character(lut$label[i])
    ijk <- which(arr == lab, arr.ind = TRUE) - 1L
    if (nrow(ijk) < min_voxels) {
      dropped <- c(dropped, nm)
      next
    }
    homogeneous <- rbind(t(ijk), 1)
    world <- t(xf %*% homogeneous)
    world <- world[, 1:3, drop = FALSE]

    n_vox <- nrow(world)
    if (n_vox > 4000L) {
      # deterministic even thinning (keeps the build reproducible)
      keep_rows <- round(seq.int(1L, n_vox, length.out = 4000L))
      world <- world[keep_rows, , drop = FALSE]
    }

    cl <- tract_centerline_from_points(world, n_points, smoother)
    if (is.null(cl)) {
      dropped <- c(dropped, nm)
      next
    }
    centerlines[[nm]] <- cl
    colours[[nm]] <- lut[i, , drop = FALSE]
  }

  if (length(centerlines) == 0) {
    cli::cli_abort("No tracts yielded a centerline from {.arg input_volume}.")
  }
  if (length(dropped) > 0 && isTRUE(verbose)) {
    cli::cli_alert_info(
      "Dropped {length(dropped)} label{?s} (no centerline): {.val {dropped}}"
    )
  }

  tract_lut <- do.call(rbind, colours)
  rownames(tract_lut) <- NULL

  create_tract_from_tractography(
    input_tracts = centerlines,
    input_lut = tract_lut,
    input_aseg = input_aseg,
    atlas_name = atlas_name,
    output_dir = output_dir,
    verbose = verbose,
    ...
  )
}


#' Order a tract's voxel cloud into a centerline with a principal curve
#'
#' Pure geometry step of [create_tract_from_volume()]: fit a smooth principal
#' curve through a tract's world-space voxel coordinates and resample it to
#' `n_points` evenly along arc length, giving an ordered centerline suitable for
#' tube generation.
#'
#' @param points Numeric matrix of world coordinates (N rows, 3 columns x/y/z).
#' @template n_points
#' @param smoother Passed to [princurve::principal_curve()].
#' @return An `n_points` x 3 matrix (columns x, y, z), or `NULL` if a centerline
#'   could not be fit (too few points, or a degenerate curve).
#' @noRd
tract_centerline_from_points <- function(
  points,
  n_points = 50L,
  smoother = "smooth_spline"
) {
  if (!is.matrix(points) || nrow(points) < 30L) {
    return(NULL)
  }
  pc <- tryCatch(
    princurve::principal_curve(points, smoother = smoother),
    error = function(e) NULL
  )
  if (is.null(pc)) {
    return(NULL)
  }
  cl <- pc$s[order(pc$lambda), , drop = FALSE]
  cl <- cl[!duplicated(cl), , drop = FALSE]
  if (nrow(cl) < 2L) {
    return(NULL)
  }
  arc <- c(0, cumsum(sqrt(rowSums(diff(cl)^2))))
  total <- arc[length(arc)]
  if (!is.finite(total) || total == 0) {
    return(NULL)
  }
  at <- seq(0, total, length.out = n_points)
  out <- cbind(
    x = stats::approx(arc, cl[, 1], at)$y,
    y = stats::approx(arc, cl[, 2], at)$y,
    z = stats::approx(arc, cl[, 3], at)$y
  )
  out
}
