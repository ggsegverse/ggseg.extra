# Create cortical atlas from FreeSurfer annotation

**\[maturing\]**

Turn FreeSurfer annotation files into a brain atlas you can plot with
ggseg and ggseg3d. Reads the annotation, extracts vertex-to-region
assignments, and generates 2D polygon geometry by projecting the
inflated mesh triangles to 2D via orthographic projection.

## Usage

``` r
create_cortical_from_annotation(
  input_annot,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  verbose = get_verbose(),
  ...,
  atlas_name = NULL,
  output_dir = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- input_annot:

  Character vector of paths to annotation files. Files should follow
  FreeSurfer naming convention with `lh.` or `rh.` prefix (e.g.,
  `c("lh.aparc.annot", "rh.aparc.annot")`).

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

  Catches the retired `dilate`, `smoothness` and `tolerance` arguments,
  so a call that still passes one keeps working and says so. These are
  post-creation steps now: see
  [`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  and
  [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md).
  Anything else in `...` is an error, as an unused argument always was.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

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

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

## Value

A `ggseg_atlas` object containing region metadata (core), vertex indices
for 3D rendering, a colour palette, and sf geometry for 2D plots.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cortical_from_annotation(
  input_annot = c("lh.aparc.DKTatlas.annot", "rh.aparc.DKTatlas.annot")
)
ggseg(atlas = atlas)
} # }
```
