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
  atlas_name = NULL,
  output_dir = NULL,
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  tolerance = NULL,
  smooth_refinements = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL
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

- smooth_refinements:

  Number of Chaikin corner-cutting refinements to apply to 2D polygons.
  Higher values produce smoother region boundaries (typical range: 0–3).
  0 disables smoothing. If not specified, uses
  `options("ggseg.extra.smooth_refinements")` or the
  `GGSEG_EXTRA_SMOOTH_REFINEMENTS` environment variable. Default is 2.

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
