# Create cerebellar atlas from FreeSurfer annotation

**\[experimental\]**

Reads FreeSurfer annotation files (`.annot`) on the SUIT cerebellar
surface and projects them onto the SUIT flatmap for 2D polygon geometry.

## Usage

``` r
create_cerebellar_from_annotation(
  input_annot,
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

- input_annot:

  Character vector of paths to annotation files on the SUIT cerebellar
  surface.

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
  generation.

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

A `ggseg_atlas` object of type "cerebellar".

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cerebellar_from_annotation(
  input_annot = "cerebellum.annot"
)
} # }
```
