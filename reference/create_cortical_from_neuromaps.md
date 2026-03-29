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
  label_table = NULL,
  n_bins = NULL,
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

- source:

  Neuromaps source identifier (e.g., `"schaefer"`).

- desc:

  Neuromaps descriptor key (e.g., `"400Parcels7Networks"`).

- space:

  Coordinate space. Defaults to `"fsaverage"`.

- density:

  Surface vertex density. Defaults to `"10k"`.

- label_table:

  Optional data.frame mapping parcel IDs to region names.

- n_bins:

  Number of quantile bins for continuous brain maps.

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
