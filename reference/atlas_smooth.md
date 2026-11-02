# Round off an atlas's voxel staircase

Smooths the outlines in an atlas's sf geometry, turning voxel-edge
stair-steps into curves. Shared boundaries between neighbouring regions
are closed again afterwards, so the parcellation stays gap-free.

## Usage

``` r
atlas_smooth(
  atlas,
  smoothness = 0.4,
  method = c("chaikin", "close", "ksmooth", "spline"),
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

  How to smooth. `"chaikin"` (the default), `"ksmooth"` and `"spline"`
  move vertices, so holes stay open. `"close"` rounds solid shapes more
  cleanly but fills holes narrower than the smoothing distance. See
  details.

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

`"chaikin"`, `"ksmooth"` and `"spline"` come from
[`smoothr::smooth()`](https://strimas.com/smoothr/reference/smooth.html)
and move vertices rather than dilating the shape, so enclosed holes
survive. `"chaikin"` is the default because the default must preserve
sulci: a brain's shape is largely its holes, and a method that fills
them is the wrong thing to do to geometry you have not looked at yet.

`"close"` is a morphological closing: a positive then negative
[`sf::st_buffer()`](https://r-spatial.github.io/sf/reference/geos_unary.html).
It rounds outlines more cleanly than the vertex movers, but **fills
holes narrower than the smoothing distance**. On a thin cortical ribbon
that erases the sulci and welds the gyri into a solid mantle – at
`smoothness = 0.4` on a millimetre grid it took one aseg backdrop from
463 enclosed rings to 27. Reach for it on solid shapes, such as tract
tubes, where there are no holes to lose.

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
[`atlas_view_region_counts()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_region_counts.md),
[`atlas_view_remove_sparse()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_remove_sparse.md),
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
#> Views: inferior, lateral, medial, superior
#> Palette: ✔
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (vertices)
#> ────────────────────────────────────────────────────────────────────────────────
#>    hemi                  region                      label
#> 1  left                bankssts                lh_bankssts
#> 2  left caudalanteriorcingulate lh_caudalanteriorcingulate
#> 3  left     caudalmiddlefrontal     lh_caudalmiddlefrontal
#> 4  left          corpuscallosum          lh_corpuscallosum
#> 5  left                  cuneus                  lh_cuneus
#> 6  left              entorhinal              lh_entorhinal
#> 7  left                fusiform                lh_fusiform
#> 8  left        inferiorparietal        lh_inferiorparietal
#> 9  left        inferiortemporal        lh_inferiortemporal
#> 10 left        isthmuscingulate        lh_isthmuscingulate
#>                              display         lobe
#> 1  banks of superior temporal sulcus     temporal
#> 2          caudal anterior cingulate    cingulate
#> 3              caudal middle frontal      frontal
#> 4                    corpus callosum white matter
#> 5                             cuneus    occipital
#> 6                         entorhinal     temporal
#> 7                           fusiform     temporal
#> 8                  inferior parietal     parietal
#> 9                  inferior temporal     temporal
#> 10                 isthmus cingulate    cingulate
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
