# Orient 2D slice for display

With RAS+ input, [`image()`](https://rdrr.io/r/graphics/image.html)
already displays axial and coronal correctly. Only left-hemisphere
sagittal needs a horizontal flip so hemispheres face each other when
plotted side-by-side.

## Usage

``` r
orient_slice_2d(slice, view, hemi = NULL)
```

## Arguments

- slice:

  2D matrix

- view:

  "axial", "coronal", or "sagittal"

- hemi:

  Hemisphere for sagittal views: "left" or "right". Left sagittal is
  flipped horizontally so left and right face each other when plotted.

## Value

Transformed 2D matrix
