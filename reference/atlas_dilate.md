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

  Regex selecting which labels to dilate, or which to leave alone. Give
  at most one.

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
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Grow the structures and leave the grey brain alone
atlas <- atlas_dilate(atlas, 0.5, exclude = "^cortex")
} # }
```
