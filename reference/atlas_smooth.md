# Round off an atlas's voxel staircase

Smooths the outlines in an atlas's sf geometry, turning voxel-edge
stair-steps into curves. Shared boundaries between neighbouring regions
are closed again afterwards, so the parcellation stays gap-free.

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

  Smoothing strength, 0 to 1. The default 0.4 rounds a millimetre voxel
  grid without distorting shapes.

- method:

  How to smooth. `"close"` (the default) rounds solid shapes well but
  fills holes narrower than the smoothing distance. `"chaikin"`,
  `"ksmooth"` and `"spline"` move vertices instead, so holes stay open.
  See details.

- vertex_budget:

  `"preserve"` (the default) simplifies the rounded geometry back
  towards the vertex count it started with; `"free"` lets it grow. See
  details.

- close_gaps:

  Whether to close the hairline gaps rounding opens along shared
  boundaries. Set `FALSE` for geometry that is not a coverage, such as
  separate tract tubes.

- labels:

  Which labels to smooth: a regular expression, or a function that takes
  the atlas and returns one. Pass `context_pattern`, without calling it,
  to select the atlas's context.

- exclude:

  Optional regex. Matching labels are left alone. Only one of `labels`
  or `exclude` may be given.

## Value

The `ggseg_atlas`, with its geometry rounded off.

## Choosing a method

`"close"` is a morphological closing: a positive then negative
[`sf::st_buffer()`](https://r-spatial.github.io/sf/reference/geos_unary.html).
It rounds outlines but **fills holes narrower than the smoothing
distance**, which erases the sulci of a thin cortical ribbon. The other
three come from
[`smoothr::smooth()`](https://strimas.com/smoothr/reference/smooth.html)
and move vertices rather than dilating the shape, so enclosed holes
survive. Reach for `"close"` on solid shapes such as tract tubes and
`"chaikin"` when the geometry has holes worth keeping.

`smoothness` means the same amount of smoothing whichever method you
pick, so switching method does not mean re-finding the value.

## What rounding costs

Rounding a corner replaces it with an arc, and an arc costs vertices: a
morphological close lays down eight segments per quarter turn. Left
alone, smoothing can leave an atlas several times larger than it found
it and undo any simplification that came before.

`vertex_budget = "preserve"` therefore simplifies the rounded geometry
back towards its original count. That is a real simplification pass, so
shapes move a little beyond what the rounding alone did, and it stops
once a pass buys nothing: geometry already as sparse as its shapes
allow, such as a raw voxel tracing, keeps some of the growth.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
which simplifies and smooths in one call and is what most builds want;
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
to reduce the vertex count;
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
to grow or shrink regions. Simplify before smoothing, never after.

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`count_vertices()`](https://ggsegverse.github.io/ggseg.extra/reference/count_vertices.md)

## Examples

``` r
dk <- ggseg.formats::dk()

# Round off the voxel staircase.
atlas_smooth(dk, smoothness = 0.4)
#> 
#> ── dk ggseg atlas ──────────────────────────────────────────────────────────────
#> Type: cortical
#> Regions: 35
#> Hemispheres: left, right
#> Views: inferior, lateral, superior, medial
#> Palette: ✔
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (vertices)
#> ────────────────────────────────────────────────────────────────────────────────
#>    hemi                            region                      label
#> 1  left banks of superior temporal sulcus                lh_bankssts
#> 2  left         caudal anterior cingulate lh_caudalanteriorcingulate
#> 3  left             caudal middle frontal     lh_caudalmiddlefrontal
#> 4  left                   corpus callosum          lh_corpuscallosum
#> 5  left                            cuneus                  lh_cuneus
#> 6  left                        entorhinal              lh_entorhinal
#> 7  left                          fusiform                lh_fusiform
#> 8  left                 inferior parietal        lh_inferiorparietal
#> 9  left                 inferior temporal        lh_inferiortemporal
#> 10 left                 isthmus cingulate        lh_isthmuscingulate
#>            lobe
#> 1      temporal
#> 2     cingulate
#> 3       frontal
#> 4  white matter
#> 5     occipital
#> 6      temporal
#> 7      temporal
#> 8      parietal
#> 9      temporal
#> 10    cingulate
#> ... with 60 more rows

if (FALSE) { # \dontrun{
# Leave the brain outline alone.
atlas_smooth(dk, smoothness = 0.4, exclude = context_pattern)

# Round a cortical ribbon without closing its sulci.
atlas_smooth(
  dk,
  smoothness = 0.4,
  method = "chaikin",
  labels = context_pattern
)
} # }
```
