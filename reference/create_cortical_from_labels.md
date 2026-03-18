# Create brain atlas from label files

**\[experimental\]**

Build an atlas from individual FreeSurfer `.label` files rather than a
complete annotation. Each label file defines a single region by listing
which surface vertices belong to it. Useful when you have analysis
results saved as labels, or when you want to combine regions from
different sources into a custom atlas.

The function detects hemisphere from filename prefixes (`lh.` or `rh.`)
and derives region names from the rest of the filename.

## Usage

``` r
create_cortical_from_labels(
  label_files,
  atlas_name = NULL,
  input_lut = NULL,
  output_dir = NULL,
  views = c("lateral", "medial"),
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

- label_files:

  Paths to `.label` files. Each file should follow FreeSurfer naming:
  `{hemi}.{regionname}.label` (e.g., `lh.motor.label`).

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- input_lut:

  Path to a color lookup table (LUT) file, or a data.frame with columns
  `region` and colour columns (R, G, B or hex). Use this to provide
  region names and colours. If NULL, names are derived from filenames
  and the atlas will have no palette.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

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

  - 1: Read label files and build 3D atlas

  - 2: Take full brain snapshots

  - 3: Take region snapshots

  - 4: Isolate regions from images

  - 5: Extract contours

  - 6: Smooth contours

  - 7: Reduce vertices

  - 8: Build final atlas with 2D geometry

  Use `steps = 1` for 3D-only atlas. Use `steps = 6:7` to iterate on
  smoothing and reduction parameters.

## Value

A `ggseg_atlas` object containing region metadata, vertex indices,
colours, and optionally sf geometry for 2D plots.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create 3D-only atlas from label files
labels <- c("lh.region1.label", "lh.region2.label", "rh.region1.label")
atlas <- create_cortical_from_labels(labels, steps = 1)
ggseg3d(atlas = atlas)

# Full atlas with 2D geometry
atlas <- create_cortical_from_labels(labels)

# Iterate on smoothing parameters
atlas <- create_cortical_from_labels(labels, steps = 6:8, smoothness = 10)
} # }
```
