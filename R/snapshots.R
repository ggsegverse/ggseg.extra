# Snapshot functions ----

# Volume extraction helpers ----
# These functions handle all orientation logic for converting 3D volumes
# to 2D images with correct neuroimaging orientation.
#
# Standard neuroimaging conventions (RAS coordinates):
# - Axial: looking from above, anterior at top, left on left (neurological)
# - Coronal: looking from front, superior at top, left on left
# - Sagittal: looking from left, superior at top, anterior at right

#' Extract 2D slice from 3D volume
#'
#' Extracts a single slice with correct orientation for display.
#' Handles all view-specific transformations internally.
#'
#' @param vol 3D array in RAS orientation
#' @param view "axial", "coronal", or "sagittal"
#' @param pos Slice position (x for sagittal, y for coronal, z for axial)
#'
#' @return 2D matrix ready for image() display
#' @keywords internal
#' @noRd
extract_slice_2d <- function(vol, view, pos, hemi = NULL) {
  # nolint start: commas_linter.
  slice <- switch(
    view,
    "axial" = vol[,, pos, drop = TRUE],
    "coronal" = vol[, pos, , drop = TRUE],
    "sagittal" = vol[pos, , , drop = TRUE]
  )
  # nolint end

  if (is.null(slice) || length(slice) == 0) {
    return(NULL)
  }

  if (!is.matrix(slice)) {
    dims <- dim(vol)
    new_dims <- switch(
      view,
      "axial" = dims[1:2],
      "coronal" = dims[c(1, 3)],
      "sagittal" = dims[2:3]
    )
    slice <- matrix(slice, nrow = new_dims[1], ncol = new_dims[2])
  }

  orient_slice_2d(slice, view, hemi = hemi)
}


#' Create maximum intensity projection of volume
#'
#' Projects a 3D volume onto a 2D plane by taking the maximum value along
#' each ray. Optionally restricts to a subset of slices.
#'
#' @param vol 3D array in RAS orientation
#' @param view "axial", "coronal", or "sagittal"
#' @param start First slice index (NULL for full projection)
#' @param end Last slice index (NULL for full projection)
#' @param hemi Hemisphere for sagittal views: "left" or "right"
#'
#' @return 2D matrix ready for image() display
#' @keywords internal
#' @noRd
volume_projection <- function(
  vol,
  view,
  start = NULL,
  end = NULL,
  hemi = NULL
) {
  dims <- dim(vol)

  if (is.null(start)) {
    start <- 1
  }
  if (is.null(end)) {
    end <- switch(
      view,
      "axial" = dims[3],
      "coronal" = dims[2],
      "sagittal" = dims[1]
    )
  }

  if (end < start) {
    cli::cli_abort(c(
      "Projection range end ({end}) is before start ({start}).",
      "i" = "Provide a range where {.arg end} is at least {.arg start}."
    ))
  }

  # nolint start: commas_linter.
  sub_vol <- switch(
    view,
    "axial" = vol[,, start:end, drop = FALSE],
    "coronal" = vol[, start:end, , drop = FALSE],
    "sagittal" = vol[start:end, , , drop = FALSE]
  )
  # nolint end

  proj <- switch(
    view,
    "axial" = apply(sub_vol, c(1, 2), max),
    "coronal" = apply(sub_vol, c(1, 3), max),
    "sagittal" = apply(sub_vol, c(2, 3), max)
  )

  orient_slice_2d(proj, view, hemi = hemi)
}


#' Orient 2D slice for display
#'
#' With RAS+ input, `image()` already displays axial and coronal correctly.
#' Only left-hemisphere sagittal needs a horizontal flip so hemispheres
#' face each other when plotted side-by-side.
#'
#' @param slice 2D matrix
#' @param view "axial", "coronal", or "sagittal"
#' @param hemi Hemisphere for sagittal views: "left" or "right". Left sagittal
#'   is flipped horizontally so left and right face each other when plotted.
#'
#' @return Transformed 2D matrix
#' @keywords internal
#' @noRd
orient_slice_2d <- function(slice, view, hemi = NULL) {
  if (view == "sagittal" && identical(hemi, "left")) {
    return(slice[rev(seq_len(nrow(slice))), ])
  }
  slice
}


# Projection store ----

