# Coregister an atlas volume to a FreeSurfer subject

Computes a rigid-plus-scale registration from a volumetric atlas onto a
FreeSurfer subject's T1 grid (e.g. `cvs_avg35_inMNI152`) using
`mri_coreg`. The resulting LTA can be reused by `mri_vol2vol` to
resample the atlas (or any volume in the same source space) onto the
target's grid, which is the first step toward producing subcortical
atlases that show realistic brain-outline anatomical context in their 2D
slices.

## Usage

``` r
coregister_volume(
  input_volume,
  target_subject = "cvs_avg35_inMNI152",
  target_volume = "brain",
  output_lta = NULL,
  dof = 12,
  binarise = TRUE,
  subjects_dir = freesurfer::fs_subj_dir(),
  skip_existing = FALSE,
  verbose = get_verbose()
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

- output_lta:

  Path to write the resulting LTA file. Defaults to a temporary file.

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

Path to the LTA file (invisibly).

## Details

Both volumes are binarised (any non-zero voxel becomes brain) before
coregistration so that the alignment is driven by tissue extent rather
than label values. To skip the binarisation and align using raw
intensities, set `binarise = FALSE`.

## See also

[`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md),
[`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md)

## Examples

``` r
if (FALSE) { # \dontrun{
lta <- coregister_volume(
  input_volume = "shen_2mm_268_parcellation.nii.gz",
  target_subject = "cvs_avg35_inMNI152"
)
} # }
```
