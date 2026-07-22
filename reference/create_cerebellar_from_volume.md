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
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  decimate = 0.5,
  tolerance = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  volume = lifecycle::deprecated()
)
```

## Arguments

- input_volume:

  Path to a cerebellar segmentation volume (NIfTI).

- input_lut:

  Optional path to a colour lookup table file, or a data.frame with
  columns `idx`, `label`, and optionally `R`, `G`, `B`. If NULL, labels
  are auto-generated from volume values.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- decimate:

  Mesh decimation factor between 0 and 1. Reduces the number of faces in
  3D meshes using quadric edge decimation (via
  [`Rvcg::vcgQEdecim()`](https://rdrr.io/pkg/Rvcg/man/vcgQEdecim.html)).
  A value of 0.5 reduces faces by 50%. Set to NULL to skip decimation.
  Requires the Rvcg package. Default is 0.5.

- tolerance:

  **\[deprecated\]** sf simplification is no longer applied during atlas
  creation. Use
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  on the returned atlas instead. Supplying a value emits a lifecycle
  warning and is otherwise ignored.

- smooth_refinements:

  **\[deprecated\]** sf-side smoothing is no longer applied during atlas
  creation. Use
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

- volume:

  **\[deprecated\]** Use `input_volume` instead.

## Value

A `ggseg_atlas` object of type "cerebellar" with both sf geometry and 3D
meshes.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cerebellar_from_volume(
  input_volume = "cerebellar_parcellation.nii.gz"
)
} # }
```
