# Snapshot a volumetric slice

Creates a PNG image of a single slice from a volumetric label file.
Supports MGZ and NIfTI formats.

## Usage

``` r
snapshot_slice(
  lab,
  x,
  y,
  z,
  view,
  label_file = NULL,
  output_dir,
  skip_existing = get_skip_existing(),
  width = 400,
  height = 400
)
```

## Arguments

- lab:

  Path to volume file (.mgz, .nii, .nii.gz) or .label file. If a .label
  file is provided, label_file must also be provided.

- x, y, z:

  Slice coordinates

- view:

  View type: "axial", "sagittal", or "coronal"

- label_file:

  Path to volume file (required when lab is a .label file)

- output_dir:

  Output directory for PNG

- skip_existing:

  Skip if output file exists

- width, height:

  Image dimensions in pixels

## Value

Invisible NULL
