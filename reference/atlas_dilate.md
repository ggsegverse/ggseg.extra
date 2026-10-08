# Grow or shrink an atlas's regions

Buffers region geometry outward, so structures too thin to read at
plotting size survive. This is the post-creation counterpart of the
snapshot-stage dilation the atlas pipelines used to apply: it works on
the finished atlas, so a build does not have to be repeated to retune
it.

## Usage

``` r
atlas_dilate(atlas, amount, labels = NULL, exclude = NULL)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with 2D geometry.

- amount:

  Buffer distance in geometry units. Positive grows a region, negative
  shrinks it, `0` returns the atlas unchanged.

- labels, exclude:

  Which labels to dilate, or which to leave alone: a regular expression,
  or a function that takes the atlas and returns one. Pass
  `context_pattern`, without calling it, to select the atlas's context.
  Give at most one.

## Value

The `ggseg_atlas`, in the representation it arrived in.

## Details

`amount` is a distance in the atlas's own geometry units, not voxels or
pixels. Start small and look: a value that reads well on one atlas will
not transfer to another built on a different grid.

Dilate the structures, not the anatomical context. Grown by even a
little, a grey brain silhouette closes its sulci and flattens into a
blob, so pass `exclude` (or `labels`) to keep it out.

## See also

[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
and
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
the other post-creation geometry steps.

Other atlas geometry:
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
[`count_vertices()`](https://ggsegverse.github.io/ggseg.extra/reference/count_vertices.md)

## Examples

``` r
dk <- ggseg.formats::dk()

# Grow the structures and leave the grey brain alone
atlas_dilate(dk, 0.5, exclude = context_pattern)
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
```
