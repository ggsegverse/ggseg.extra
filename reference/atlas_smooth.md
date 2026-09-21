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
  smoothness = 0.4,
  method = c("close", "chaikin", "ksmooth", "spline"),
  vertex_budget = c("preserve", "free"),
  close_gaps = TRUE,
  labels = NULL,
  exclude = NULL
)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with sf data.

- smoothness:

  Smoothing strength between 0 and 1. The scale is shared by every
  `method`, so the same value means a comparable amount of smoothing
  whichever one you pick; each method's native parameter is derived from
  it. Around 0.4–0.6, the default, rounds off voxel-edge stair-steps on
  millimetre voxel grids without distorting shapes; 1 is the most
  smoothing a method applies before shapes stop resembling their input.

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

- vertex_budget:

  What rounding is allowed to cost. Rounding a corner replaces it with
  an arc, and an arc costs vertices: a morphological close lays down
  eight segments per quarter turn, so smoothing an atlas can leave it
  several times larger than it found it and undo any simplification that
  came before.

  `"preserve"`, the default, simplifies the rounded geometry back to
  roughly the vertex count it started with. It is a real simplification
  pass, so shapes move slightly beyond what the rounding alone did, and
  it stops once a pass buys nothing - geometry already at the floor that
  holds its shape, a raw voxel tracing say, cannot be brought all the
  way back. `"free"` rounds and stops there, and the vertex count grows.

- close_gaps:

  Whether to hand back the slivers rounding opens between neighbouring
  regions. Every method moves each region's boundary on its own, and a
  boundary shared with the region next door moves the other way for the
  neighbour, so a hairline gap opens along every shared edge. With
  `TRUE`, the default, area that no longer belongs to any region but
  borders two of them is given back to one of them, and the parcellation
  closes again. Set `FALSE` for geometry that is not a coverage -
  separate tract tubes, say - where there is nothing to close.

- labels:

  Optional regex pattern. Only labels matching this pattern are
  smoothed; others are left unchanged.

- exclude:

  Optional regex pattern. Labels matching this pattern are left
  unchanged; all others are smoothed.

## Value

The `ggseg_atlas`, with its geometry rounded off. Under the default
`vertex_budget`, at close to the vertex count it arrived with.

## Details

Note that the default `method = "close"` fills holes narrower than
`smoothness`; see `method` for alternatives that preserve them.

Rounding a corner replaces it with an arc, which costs vertices: a
morphological close lays down eight segments per quarter turn. Those the
rounding added are dropped again before the atlas is returned, so a
preceding
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
still counts rather than being undone. Geometry that is already as
sparse as its shapes allow - a raw voxel tracing - keeps a little of the
growth, since simplification cannot take a ring below the vertices it
needs.

By default all labels are smoothed equally. Use `labels` to smooth only
matching labels, or `exclude` to smooth everything except matching
labels. Only one of `labels` or `exclude` may be specified.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
to simplify and smooth in one call against a stated vertex budget, which
is what most builds want.
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
to reduce the vertex count, and
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
to grow or shrink regions. Simplify before smoothing, not after -
dropping vertices from a rounded outline replaces its curves with
straight chords, putting the stair-step back.

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Round off the voxel staircase.
atlas <- atlas_smooth(my_atlas, smoothness = 0.4)

# Leave the brain outline alone.
atlas <- atlas_smooth(my_atlas, smoothness = 0.4, exclude = "^cortex")

# Round a cortical ribbon without closing its sulci.
atlas <- atlas_smooth(
  my_atlas,
  smoothness = 0.4,
  method = "chaikin",
  labels = "^cortex"
)
} # }
```
