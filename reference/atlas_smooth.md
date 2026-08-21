# Smooth and simplify atlas 2D contours

Topology-preserving simplification of atlas sf geometry via
[`rmapshaper::ms_simplify()`](http://andyteucher.ca/rmapshaper/reference/ms_simplify.md),
with optional smoothing layered on top to round off voxel-edge
stair-steps into smooth curves. Shared boundaries between adjacent
regions are simplified together, preventing gaps.

## Usage

``` r
atlas_smooth(
  atlas,
  keep = 0.05,
  smoothness = 0,
  labels = NULL,
  exclude = NULL,
  method = c("close", "chaikin", "ksmooth", "spline")
)

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

  Smoothing strength between 0 and 1, applied after simplification. 0
  (the default) skips smoothing. The scale is shared by every `method`,
  so the same value means a comparable amount of smoothing whichever one
  you pick; each method's native parameter is derived from it. Around
  0.4–0.6 rounds off voxel-edge stair-steps on millimetre voxel grids
  without distorting shapes; 1 is the most smoothing a method applies
  before shapes stop resembling their input.

- labels:

  Optional regex pattern. Only labels matching this pattern are
  smoothed; others are left unchanged.

- exclude:

  Optional regex pattern. Labels matching this pattern are left
  unchanged; all others are smoothed.

- method:

  Smoothing method. `"close"` (the default) is a morphological closing:
  a positive then negative
  [`sf::st_buffer()`](https://r-spatial.github.io/sf/reference/geos_unary.html).
  It rounds outlines but **fills holes narrower than the smoothing
  distance**, which erases the sulci of a thin cortical ribbon. The
  remaining methods come from
  [`smoothr::smooth()`](https://strimas.com/smoothr/reference/smooth.html)
  and move vertices rather than dilating the shape, so enclosed holes
  stay open: `"chaikin"` (corner cutting), `"ksmooth"` (kernel
  smoothing) and `"spline"`. Choose `"close"` to round solid shapes such
  as tract tubes, and one of the others when the geometry has holes
  worth keeping.

## Value

A modified `ggseg_atlas` with simplified sf geometry.

## Details

Note that the default `method = "close"` fills holes narrower than
`smoothness`; see `method` for alternatives that preserve them.

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
atlas <- atlas_smooth(my_atlas, keep = NULL, smoothness = 0.6)

# Per-region tuning: hard simplification for tiny nuclei, gentle
# closing for the brain outline.
atlas <- atlas_smooth(my_atlas, keep = 0.05, exclude = "cortex_")
atlas <- atlas_smooth(
  atlas,
  keep = NULL,
  smoothness = 0.6,
  labels = "cortex_"
)

# Round a cortical ribbon without closing its sulci.
atlas <- atlas_smooth(
  my_atlas,
  keep = NULL,
  smoothness = 0.4,
  method = "chaikin",
  labels = "cortex_"
)
} # }
```
