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
  atlas_name = NULL,
  input_lut = NULL,
  tube_radius = 5,
  tube_segments = 8,
  n_points = 50,
  centerline_method = c("mean", "medoid"),
  views = NULL,
  output_dir = NULL,
  verbose = get_verbose(),
  tolerance = NULL,
  smoothness = NULL,
  cleanup = NULL,
  skip_existing = NULL,
  dilate = NULL,
  vertex_size_limits = NULL,
  steps = NULL
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

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- input_lut:

  Path to a color lookup table (LUT) file, or a data.frame with columns
  `region` and colour columns (R, G, B or hex). Use this to provide
  tract names and colours. If NULL, names are derived from filenames or
  list names, and the atlas will have no palette.

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

- views:

  A data.frame specifying projection views. If NULL, uses
  [`default_tract_views()`](https://ggsegverse.github.io/ggseg.extra/reference/default_tract_views.md).

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

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

- cleanup:

  Remove intermediate files after atlas creation. If not specified, uses
  `options("ggseg.extra.cleanup")` or the `GGSEG_EXTRA_CLEANUP`
  environment variable. Default is TRUE.

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

- dilate:

  Dilation iterations for 2D polygons. Useful for filling small gaps
  between structures.

- vertex_size_limits:

  Numeric vector of length 2 setting minimum and maximum vertex count
  for polygons. Polygons outside this range are filtered out. Default
  NULL applies no limits.

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
