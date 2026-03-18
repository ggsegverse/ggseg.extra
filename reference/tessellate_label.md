# Tessellate a single label from a volume

Creates a mesh from a single label in a segmentation volume using
FreeSurfer's tessellation pipeline.

## Usage

``` r
tessellate_label(
  volume_file,
  label_id,
  output_dir,
  verbose = get_verbose(),
  skip_existing = get_skip_existing()
)
```

## Arguments

- volume_file:

  Path to segmentation volume

- label_id:

  Numeric label ID

- output_dir:

  Output directory for intermediate files

- verbose:

  Print progress

- skip_existing:

  If TRUE, skip files that already exist

## Value

list with vertices (data.frame) and faces (data.frame)
