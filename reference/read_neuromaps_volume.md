# Read neuromaps volume annotation via surface projection

Projects an MNI152-space NIfTI volume onto the fsaverage5 surface via
FreeSurfer's `mri_vol2surf`, then discretizes the projected per-vertex
values using the same binning logic as
[`read_neuromaps_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_neuromaps_annotation.md).

## Usage

``` r
read_neuromaps_volume(
  nifti_file,
  breaks = NULL,
  label_table = NULL,
  output_dir = tempdir()
)
```

## Arguments

- nifti_file:

  Path to a `.nii` or `.nii.gz` file in MNI152 space.

- breaks:

  How to cut a continuous map into bins. One of:

  - `NULL`, the default: quantile bins, as many as Sturges' rule gives
    for the number of vertices (`1 + log2(n)`), kept between 5 and 20.

  - A single number: that many quantile bins.

  - Increasing numbers: the edges of the bins.

  - A function that takes the map's finite values and returns the edges,
    such as `function(x) pretty(x, 6)` for round, equal-width bins.

  Quantile bins each hold about the same number of vertices. Both
  hemispheres are cut on the same edges, so a bin covers the same range
  of values on the left and on the right. Values outside edges you
  supply are left `unknown`, with a warning. Ignored for parcellation
  data.

- label_table:

  Optional data.frame mapping parcel ids to region names and colours, as
  for
  [`read_neuromaps_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_neuromaps_annotation.md).
  Supplying one declares the volume a parcellation. Continuous volumes
  are binned and the bins named `bin_1`, `bin_2`, and so on.

- output_dir:

  Directory for intermediate surface overlay files.

## Value

A tibble with columns: hemi, region, label, colour, vertices

## Details

A volume whose voxels are all whole numbers, or one given a
`label_table`, is treated as a parcellation and sampled with
nearest-neighbour interpolation, so every vertex takes the id of a
parcel in the volume. Any other volume is treated as a continuous map
and sampled with trilinear interpolation.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas_data <- read_neuromaps_volume("map.nii.gz", breaks = 7)
} # }
```