#' Path of one region's projection, under the name its contour will carry
#'
#' The file name is the region's identity: `extract_contours()` reads the
#' label and view back off it, so this is the one place that spelling is
#' decided.
#' @noRd
projection_file <- function(output_dir, view_name, label) {
  as.character(fs::path(output_dir, projection_name(view_name, label)))
}


#' The bare file name a projection carries, without a directory
#'
#' The manifests key on names rather than paths, so this is separated out to
#' spare the callers a round-trip through a dummy directory and `basename()`.
#' @noRd
projection_name <- function(view_name, label) {
  paste0(view_name, "_", label, ".rda")
}


#' Write a projection matrix for the contour step to trace
#'
#' The matrix is stored as it is, in voxel indices, rather than rendered to a
#' PNG and read back. A PNG carries no coordinates, so a reader has to decide
#' which way its rows run and what a pixel is worth; the round-trip also put
#' the projection on a fixed 400x400 canvas, which quantised it and made every
#' distance depend on the volume's dimensions.
#'
#' The file is not stamped here. Snapshots are written from parallel workers,
#' and stamping is a read-modify-write of one manifest shared by the whole
#' directory, so concurrent stamps drop each other's rows and leave
#' projections that the contour step then refuses as unversioned. The caller
#' collects the paths and stamps them on the main thread instead.
#' @noRd
save_projection <- function(proj, outfile) {
  projection <- proj
  save(projection, file = outfile)
  invisible(outfile)
}


#' Read a projection back, rejecting a cache older than this convention
#' @noRd
read_projection <- function(file) {
  env <- new.env(parent = emptyenv())
  load_cached_rda(file, contour_rerun_remedy, envir = env)
  env$projection
}


# Batch snapshot engine ----

#' Snapshot one cortex reference slice
#'
#' Returns what [snapshot_partial_projection()] returns, under the same
#' contract: the path only when this call wrote it.
#' @noRd
snapshot_cortex_slice <- function(
  vol,
  x,
  y,
  z,
  slice_view,
  view_name,
  hemi,
  output_dir,
  width = 400,
  height = 400,
  skip_existing = get_skip_existing()
) {
  outfile <- cortex_slice_file(path.expand(output_dir), view_name, hemi)

  if (skip_existing && file.exists(outfile)) {
    return(invisible(NULL))
  }

  pos <- switch(slice_view, "axial" = z, "coronal" = y, "sagittal" = x)
  slice <- extract_slice_2d(vol, slice_view, pos, hemi = hemi)
  if (is.null(slice) || !any(slice > 0)) {
    return(invisible(NULL))
  }
  save_projection(slice, outfile)
}


#' Path of the cortex reference snapshot for one view
#' @noRd
cortex_slice_file <- function(output_dir, view_name, hemi) {
  projection_file(output_dir, view_name, cortex_slice_label(hemi))
}


#' @noRd
cortex_slice_label <- function(hemi) {
  paste0("cortex_", hemi)
}


#' Snapshot a partial volume projection
#'
#' Writes the maximum intensity projection of a volume subset, as a matrix in
#' voxel indices.
#'
#' @param start First slice index
#' @param end Last slice index
#' @param view_name Name for this view (used in filename)
#' @param hemi Hemisphere for sagittal views: "left" or "right"
#'
#' @return Invisible path to the file this call wrote, or `NULL` if it wrote
#'   nothing -- because the projection was empty, or because `skip_existing`
#'   let an earlier run's file stand. Callers stamp what they are given, so a
#'   file this run did not write must not come back: re-stamping one written
#'   under an older cache format would relabel it as current and defeat
#'   [check_cache_current()].
#' @keywords internal
#' @noRd
snapshot_partial_projection <- function(
  vol,
  view,
  start,
  end,
  view_name,
  label,
  output_dir,
  hemi = NULL,
  skip_existing = get_skip_existing()
) {
  output_dir <- path.expand(output_dir)
  label <- sanitize_label(label)
  outfile <- projection_file(output_dir, view_name, label)

  if (skip_existing && file.exists(outfile)) {
    return(invisible(NULL))
  }

  proj <- volume_projection(vol, view, start, end, hemi = hemi)
  if (is.null(proj) || !any(proj > 0)) {
    return(invisible(NULL))
  }
  save_projection(proj, outfile)
}
