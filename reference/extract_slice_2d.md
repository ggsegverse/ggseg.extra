# Extract 2D slice from 3D volume

Extracts a single slice with correct orientation for display. Handles
all view-specific transformations internally.

## Usage

``` r
extract_slice_2d(vol, view, pos, hemi = NULL)
```

## Arguments

- vol:

  3D array in RAS orientation

- view:

  "axial", "coronal", or "sagittal"

- pos:

  Slice position (x for sagittal, y for coronal, z for axial)

## Value

2D matrix ready for image() display
