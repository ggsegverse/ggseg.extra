# Build a slab table from a bounding box

**\[deprecated\]**

Renamed to
[`subcortical_views()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_views.md).
The table it returns names the atlas's views, and `view` is the word the
rest of the ecosystem uses for them — `name` here becomes the `view`
column of the built atlas, and the value
[`ggseg.formats::atlas_views()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_views.html)
reports.

## Usage

``` r
subcortical_slabs(
  volume,
  labels,
  coronal = 0,
  axial = 0,
  sagittal = 0,
  pad = 0,
  reorient = TRUE
)
```

## Arguments

- volume:

  Path to a label volume, or an integer array already in the builder's
  frame.

- labels:

  Integer label ids whose combined bounding box frames the slabs.

- coronal, axial, sagittal:

  Number of slabs to produce for each orientation (`0` = none).

- pad:

  Voxels by which to expand the bounding box before slabbing.

- reorient:

  Passed to the internal volume reader; must match the value
  [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  uses (default `TRUE`).

## Value

A data.frame with columns `name`, `type`, `start`, `end`.

## Examples

``` r
# Deprecated. Use subcortical_views():
vol <- array(0L, dim = c(20, 20, 20))
vol[8:12, 6:14, 9:11] <- 17L
subcortical_views(vol, labels = 17, coronal = 3, axial = 2)
#>        name    type start end
#> 1 coronal_1 coronal     6   8
#> 2 coronal_2 coronal     9  10
#> 3 coronal_3 coronal    11  14
#> 4   axial_1   axial     9   9
#> 5   axial_2   axial    10  11
```
