# Read neuromaps volume annotation via surface projection

Projects an MNI152-space NIfTI volume onto the fsaverage5 surface via
FreeSurfer's `mri_vol2surf`, then discretizes the projected per-vertex
values using the same binning logic as
[`read_neuromaps_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_neuromaps_annotation.md).

## Usage

``` r
read_neuromaps_volume(nifti_file, n_bins = NULL, output_dir = tempdir())
```

## Arguments

- nifti_file:

  Path to a `.nii` or `.nii.gz` file in MNI152 space.

- n_bins:

  Number of quantile bins for continuous data. When `NULL` (default),
  auto-detected via Sturges' rule. Ignored for integer data.

- output_dir:

  Directory for intermediate surface overlay files.

## Value

A tibble with columns: hemi, region, label, colour, vertices

## Examples

``` r
if (FALSE) { # \dontrun{
atlas_data <- read_neuromaps_volume("map.nii.gz", n_bins = 7)
} # }
```
