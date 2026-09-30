# Create cortical atlas from a neuromaps annotation

**\[experimental\]**

Build a brain atlas directly from a
[neuromaps](https://github.com/netneurolab/neuromaps) annotation. The
annotation is downloaded via
[`neuromapr::fetch_neuromaps_annotation()`](https://lcbc-uio.github.io/neuromapr/reference/fetch_neuromaps_annotation.html).

Supports both surface (`.func.gii`) and volume (`.nii`/`.nii.gz`)
annotations. Volume annotations in MNI152 space are automatically
projected to fsaverage5 via FreeSurfer's `mri_vol2surf`.

## Usage

``` r
create_cortical_from_neuromaps(
  source,
  desc,
  space = "fsaverage",
  density = "10k",
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  verbose = get_verbose(),
  ...,
  label_table = NULL,
  n_bins = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- source:

  Neuromaps source identifier (e.g., `"schaefer"`).

- desc:

  Neuromaps descriptor key (e.g., `"400Parcels7Networks"`).

- space:

  Coordinate space. Defaults to `"fsaverage"`.

- density:

  Surface vertex density. Defaults to `"10k"`.

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

- label_table:

  Optional data.frame mapping parcel IDs to region names.

- n_bins:

  Number of quantile bins for continuous brain maps.

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

A `ggseg_atlas` object.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cortical_from_neuromaps(
  source = "abagen",
  desc = "genepc1",
  n_bins = 7
)
} # }
```
