# Create cortical atlas from GIFTI annotation files

**\[experimental\]**

Build a brain atlas from GIFTI label files (`.label.gii`). This is the
entry point for parcellations distributed in GIFTI format, such as those
from the Human Connectome Project or neuromaps.

The function assumes fsaverage5 surface space (10,242 vertices per
hemisphere). No FreeSurfer installation is needed for 3D-only atlases
(`steps = 1`).

## Usage

``` r
create_cortical_from_gifti(
  gifti_files,
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

- gifti_files:

  Character vector of paths to `.label.gii` files. Hemisphere is
  detected from filename patterns (`lh.`, `rh.`, `.L.`, `.R.`).

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

  Which pipeline steps to run. See
  [`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md)
  for step descriptions. Use `steps = 1` for 3D-only atlas.

## Value

A `ggseg_atlas` object.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cortical_from_gifti(
  gifti_files = c("lh.aparc.label.gii", "rh.aparc.label.gii"),
  steps = 1
)
ggseg3d::ggseg3d(atlas = atlas)
} # }
```
