# Atlas manipulation verbs, re-exported from ggseg.formats

The vocabulary for reshaping a finished atlas – dropping regions,
gathering views, boolean geometry between labels – lives in
ggseg.formats, because it belongs to the atlas format rather than to any
one builder. Every atlas build reaches for both packages, so ggseg.extra
re-exports the verbs and
[`library(ggseg.extra)`](https://github.com/ggsegverse/ggseg.extra) is
enough.

## Reading an atlas

[`atlas_regions()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_regions.html),
[`atlas_labels()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_labels.html),
[`atlas_views()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_views.html)
and
[`atlas_type()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_type.html)
report what an atlas holds.
[`atlas_geom()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_geom.html),
[`atlas_sf()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_sf.html),
[`atlas_polygons()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_polygons.html),
[`atlas_meshes()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_meshes.html),
[`atlas_vertices()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_vertices.html),
[`atlas_palette()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_palette.html)
and
[`atlas_geometry_type()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_geometry_type.html)
reach into its parts.

## Changing which regions are in it

[`atlas_region_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
and
[`atlas_region_keep()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
drop or select regions by regex.
[`atlas_region_rename()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
rewrites display names without touching labels.
[`atlas_region_contextual()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
keeps a region's geometry as a grey outline but takes it out of the
palette, which is how the brain silhouette behind an atlas is made;
[`atlas_context_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
drops it again.
[`atlas_region_op()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
does boolean geometry between two labels, and
[`atlas_core_add()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
joins extra columns onto `$core`.

## Changing which views are in it

[`atlas_view_keep()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html),
[`atlas_view_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
and
[`atlas_view_reorder()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
select and order the 2D views.
[`atlas_view_remove_region()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
drops one region from some views only,
[`atlas_view_remove_small()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
drops slivers below an area, and
[`atlas_view_gather()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
closes the gaps between panels.

## Building an atlas object

[`ggseg_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/ggseg_atlas.html)
is the constructor, and validates that core, palette and geometry agree;
[`is_ggseg_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/is_ggseg_atlas.html)
tests the result. Reach for them when you have edited a component by
hand and want it checked.

## What is not re-exported

Only functions are. ggseg.formats also ships atlases named `dk`, `aseg`,
`tracula` and `suit`, and so does ggseg; attaching the whole namespace
would mask one set with the other depending on load order, which is a
silently wrong atlas rather than an error.

Four more verbs - `atlas_centerlines()`, `atlas_plot_palette()`,
`atlas_structure_reorder()` and `atlas_view_select()` - exist only in
ggseg.formats' development build, so re-exporting them here would stop
this package building against the release its DESCRIPTION asks for. They
can come across once ggseg.formats releases them and the floor here
moves up.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
and
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
which shape an atlas's geometry and are native to ggseg.extra.
