# Pipeline configuration

The atlas creation functions share common parameters that control
pipeline behaviour. You can set these explicitly in each function call,
globally via R options, or through environment variables.

## Parameter hierarchy

Parameters resolve in this order:

1.  **Explicit argument** — value passed directly to the function
2.  **R option** — value from
    [`options()`](https://rdrr.io/r/base/options.html)
3.  **Environment variable** — value from
    [`Sys.getenv()`](https://rdrr.io/r/base/Sys.getenv.html)
4.  **Default** — built-in default value

This lets you set project-wide defaults while still overriding them for
specific calls.

## Available options

| Parameter | R Option | Environment Variable | Default |
|----|----|----|----|
| `verbose` | `ggseg.extra.verbose` | `GGSEG_EXTRA_VERBOSE` | `TRUE` |
| `cleanup` | `ggseg.extra.cleanup` | `GGSEG_EXTRA_CLEANUP` | `TRUE` |
| `skip_existing` | `ggseg.extra.skip_existing` | `GGSEG_EXTRA_SKIP_EXISTING` | `TRUE` |
| `tolerance` | `ggseg.extra.tolerance` | `GGSEG_EXTRA_TOLERANCE` | `0.5` |
| `smoothness` | `ggseg.extra.smoothness` | `GGSEG_EXTRA_SMOOTHNESS` | `5` |

Note: `smoothness` applies only to subcortical and tract pipelines.
Cortical atlases use direct mesh projection and do not require
smoothing.

## Setting options in R

Use [`options()`](https://rdrr.io/r/base/options.html) to set defaults
for your R session:

``` r

options(
  ggseg.extra.tolerance = 0.5,
  ggseg.extra.cleanup = FALSE
)

atlas <- create_cortical_from_annotation(
  input_annot = c("lh.aparc.annot", "rh.aparc.annot"),
  output_dir = "my_atlas"
)
```

### Verbosity

The `verbose` parameter controls progress messages during pipeline
execution.

``` r

options(ggseg.extra.verbose = FALSE)

Sys.setenv(GGSEG_EXTRA_VERBOSE = "false")
```

### Cleanup

The `cleanup` parameter controls whether intermediate files are removed
after pipeline completion. Set it to `FALSE` to keep them for debugging:

``` r

options(ggseg.extra.cleanup = FALSE)

atlas <- create_subcortical_from_volume(
  input_volume = "aseg.mgz",
  output_dir = "my_atlas_files"
)
```

### Skip existing

The `skip_existing` parameter lets you resume interrupted pipeline runs
by reusing existing intermediate files:

``` r

options(ggseg.extra.skip_existing = FALSE)

options(ggseg.extra.skip_existing = TRUE)
```

### Geometry parameters

The `tolerance` parameter controls the quality of 2D polygon geometry.
Higher tolerance means fewer vertices — smaller file size, less detail.

For subcortical and tract pipelines, `smoothness` controls kernel
smoothing of contour boundaries. Higher smoothness means rounder region
boundaries.

``` r

options(ggseg.extra.tolerance = 0.5)

# smoothness only applies to subcortical/tract pipelines
options(ggseg.extra.smoothness = 15)
```

## Environment variables

Environment variables are useful for CI pipelines, Docker containers, or
settings that should persist across R sessions.

In `.Renviron`:

    GGSEG_EXTRA_VERBOSE=false
    GGSEG_EXTRA_CLEANUP=true
    GGSEG_EXTRA_SKIP_EXISTING=true
    GGSEG_EXTRA_TOLERANCE=0.5

In a shell:

``` bash
export GGSEG_EXTRA_VERBOSE=false
export GGSEG_EXTRA_TOLERANCE=0.5
R -e "ggseg.extra::create_cortical_from_annotation(...)"
```

In Docker:

``` dockerfile
ENV GGSEG_EXTRA_VERBOSE=false
ENV GGSEG_EXTRA_CLEANUP=true
```

## Overriding defaults

Explicit arguments always win:

``` r

options(ggseg.extra.cleanup = TRUE)

atlas <- create_cortical_from_annotation(
  input_annot = c("lh.aparc.annot", "rh.aparc.annot"),
  cleanup = FALSE
)
```

## Recipes

### Development and debugging

``` r

options(
  ggseg.extra.verbose = TRUE,
  ggseg.extra.cleanup = FALSE,
  ggseg.extra.skip_existing = FALSE
)
```

### Production and CI

``` r

options(
  ggseg.extra.verbose = FALSE,
  ggseg.extra.cleanup = TRUE,
  ggseg.extra.skip_existing = TRUE
)
```

### Iterating on tolerance

For cortical atlases, adjusting `tolerance` is the main tuning knob. Use
0 for maximum mesh fidelity, or higher values for smaller file sizes:

``` r

annot_files <- c("lh.myatlas.annot", "rh.myatlas.annot")

# High fidelity (no simplification)
atlas <- create_cortical_from_annotation(
  input_annot = annot_files,
  output_dir = "atlas_workdir",
  tolerance = 0
)

# Compact (more simplification)
atlas <- create_cortical_from_annotation(
  input_annot = annot_files,
  output_dir = "atlas_workdir",
  tolerance = 1
)
```
