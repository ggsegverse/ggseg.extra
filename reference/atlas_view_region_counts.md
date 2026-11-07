# Count the drawn regions in each view

Count the drawn regions in each view

## Usage

``` r
atlas_view_region_counts(atlas)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with 2D geometry.

## Value

A named integer vector, one entry per view, in view order. Views holding
nothing but context count zero.

## See also

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
[`atlas_view_remove_sparse()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_remove_sparse.md),
[`count_vertices()`](https://ggsegverse.github.io/ggseg.extra/reference/count_vertices.md)

## Examples

``` r
atlas_view_region_counts(ggseg.formats::aseg())
#>       axial_2     coronal_2 sagittal_left 
#>            29            26            20 
```
