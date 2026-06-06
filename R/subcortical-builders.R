# Convenience helpers shared by subcortical atlas build scripts ----
#
# These extract the patterns repeated across the ggsegFreeSurfer
# `make_*.R` scripts (thalamus, hippoamyg, brainstem, hypothalamus, hcpa)
# so a new subcortical atlas needs only its segmentation-specific prep plus
# a couple of helper calls. They compose the ggseg.formats atlas_* ops and
# the internal volume reader; the orchestrators can dispatch to them.

#' Escape regex metacharacters in a string
#'
#' Character class is ordered for TRE (the engine `grepl()` uses by default):
#' `]` must come first to be literal, and metacharacters are listed plainly
#' rather than backslash-escaped (backslash is literal inside a TRE class).
#' @noRd
rx_escape <- function(x) {
  gsub("([][{}()*+?.^$|])", "\\\\\\1", x)
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

#' Build subcortical slice views from a label bounding box
#'
#' Computes evenly spaced coronal, axial and/or sagittal slabs spanning the
#' bounding box of the requested labels, ready to pass as the `views`
#' argument of [create_subcortical_from_volume()].
#'
#' The volume is read with the **same** axis reorientation the builder uses
#' internally, so the returned slab indices are in the projection frame. This
#' avoids a subtle trap: `RNifti::readNifti()` and the builder's reader can
#' return different axis orders, so a bounding box computed from the RNifti
#' array points the slabs at the wrong slices (silently producing empty
#' views). Always derive views with this function rather than indexing the
#' volume by hand.
#'
#' @param volume Path to a label volume, or an integer array already in the
#'   builder's frame.
#' @param labels Integer label ids whose combined bounding box frames the
#'   views.
#' @param coronal,axial,sagittal Number of slabs to produce for each
#'   orientation (`0` = none).
#' @param pad Voxels by which to expand the bounding box before slabbing.
#' @param reorient Passed to the internal volume reader; must match the value
#'   [create_subcortical_from_volume()] uses (default `TRUE`).
#' @return A data.frame with columns `name`, `type`, `start`, `end`.
#' @seealso [create_subcortical_from_volume()], [aseg_context()]
#' @export
#' @examples
#' vol <- array(0L, dim = c(20, 20, 20))
#' vol[8:12, 6:14, 9:11] <- 17L
#' subcortical_views(vol, labels = 17, coronal = 3, axial = 2)
subcortical_views <- function(
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


#' Standard FreeSurfer aseg labels stripped from a subcortical atlas
#'
#' The default set of [ggseg.formats::atlas_region_remove()] patterns applied
#' by [aseg_context()]: structures the FreeSurfer `aseg` carries but that a
#' subcortical atlas does not draw (white matter, ventricles, CSF, the
#' cortical ribbon, corpus callosum pieces, choroid plexus, vessels).
#'
#' @return A character vector of regex patterns (matched against labels).
#' @seealso [aseg_context()]
#' @export
#' @examples
#' aseg_hidden_labels()
aseg_hidden_labels <- function() {
  c(
    "White-Matter",
    "WM-hypointensities",
    "-Ventricle",
    "-Vent$",
    "CSF",
    "Cerebral-Cortex",
    "choroid-plexus",
    "vessel",
    "CC_"
  )
}


#' Reduce a subcortical atlas to focus regions on grey anatomical context
#'
#' Applies the post-processing recipe shared by the FreeSurfer subcortical
#' atlases:
#'
#' 1. Punch the cerebral white matter out of the brain silhouette
#'    ([ggseg.formats::atlas_region_op()]) so slices show the cortical ribbon
#'    with the white-matter interior as a hole rather than a solid blob.
#' 2. Remove the structures `aseg` does not draw ([aseg_hidden_labels()]).
#' 3. Demote every remaining structure that is **not** matched by `focus` to
#'    grey context, so only the focus regions are coloured.
#' 4. Optionally drop views left with no focus geometry.
#'
#' The context demotion matches the leftover core labels exactly and
#' case-sensitively, so a focus region is never swallowed by a context entry
#' that happens to be a substring of its name (e.g. `Thalamus` vs
#' `hypothalamus`).
#'
#' @param atlas A subcortical `ggseg_atlas`, e.g. from
#'   [create_subcortical_from_volume()].
#' @param focus Regex matched (case-insensitively) against `match_on`
#'   identifying the regions to keep as coloured core; everything else becomes
#'   context.
#' @param match_on Column to match `focus` against: `"label"` or `"region"`.
#' @param remove Character vector of [ggseg.formats::atlas_region_remove()]
#'   patterns to strip before demoting context. Defaults to
#'   [aseg_hidden_labels()]; pass `character(0)` to skip.
#' @param punch_white_matter If `TRUE`, subtract `white_matter` from the
#'   `cortex` silhouette. Skipped with a message if either pattern is absent.
#' @param cortex,white_matter Label patterns for the brain silhouette and the
#'   cerebral white matter used by the punch.
#' @param drop_empty_views If `TRUE`, remove views containing no focus region.
#' @return The post-processed `ggseg_atlas`.
#' @seealso [subcortical_views()], [ggseg.formats::atlas_region_contextual()]
#' @export
#' @examples
#' \dontrun{
#' atlas <- create_subcortical_from_volume(
#'   input_volume = file.path(
#'     freesurfer::fs_subj_dir(), "fsaverage5", "mri", "aseg.mgz"
#'   ),
#'   atlas_name = "aseg"
#' )
#' aseg_context(atlas, focus = "Hippocampus")
#' }
aseg_context <- function(
  atlas,
  focus,
  match_on = c("label", "region"),
  remove = aseg_hidden_labels(),
  punch_white_matter = TRUE,
  cortex = "^cortex",
  white_matter = "White-Matter$",
  drop_empty_views = TRUE
) {
  match_on <- match.arg(match_on)
  if (!ggseg.formats::is_ggseg_atlas(atlas)) {
    cli::cli_abort("{.arg atlas} must be a {.cls ggseg_atlas}.")
  }

  geom <- ggseg.formats::atlas_geom(atlas)
  sf_labels <- if (is.null(geom)) {
    character(0)
  } else {
    geom$label
  }

  if (punch_white_matter) {
    if (any(grepl(cortex, sf_labels)) && any(grepl(white_matter, sf_labels))) {
      atlas <- atlas_region_op(
        atlas,
        x = cortex,
        y = white_matter,
        action = "difference",
        into = "cortex"
      )
    } else {
      cli::cli_alert_info(
        "Skipping white-matter punch: {.val {cortex}} and
        {.val {white_matter}} not both present."
      )
    }
  }

  for (pat in remove) {
    atlas <- atlas_region_remove(atlas, pat, match_on = "label")
  }

  focus_mask <- grepl(focus, atlas$core[[match_on]], ignore.case = TRUE)
  context_labels <- atlas$core$label[!focus_mask]
  if (length(context_labels) > 0) {
    pattern <- paste0(
      "^(",
      paste(rx_escape(context_labels), collapse = "|"),
      ")$"
    )
    atlas <- atlas_region_contextual(
      atlas,
      pattern,
      match_on = "label",
      ignore.case = FALSE
    )
  }

  if (drop_empty_views && !is.null(ggseg.formats::atlas_geom(atlas))) {
    # atlas was rebuilt by the region ops above, so re-derive its 2D rows.
    sf_rows <- ggseg.formats::atlas_sf(atlas)
    views <- unique(sf_rows$view)
    empty <- vapply(
      views,
      function(v) {
        rows <- sf_rows[sf_rows$view == v, ]
        !any(rows$label %in% atlas$core$label)
      },
      logical(1)
    )
    if (any(empty)) {
      atlas <- atlas_view_remove(atlas, views[empty])
    }
  }

  atlas
}
