# Create cerebellar atlas from SUIT flatmap

**\[experimental\]**

Turn SUIT cerebellar parcellation files into a brain atlas you can plot
with ggseg and ggseg3d. Reads GIFTI label files containing
vertex-to-region assignments and projects them onto the SUIT flatmap
surface to generate 2D polygon geometry. Optionally tessellates
per-region 3D meshes from a cerebellar segmentation volume.

The SUIT (Spatially Unbiased Infratentorial Template) flatmap is a
standard 2D representation of the cerebellar cortex. Unlike cortical
atlases that require orthographic projection of an inflated mesh, the
flatmap surface already contains 2D coordinates.

## Usage

``` r
create_cerebellar_from_gifti(
  gifti_files,
  volume = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  decimate = 0.5,
  tolerance = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
)
```

## Arguments

- gifti_files:

  Character vector of paths to GIFTI label files (`.label.gii` or
  `.func.gii`) containing the cerebellar parcellation.

- volume:

  Optional path to a cerebellar segmentation volume (NIfTI) for 3D mesh
  generation. When provided, per-region meshes are tessellated using
  FreeSurfer tools and included in the atlas for 3D rendering.

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

## Value

A `ggseg_atlas` object of type "cerebellar" containing region metadata
(core), a colour palette, sf geometry for 2D plots, and optionally 3D
meshes.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cerebellar_from_gifti(
  gifti_files = "Lobules-SUIT.label.gii"
)
ggseg(atlas = atlas)
} # }
```
