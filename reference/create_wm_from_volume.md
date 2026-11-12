# Create a white-matter atlas from a label volume

**\[experimental\]**

Builds a white-matter atlas from a volumetric label map. This is
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
under another name: a white-matter atlas stores what a subcortical one
stores – polygons for the slab views and a mesh per structure – and is
built the same way. Only the type of the finished atlas differs, which
is what lets a plot label it as white matter while every method written
for a subcortical atlas still applies.

Use this for a parcellation of white-matter *regions*. White-matter
*tracts* reconstructed as bundles are a different shape and belong in
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md),
which also carries centerlines.

## Usage

``` r
create_wm_from_volume(
  input_volume,
  decimate = 0.5,
  verbose = get_verbose(),
  ...,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  views = NULL,
  vertex_size_limits = NULL,
  min_coverage = NULL,
  cleanup = NULL,
  skip_existing = NULL,
  steps = NULL,
  slabs = lifecycle::deprecated()
)
```

## Arguments

- input_volume:

  Path to the segmentation volume. Supports `.mgz`, `.nii`, and
  `.nii.gz` formats. Typically this is `aseg.mgz` or a custom
  segmentation in the same space. May also be the
  `list(volume, lut, id_offset)` returned by
  [`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md)
  /
  [`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md),
  in which case its `volume` and `lut` are used (an explicit `input_lut`
  takes precedence over the bundled one).

- decimate:

  Mesh decimation factor between 0 and 1. Reduces the number of faces in
  3D meshes using quadric edge decimation (via
  [`Rvcg::vcgQEdecim()`](https://rdrr.io/pkg/Rvcg/man/vcgQEdecim.html)).
  A value of 0.5 reduces faces by 50%. Set to NULL to skip decimation.
  Requires the Rvcg package. Default is 0.5.

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

- input_lut:

  Path to a FreeSurfer-style colour lookup table that maps label IDs to
  region names and colours (e.g., `FreeSurferColorLUT.txt` or
  `ASegStatsLUT.txt`), or a data.frame with columns `idx`, `label`, `R`,
  `G`, `B` and `A` (see
  [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)).

  The table decides what is a region and what is context, the grey
  anatomy the regions are drawn against. Nothing is recognised by its id
  or its name:

  - A row is a **region** unless it says otherwise. It gets a mesh, a
    colour and a shape in each 2D view.

  - A row whose optional `context` column is `TRUE` is **context**, the
    grey anatomy the regions are drawn against. It keeps its name, is
    traced on one slice per view rather than projected through the slab,
    and gets no mesh.

  - A row whose `context` column names something else joins the
    silhouette of that name: every row sharing it is traced as one
    shape, called after the group. A parcellation's cortical labels
    marked `context = "cortex"` become one ribbon rather than a hundred
    patches.

  - A label in the volume that the table does not list is **not drawn**.
    Nothing has said what it is, and guessing fills the sulci a backdrop
    exists to show – white matter drawn as context turns a ribbon into a
    solid blob. List it to draw it.

  To leave a context shape out of the atlas altogether, remove it
  afterwards with
  [`ggseg.formats::atlas_context_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/region_manipulation.html).
  To treat the context differently when polishing, pass
  `context_pattern` as `labels` or `exclude`; see
  [`context_pattern()`](https://ggsegverse.github.io/ggseg.extra/reference/context_pattern.md).

  Either form may also carry a `hemi` column (`"left"`, `"right"` or
  `"midline"`) that sets each region's hemisphere; a row left `NA`, or a
  table without the column, has it read from the label's name, and any
  other value is an error.
  [`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
  stores the column in a file.

  A data.frame may also carry a `names` column: the display name each
  region shows in a legend. A row left `NA`, or a table without the
  column, is named after its region.

  If NULL, every label is a region with a generic name (e.g.,
  "region_0010"), there is no context, and the atlas will have no
  palette.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename. It also
  names the folder of intermediate files inside `output_dir`, so it must
  be a single name without path separators.

- output_dir:

  Where to put the intermediate files. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), from
  `options("ggseg.extra.output_dir")` or `GGSEG_EXTRA_OUTPUT_DIR`.

- views:

  The views to build, as a data.frame with columns `name`, `type`
  ("axial", "coronal", "sagittal"), `start` (first slice) and `end`
  (last slice). Each row is one view of the finished atlas: `name`
  becomes its `view`, the value
  [`ggseg.formats::atlas_views()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_views.html)
  reports and the name the view verbs match on. `start`/`end` are the
  band of slices that view is projected through — unlike a single slice,
  a projection shows every structure in the band in its spatial
  relationships, like an X-ray. `NULL`, the default, derives a set from
  the volume's own labels.

- vertex_size_limits:

  Numeric vector of length 2 setting minimum and maximum vertex count
  for polygons. Polygons outside this range are filtered out. Default
  NULL applies no limits.

- min_coverage:

  Smallest share of `core` labels that must end up with 2D geometry,
  between 0 and 1. A build that falls below it warns and names the
  labels that have no shape; the warning fires whatever `verbose` is set
  to, because a region that cannot be drawn is data loss rather than
  progress chatter. The build itself still returns, so a long pipeline
  is never thrown away over a threshold. Use `0` to turn the check off.
  Defaults to `0.8`, or to `options("ggseg.extra.min_coverage")`, then
  `GGSEG_EXTRA_MIN_COVERAGE`.

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

- steps:

  Which pipeline steps to run. Default NULL runs all six:

  - 1: Extract labels from the volume and read the colour table

  - 2: Create a mesh for each structure

  - 3: Build atlas data (3D only if stopping here)

  - 4: Create projection snapshots

  - 5: Extract contours

  - 6: Build the final atlas with 2D geometry

  Use `steps = 1:3` for a 3D-only atlas. Geometry is shaped after the
  build, not during it: see
  [`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md).

- slabs:

  **\[deprecated\]** Renamed to `views`.

## Value

A `ggseg_atlas` of type `"wm"`.

## See also

[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
which this delegates to, and
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md)
for bundles.

Other atlas creation:
[`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md),
[`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md),
[`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md),
[`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md),
[`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md),
[`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md),
[`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md),
[`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md),
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md),
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md),
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_wm_from_volume(
  input_volume = "JHU-ICBM-labels-1mm.nii.gz",
  input_lut = "JHU_LUT.txt"
)
} # }
```
