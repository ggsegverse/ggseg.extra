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

plan(multisession, workers = 4)
```

**Use `multisession`, not `multicore`.** The subcortical pipeline uses
[chromote](https://rstudio.github.io/chromote/) to take 3D brain
screenshots via headless Chrome. `multicore` relies on process forking,
which corrupts chromote’s websocket connections and causes crashes.
`multisession` spawns independent R worker processes that each get their
own clean Chrome instance.

If `plan(multicore)` is active when the pipeline runs, it will
automatically switch to `multisession` and warn you.

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
