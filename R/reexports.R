# Re-exports from ggseg.formats ----

#' The ggseg.formats API, re-exported
#'
#' @description
#' The atlas format -- its accessors, its reshaping verbs, its constructors and
#' its readers -- lives in ggseg.formats, because it belongs to the format
#' rather than to any one builder. Every atlas build reaches for both
#' packages, so ggseg.extra re-exports the whole non-deprecated ggseg.formats
#' API and `library(ggseg.extra)` is enough.
#'
#' @section Reading an atlas:
#' `atlas_regions()`, `atlas_labels()`, `atlas_hemi()`, `atlas_display()`,
#' `atlas_views()`, `atlas_type()`, `atlas_context()`, `atlas_undrawn()`,
#' `atlas_region_semantics()` and `atlas_provenance()` report what an atlas
#' holds. `atlas_geom()`, `atlas_sf()`, `atlas_polygons()`, `atlas_meshes()`,
#' `atlas_vertices()`, `atlas_centerlines()`, `atlas_palette()`,
#' `atlas_plot_palette()` and `atlas_geometry_type()` reach into its parts.
#' `is_ggseg_atlas()`, `is_cortical_atlas()`, `is_subcortical_atlas()`,
#' `is_tract_atlas()`, `is_cerebellar_atlas()`, `is_wm_atlas()`,
#' `is_ggseg3d_atlas()`, `is_atlas_sf()` and `is_atlas_polygon()` test it, and
#' `assert_ggseg_atlas()` errors when the answer is no.
#'
#' @section Changing which regions are in it:
#' `atlas_region_remove()` and `atlas_region_keep()` drop or select regions by
#' regex. `atlas_region_rename()` rewrites display names without touching
#' labels. `atlas_region_contextual()` keeps a region's geometry as a grey
#' outline but takes it out of the palette, which is how the brain silhouette
#' behind an atlas is made; `atlas_context_remove()` drops it again.
#' `atlas_region_op()` does boolean geometry between two labels, selected with
#' `regions()` and `context()`. `atlas_structure_reorder()` changes the order
#' structures draw in, and `atlas_core_add()` joins extra columns onto `$core`.
#'
#' @section Changing which views are in it:
#' `atlas_view_keep()`, `atlas_view_remove()`, `atlas_view_select()` and
#' `atlas_view_reorder()` select and order the 2D views.
#' `atlas_view_remove_region()` drops one region from some views only,
#' `atlas_view_remove_small()` drops slivers below an area, and
#' `atlas_view_gather()` closes the gaps between panels.
#'
#' @section Building and converting an atlas object:
#' `ggseg_atlas()` is the constructor, and validates that core, palette and
#' geometry agree; reach for it when you have edited a component by hand and
#' want it checked. `ggseg_data_cortical()`, `ggseg_data_subcortical()`,
#' `ggseg_data_tract()`, `ggseg_data_cerebellar()` and `ggseg_data_wm()` build
#' its `data`. `set_atlas_palette()`, `set_atlas_type()`,
#' `set_atlas_provenance()` and `relabel_atlas()` change one part of a finished
#' atlas. `as_ggseg_atlas()`, `as_sf_atlas()` and `as_polygon_atlas()` convert
#' between representations, `attach_sfc()` and `reorder_sfc()` work on the sf
#' geometry column, and `convert_legacy_brain_atlas()`,
#' `migrate_atlas_files()`, `migrate_atlas_hemi()`, `migrate_atlas_display()`
#' and `legacy_region_map()` bring older atlases forward.
#'
#' @section Data, meshes and readers:
#' `dk`, `aseg`, `tracula` and `suit` are the bundled atlases; ggseg and
#' ggseg3d re-export the same objects, so attaching any combination of them
#' masks nothing. `get_brain_mesh()` and `get_cerebellar_mesh()` return the
#' template surfaces. `read_atlas_files()`, `read_freesurfer_stats()` and
#' `read_freesurfer_table()` read data to plot on an atlas.
#'
#' @section What is not re-exported:
#' ggseg.formats' deprecated functions -- the `brain_*` family,
#' `as_brain_atlas()`, `is_brain_atlas()` and `unify_legacy_atlases()`. A
#' re-export would stop this package installing on the day ggseg.formats
#' removes them.
#'
#' @seealso [atlas_polish()], [atlas_simplify()], [atlas_smooth()] and
#'   [atlas_dilate()], which shape an atlas's geometry and are native to
#'   ggseg.extra.
#'
#' @name atlas-verbs
NULL

#' @importFrom ggseg.formats as_ggseg_atlas
#' @export
ggseg.formats::as_ggseg_atlas

#' @importFrom ggseg.formats as_polygon_atlas
#' @export
ggseg.formats::as_polygon_atlas

#' @importFrom ggseg.formats as_sf_atlas
#' @export
ggseg.formats::as_sf_atlas

#' @importFrom ggseg.formats aseg
#' @export
ggseg.formats::aseg

#' @importFrom ggseg.formats assert_ggseg_atlas
#' @export
ggseg.formats::assert_ggseg_atlas

#' @importFrom ggseg.formats atlas_centerlines
#' @export
ggseg.formats::atlas_centerlines

#' @importFrom ggseg.formats atlas_context
#' @export
ggseg.formats::atlas_context

#' @importFrom ggseg.formats atlas_context_remove
#' @export
ggseg.formats::atlas_context_remove

#' @importFrom ggseg.formats atlas_core_add
#' @export
ggseg.formats::atlas_core_add

#' @importFrom ggseg.formats atlas_display
#' @export
ggseg.formats::atlas_display

#' @importFrom ggseg.formats atlas_geom
#' @export
ggseg.formats::atlas_geom

#' @importFrom ggseg.formats atlas_geometry_type
#' @export
ggseg.formats::atlas_geometry_type

