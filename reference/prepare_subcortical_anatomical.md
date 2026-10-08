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
  target_subject = "cvs_avg35_inMNI152",
  target_volume = "brain",
  threshold = 0.3,
  id_offset = 200L,
  protect_cortex = TRUE,
  dof = 12,
  binarise = TRUE,
  subjects_dir = freesurfer::fs_subj_dir(),
  skip_existing = FALSE,
  verbose = get_verbose(),
  lut = NULL,
  output_file = NULL,
  output_lta = NULL
)
```

## Arguments

- input_volume:

  Path to the atlas volume to coregister, or an `RNifti` object.

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

  Integer added to every input label ID so it cannot collide with a
  FreeSurfer `aparc+aseg` label. Defaults to `200L`; use `0L` if your
  IDs are already remapped. A collision is an error either way, never a
  silent merge.

- protect_cortex:

  Whether the cerebral outline in `aparc+aseg` is safe from being
  overwritten by your labels. `TRUE`, the default, keeps the
  brain-outline geometry the subcortical pipeline draws as context. See
  details.

- dof:

  Degrees of freedom for `mri_coreg` (`6`, `9`, or `12`). Defaults to
  `12` (rigid + per-axis scale + shear).

- binarise:

  Logical. If `TRUE` (default), binarise both volumes before
  coregistration. Set to `FALSE` to register on raw intensities.

- subjects_dir:

  FreeSurfer `SUBJECTS_DIR`. Defaults to
  [`freesurfer::fs_subj_dir()`](https://rdrr.io/pkg/freesurfer/man/fs_dir.html).

- skip_existing:

  Reuse the registration at `output_lta` when the file already exists,
  instead of running it again. Default `FALSE`.

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

- output_lta:

  Path to write the resulting LTA file. Defaults to a temporary file.

## Value

Invisibly, the `list(volume, lut, id_offset)` returned by
[`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md).
Pass it straight to
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
which unpacks `volume` and `lut`.

## Details

**Start here.** The three functions it wraps or sits beside are for when
this one does not fit; see *Which of these to use*.

## Which of these to use

A subcortical atlas is drawn against a brain outline, and that outline
comes from a FreeSurfer subject's `aparc+aseg`. Getting your volume onto
that grid is what these four functions do between them.

- `prepare_subcortical_anatomical()` is the whole job in one call, and
  what most atlases want: align the volume, merge it into `aparc+aseg`,
  hand back a volume and a matching colour table.

- [`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md)
  is only the alignment, and returns an LTA. Reach for it when you want
  to inspect or reuse the registration, or pass it to `registration =`
  yourself.

- [`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md)
  is only the merge, and takes a volume that already sits on the target
  grid – either because its header says so (`registration = "header"`)
  or because you have an LTA from
  [`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md).

- [`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md)
  is the older, lighter route: it replaces labels in a stock MNI152
  `aseg` rather than registering to a subject. Use it when your volume
  is already in MNI152 space and you do not need a subject-specific
  outline.

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
