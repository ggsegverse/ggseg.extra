# Snapshot a volume slice

Creates a PNG image of a volume at a specific slice position.

## Usage

``` r
snapshot_volume_slice(
  vol,
  x,
  y,
  z,
  view,
  label,
  output_dir,
  colour = "red",
  width = 400,
  height = 400,
  skip_existing = get_skip_existing()
)
```

## Arguments

- vol:

  3D array with voxel values

- x, y, z:

  Slice coordinates

- view:

  "axial", "sagittal", or "coronal"

- label:

  Label for filename

- output_dir:

  Output directory

- colour:

  Colour for non-zero voxels

- width, height:

  Image dimensions

- skip_existing:

  If TRUE, skip if output file already exists

## Value

Invisible path to output file, or NULL if no voxels in slice
