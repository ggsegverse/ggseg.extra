#' Drop the views a build left nearly empty
#'
#' Slabs tile the bounding box of an atlas's labels, so a slab can land where
#' almost none of the structures are and come back holding a region or two
#' against a full anatomical backdrop. This drops those views, counting what
#' each one actually holds rather than naming the views to remove.
#'
#' @details
#' Count, do not name. A build script that names the views to drop goes stale
#' silently: rename a slab or lay the slabs out again and the pattern matches
#' nothing, the panel survives, and the only sign is a thin view in the
#' finished atlas. Counting degrades to dropping nothing instead.
#'
#' Context does not count. A view showing nothing but the grey brain is the
#' case this exists to remove, so only labels that are drawn as regions are
#' counted; see [ggseg.formats::atlas_context()].
#'
#' Run this after the regions have been removed, not before. A slab full of
#' ventricles looks well populated to the builder and renders empty once
#' [ggseg.formats::atlas_region_remove()] has taken the ventricles out. The
#' pipeline already discards slabs that no labelled voxel falls into, which is
#' the same policy at a threshold of zero, applied to the volume before
#' anything is traced.
#'
#' @inheritParams atlas_dilate
#' @param min_regions Smallest number of drawn regions a view may hold and
#'   still be kept. A view with fewer is dropped.
#'
#' @return The `ggseg_atlas`, in the representation it arrived in.
#' @family atlas geometry
#' @seealso [ggseg.formats::atlas_view_remove()] to drop views by name, and
#'   [ggseg.formats::atlas_view_remove_small()] to drop slivers within a view
#'   rather than the view itself.
#' @export
#' @examples
#' aseg <- ggseg.formats::aseg()
#'
#' # How many regions each view is carrying
#' atlas_view_region_counts(aseg)
#'
#' atlas_view_remove_sparse(aseg, min_regions = 5)
atlas_view_remove_sparse <- function(atlas, min_regions = 5) {
  check_min_regions(min_regions)

  if (is.null(ggseg.formats::atlas_geom(atlas))) {
    cli::cli_warn("Atlas has no 2D geometry, nothing to drop.")
    return(atlas)
  }

  counts <- atlas_view_region_counts(atlas)
  sparse <- names(counts)[counts < min_regions]

  if (length(sparse) == 0) {
    return(atlas)
  }

  if (length(sparse) == length(counts)) {
    cli::cli_abort(c(
      "{.arg min_regions} of {min_regions} would drop every view.",
      "i" = "The fullest view holds {max(counts)} region{?s}.",
      "i" = "Lower {.arg min_regions}, or check that the regions survived
             the build."
    ))
  }

  cli::cli_alert_info(
    "Dropping {length(sparse)} sparse view{?s}: {.val {sparse}}"
  )
  ggseg.formats::atlas_view_remove(atlas, sparse)
}


#' Drop the views that draw no region at all
#'
#' A view holding nothing but the grey anatomical backdrop takes up room in
#' the layout and carries a title while showing none of the atlas. This drops
#' those views.
#'
#' @details
#' Empty is usually a consequence of editing rather than of the build: take
#' the ventricles out of an `aseg`, or prune small depictions, and a view
#' whose only content was those regions is left drawing nothing.
#'
#' Takes the atlas once, on purpose. [ggseg.formats::atlas_views_empty()]
#' reports the same views without removing them, and pairing the two by hand
#' would mean naming the atlas twice --- which reads as a pipe but is not
#' one, and in a longer pipeline measures the atlas *before* the editing that
#' emptied the view. Asking this verb instead means the atlas it measures is
#' always the atlas it changes.
#'
#' This is the zero case of [atlas_view_remove_sparse()], which drops views a
#' build left *thin* against a threshold. Reach for this one when the
#' threshold is not a judgement call: a view drawing no region is empty by
#' definition, not by a choice of `min_regions`.
#'
#' @inheritParams atlas_dilate
#'
#' @return The `ggseg_atlas`, in the representation it arrived in. An atlas
#'   with no empty view is returned unchanged.
#' @family atlas geometry
#' @seealso [ggseg.formats::atlas_views_empty()] to see which views these are
#'   without removing them, and [atlas_view_remove_sparse()] for views that
#'   are thin rather than empty.
#' @export
#' @examples
#' aseg <- ggseg.formats::aseg()
#'
#' # Nothing to do: every aseg view draws something
#' ggseg.formats::atlas_views_empty(aseg)
#' atlas_view_remove_empty(aseg)
atlas_view_remove_empty <- function(atlas) {
  if (is.null(ggseg.formats::atlas_geom(atlas))) {
    cli::cli_warn("Atlas has no 2D geometry, nothing to drop.")
    return(atlas)
  }

  empty <- ggseg.formats::atlas_views_empty(atlas)

  if (length(empty) == 0) {
    return(atlas)
  }

  if (length(empty) == length(ggseg.formats::atlas_views(atlas))) {
    cli::cli_abort(c(
      "Every view draws no region, so dropping the empty ones would leave
       no view at all.",
      "i" = "Check that the regions survived the build; see
             {.fun ggseg.formats::atlas_undrawn}."
    ))
  }

  cli::cli_alert_info(
    "Dropping {length(empty)} empty view{?s}: {.val {empty}}"
  )
  ggseg.formats::atlas_view_remove(atlas, empty)
}


#' Count the drawn regions in each view
#'
#' @inheritParams atlas_dilate
#' @return A named integer vector, one entry per view, in view order. Views
#'   holding nothing but context count zero.
#' @family atlas geometry
#' @export
#' @examples
#' atlas_view_region_counts(ggseg.formats::aseg())
atlas_view_region_counts <- function(atlas) {
  pairs <- view_label_pairs(atlas)
  context <- ggseg.formats::atlas_context(atlas)
  drawn <- pairs[!pairs$label %in% context, , drop = FALSE]

  views <- ggseg.formats::atlas_views(atlas)
  counts <- stats::setNames(integer(length(views)), views)
  per_view <- tapply(drawn$label, drawn$view, function(x) length(unique(x)))
  counts[names(per_view)] <- as.integer(per_view)
  counts
}


#' Every label/view pair in an atlas's 2D geometry
#'
#' Polygon geometry keeps `view` inside its list-column and sf geometry keeps
#' it in a column, so read whichever the atlas arrived in rather than
#' converting it: counting views should not cost an sf round trip.
#'
#' @inheritParams atlas_dilate
#' @return A data.frame with one row per label and view it appears in.
#' @noRd
view_label_pairs <- function(atlas) {
  geom <- ggseg.formats::atlas_geom(atlas)

  if (!ggseg.formats::is_atlas_polygon(atlas)) {
    return(data.frame(label = geom$label, view = geom$view))
  }

  views <- lapply(geom$geometry, function(g) unique(g$view))
  data.frame(
    label = rep(geom$label, lengths(views)),
    view = unlist(views)
  )
}


#' @noRd
check_min_regions <- function(min_regions, call = rlang::caller_env()) {
  if (
    !is.numeric(min_regions) ||
      length(min_regions) != 1L ||
      is.na(min_regions) ||
      min_regions < 0
  ) {
    cli::cli_abort(
      "{.arg min_regions} must be a single non-negative number.",
      call = call
    )
  }
  invisible(min_regions)
}
