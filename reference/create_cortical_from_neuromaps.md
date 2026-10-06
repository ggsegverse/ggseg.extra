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
  hemisphere = c("rh", "lh"),
  views = c("lateral", "medial", "superior", "inferior"),
  verbose = get_verbose(),
  ...,
  label_table = NULL,
  breaks = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  cleanup = NULL,
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

- hemisphere:

  Which hemispheres to include: "lh", "rh", or both.

- views:

  Which views to include: "lateral", "medial", "superior", "inferior".

- verbose:

  How much to print: `0` silent, `1` progress (the default), `2` adds
  FreeSurfer's own output. `TRUE` and `FALSE` mean `1` and `0`. Falls
  back to `options("ggseg.extra.verbose")`, then `GGSEG_EXTRA_VERBOSE`.

- ...:

  Not used. Present so that a mistyped or misplaced argument is reported
  against this function rather than silently ignored; anything passed
  here is an error. Geometry is shaped after the build: see
  [`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
  or
  [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  and
  [`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
  individually.

- label_table:

  Optional data.frame mapping parcel IDs to region names.

- breaks:

  How to cut a continuous map into bins. One of:

  - `NULL`, the default: quantile bins, as many as Sturges' rule gives
    for the number of vertices (`1 + log2(n)`), kept between 5 and 20.

  - A single number: that many quantile bins.

  - Increasing numbers: the edges of the bins.

  - A function that takes the map's finite values and returns the edges,
    such as `function(x) pretty(x, 6)` for round, equal-width bins.

  Quantile bins each hold about the same number of vertices. Both
  hemispheres are cut on the same edges, so a bin covers the same range
  of values on the left and on the right. Values outside edges you
  supply are left `unknown`, with a warning. Ignored for parcellation
  data.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename. It also
  names the folder of intermediate files inside `output_dir`, so it must
  be a single name without path separators.

- output_dir:

  Where to put the intermediate files. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), from
  `options("ggseg.extra.output_dir")` or `GGSEG_EXTRA_OUTPUT_DIR`.

- cleanup:

  Remove the intermediate files afterwards. Default `TRUE`, from
  `options("ggseg.extra.cleanup")` or `GGSEG_EXTRA_CLEANUP`.

  The intermediate files live in a folder named after the atlas inside
  `output_dir`, and the whole folder is removed. A build therefore
  refuses to start if that folder already holds files it did not write,
  since removing it would take them too. Choose another `output_dir` or
  `atlas_name`, or pass `FALSE` to build there and keep everything.

- skip_existing:

  Reuse a step's intermediate files when they already exist, instead of
  running the step. Default `FALSE`, from
  `options("ggseg.extra.skip_existing")` or `GGSEG_EXTRA_SKIP_EXISTING`.

  A cache records which ggseg.extra wrote it, not what it was built
  from, so reuse cannot tell that the volume or lookup table has
  changed. Reuse is therefore asked for rather than assumed, and is
  reported when it happens. To continue an interrupted build, either
  pass `TRUE` or leave the finished steps out of `steps`.

## Value

A `ggseg_atlas` object of type "cortical" containing region metadata
(core), vertex indices for 3D rendering, a colour palette, and sf
geometry for 2D plots.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
to simplify and round off the result, which most builds want next.

Other atlas creation:
[`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md),
[`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md),
[`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md),
[`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md),
[`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md),
[`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md),
[`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md),
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md),
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md),
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_cortical_from_neuromaps(
  source = "abagen",
  desc = "genepc1",
  breaks = 7
)
} # }
```
