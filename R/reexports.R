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
#' @section Reading an atlas:
#' `atlas_regions()`, `atlas_labels()`, `atlas_views()` and `atlas_type()`
#' report what an atlas holds. `atlas_geom()`, `atlas_sf()`,
#' `atlas_polygons()`, `atlas_meshes()`, `atlas_vertices()`,
#' `atlas_palette()` and `atlas_geometry_type()` reach into its parts.
#'
#' @section Changing which regions are in it:
#' `atlas_region_remove()` and `atlas_region_keep()` drop or select regions by
#' regex. `atlas_region_rename()` rewrites display names without touching
#' labels. `atlas_region_contextual()` keeps a region's geometry as a grey
#' outline but takes it out of the palette, which is how the brain silhouette
#' behind an atlas is made; `atlas_context_remove()` drops it again.
#' `atlas_region_op()` does boolean geometry between two labels, and
#' `atlas_core_add()` joins extra columns onto `$core`.
#'
#' @section Changing which views are in it:
#' `atlas_view_keep()`, `atlas_view_remove()` and `atlas_view_reorder()`
#' select and order the 2D views. `atlas_view_remove_region()` drops one
#' region from some views only, `atlas_view_remove_small()` drops slivers
#' below an area, and `atlas_view_gather()` closes the gaps between panels.
#'
#' @section Building an atlas object:
#' `ggseg_atlas()` is the constructor, and validates that core, palette and
#' geometry agree; `is_ggseg_atlas()` tests the result. Reach for them when
#' you have edited a component by hand and want it checked.
#'
#' @section What is not re-exported:
#' Only functions are. ggseg.formats also ships atlases named `dk`, `aseg`,
#' `tracula` and `suit`, and so does ggseg; attaching the whole namespace
#' would mask one set with the other depending on load order, which is a
#' silently wrong atlas rather than an error.
#'
#' Four more verbs - `atlas_centerlines()`, `atlas_plot_palette()`,
#' `atlas_structure_reorder()` and `atlas_view_select()` - exist only in
#' ggseg.formats' development build, so re-exporting them here would stop this
#' package building against the release its DESCRIPTION asks for. They can come
#' across once ggseg.formats releases them and the floor here moves up.
#'
#' @seealso [atlas_polish()], [atlas_simplify()], [atlas_smooth()] and
#'   [atlas_dilate()], which shape an atlas's geometry and are native to
#'   ggseg.extra.
#'
#' @name atlas-verbs
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

#' @importFrom ggseg.formats ggseg_atlas
#' @export
ggseg.formats::ggseg_atlas

#' @importFrom ggseg.formats is_ggseg_atlas
#' @export
ggseg.formats::is_ggseg_atlas
