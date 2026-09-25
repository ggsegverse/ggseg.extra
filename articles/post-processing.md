# Post-processing atlases

Raw atlases come with everything: white matter, ventricles, unknown
labels, cortex outlines, and views that may not show your structures
well. The `atlas_region_*` and `atlas_view_*` families let you curate an
atlas without rebuilding from scratch.

Most of the functions in this vignette come from ggseg.formats and are
re-exported by ggseg.extra for convenience. The geometry adjustment
functions
([`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md))
are native to ggseg.extra.

## Inspecting an atlas

Before changing anything, understand what you have:

``` r

library(ggseg.formats)

atlas_labels(atlas)

atlas_regions(atlas)

atlas_views(atlas)

atlas_sf(atlas)

atlas_meshes(atlas)
```

[`atlas_labels()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_labels.html)
returns the annotation-level identifiers.
[`atlas_regions()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_regions.html)
returns the display names stored in `$core`.
[`atlas_views()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_views.html)
lists the available 2D views.
[`atlas_sf()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_sf.html)
returns the sf geometry used for 2D plotting.
[`atlas_meshes()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_meshes.html)
returns the 3D mesh data for each region.

## Removing regions

The most common post-processing step is removing structures you don’t
need.
[`atlas_region_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
matches against labels by default:

``` r

atlas <- atlas |>
  atlas_region_remove("White-Matter") |>
  atlas_region_remove("WM-hypointensities") |>
  atlas_region_remove("-Ventricle") |>
  atlas_region_remove("-Vent$") |>
  atlas_region_remove("CSF")
```

Patterns are regular expressions, so `-Vent$` matches “3rd-Vent” and
“4th-Vent” but not “Ventral-DC”.

This removes the region from `$core`, `$palette`, and all geometry data.

## Keeping regions

The inverse operation — keep only regions that match:

``` r

atlas <- atlas |>
  atlas_region_keep("Thalamus|Caudate|Putamen|Pallidum")
```

Everything that doesn’t match gets dropped.

## Context regions

Some regions work better as background outlines than as filled areas.
The cerebral cortex in a subcortical atlas is the classic example — you
want to see where it is for spatial reference, but you don’t want it
competing with the subcortical structures for colour.

[`atlas_region_contextual()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
keeps the geometry in `$data$sf` but removes the region from `$core`.
The region renders as an outline, not a filled polygon:

``` r

atlas <- atlas |>
  atlas_region_contextual("cortex", match_on = "label") |>
  atlas_region_contextual("unknown", match_on = "label") |>
  atlas_region_contextual("corpuscallosum", match_on = "label")
```

The `match_on` parameter controls whether patterns match against `label`
(annotation identifiers) or `region` (display names).

## Labels versus regions

Every ggseg atlas carries two columns that describe the same parcels in
different ways, and keeping them distinct matters.

The `label` column is the machine-readable identifier — the string that
traces directly back to the source parcellation. It should be
unambiguous, stable across versions, and safe to use in programmatic
joins: `"Left-Thalamus"`, `"lh_7Networks_3"`,
`"ctx-lh-superiorfrontal"`. When you merge external data (effect sizes,
p-values, cortical thickness) onto the atlas, `label` is the column you
match against.

The `region` column in `$core` is for humans. It appears in plot legends
and figure labels, so it should be readable, lowercase, and stripped of
hemisphere prefixes and technical notation: `"thalamus"`,
`"dorsal attention"`, `"superior frontal gyrus"`. Hemispheres are
already tracked in the `hemi` column — repeating them in `region` is
redundant.

The pipeline generates both from the source annotation, but the defaults
are rarely publication-ready.
[`atlas_region_rename()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
cleans up the `region` column without touching `label`:

``` r

atlas <- atlas |>
  atlas_region_rename("Left-", "") |>
  atlas_region_rename("Right-", "") |>
  atlas_region_rename("-", " ")
```

## Adding metadata columns

The `$core` data frame only requires three columns: `hemi`, `region`,
and `label`. Everything else is yours to add, and this is where atlases
go from functional to genuinely useful.

Neuroscientists think in networks, lobes, and functional systems — not
individual parcels. Adding grouping columns lets users facet plots by
system, color by network, or filter to structures they care about:

``` r

metadata <- data.frame(
  stringsAsFactors = FALSE,
  region = c("thalamus", "caudate", "putamen", "hippocampus", "amygdala"),
  structure = c("diencephalon", "basal ganglia", "basal ganglia",
                "limbic", "limbic")
)

atlas <- atlas |>
  atlas_core_add(metadata, by = "region")
```

This merges new columns into `$core` via a left join.

You can add as many columns as you need. A Schaefer atlas might carry
`network` and `parcel_order`. A Brainnetome atlas might include
`cytoarchitectonic_area` and `connectivity_profile`. The atlas machinery
ignores anything beyond the three required columns — extra columns are
carried through plotting, subsetting, and serialization without
interference. The more semantic structure you encode, the more your
users can do downstream without looking up region names in a separate
table.

## View management

New subcortical and tract atlases have many slices that are selected by
default to provide options of which slices give the best overall
coverage of the atlas. You will likely want to reduce the atlas to just
views you see as necessary and provide the best general coverage.

### Keeping specific views

``` r

atlas <- atlas |>
  atlas_view_keep("axial_3|axial_5|coronal_2|sagittal")
```

### Removing views

``` r

atlas <- atlas |>
  atlas_view_remove("axial_1|axial_2")
```

### Reordering views

``` r

atlas <- atlas |>
  atlas_view_reorder(
    c("sagittal_left", "sagittal_right", "coronal_3", "axial_4")
  )
```

## Removing small regions from views

After filtering views, some regions may appear as tiny slivers that add
clutter without information. Remove them by minimum area:

``` r

atlas <- atlas |>
  atlas_view_remove_small(
    min_area = 500,
    views = c("axial", "coronal")
  ) |>
  atlas_view_remove_small(min_area = 50)
```

The first call targets specific view types with a higher threshold. The
second call applies a lower threshold across all views.

## Gathering views

Raw atlas views often have large gaps between panels.
[`atlas_view_gather()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
repositions views into a compact layout:

``` r

atlas <- atlas |>
  atlas_view_gather()
```

This is typically the last step before saving.

## Adjusting geometry after the fact

The creation pipelines return raw geometry: whatever the contours
traced, at full vertex count and with the voxel staircase intact.
Shaping it is a separate step you run on the finished atlas, so retuning
a value costs a second rather than another pass through snapshots and
contours.

Three functions, each answering one question:

| Function | Question | Typical values |
|----|----|----|
| [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md) | How many vertices does this cost? | `keep = 0.05`–`0.5` |
| [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md) | How round is the outline? | `smoothness = 0.4`–`0.6` |
| [`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md) | How big is the region? | `0.5`–`1` voxels |

### Order matters

Simplify first, smooth second. Dropping vertices from an outline that
has already been rounded replaces its curves with straight chords, which
puts back the stair-step the smoothing removed:

``` r

atlas <- atlas |>
  atlas_simplify(keep = 0.3) |>
  atlas_smooth(smoothness = 0.4)
```

### Reducing the vertex count

Region boundaries traced from volumes carry far more vertices than a
plot needs.
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
drops them while preserving topology, via
[`rmapshaper::ms_simplify()`](http://andyteucher.ca/rmapshaper/reference/ms_simplify.md):

``` r

atlas <- atlas_simplify(atlas, keep = 0.3)
```

`keep` is the proportion of vertices retained. The brain silhouette
drawn behind the structures usually holds most of an atlas’s vertices,
so it is the part worth simplifying; small deep structures have few to
spare. `labels` and `exclude` say which:

``` r

atlas <- atlas_simplify(atlas, keep = 0.3, labels = "^cortex")
```

### Rounding off the staircase

[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
rounds voxel-edge stair-steps. Its default `method = "close"` is a
morphological closing, which rounds solid shapes well but **fills holes
narrower than the smoothing distance** — on a thin cortical ribbon that
erases the sulci. Use `"chaikin"` when the geometry has holes worth
keeping:

``` r

atlas <- atlas_smooth(atlas, smoothness = 0.4)

atlas <- atlas_smooth(atlas, smoothness = 0.4, method = "chaikin",
                      labels = "^cortex")
```

`smoothness` runs 0–1 on a scale shared by every method, so switching
method does not mean re-finding the value.

All three return a modified `ggseg_atlas`, so you can
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) the result and
adjust before committing.

### Context and core are two different problems

A subcortical or whole-brain atlas carries two kinds of geometry at
once, and one undifferentiated pass is wrong for one of them. The
`^cortex` context is a thin sulcal ribbon whose job is to be a
silhouette you read structures against. The structures are solid nuclei
with nothing interior to lose. Polish both with the same settings and
the ribbon loses its sulci and flattens into a blob, which is the one
thing the context was there to avoid.

Polish them separately — the context gently and with `"chaikin"`, the
structures more firmly and with the default `"close"`:

``` r

atlas <- atlas |>
  atlas_simplify(keep = 0.5, labels = "^cortex") |>
  atlas_smooth(smoothness = 0.35, labels = "^cortex", method = "chaikin") |>
  atlas_simplify(keep = 0.25, exclude = "^cortex") |>
  atlas_smooth(smoothness = 0.4, exclude = "^cortex")
```

Each of those four numbers is answering a question about the geometry it
applies to:

- The context keeps half its vertices. Every gyral crown and sulcal
  fragment in the ribbon is a contour ring of its own, so simplifying it
  costs whole rings rather than only vertices — push `keep` much below
  0.5 and small crowns disappear outright.
- The context is smoothed with `"chaikin"`. Corner cutting takes off the
  voxel staircase without moving the rings that remain. The default
  `"close"` dilates and then erodes, which fattens the ribbon until
  adjacent sulci merge.
- The structures keep a quarter of their vertices. A solid nucleus has
  no interior rings at risk, so it takes the firmer simplification.
- The structures are smoothed with the default `"close"`, a touch harder
  than the context, so they read as smooth shapes rather than as traced
  voxels.

These values are a starting point, not constants: they were chosen by
comparing renders, and a coarser or finer parcellation will want
different ones. What carries over is the split — gently and `"chaikin"`
for the context, firmly and `"close"` for the core.

## Rebuilding the atlas

After modifying components directly (e.g., editing `$core` by hand),
reconstruct the atlas to ensure consistency:

``` r

atlas <- ggseg_atlas(
  atlas = atlas$atlas,
  type = atlas$type,
  palette = atlas$palette,
  core = modified_core,
  data = atlas$data
)
```

The constructor validates that core, palette, and geometry data are
consistent.

## Putting it together

A typical post-processing pipeline for a subcortical atlas:

``` r

atlas <- atlas_raw |>
  atlas_region_remove("White-Matter", match_on = "label") |>
  atlas_region_remove("-Ventricle", match_on = "label") |>
  atlas_region_remove("CSF", match_on = "label") |>
  atlas_region_contextual("Cortex", match_on = "label") |>
  atlas_view_keep("axial_3|axial_5|coronal_3|sagittal") |>
  atlas_view_remove_small(min_area = 100) |>
  atlas_view_gather() |>
  atlas_dilate(0.6, exclude = "^cortex") |>
  atlas_simplify(keep = 0.5, labels = "^cortex") |>
  atlas_smooth(smoothness = 0.35, labels = "^cortex", method = "chaikin") |>
  atlas_simplify(keep = 0.25, exclude = "^cortex") |>
  atlas_smooth(smoothness = 0.4, exclude = "^cortex")
```

Each step is a pure transformation — pipe them together, inspect the
result, adjust as needed.
