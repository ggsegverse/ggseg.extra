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
  registration = "header",
  target_subject = "cvs_avg35_inMNI152",
  threshold = 0.3,
  id_offset = 200L,
  protect_cortex = TRUE,
  subjects_dir = freesurfer::fs_subj_dir(),
  verbose = get_verbose(),
  lut = NULL,
  output_file = NULL
)
```

## Arguments

- input_volume:

  Path to the atlas volume, or an `RNifti` object.

- registration:

  How the volume reaches the target's grid: `"header"` (the default)
  trusts the volume's own xform, `"mni152"` applies FreeSurfer's
  `mni152.register.dat`, or give the path to an LTA file, typically from
  [`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md).
  See details.

- target_subject:

  FreeSurfer subject providing the anatomical grid and `aparc+aseg.mgz`.
  Defaults to `"cvs_avg35_inMNI152"`.

- threshold:

  Numeric in `[0, 1]`. Voxels whose argmax probability does not exceed
  this threshold are kept as the source `aparc+aseg` label. Defaults to
  `0.3`.

- id_offset:

  Integer added to every input label ID so it cannot collide with a
  FreeSurfer `aparc+aseg` label. Defaults to `200L`; use `0L` if your
  IDs are already remapped. A collision is an error either way, never a
  silent merge.

- protect_cortex:

  Whether the cerebral outline in `aparc+aseg` is safe from being
  overwritten by your labels. `TRUE`, the default, keeps the
  brain-outline geometry the subcortical pipeline draws as context. See
  details.

- subjects_dir:

  FreeSurfer `SUBJECTS_DIR`. Defaults to
  [`freesurfer::fs_subj_dir()`](https://rdrr.io/pkg/freesurfer/man/fs_dir.html).

- verbose:

  How much to print: `0` silent, `1` progress (the default), `2` adds
  FreeSurfer's own output. `TRUE` and `FALSE` mean `1` and `0`. Falls
  back to `options("ggseg.extra.verbose")`, then `GGSEG_EXTRA_VERBOSE`.

- lut:

  Optional colour lookup table: a data frame with at least an `idx`
  column, or a path to one. Its `idx` selects which labels to project,
  and it comes back beside the volume with `idx` shifted to match. With
  no `lut`, every non-zero label is projected.

- output_file:

  Path for the merged volume. Defaults to a temp file.

## Value

Invisibly, a list with three elements ready to feed
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md):

- `volume`:

  Path to the merged anatomical-context volume.

- `lut`:

  A colour table matching the merged volume one-to-one: FreeSurfer names
  for the surviving `aparc+aseg` context labels, plus the user's atlas
  labels with `idx` shifted by `id_offset`. When `lut` is `NULL`, the
  user labels get generic `region_XXXX` names and no colours.

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

## Registration

`registration` takes the same vocabulary as
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
and
[`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md).
An LTA must be registered to a volume on the same subject's conformed
grid as `aparc+aseg.mgz`, which any `recon-all` output is; a mismatch is
caught and aborted. `NULL` is deprecated and meant `"header"`.

## What `protect_cortex` protects

The cortical ribbon (aparc labels `1000-2999`), cerebral white matter
(`2`, `41`) and the corpus callosum (`251-255`) are left in place even
where a user label wins the argmax above `threshold`. Cerebellar
structures are not protected here;
[`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)
handles them downstream. Disable it only if you mean your labels to
overwrite the cerebrum.

## See also

[`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md),
which runs this and
[`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md)
together, and explains which of the four to reach for.

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
