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
  decimate = 0.5,
  verbose = get_verbose(),
  ...,
  volume = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- gifti_files:

  Character vector of paths to GIFTI label files (`.label.gii` or
  `.func.gii`) containing the cerebellar parcellation.

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

  Catches the retired `dilate`, `smoothness`, `tolerance` and
  `smooth_refinements` arguments, so a call that still passes one keeps
  working and says so. These are post-creation steps now: see
  [`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
  or
  [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  and
  [`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
  individually. Anything else in `...` is an error, as an unused
  argument always was.

- volume:

  Optional path to a cerebellar segmentation volume (NIfTI) for 3D mesh
  generation. When provided, per-region meshes are tessellated using
  FreeSurfer tools and included in the atlas for 3D rendering.

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

  Reuse intermediate files that already exist, so an interrupted run can
  resume. Default `TRUE`, from `options("ggseg.extra.skip_existing")` or
  `GGSEG_EXTRA_SKIP_EXISTING`.

## Value

A `ggseg_atlas` object of type "cerebellar" containing region metadata
(core), a colour palette, sf geometry for 2D plots, and optionally 3D
meshes.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
to simplify and round off the result, which most builds want next.

Other atlas creation:
[`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md),
[`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md),
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
atlas <- create_cerebellar_from_gifti(
  gifti_files = "Lobules-SUIT.label.gii"
)
plot(atlas)
} # }
```
