# Create brain atlas from subcortical segmentation

**\[experimental\]**

Turn a subcortical segmentation volume (like `aseg.mgz`) into a brain
atlas with 3D meshes for each structure. The function extracts each
labelled region from the volume, creates a surface mesh, and smooths it.

For 2D plotting, the function can also generate slice views by taking
snapshots at specified coordinates and extracting contours.

Requires FreeSurfer for mesh generation.

## Usage

``` r
create_subcortical_from_volume(
  input_volume,
  input_lut = NULL,
  atlas_name = NULL,
  views = NULL,
  output_dir = NULL,
  vertex_size_limits = NULL,
  dilate = NULL,
  tolerance = NULL,
  smoothness = NULL,
  verbose = get_verbose(),
  cleanup = NULL,
  skip_existing = NULL,
  decimate = 0.5,
  steps = NULL
)
```

## Arguments

- input_volume:

  Path to the segmentation volume. Supports `.mgz`, `.nii`, and
  `.nii.gz` formats. Typically this is `aseg.mgz` or a custom
  segmentation in the same space.

- input_lut:

  Path to a FreeSurfer-style colour lookup table that maps label IDs to
  region names and colours (e.g., `FreeSurferColorLUT.txt` or
  `ASegStatsLUT.txt`), or a data.frame with columns `region` and colour
  columns (R, G, B or hex). If NULL, region names will be generic (e.g.,
  "region_0010") and the atlas will have no palette.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- views:

  A data.frame specifying projection views with columns `name`, `type`
  ("axial", "coronal", "sagittal"), `start` (first slice), `end` (last
  slice). Default projects entire volume from each direction. Unlike
  slices, projections show ALL structures in their spatial
  relationships - like an X-ray view.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- vertex_size_limits:

  Numeric vector of length 2 setting minimum and maximum vertex count
  for polygons. Polygons outside this range are filtered out. Default
  NULL applies no limits.

- dilate:

  Dilation iterations for 2D polygons. Useful for filling small gaps
  between structures.

- tolerance:

  Simplification tolerance for 2D polygons. Higher values produce
  simpler shapes with fewer vertices (typical range: 0.1–2). Passed to
  [`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html).
  If not specified, uses `options("ggseg.extra.tolerance")` or the
  `GGSEG_EXTRA_TOLERANCE` environment variable. Default is 1.

- smoothness:

  Smoothing factor for 2D contours. Higher values produce smoother
  region boundaries (typical range: 3–15). Passed to
  [`smoothr::smooth()`](https://strimas.com/smoothr/reference/smooth.html).
  If not specified, uses `options("ggseg.extra.smoothness")` or the
  `GGSEG_EXTRA_SMOOTHNESS` environment variable. Default is 5.

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

- cleanup:

  Remove intermediate files after atlas creation. If not specified, uses
  `options("ggseg.extra.cleanup")` or the `GGSEG_EXTRA_CLEANUP`
  environment variable. Default is TRUE.

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

- decimate:

  Mesh decimation factor between 0 and 1. Reduces the number of faces in
  3D meshes using quadric edge decimation (via
  [`Rvcg::vcgQEdecim()`](https://rdrr.io/pkg/Rvcg/man/vcgQEdecim.html)).
  A value of 0.5 reduces faces by 50%. Set to NULL to skip decimation.
  Requires the Rvcg package. Default is 0.5.

- steps:

  Which pipeline steps to run. Default NULL runs all steps. Steps are:

  - 1: Extract labels from volume and get colour table

  - 2: Create meshes for each structure

  - 3: Build atlas data (3D only if stopping here)

  - 4: Create projection snapshots

  - 5: Process images

  - 6: Extract contours

  - 7: Smooth contours

  - 8: Reduce vertices

  - 9: Build final atlas with 2D geometry

  Use `steps = 1:3` for 3D-only atlas. Use `steps = 7:8` to iterate on
  smoothing and reduction parameters.

## Value

A `ggseg_atlas` object with region metadata (core), 3D meshes, a colour
palette, and optionally sf geometry for 2D slice plots.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create 3D-only subcortical atlas from aseg
atlas <- create_subcortical_from_volume(
  input_volume = "path/to/aseg.mgz",
  input_lut = "path/to/FreeSurferColorLUT.txt",
  steps = 1:3
)

# View with ggseg3d
ggseg3d(atlas = atlas, hemisphere = "subcort")

# Full atlas with 2D slices
atlas <- create_subcortical_from_volume(
  input_volume = "path/to/aseg.mgz",
  input_lut = "path/to/ASegStatsLUT.txt"
)

# Post-process to remove/modify regions (functions from ggseg.formats)
atlas <- atlas |>
  atlas_region_remove("White-Matter") |>
  atlas_region_contextual("Cortex")
} # }
```
