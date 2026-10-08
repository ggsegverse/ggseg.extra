# Create brain atlas from subcortical segmentation

**\[experimental\]**

Turn a subcortical segmentation volume (like `aseg.mgz`) into a brain
atlas with 3D meshes for each structure. The function extracts each
labelled region from the volume, creates a surface mesh, and smooths it.

For 2D plotting, the function can also generate slice views by taking
snapshots at specified coordinates and extracting contours.

Requires FreeSurfer for mesh generation.

## Usage

``` r
create_subcortical_from_volume(
  input_volume,
  decimate = 0.5,
  verbose = get_verbose(),
  ...,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  slabs = NULL,
  vertex_size_limits = NULL,
  cleanup = NULL,
  skip_existing = NULL,
  steps = NULL,
  context = NULL
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
  Either may also carry a `hemi` column (`"left"`, `"right"` or
  `"midline"`) that sets each region's hemisphere; a row left `NA`, or a
  table without the column, has it read from the label's name, and any
  other value is an error.
  [`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
  stores the column in a file.

  A data.frame may also carry a `names` column: the display name each
  region shows in a legend. A row left `NA`, or a table without the
  column, is named after its region.

  If NULL, region names will be generic (e.g., "region_0010") and the
  atlas will have no palette.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename. It also
  names the folder of intermediate files inside `output_dir`, so it must
  be a single name without path separators.

- output_dir:

  Where to put the intermediate files. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), from
  `options("ggseg.extra.output_dir")` or `GGSEG_EXTRA_OUTPUT_DIR`.

- slabs:

  A data.frame specifying projection slabs with columns `name`, `type`
  ("axial", "coronal", "sagittal"), `start` (first slice), `end` (last
  slice). Defaults to three coronal and three axial slabs tiling the
  bounding box of the atlas's own labels, plus one left-hemisphere
  sagittal slab, so the band follows the anatomy of the volume rather
  than a fixed set of slice indices. Unlike slices, projections show ALL
  structures in their spatial relationships - like an X-ray view. May
  also be a named list of
  [`subcortical_slabs()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
  arguments (e.g.
  `slabs = list(labels = 801:810, coronal = 3, axial = 2)`); it is
  expanded into a slab table with `volume` defaulting to `input_volume`,
  so the slab indices are computed in the builder's own frame.

- vertex_size_limits:

  Numeric vector of length 2 setting minimum and maximum vertex count
  for polygons. Polygons outside this range are filtered out. Default
  NULL applies no limits.

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

- context:

  Optional named list of
  [`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)
  arguments (e.g. `context = list(focus = "Hippocampus")`) applied to
  the finished 2D atlas to keep the focus regions coloured on grey
  anatomical context. `NULL` (default) leaves the atlas unchanged. Only
  applied when the 2D build (step 6) runs.

## Value

A `ggseg_atlas` object with region metadata (core), 3D meshes, a colour
palette, and optionally sf geometry for 2D slice plots.

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
[`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md),
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md),
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md),
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Create 3D-only subcortical atlas from aseg
atlas <- create_subcortical_from_volume(
  input_volume = "path/to/aseg.mgz",
  input_lut = "path/to/FreeSurferColorLUT.txt",
  steps = 1:3
)

# View with ggseg3d
ggseg3d::ggseg3d(atlas = atlas)

# Full atlas with 2D slices
atlas <- create_subcortical_from_volume(
  input_volume = "path/to/aseg.mgz",
  input_lut = "path/to/ASegStatsLUT.txt"
)

# Post-process to remove/modify regions (functions from ggseg.formats)
atlas <- atlas |>
  atlas_region_remove("White-Matter", match_on = "label") |>
  atlas_region_contextual("Cortex", match_on = "label")
} # }
```