#' @importFrom ggseg.formats atlas_hemi
#' @export
ggseg.formats::atlas_hemi

#' @importFrom ggseg.formats atlas_labels
#' @export
ggseg.formats::atlas_labels

#' @importFrom ggseg.formats atlas_meshes
#' @export
ggseg.formats::atlas_meshes

#' @importFrom ggseg.formats atlas_palette
#' @export
ggseg.formats::atlas_palette

#' @importFrom ggseg.formats atlas_plot_palette
#' @export
ggseg.formats::atlas_plot_palette

#' @importFrom ggseg.formats atlas_polygons
#' @export
ggseg.formats::atlas_polygons

#' @importFrom ggseg.formats atlas_provenance
#' @export
ggseg.formats::atlas_provenance

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

#' @importFrom ggseg.formats atlas_region_semantics
#' @export
ggseg.formats::atlas_region_semantics

#' @importFrom ggseg.formats atlas_regions
#' @export
ggseg.formats::atlas_regions

#' @importFrom ggseg.formats atlas_sf
#' @export
ggseg.formats::atlas_sf

#' @importFrom ggseg.formats atlas_structure_reorder
#' @export
ggseg.formats::atlas_structure_reorder

#' @importFrom ggseg.formats atlas_type
#' @export
ggseg.formats::atlas_type

#' @importFrom ggseg.formats atlas_undrawn
#' @export
ggseg.formats::atlas_undrawn

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

#' @importFrom ggseg.formats atlas_view_select
#' @export
ggseg.formats::atlas_view_select

#' @importFrom ggseg.formats atlas_views
#' @export
ggseg.formats::atlas_views

#' @importFrom ggseg.formats attach_sfc
#' @export
ggseg.formats::attach_sfc

#' @importFrom ggseg.formats context
#' @export
ggseg.formats::context

#' @importFrom ggseg.formats convert_legacy_brain_atlas
#' @export
ggseg.formats::convert_legacy_brain_atlas

#' @importFrom ggseg.formats dk
#' @export
ggseg.formats::dk

#' @importFrom ggseg.formats get_brain_mesh
#' @export
ggseg.formats::get_brain_mesh

#' @importFrom ggseg.formats get_cerebellar_mesh
#' @export
ggseg.formats::get_cerebellar_mesh

#' @importFrom ggseg.formats ggseg_atlas
#' @export
ggseg.formats::ggseg_atlas

#' @importFrom ggseg.formats ggseg_data_cerebellar
#' @export
ggseg.formats::ggseg_data_cerebellar

#' @importFrom ggseg.formats ggseg_data_cortical
#' @export
ggseg.formats::ggseg_data_cortical

#' @importFrom ggseg.formats ggseg_data_subcortical
#' @export
ggseg.formats::ggseg_data_subcortical

#' @importFrom ggseg.formats ggseg_data_tract
#' @export
ggseg.formats::ggseg_data_tract

#' @importFrom ggseg.formats ggseg_data_wm
#' @export
ggseg.formats::ggseg_data_wm

#' @importFrom ggseg.formats is_atlas_polygon
#' @export
ggseg.formats::is_atlas_polygon

#' @importFrom ggseg.formats is_atlas_sf
#' @export
ggseg.formats::is_atlas_sf

#' @importFrom ggseg.formats is_cerebellar_atlas
#' @export
ggseg.formats::is_cerebellar_atlas

#' @importFrom ggseg.formats is_cortical_atlas
#' @export
ggseg.formats::is_cortical_atlas

#' @importFrom ggseg.formats is_ggseg_atlas
#' @export
ggseg.formats::is_ggseg_atlas

#' @importFrom ggseg.formats is_ggseg3d_atlas
#' @export
ggseg.formats::is_ggseg3d_atlas

#' @importFrom ggseg.formats is_subcortical_atlas
#' @export
ggseg.formats::is_subcortical_atlas

#' @importFrom ggseg.formats is_tract_atlas
#' @export
ggseg.formats::is_tract_atlas

#' @importFrom ggseg.formats is_wm_atlas
#' @export
ggseg.formats::is_wm_atlas

#' @importFrom ggseg.formats legacy_region_map
#' @export
ggseg.formats::legacy_region_map

#' @importFrom ggseg.formats migrate_atlas_display
#' @export
ggseg.formats::migrate_atlas_display

#' @importFrom ggseg.formats migrate_atlas_files
#' @export
ggseg.formats::migrate_atlas_files

#' @importFrom ggseg.formats migrate_atlas_hemi
#' @export
ggseg.formats::migrate_atlas_hemi

#' @importFrom ggseg.formats read_atlas_files
#' @export
ggseg.formats::read_atlas_files

#' @importFrom ggseg.formats read_freesurfer_stats
#' @export
ggseg.formats::read_freesurfer_stats

#' @importFrom ggseg.formats read_freesurfer_table
#' @export
ggseg.formats::read_freesurfer_table

#' @importFrom ggseg.formats regions
#' @export
ggseg.formats::regions

#' @importFrom ggseg.formats relabel_atlas
#' @export
ggseg.formats::relabel_atlas

#' @importFrom ggseg.formats reorder_sfc
#' @export
ggseg.formats::reorder_sfc

#' @importFrom ggseg.formats set_atlas_palette
#' @export
ggseg.formats::set_atlas_palette

#' @importFrom ggseg.formats set_atlas_provenance
#' @export
ggseg.formats::set_atlas_provenance

#' @importFrom ggseg.formats set_atlas_type
#' @export
ggseg.formats::set_atlas_type

#' @importFrom ggseg.formats suit
#' @export
ggseg.formats::suit

#' @importFrom ggseg.formats tracula
#' @export
ggseg.formats::tracula
