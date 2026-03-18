# Create maximum intensity projection of volume

Projects a 3D volume onto a 2D plane by taking the maximum value along
each ray. Optionally restricts to a subset of slices.

## Usage

``` r
volume_projection(vol, view, start = NULL, end = NULL, hemi = NULL)
```

## Arguments

- vol:

  3D array in RAS orientation

- view:

  "axial", "coronal", or "sagittal"

- start:

  First slice index (NULL for full projection)

- end:

  Last slice index (NULL for full projection)

- hemi:

  Hemisphere for sagittal views: "left" or "right"

## Value

2D matrix ready for image() display
