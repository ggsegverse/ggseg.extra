# Re-exports from ggseg.formats ----

#' Atlas manipulation verbs, re-exported from ggseg.formats
#'
#' @description
#' The vocabulary for reshaping a finished atlas -- dropping regions, gathering
#' views, boolean geometry between labels -- lives in ggseg.formats, because it
#' belongs to the atlas format rather than to any one builder. Every atlas
#' build reaches for both packages, so ggseg.extra re-exports the verbs and
#' `library(ggseg.extra)` is enough.
#'
#' Only the `atlas_*` verbs are re-exported. ggseg.formats also ships atlases
#' named `dk`, `aseg`, `tracula` and `suit`, and so does ggseg; attaching the
#' whole namespace would mask one set with the other depending on load order,
#' which is a silently wrong atlas rather than an error.
#'
#' Four more verbs - `atlas_centerlines()`, `atlas_plot_palette()`,
#' `atlas_structure_reorder()` and `atlas_view_select()` - exist only in
#' ggseg.formats' development build, so re-exporting them here would stop this
#' package building against the release its DESCRIPTION asks for. They can come
#' across once ggseg.formats releases them and the floor here moves up.
#'
#' @name atlas-verbs
#' @keywords internal
NULL

#' @importFrom ggseg.formats atlas_context_remove
#' @export
ggseg.formats::atlas_context_remove

#' @importFrom ggseg.formats atlas_core_add
#' @export
ggseg.formats::atlas_core_add

#' @importFrom ggseg.formats atlas_geom
#' @export
ggseg.formats::atlas_geom

#' @importFrom ggseg.formats atlas_geometry_type
#' @export
ggseg.formats::atlas_geometry_type

#' @importFrom ggseg.formats atlas_labels
#' @export
ggseg.formats::atlas_labels

#' @importFrom ggseg.formats atlas_meshes
#' @export
ggseg.formats::atlas_meshes

#' @importFrom ggseg.formats atlas_palette
#' @export
ggseg.formats::atlas_palette

#' @importFrom ggseg.formats atlas_polygons
#' @export
ggseg.formats::atlas_polygons

#' @importFrom ggseg.formats atlas_region_contextual
#' @export
ggseg.formats::atlas_region_contextual

#' @importFrom ggseg.formats atlas_region_keep
#' @export
ggseg.formats::atlas_region_keep

#' @importFrom ggseg.formats atlas_region_op
#' @export
ggseg.formats::atlas_region_op

#' @importFrom ggseg.formats atlas_region_remove
#' @export
ggseg.formats::atlas_region_remove

#' @importFrom ggseg.formats atlas_region_rename
#' @export
ggseg.formats::atlas_region_rename

#' @importFrom ggseg.formats atlas_regions
#' @export
ggseg.formats::atlas_regions

#' @importFrom ggseg.formats atlas_sf
#' @export
ggseg.formats::atlas_sf

#' @importFrom ggseg.formats atlas_type
#' @export
ggseg.formats::atlas_type

#' @importFrom ggseg.formats atlas_vertices
#' @export
ggseg.formats::atlas_vertices

#' @importFrom ggseg.formats atlas_view_gather
#' @export
ggseg.formats::atlas_view_gather

#' @importFrom ggseg.formats atlas_view_keep
#' @export
ggseg.formats::atlas_view_keep

#' @importFrom ggseg.formats atlas_view_remove
#' @export
ggseg.formats::atlas_view_remove

#' @importFrom ggseg.formats atlas_view_remove_region
#' @export
ggseg.formats::atlas_view_remove_region

#' @importFrom ggseg.formats atlas_view_remove_small
#' @export
ggseg.formats::atlas_view_remove_small

#' @importFrom ggseg.formats atlas_view_reorder
#' @export
ggseg.formats::atlas_view_reorder

#' @importFrom ggseg.formats atlas_views
#' @export
ggseg.formats::atlas_views
