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


# Batch snapshot engine ----

#' Snapshot cortex slice for tract atlas
#'
#' Creates a PNG with filename format matching tract projections.
#'
#' @inheritParams snapshot_volume_slice
#' @param slice_view "axial", "sagittal", or "coronal"
#' @param view_name Name for this view (used in filename)
#' @param hemi Hemisphere ("left" or "right")
#'
#' @return Invisible path to output file, or NULL if no voxels
#' @keywords internal
#' @noRd
#' @importFrom grDevices png dev.off
#' @importFrom graphics par image
render_slice_png <- function(
  slice_data,
  outfile,
  colour = "red",
  width = 400,
  height = 400
) {
  if (is.null(slice_data)) {
    return(invisible(NULL))
  }

  slice_data[slice_data == 0] <- NA
  if (!any(is.finite(slice_data))) {
    return(invisible(NULL))
  }

  png(outfile, width = width, height = height, bg = "black")
  on.exit(dev.off(), add = TRUE)
  par(mar = c(0, 0, 0, 0))

  image(
    slice_data,
    col = colour,
    useRaster = TRUE,
    axes = FALSE,
    asp = 1
  )

  invisible(outfile)
}


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
  output_dir <- path.expand(output_dir)
  outfile <- file.path(output_dir, paste0(view_name, "_cortex_", hemi, ".png"))

  if (skip_existing && file.exists(outfile)) {
    return(invisible(outfile))
  }

  pos <- switch(slice_view, "axial" = z, "coronal" = y, "sagittal" = x)
  slice <- extract_slice_2d(vol, slice_view, pos, hemi = hemi)
  render_slice_png(slice, outfile, width = width, height = height)
}


#' Snapshot a partial volume projection
#'
#' Creates a PNG image showing maximum intensity projection of a volume subset.
#'
#' @inheritParams snapshot_volume_slice
#' @param start First slice index
#' @param end Last slice index
#' @param view_name Name for this view (used in filename)
#' @param hemi Hemisphere for sagittal views: "left" or "right"
#'
#' @return Invisible path to output file, or NULL if no voxels
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
  colour = "red",
  hemi = NULL,
  width = 400,
  height = 400,
  skip_existing = get_skip_existing()
) {
  output_dir <- path.expand(output_dir)
  label <- sanitize_label(label)
  outfile <- file.path(output_dir, paste0(view_name, "_", label, ".png"))

  if (skip_existing && file.exists(outfile)) {
    return(invisible(outfile))
  }

  proj <- volume_projection(vol, view, start, end, hemi = hemi)
  render_slice_png(
    proj,
    outfile,
    colour = colour,
    width = width,
    height = height
  )
}
