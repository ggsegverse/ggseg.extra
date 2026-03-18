# Snapshot a partial volume projection

Creates a PNG image showing maximum intensity projection of a volume
subset.

## Usage

``` r
snapshot_partial_projection(
  vol,
  view,
  start,
  end,
  view_name,
  label,
  output_dir,
  colour = "red",
  hemi = NULL,
  width = 400,
  height = 400,
  skip_existing = get_skip_existing()
)
```

## Arguments

- vol:

  3D array with voxel values

- view:

  "axial", "coronal", or "sagittal"

- start:

  First slice index

- end:

  Last slice index

- view_name:

  Name for this view (used in filename)

- label:

  Label for filename

- output_dir:

  Output directory

- colour:

  Colour for non-zero voxels

- hemi:

  Hemisphere for sagittal views: "left" or "right"

- width, height:

  Image dimensions

- skip_existing:

  If TRUE, skip if output file already exists

## Value

Invisible path to output file, or NULL if no voxels
