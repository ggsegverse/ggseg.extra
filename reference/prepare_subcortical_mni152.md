# Embed MNI152 subcortical parcels in a FreeSurfer aseg for grey-brain context

Registers a subcortical parcellation supplied in fixed FSL-MNI152 space
into a FreeSurfer subject's `aseg`, replacing the lumped aseg structures
the parcels subdivide, so
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
can render the parcels as coloured structures inside a grey brain
silhouette (cortex, white matter, cerebellum and brain-stem context).

This is the *fixed-registration* counterpart to
[`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md).
Use this when the atlas already lives in a standard MNI152 template: the
registration is the known `mni152.register.dat` transform (no
`mri_coreg` search needed) and the context is taken from `fsaverage5`,
matching the rest of the ecosystem. Use
[`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md)
instead when the registration must be computed from an arbitrary volume
(it targets `cvs_avg35_inMNI152` via `mri_coreg`).

## Usage

``` r
prepare_subcortical_mni152(
  input_volume,
  labels = NULL,
  lut = NULL,
  replace_labels = aseg_subcortical_labels(),
  target_subject = "fsaverage5",
  registration = NULL,
  output_file = NULL,
  subjects_dir = freesurfer::fs_subj_dir(),
  verbose = get_verbose()
)
```

## Arguments

- input_volume:

  Path or `RNifti` image of the parcellation in FSL-MNI152 space. Only
  voxels whose value is in `labels` are embedded.

- labels:

  Integer ids of the parcels to embed. Defaults to every non-zero id in
  `input_volume`. Ids must not collide with the surviving `aseg` context
  ids; remap them upstream (e.g. add a fixed offset) if they do.

- lut:

  Optional colour table (`data.frame` with `idx, label, R, G, B, A`)
  naming the parcels. When `NULL`, generic `region_XXXX` names and an
  HCL palette are generated.

- replace_labels:

  Integer `aseg` ids the parcels subdivide, blanked before the parcels
  are stamped in. Defaults to
  [`aseg_subcortical_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_subcortical_labels.md).

- target_subject:

  FreeSurfer subject whose `aseg` supplies the grey-brain context.
  Defaults to `"fsaverage5"`.

- registration:

  Path to the MNI152 registration `.dat`. Defaults to
  `mni152.register.dat` under `FREESURFER_HOME/average`.

- output_file:

  Optional path for the merged volume; defaults to a tempfile.

- subjects_dir:

  FreeSurfer subjects directory.

- verbose:

  Verbosity, passed to the FreeSurfer command runner.

## Value

Invisibly, `list(volume, lut)`: the merged volume path and a matching
colour table, ready to pass straight to
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
(optionally with `context = list(focus = ...)`).

## See also

[`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md)
for the computed-registration (`cvs_avg35_inMNI152`, `mri_coreg`)
counterpart;
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
which consumes the result.

## Examples

``` r
if (FALSE) { # \dontrun{
merged <- prepare_subcortical_mni152(
  input_volume = "BN_Atlas_subcortical_1mm.nii.gz",
  labels = 211:246
)
atlas <- create_subcortical_from_volume(
  input_volume = merged,
  context = list(focus = "region_", match_on = "label")
)
} # }
```
