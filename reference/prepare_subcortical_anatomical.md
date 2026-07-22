# Prepare an atlas for the subcortical pipeline with anatomical context

Convenience wrapper that runs
[`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md)
followed by
[`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md)
in one call, producing a merged volume on a FreeSurfer subject's
`aparc+aseg` grid together with a matching colour table, ready to feed
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md).

## Usage

``` r
prepare_subcortical_anatomical(
  input_volume,
  lut = NULL,
  target_subject = "cvs_avg35_inMNI152",
  target_volume = "brain",
  threshold = 0.3,
  id_offset = 200L,
  protect_cortex = TRUE,
  dof = 12,
  output_file = NULL,
  output_lta = NULL,
  binarise = TRUE,
  subjects_dir = freesurfer::fs_subj_dir(),
  skip_existing = FALSE,
  verbose = get_verbose()
)
```

## Arguments

- input_volume:

  Path to the atlas volume to coregister, or an `RNifti` object.

- lut:

  Optional colour LUT (data frame with at least an `idx` column, or path
  to a TSV with `idx, label, R, G, B, A`). When provided, its `idx`
  (intersected with the volume) selects which labels to project, and it
  is returned alongside the volume with `idx` shifted by `id_offset` to
  match. With no `lut`, every non-zero label is projected. To project a
  subset, subset the `lut`.

- target_subject:

  FreeSurfer subject name to register to. Defaults to
  `"cvs_avg35_inMNI152"`, which is in MNI152 1mm space.

- target_volume:

  Name of the volume in the subject's `mri/` directory used as the
  registration target. Defaults to `"brain"` (i.e. `brain.mgz`).

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

- dof:

  Degrees of freedom for `mri_coreg` (`6`, `9`, or `12`). Defaults to
  `12` (rigid + per-axis scale + shear).

- output_file:

  Path for the merged volume. Defaults to a temp file.

- output_lta:

  Path to write the resulting LTA file. Defaults to a temporary file.

- binarise:

  Logical. If `TRUE` (default), binarise both volumes before
  coregistration. Set to `FALSE` to register on raw intensities.

- subjects_dir:

  FreeSurfer `SUBJECTS_DIR`. Defaults to
  [`freesurfer::fs_subj_dir()`](https://rdrr.io/pkg/freesurfer/man/fs_dir.html).

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

## Value

Invisibly, the `list(volume, lut, id_offset)` returned by
[`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md).
Pass it straight to
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
which unpacks `volume` and `lut`.

## Examples

``` r
if (FALSE) { # \dontrun{
merged <- prepare_subcortical_anatomical(
  input_volume = "shen_2mm_268_parcellation.nii.gz",
  lut = subcortical_lut
)
atlas <- create_subcortical_from_volume(
  input_volume = merged,
  context = list(focus = "my-structures")
)
} # }
```
