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
  verbose = get_verbose(),
  views = lifecycle::deprecated(),
  ...,
  input_aseg = NULL,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  tube_opts = list(),
  slabs = NULL,
  vertex_size_limits = NULL,
  steps = NULL,
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- input_tracts:

  Paths to tractography files (`.trk` or `.tck`), or a named list of
  coordinate matrices where each matrix has N rows and 3 columns (x, y,
  z).

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

- views:

  **\[deprecated\]** Use `slabs` instead.

- ...:

  Catches the retired `dilate`, `smoothness` and `tolerance` arguments,
  so a call that still passes one keeps working and says so. These are
  post-creation steps now: see
  [`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  and
  [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md).
  Anything else in `...` is an error, as an unused argument always was.

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

- tube_opts:

  Named list controlling how a bundle of streamlines becomes a 3D tube
  mesh, with these entries and defaults:

  - `centerline_method` (`"mean"`) and `n_points` (`50`): how one
    centerline is derived from many streamlines, and how many points it
    is resampled to. All tracts are resampled to the same length so the
    tubes are consistent.

  - `tube_radius` (`5`) and `tube_segments` (`8`): the thickness of the
    tube drawn along that centerline, and how many segments go around
    its circumference. `tube_radius` also takes `"density"`, to scale
    thickness by how many streamlines pass through each point.

  Unknown entries error. Replaces the flat `tube_radius`,
  `tube_segments`, `n_points` and `centerline_method` arguments.

- slabs:

  A data.frame specifying projection slabs. If NULL, a default set of
  tract slabs is derived from the volume dimensions.

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

- cleanup:

  Remove intermediate files after atlas creation. If not specified, uses
  `options("ggseg.extra.cleanup")` or the `GGSEG_EXTRA_CLEANUP`
  environment variable. Default is TRUE.

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

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
