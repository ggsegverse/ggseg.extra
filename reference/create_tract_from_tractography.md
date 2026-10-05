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
  skip_existing = NULL,
  coord_space = c("infer", "voxel", "mm")
)
```

## Arguments

- input_tracts:

  Paths to tractography files (`.trk` or `.tck`), or a named list of
  coordinate matrices where each matrix has N rows and 3 columns (x, y,
  z).

- verbose:

  How much to print: `0` silent, `1` progress (the default), `2` adds
  FreeSurfer's own output. `TRUE` and `FALSE` mean `1` and `0`. Falls
  back to `options("ggseg.extra.verbose")`, then `GGSEG_EXTRA_VERBOSE`.

- ...:

  Not used. Present so that a mistyped or misplaced argument is reported
  against this function rather than silently ignored; anything passed
  here is an error. Geometry is shaped after the build: see
  [`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
  or
  [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  and
  [`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
  individually.

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

  Where to put the intermediate files. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), from
  `options("ggseg.extra.output_dir")` or `GGSEG_EXTRA_OUTPUT_DIR`.

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

  Unknown entries error.

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

  - 3: Extract contours

  - 4: Build the atlas

  Use `steps = 1` for a 3D-only atlas. Geometry is shaped after the
  build, not during it: see
  [`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md).

- cleanup:

  Remove the intermediate files afterwards. Default `TRUE`, from
  `options("ggseg.extra.cleanup")` or `GGSEG_EXTRA_CLEANUP`.

- skip_existing:

  Reuse a step's intermediate files when they already exist, instead of
  running the step. Default `FALSE`, from
  `options("ggseg.extra.skip_existing")` or `GGSEG_EXTRA_SKIP_EXISTING`.

  A cache records which ggseg.extra wrote it, not what it was built
  from, so reuse cannot tell that the volume or lookup table has
  changed. Reuse is therefore asked for rather than assumed, and is
  reported when it happens. To continue an interrupted build, either
  pass `TRUE` or leave the finished steps out of `steps`.

- coord_space:

  The space the streamline coordinates are in, when `input_tracts` is a
  list of coordinate matrices. One of `"infer"` (the default), `"voxel"`
  for voxel indices, or `"mm"` for RAS world millimetres. Inference is a
  heuristic: it cannot always tell, and a wrong guess does not error –
  it places the tract in the wrong space and produces a
  plausible-looking atlas. Declare the space when you know it. Whichever
  applies is reported at `verbose >= 1`.

  Tractography files need no declaration: `.trk` and `.tck` files are
  always read into RAS world millimetres, and `"voxel"` is an error for
  them.

## Value

A `ggseg_atlas` object with type `"tract"`, containing region metadata,
tube meshes for 3D rendering, colours, and optionally sf geometry for 2D
projection plots. A run that stops before the final step returns `NULL`,
invisibly.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
to simplify and round off the result, which most builds want next.

Other atlas creation:
[`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md),
[`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md),
[`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md),
[`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md),
[`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md),
[`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md),
[`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md),
[`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md),
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md),
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)

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

# Coordinate matrices: declare their space rather than letting it be
# inferred
atlas <- create_tract_from_tractography(
  input_tracts = list(cst_left = cst_left_points),
  coord_space = "mm"
)

# View with ggseg3d
ggseg3d::ggseg3d(atlas = atlas)
} # }
```
