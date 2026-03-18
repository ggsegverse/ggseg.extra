# Create cortical atlas from FreeSurfer annotation

**\[maturing\]**

Turn FreeSurfer annotation files into a brain atlas you can plot with
ggseg and ggseg3d. The function reads the annotation, extracts which
vertices belong to each brain region, and (optionally) generates 2D
polygon outlines for flat brain plots.

Use the `steps` parameter to control which pipeline steps to run. For
3D-only atlases, use `steps = 1`. For iterating on contour parameters,
use `steps = 6:7` to re-run smoothing and reduction without regenerating
snapshots.

## Usage

``` r
create_cortical_from_annotation(
  input_annot,
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smoothness = NULL,
  snapshot_dim = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  steps = NULL
)
```

## Arguments

- input_annot:

  Character vector of paths to annotation files. Files should follow
  FreeSurfer naming convention with `lh.` or `rh.` prefix (e.g.,
  `c("lh.aparc.annot", "rh.aparc.annot")`).

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- hemisphere:

  Which hemispheres to include: "lh", "rh", or both.

- views:

  Which views to include: "lateral", "medial", "superior", "inferior".

- tolerance:

  Simplification tolerance for 2D polygons. Higher values produce
  simpler shapes with fewer vertices (typical range: 0.1–2). Passed to
  [`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html).
  If not specified, uses `options("ggseg.extra.tolerance")` or the
  `GGSEG_EXTRA_TOLERANCE` environment variable. Default is 1.

- smoothness:

  Smoothing factor for 2D contours. Higher values produce smoother
  region boundaries (typical range: 3–15). Passed to
  [`smoothr::smooth()`](https://strimas.com/smoothr/reference/smooth.html).
  If not specified, uses `options("ggseg.extra.smoothness")` or the
  `GGSEG_EXTRA_SMOOTHNESS` environment variable. Default is 5.

- snapshot_dim:

  Width and height (in pixels) for brain surface snapshots. Higher
  values capture more detail for dense parcellations. If not specified,
  uses `options("ggseg.extra.snapshot_dim")` or the
  `GGSEG_EXTRA_SNAPSHOT_DIM` environment variable. Default is 800.

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

- steps:

  Which pipeline steps to run. Default NULL runs all steps. Steps are:

  - 1: Read annotation files and build 3D atlas

  - 2: Take full brain snapshots

  - 3: Take region snapshots

  - 4: Isolate regions from images

  - 5: Extract contours

  - 6: Smooth contours

  - 7: Reduce vertices

  - 8: Build final atlas with 2D geometry

  Use `steps = 1` for 3D-only atlas. Use `steps = 1:4` to stop before
  contour extraction. Use `steps = 6:7` to iterate on smoothing and
  reduction parameters without re-extracting contours.

## Value

A `ggseg_atlas` object containing region metadata (core), vertex indices
for 3D rendering, a colour palette, and optionally sf geometry for 2D
plots.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create 3D-only atlas from annotation files
atlas <- create_cortical_from_annotation(
  input_annot = c("lh.yeo7.annot", "rh.yeo7.annot"),
  steps = 1
)

# Create full atlas with 2D geometry (requires FreeSurfer for rendering)
atlas <- create_cortical_from_annotation(
  input_annot = c("lh.aparc.DKTatlas.annot", "rh.aparc.DKTatlas.annot")
)
ggseg(atlas = atlas)

# Iterate on smoothing parameters
atlas <- create_cortical_from_annotation(
  input_annot = c("lh.aparc.annot", "rh.aparc.annot"),
  steps = 6:8,
  smoothness = 10,
  tolerance = 0.5
)
} # }
```
