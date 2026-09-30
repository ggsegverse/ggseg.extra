# Create cortical atlas from GIFTI annotation files

**\[experimental\]**

Build a brain atlas from GIFTI label files (`.label.gii`). Assumes
fsaverage5 surface space (10,242 vertices per hemisphere).

## Usage

``` r
create_cortical_from_gifti(
  gifti_files,
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

- gifti_files:

  Character vector of paths to `.label.gii` files. Hemisphere is
  detected from filename patterns (`lh.`, `rh.`, `.L.`, `.R.`).

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

A `ggseg_atlas` object.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cortical_from_gifti(
  gifti_files = c("lh.aparc.label.gii", "rh.aparc.label.gii")
)
} # }
```
