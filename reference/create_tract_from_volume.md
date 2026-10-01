# Create a white matter tract atlas from a label volume

**\[experimental\]**

Build a tract atlas from a volumetric white-matter tract *label map* —
one integer label per tract — rather than from streamlines. Each tract's
voxel cloud is reduced to an ordered centerline with a principal curve,
and the centerlines are handed to
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md),
which builds the 3D tubes and 2D projection. This suits probabilistic
tract atlases distributed as NIfTI label volumes (e.g. AtlasTrack).

## Usage

``` r
create_tract_from_volume(
  input_volume,
  input_lut,
  n_points = 50L,
  min_voxels = 30L,
  smoother = "smooth_spline",
  verbose = get_verbose(),
  ...,
  input_aseg = NULL,
  exclude = NULL,
  atlas_name = NULL,
  output_dir = NULL
)
```

## Arguments

- input_volume:

  Path or `RNifti` image of the tract label volume.

- input_lut:

  Path to a colour lookup table, or a data.frame with `idx`, `label` (or
  `region`) and colour columns (`R`, `G`, `B`). Supplies tract names and
  colours; labels absent from the volume are ignored.

- n_points:

  Number of points along each tract centerline. Also sets the number of
  points the tube is built from, unless `tube_opts` names `n_points`
  explicitly.

- min_voxels:

  Minimum voxel count for a tract to be kept.

- smoother:

  Principal-curve smoother, passed to
  [`princurve::principal_curve()`](https://rdrr.io/pkg/princurve/man/principal_curve.html).

- verbose:

  How much to print: `0` silent, `1` progress (the default), `2` adds
  FreeSurfer's own output. `TRUE` and `FALSE` mean `1` and `0`. Falls
  back to `options("ggseg.extra.verbose")`, then `GGSEG_EXTRA_VERBOSE`.

- ...:

  Passed to
  [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
  (for example `tube_opts`, `slabs`, `steps`).

- input_aseg:

  Path to a segmentation volume in the same space, used to draw the
  grey-brain cortex outline in the 2D views. Required for the 2D
  projection (see `steps`).

- exclude:

  Integer label ids to drop (for example aggregate whole-brain fibre
  masks). Labels with fewer than `min_voxels` voxels, or for which a
  centerline cannot be fit, are dropped automatically with a message.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Where to put the intermediate files. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), from
  `options("ggseg.extra.output_dir")` or `GGSEG_EXTRA_OUTPUT_DIR`.

## Value

A `ggseg_atlas` of type `"tract"`, as returned by
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md).

## See also

[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
for the streamline-based counterpart.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_tract_from_volume(
  input_volume = "AtlasTrack_labels.nii.gz",
  input_lut = "AtlasTrack_LUT.txt",
  input_aseg = "fsaverage/mri/aseg.mgz",
  exclude = c(2000, 2001, 2002, 2003, 2004),
  tube_opts = list(tube_radius = 3)
)
} # }
```
