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
  input_aseg = NULL,
  exclude = NULL,
  n_points = 50L,
  min_voxels = 30L,
  smoother = "smooth_spline",
  atlas_name = NULL,
  output_dir = NULL,
  verbose = get_verbose(),
  ...
)
```

## Arguments

- input_volume:

  Path or `RNifti` image of the tract label volume.

- input_lut:

  Path to a colour lookup table, or a data.frame with `idx`, `label` (or
  `region`) and colour columns (`R`, `G`, `B`). Supplies tract names and
  colours; labels absent from the volume are ignored.

- input_aseg:

  Path to a segmentation volume in the same space, used to draw the
  grey-brain cortex outline in the 2D views. Required for the 2D
  projection (see `steps`).

- exclude:

  Integer label ids to drop (for example aggregate whole-brain fibre
  masks). Labels with fewer than `min_voxels` voxels, or for which a
  centerline cannot be fit, are dropped automatically with a message.

- n_points:

  Number of points along each tract centerline.

- min_voxels:

  Minimum voxel count for a tract to be kept.

- smoother:

  Principal-curve smoother, passed to
  [`princurve::principal_curve()`](https://rdrr.io/pkg/princurve/man/principal_curve.html).

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

- ...:

  Passed to
  [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
  (for example `tube_radius`, `tube_segments`, `steps`).

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
  tube_radius = 3
)
} # }
```
