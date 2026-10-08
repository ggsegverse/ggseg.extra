# Convenience helpers shared by subcortical atlas build scripts ----
#
# These extract the patterns repeated across the ggsegFreeSurfer
# `make_*.R` scripts (thalamus, hippoamyg, brainstem, hypothalamus, hcpa)
# so a new subcortical atlas needs only its segmentation-specific prep plus
# a couple of helper calls. They compose the ggseg.formats atlas_* ops and
# the internal volume reader; the orchestrators can dispatch to them.

#' Build subcortical slabs from a label bounding box
#'
#' Computes evenly spaced coronal, axial and/or sagittal slabs spanning the
#' bounding box of the requested labels, ready to pass as the `slabs`
#' argument of [create_subcortical_from_volume()].
#'
#' The volume is read with the **same** axis reorientation the builder uses
#' internally, so the returned slab indices are in the projection frame. This
#' avoids a subtle trap: `RNifti::readNifti()` and the builder's reader can
#' return different axis orders, so a bounding box computed from the RNifti
#' array points the slabs at the wrong slices (silently producing empty
#' views). Always derive slabs with this function rather than indexing the
#' volume by hand.
#'
#' @param volume Path to a label volume, or an integer array already in the
#'   builder's frame.
#' @param labels Integer label ids whose combined bounding box frames the
#'   slabs.
#' @param coronal,axial,sagittal Number of slabs to produce for each
#'   orientation (`0` = none).
#' @param pad Voxels by which to expand the bounding box before slabbing.
#' @param reorient Passed to the internal volume reader; must match the value
#'   [create_subcortical_from_volume()] uses (default `TRUE`).
#' @return A data.frame with columns `name`, `type`, `start`, `end`.
#' @seealso [create_subcortical_from_volume()]
#' @export
#' @examples
#' vol <- array(0L, dim = c(20, 20, 20))
#' vol[8:12, 6:14, 9:11] <- 17L
#' subcortical_slabs(vol, labels = 17, coronal = 3, axial = 2)
subcortical_slabs <- function(
  volume,
  labels,
  coronal = 0,
  axial = 0,
  sagittal = 0,
  pad = 0,
  reorient = TRUE
) {
  vol <- if (is.character(volume)) {
    read_volume(volume, reorient = reorient)
  } else {
    volume
  }
  dims <- dim(vol)

  # array() restores the dim that %in% drops — the bbox must stay 3D.
  mask <- array(as.vector(vol) %in% labels, dim = dims)
  idx <- which(mask, arr.ind = TRUE)
  if (nrow(idx) == 0) {
    cli::cli_abort("None of {.arg labels} are present in {.arg volume}.")
  }

  axis_range <- function(d) {
    r <- range(idx[, d])
    c(max(1L, r[1] - pad), min(dims[d], r[2] + pad))
  }

  # volume_projection() slices sagittal on dim1, coronal on dim2, axial on
  # dim3; keep this mapping in lockstep with that function.
  specs <- list(
    list(type = "coronal", n = coronal, d = 2L),
    list(type = "axial", n = axial, d = 3L),
    list(type = "sagittal", n = sagittal, d = 1L)
  )
  out <- do.call(
    rbind,
    lapply(specs, function(s) {
      if (s$n <= 0) {
        return(NULL)
      }
      b <- axis_range(s$d)
      view_slabs(b[1], b[2], s$n, s$type)
    })
  )

  if (is.null(out) || nrow(out) == 0) {
    cli::cli_abort(
      "Request at least one slab via {.arg coronal}, {.arg axial} or
      {.arg sagittal}."
    )
  }
  rownames(out) <- NULL
  out
}

#' Evenly spaced, contiguous slabs covering `lo` to `hi` along one axis
#'
#' Slab i spans `edges[i]` to `edges[i + 1] - 1`; the final slab is inclusive
#' of `hi` so the whole bounding box is covered.
#' @noRd
view_slabs <- function(lo, hi, n, type) {
  edges <- round(seq(lo, hi, length.out = n + 1))
  do.call(
    rbind,
    lapply(seq_len(n), function(i) {
      end <- if (i == n) edges[i + 1] else edges[i + 1] - 1L
      data.frame(
        name = sprintf("%s_%d", type, i),
        type = type,
        start = edges[i],
        end = max(end, edges[i]),
        stringsAsFactors = FALSE
      )
    })
  )
}
