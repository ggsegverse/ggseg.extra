# Smooth and simplify atlas 2D contours

Topology-preserving simplification of atlas sf geometry via
[`rmapshaper::ms_simplify()`](http://andyteucher.ca/rmapshaper/reference/ms_simplify.md),
with optional morphological closing (positive then negative
[`sf::st_buffer()`](https://r-spatial.github.io/sf/reference/geos_unary.html))
layered on top to round off voxel-edge stair-steps into smooth curves.
Shared boundaries between adjacent regions are simplified together,
preventing gaps.

## Usage

``` r
atlas_smooth(atlas, keep = 0.05, smoothness = 0, labels = NULL, exclude = NULL)

atlas_simplify(atlas, keep = 0.05)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with sf data.

- keep:

  Proportion of vertices to retain (0–1), or `NULL` to skip vertex
  simplification. Lower values produce simpler shapes; values near 1 are
  an effective no-op. Default 0.05.

- smoothness:

  Buffer distance in geometry units for morphological closing after
  simplification. 0 (the default) skips closing. Values of 2–3 round off
  voxel-edge stair-steps on millimetre voxel grids without merging
  adjacent regions; larger values produce rounder shapes but can bleed
  nearby region boundaries together.

- labels:

  Optional regex pattern. Only labels matching this pattern are
  smoothed; others are left unchanged.

- exclude:

  Optional regex pattern. Labels matching this pattern are left
  unchanged; all others are smoothed.

## Value

A modified `ggseg_atlas` with simplified sf geometry.

## Details

By default all labels are smoothed equally. Use `labels` to smooth only
matching labels, or `exclude` to smooth everything except matching
labels. Only one of `labels` or `exclude` may be specified.

## Examples

``` r
if (FALSE) { # \dontrun{
# Vertex reduction only (legacy behaviour).
atlas <- atlas_smooth(my_atlas, keep = 0.05)

# Keep cortex outline detailed, simplify everything else.
atlas <- atlas_smooth(my_atlas, keep = 0.2, exclude = "cortex_|Cortex")

# Round off jagged voxel edges without dropping vertices.
atlas <- atlas_smooth(my_atlas, keep = NULL, smoothness = 3)

# Per-region tuning: hard simplification for tiny nuclei, gentle
# closing for the brain outline.
atlas <- atlas_smooth(my_atlas, keep = 0.05, exclude = "cortex_")
atlas <- atlas_smooth(atlas, keep = NULL, smoothness = 3, labels = "cortex_")
} # }
```
