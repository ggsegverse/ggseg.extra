# Create cerebellar atlas from volume segmentation

**\[experimental\]**

Creates a cerebellar atlas from a NIfTI segmentation volume. Uses the
bundled SUIT 3D surface for volume-to-surface sampling and the SUIT
flatmap for 2D polygon generation. Per-region 3D meshes are tessellated
from the volume for 3D rendering.

## Usage

``` r
create_cerebellar_from_volume(
  input_volume = NULL,
  decimate = 0.5,
  verbose = get_verbose(),
  ...,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- input_volume:

  Path to a cerebellar segmentation volume (NIfTI).

- decimate:

  Mesh decimation factor between 0 and 1. Reduces the number of faces in
  3D meshes using quadric edge decimation (via
  [`Rvcg::vcgQEdecim()`](https://rdrr.io/pkg/Rvcg/man/vcgQEdecim.html)).
  A value of 0.5 reduces faces by 50%. Set to NULL to skip decimation.
  Requires the Rvcg package. Default is 0.5.

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

- input_lut:

  Optional path to a colour lookup table file, or a data.frame with
  columns `idx`, `label`, and optionally `R`, `G`, `B`. A data.frame may
  also carry a `hemi` column (`"left"`, `"right"`, `"vermis"` or
  `"midline"`) that sets each region's hemisphere; a row left `NA`, or a
  table without the column, has it read from the label's name. If NULL,
  labels are auto-generated from volume values.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Where to put the intermediate files. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), from
  `options("ggseg.extra.output_dir")` or `GGSEG_EXTRA_OUTPUT_DIR`.

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

## Value

A `ggseg_atlas` object of type "cerebellar" with both sf geometry and 3D
meshes.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
to simplify and round off the result, which most builds want next.

Other atlas creation:
[`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md),
[`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md),
[`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md),
[`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md),
[`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md),
[`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md),
[`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md),
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md),
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md),
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cerebellar_from_volume("cerebellar_parcellation.nii.gz")
} # }
```
