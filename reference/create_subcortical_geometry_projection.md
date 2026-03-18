# Create 2D geometry for subcortical atlas using projections

Generate polygon outlines for subcortical structures using volumetric
projections instead of slices. This shows all structures in their
spatial relationships - like an X-ray view.

## Usage

``` r
create_subcortical_geometry_projection(
  input_volume,
  colortable,
  views = NULL,
  cortex_slices = NULL,
  output_dir = NULL,
  vertex_size_limits = NULL,
  dilate = NULL,
  tolerance = NULL,
  smoothness = NULL,
  verbose = get_verbose(),
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- input_volume:

  Path to segmentation volume

- colortable:

  Color lookup table data.frame

- views:

  A data.frame defining projection views. Columns: `name` (view label),
  `type` ("axial", "coronal", "sagittal"), `start` (first slice), `end`
  (last slice).

- cortex_slices:

  A data.frame specifying cortex slice positions. Columns: `x`, `y`,
  `z`, `view`, `name`. Cortex uses single slices (not projections) to
  show outlines rather than filled blobs.

- output_dir:

  Output directory for intermediate files

- vertex_size_limits:

  Size limits for contour filtering

- dilate:

  Dilation amount for image processing

- tolerance:

  Vertex reduction tolerance

- smoothness:

  Contour smoothing amount

- verbose:

  Print progress

- cleanup:

  Remove intermediate files

- skip_existing:

  Skip existing files

## Value

sf data.frame with label, view, and geometry columns

## Details

Subcortical structures are projected (all voxels visible), while cortex
reference outlines use single slices (to show outline, not filled blob).
