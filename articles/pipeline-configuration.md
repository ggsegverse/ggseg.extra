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
| `verbose` | `ggseg.extra.verbose` | `GGSEG_EXTRA_VERBOSE` | `1` |
| `cleanup` | `ggseg.extra.cleanup` | `GGSEG_EXTRA_CLEANUP` | `TRUE` |
| `skip_existing` | `ggseg.extra.skip_existing` | `GGSEG_EXTRA_SKIP_EXISTING` | `TRUE` |
| `output_dir` | `ggseg.extra.output_dir` | `GGSEG_EXTRA_OUTPUT_DIR` | [`tempdir()`](https://rdrr.io/r/base/tempfile.html) |

`verbose` runs on a three-level scale rather than being a flag: `0` is
silent, `1` is progress, `2` adds FreeSurfer’s own output. `TRUE` and
`FALSE` are accepted and mean `1` and `0`.

The `tolerance`, `smoothness`, `smooth_refinements` and `dilate`
arguments are gone, along with the `ggseg.extra.tolerance` and
`ggseg.extra.smoothness` options. Geometry shaping happens after the
build: see
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
and
[`vignette("post-processing")`](https://ggsegverse.github.io/ggseg.extra/articles/post-processing.md).
Passing one of the old arguments is an error.

## Setting options in R

Use [`options()`](https://rdrr.io/r/base/options.html) to set defaults
for your R session:

``` r

options(
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

options(ggseg.extra.verbose = 0)

options(ggseg.extra.verbose = 2)

Sys.setenv(GGSEG_EXTRA_VERBOSE = "0")
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

### Output directory

Intermediate files — meshes, projections, traced contours — are written
to a folder named after the atlas under `output_dir`, and that folder is
removed again unless `cleanup = FALSE`. A build will not start if the
folder already holds files it did not write, because removing it would
delete them: keep source files somewhere other than
`output_dir/atlas_name`, or pass `cleanup = FALSE`. `output_dir`
defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html), so a
build leaves nothing behind. Set it when you want the intermediates to
survive the session, which is what makes `skip_existing` useful:

``` r

options(ggseg.extra.output_dir = "~/atlas-builds")
```

### Geometry

Nothing about the geometry is configured here. The pipelines return raw
outlines and shaping is a separate step on the finished atlas, so there
is nothing to set before a build. See
[`vignette("post-processing")`](https://ggsegverse.github.io/ggseg.extra/articles/post-processing.md).

## Environment variables

Environment variables are useful for CI pipelines, Docker containers, or
settings that should persist across R sessions.

In `.Renviron`:

    GGSEG_EXTRA_VERBOSE=0
    GGSEG_EXTRA_CLEANUP=true
    GGSEG_EXTRA_SKIP_EXISTING=true

In a shell:

``` bash
export GGSEG_EXTRA_VERBOSE=0
R -e "ggseg.extra::create_cortical_from_annotation(...)"
```

In Docker:

``` dockerfile
ENV GGSEG_EXTRA_VERBOSE=0
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
  ggseg.extra.verbose = 2,
  ggseg.extra.cleanup = FALSE,
  ggseg.extra.skip_existing = FALSE
)
```

### Production and CI

``` r

options(
  ggseg.extra.verbose = 0,
  ggseg.extra.cleanup = TRUE,
  ggseg.extra.skip_existing = TRUE
)
```

### Iterating on the geometry

Build once, then shape the returned atlas as many times as you like.
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
does the usual pair — simplify, then smooth — against a vertex budget:

``` r

annot_files <- c("lh.myatlas.annot", "rh.myatlas.annot")

atlas_raw <- create_cortical_from_annotation(
  input_annot = annot_files,
  output_dir = "atlas_workdir"
)

# High fidelity
atlas <- atlas_polish(atlas_raw, keep = 0.5)

# Compact, leaving the brain silhouette crisp
atlas <- atlas_polish(atlas_raw, keep = 0.05, exclude = context_pattern)
```

`context_pattern` selects the grey silhouette the structures are read
against, which usually wants gentler treatment than they do. See
[`vignette("post-processing")`](https://ggsegverse.github.io/ggseg.extra/articles/post-processing.md).
