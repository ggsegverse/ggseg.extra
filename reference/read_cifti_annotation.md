# Read CIFTI annotation file

Reads a CIFTI dense label file (`.dlabel.nii`) and extracts region
information for both hemispheres. Returns data in the same format as
[`read_annotation_data()`](https://ggsegverse.github.io/ggseg.extra/reference/read_annotation_data.md)
for use with the cortical atlas pipeline.

## Usage

``` r
read_cifti_annotation(cifti_file)
```

## Arguments

- cifti_file:

  Path to a `.dlabel.nii` CIFTI file.

## Value

A tibble with columns: hemi, region, label, colour, vertices

## Details

The CIFTI file must be in fsaverage5 space (10,242 vertices per
hemisphere). If your file uses a different resolution, resample it first
with Connectome Workbench:

    wb_command -cifti-resample input.dlabel.nii ...

## Examples

``` r
if (FALSE) { # \dontrun{
atlas_data <- read_cifti_annotation("parcellation.dlabel.nii")
} # }
```
