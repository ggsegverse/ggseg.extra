# Create brain atlas from white matter tracts

**\[experimental\]**

Turn tractography streamlines into a brain atlas where each tract is
rendered as a 3D tube. The function computes a centerline from the
streamlines and generates a tube mesh around it.

You can provide tract data in several formats: TRK files from TrackVis,
TCK files from MRtrix, or coordinate matrices directly in R. The
function reads the streamlines, extracts a representative centerline (by
averaging or selecting the medoid), and builds a tube mesh for 3D
rendering.

For tracts with many streamlines, set `tube_radius = "density"` to make
the tube thicker where more streamlines pass through.

## Usage

``` r
create_tract_from_tractography(
  input_tracts,
  input_aseg = NULL,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  tube_radius = 5,
  tube_segments = 8,
  n_points = 50,
  centerline_method = c("mean", "medoid"),
  slabs = NULL,
  vertex_size_limits = NULL,
  dilate = NULL,
  tolerance = NULL,
  smoothness = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  steps = NULL,
  views = lifecycle::deprecated()
)
```

## Arguments

- input_tracts:

  Paths to tractography files (`.trk` or `.tck`), or a named list of
  coordinate matrices where each matrix has N rows and 3 columns (x, y,
  z).

- input_aseg:

  Path to a segmentation volume (`.mgz`, `.nii`) used to draw cortex
  outlines in 2D views. Required for steps 2+.

- input_lut:

  Path to a color lookup table (LUT) file, or a data.frame with a
  `region` column (or a FreeSurfer-style `label` column) plus colour
  columns (R, G, B or hex). Rows must be in the same order as
  `input_tracts`. Use this to provide tract names and colours. If NULL,
  names are derived from filenames or list names, and colours will be
  auto-generated.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- tube_radius:

  Controls the tube thickness. Either a single numeric value for uniform
  radius, or `"density"` to scale radius by how many streamlines pass
  through each point.

- tube_segments:

  Number of segments around the tube circumference. Higher values make
  smoother tubes but larger meshes. Default 8 is a good balance.

- n_points:

  Number of points to resample the centerline to. All tracts are
  resampled to this length for consistent tube generation.

- centerline_method:

  How to extract the centerline from multiple streamlines: `"mean"`
  averages coordinates point-by-point, `"medoid"` selects the single
  most representative streamline.

- slabs:

  A data.frame specifying projection slabs. If NULL, a default set of
  tract slabs is derived from the volume dimensions.

- vertex_size_limits:

  Numeric vector of length 2 setting minimum and maximum vertex count
  for polygons. Polygons outside this range are filtered out. Default
  NULL applies no limits.

- dilate:

  Dilation iterations for 2D polygons. Useful for filling small gaps
  between structures.

- tolerance:

  **\[deprecated\]** sf simplification is no longer applied during atlas
  creation. Use
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  on the returned atlas instead. Supplying a value emits a lifecycle
  warning and is otherwise ignored.

- smoothness:

  **\[deprecated\]** sf contour smoothing is no longer applied during
  atlas creation. Use
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  on the returned atlas instead. Supplying a value emits a lifecycle
  warning and is otherwise ignored.

- cleanup:

  Remove intermediate files after atlas creation. If not specified, uses
  `options("ggseg.extra.cleanup")` or the `GGSEG_EXTRA_CLEANUP`
  environment variable. Default is TRUE.

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

- steps:

  Which pipeline steps to run. Default NULL runs all steps. Steps are:

  - 1: Read tractography and create tube meshes

  - 2: Create projection snapshots

  - 3: Process images

  - 4: Extract contours

  - 5: Smooth contours

  - 6: Reduce vertices

  - 7: Build atlas

  Use `steps = 1` for 3D-only atlas. Use `steps = 5:7` to iterate on
  smoothing and vertex reduction.

- views:

  **\[deprecated\]** Use `slabs` instead.

## Value

A `ggseg_atlas` object with type `"tract"`, containing region metadata,
tube meshes for 3D rendering, colours, and optionally sf geometry for 2D
projection plots.

## Examples

``` r
if (FALSE) { # \dontrun{
# From TRK files (names derived from filenames)
atlas <- create_tract_from_tractography(
  input_tracts = c("cst_left.trk", "cst_right.trk")
)

# With custom names and colours via LUT
atlas <- create_tract_from_tractography(
  input_tracts = c("cst_left.trk", "cst_right.trk"),
  input_lut = "tract_colors.txt"
)

# View with ggseg3d
ggseg3d(atlas = atlas)
} # }
```
