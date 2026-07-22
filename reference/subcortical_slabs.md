# Build subcortical slabs from a label bounding box

Computes evenly spaced coronal, axial and/or sagittal slabs spanning the
bounding box of the requested labels, ready to pass as the `slabs`
argument of
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md).

**\[deprecated\]**

`subcortical_views()` was renamed to `subcortical_slabs()` to match the
`slabs` argument of
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
and
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md).

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

subcortical_views(
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

## Details

The volume is read with the **same** axis reorientation the builder uses
internally, so the returned slab indices are in the projection frame.
This avoids a subtle trap:
[`RNifti::readNifti()`](https://rdrr.io/pkg/RNifti/man/readNifti.html)
and the builder's reader can return different axis orders, so a bounding
box computed from the RNifti array points the slabs at the wrong slices
(silently producing empty views). Always derive slabs with this function
rather than indexing the volume by hand.

## See also

[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
[`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)

## Examples

``` r
vol <- array(0L, dim = c(20, 20, 20))
vol[8:12, 6:14, 9:11] <- 17L
subcortical_slabs(vol, labels = 17, coronal = 3, axial = 2)
#>        name    type start end
#> 1 coronal_1 coronal     6   8
#> 2 coronal_2 coronal     9  10
#> 3 coronal_3 coronal    11  14
#> 4   axial_1   axial     9   9
#> 5   axial_2   axial    10  11
```
