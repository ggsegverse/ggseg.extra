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

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

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

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- cleanup:

  Remove intermediate files after atlas creation. If not specified, uses
  `options("ggseg.extra.cleanup")` or the `GGSEG_EXTRA_CLEANUP`
  environment variable. Default is TRUE.

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

## Value

A `ggseg_atlas` object.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cortical_from_cifti(
  cifti_file = "parcellation.dlabel.nii"
)
} # }
```
