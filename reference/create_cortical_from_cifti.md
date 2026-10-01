# Create cortical atlas from a CIFTI file

**\[experimental\]**

Build a brain atlas from a CIFTI dense label file (`.dlabel.nii`). The
file must be in fsaverage5 space (10,242 vertices per hemisphere).

## Usage

``` r
create_cortical_from_cifti(
  cifti_file,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  verbose = get_verbose(),
  ...,
  atlas_name = NULL,
  output_dir = NULL,
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- cifti_file:

  Path to a `.dlabel.nii` CIFTI file.

- hemisphere:

  Which hemispheres to include: "lh", "rh", or both.

- views:

  Which views to include: "lateral", "medial", "superior", "inferior".

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

A `ggseg_atlas` object of type "cortical" containing region metadata
(core), vertex indices for 3D rendering, a colour palette, and sf
geometry for 2D plots.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
to simplify and round off the result, which most builds want next.

Other atlas creation:
[`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md),
[`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md),
[`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md),
[`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md),
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
atlas <- create_cortical_from_cifti(
  cifti_file = "parcellation.dlabel.nii"
)
} # }
```
