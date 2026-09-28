# Count the vertices an atlas carries

Reports how many polygon vertices each region is drawn from. The total
is the figure the `create_*()` pipelines warn about when an atlas is
large, and the one
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
brings down, so it is the number to watch when tuning an atlas for size.

## Usage

``` r
count_vertices(atlas)
```

## Arguments

- atlas:

  A `ggseg_atlas`.

## Value

A named integer vector, one element per geometry label value, in the
order those values appear in the atlas. When geometry is missing a
label, it is counted in a separate `"<NA>"` entry. Take
[`sum()`](https://rdrr.io/r/base/sum.html) of the vector for the atlas
total; that total is every vertex the atlas carries, so it always agrees
with the large-atlas warning.

## Details

Counts are summed across views, so a region that appears on the lateral
and medial views is reported once.

## See also

[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
to bring the count down, and
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
which raises it again – rounding a corner off means inserting points.

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# The total is what the large-atlas warning reports.
sum(count_vertices(my_atlas))

# Which regions are the expensive ones?
sort(count_vertices(my_atlas), decreasing = TRUE) |> head()
} # }
```
