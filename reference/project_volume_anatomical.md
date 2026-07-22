# Project atlas labels onto FreeSurfer anatomical context

For each label in an atlas volume, resamples a binary indicator with
trilinear interpolation onto the target FreeSurfer subject's
`aparc+aseg` grid, takes the argmax across labels at every voxel, and
returns a merged volume that combines the source `aparc+aseg` (providing
anatomical brain-outline context) with the user's atlas labels
(replacing `aparc+aseg` voxels wherever a label wins above `threshold`).

## Usage

``` r
project_volume_anatomical(
  input_volume,
  lut = NULL,
  registration = NULL,
  target_subject = "cvs_avg35_inMNI152",
  threshold = 0.3,
  id_offset = 200L,
  protect_cortex = TRUE,
  output_file = NULL,
  subjects_dir = freesurfer::fs_subj_dir(),
  verbose = get_verbose()
)
```

## Arguments

- input_volume:

  Path to the atlas volume, or an `RNifti` object.

- lut:

  Optional colour LUT (data frame with at least an `idx` column, or path
  to a TSV with `idx, label, R, G, B, A`). When provided, its `idx`
  (intersected with the volume) selects which labels to project, and it
  is returned alongside the volume with `idx` shifted by `id_offset` to
  match. With no `lut`, every non-zero label is projected. To project a
  subset, subset the `lut`.

- registration:

  Path to an LTA file (typically from
  [`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md)).
  If `NULL`, `mri_vol2vol` falls back to `--regheader` and trusts the
  volume's xform. The LTA must be registered to a volume on the same
  subject's conformed grid as `aparc+aseg.mgz` (true for any `recon-all`
  output); a mismatch is caught and aborted.

- target_subject:

  FreeSurfer subject providing the anatomical grid and `aparc+aseg.mgz`.
  Defaults to `"cvs_avg35_inMNI152"`.

- threshold:

  Numeric in `[0, 1]`. Voxels whose argmax probability does not exceed
  this threshold are kept as the source `aparc+aseg` label. Defaults to
  `0.3`.

- id_offset:

  Integer added to every input label ID when writing the merged volume
  to avoid collisions with FreeSurfer `aparc+aseg` labels. Defaults to
  `200L`. Set to `0L` if you have already remapped your IDs (or if
  you've verified there are no collisions).

- protect_cortex:

  Logical. If `TRUE` (default), the cerebral outline in `aparc+aseg` is
  never overwritten by user labels even when argmax wins above
  `threshold`: the cortical ribbon (aparc labels `1000-2999`) plus
  cerebral white matter (`2`, `41`) and the corpus callosum (`251-255`).
  This preserves the brain-outline geometry the subcortical pipeline
  renders as context. Cerebellar structures are not protected here (they
  are handled downstream by
  [`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)).
  Disable only if you intentionally want user labels to overwrite the
  cerebrum.

- output_file:

  Path for the merged volume. Defaults to a temp file.

- subjects_dir:

  FreeSurfer `SUBJECTS_DIR`. Defaults to
  [`freesurfer::fs_subj_dir()`](https://rdrr.io/pkg/freesurfer/man/fs_dir.html).

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

## Value

Invisibly, a list with three elements ready to feed
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md):

- `volume`:

  Path to the merged anatomical-context volume.

- `lut`:

  A colour table matching the merged volume one-to-one: FreeSurfer names
  for the surviving `aparc+aseg` context labels, plus the user's atlas
  labels with `idx` shifted by `id_offset`. When `lut` is `NULL`, the
  user labels get generic `region_XXXX` names and an auto-generated
  palette.

- `id_offset`:

  The offset applied to the user's label IDs.

## Details

The merged volume is what
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
needs to render 2D slices that show real brain outlines around the atlas
regions, instead of a generic shape.

Atlas IDs that collide with FreeSurfer `aparc+aseg` labels (e.g. an
atlas where `11` means "Putamen" while FS uses `11` for "Caudate") would
cause the subcortical pipeline to extract leftover `aparc+aseg` voxels
of a different anatomical structure as if they belonged to the user's
region. To prevent this, the function shifts every input label ID by
`id_offset` (default `200`) when writing the merged volume, so that the
user's IDs sit in a range that doesn't overlap any `aparc+aseg` label.
The `lut` argument is shifted in the same way so it matches the merged
volume.

## See also

[`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md),
[`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md)

## Examples

``` r
if (FALSE) { # \dontrun{
lta <- coregister_volume("atlas.nii.gz")
merged <- project_volume_anatomical(
  "atlas.nii.gz",
  lut = my_lut,
  registration = lta
)
atlas <- create_subcortical_from_volume(merged)
} # }
```
