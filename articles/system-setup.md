# System setup

Using pre-built atlases requires nothing beyond R. Creating your own
atlases may require external software depending on the pipeline.

## What each pipeline needs

| Pipeline | R packages | System tools |
|----|----|----|
| **Cortical** (annotation, labels) | `freesurferformats` | None |
| **Cortical** (neuromaps volume) | `freesurfer`, `neuromapr` | FreeSurfer |
| **Subcortical** | `freesurfer`, `magick`, `chromote`, `htmlwidgets`, `terra` | FreeSurfer, ImageMagick |
| **Whole-brain** | `freesurfer`, `RNifti`, `magick`, `chromote`, `htmlwidgets`, `terra` | FreeSurfer, ImageMagick |
| **Tract** | `RNifti`, `Rvcg` | None |
| **GIFTI / CIFTI** | `gifti` or `ciftiTools` | Connectome Workbench (CIFTI only) |

The cortical mesh-projection pipeline is the lightest — it runs in
seconds with no system tools and minimal R dependencies. All heavier
packages (`freesurfer`, `magick`, `chromote`, `terra`, etc.) are in
Suggests and only loaded when a pipeline actually needs them.

## FreeSurfer

[FreeSurfer](https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall)
is needed by the subcortical, whole-brain, and neuromaps volume
pipelines. The cortical annotation pipeline needs the
`freesurferformats` R package (not FreeSurfer itself) to read `.annot`
and `.label` files.

On macOS, you also need:

- [XQuartz](https://www.xquartz.org/)
- [Xcode](https://developer.apple.com/xcode/) command line tools

Verify your installation:

``` r

freesurfer::fs_dir()
```

## ImageMagick

[ImageMagick](https://imagemagick.org/) is used by the subcortical and
whole-brain pipelines for image processing — isolating regions from
screenshots, tracing contours, and converting them to polygons.

**Not needed for cortical or tract pipelines.**

Install via your package manager:

``` bash
# macOS
brew install imagemagick

# Ubuntu/Debian
sudo apt-get install imagemagick
```

## Chrome / Chromium

The subcortical and whole-brain pipelines take 3D screenshots using the
`chromote` package, which needs Google Chrome or Chromium. Chrome is
typically already installed. If not, `chromote` will attempt to download
a suitable version automatically.

**Not needed for cortical or tract pipelines.**

## Parallel processing

ggseg.extra uses the [furrr](https://furrr.futureverse.org/) package for
parallel processing. By default, processing runs sequentially.

To enable parallel processing, set up a `future` plan before running
atlas creation functions:

``` r

library(future)

plan(multicore, workers = 4)
```

**Prefer `multicore` where it is available.** The pipelines hand each
worker a whole volume, which under `multicore` costs nothing: forked
workers share the parent’s memory copy-on-write. A `multisession` worker
is a fresh R process, so the volume is serialised to it over a socket –
for a 256^3 aseg that is 67 MB per worker, which is more work than the
projection it was sent to compute. Measured on an 8-core machine, the
projection step runs about 3.4x faster under
`plan(multicore, workers = 4)` and slightly *slower* under
`plan(multisession, workers = 4)` than it does sequentially.

`multicore` is unavailable on Windows, and RStudio disables it by
default. There `multisession` is the only parallel option, and
sequential is often the better choice.

``` r

plan(multisession, workers = 4)
```

To return to sequential processing:

``` r

plan(sequential)
```

## Progress bars

ggseg.extra uses [progressr](https://progressr.futureverse.org/) to
report progress during long-running operations. Progress reporting is
disabled by default.

To enable progress bars:

``` r

library(progressr)

handlers("cli")
handlers(global = TRUE)
```

This gives you a cli-style progress bar that updates as each region or
step completes. It works with both sequential and parallel execution.

## Checking your setup

Run the setup report to verify everything is in place:

``` r

setup_sitrep()
```
