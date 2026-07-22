# Transform a volume from MNI space to SUIT cerebellar space

**\[experimental\]**

Resamples a volumetric parcellation from MNI152 space into the SUIT
cerebellar template space using a nonlinear deformation field. This is
required when working with cerebellar atlases that are distributed in
MNI space (e.g., the Buckner cerebellar network parcellations shipped
with FreeSurfer).

The deformation field must be a 5D NIfTI file where each SUIT-space
voxel stores the corresponding MNI coordinate to sample from. These are
available from the Diedrichsen Lab cerebellar atlases repository as
`tpl-SUIT_from-MNI152NLin*_mode-image_xfm.nii`.

## Usage

``` r
transform_mni_to_suit(
  input_volume,
  deformation_field,
  output_file = NULL,
  interpolation = c("nearest", "linear")
)
```

## Arguments

- input_volume:

  Path to the MNI-space volume (NIfTI).

- deformation_field:

  Path to the SUIT deformation field NIfTI. A 5D volume (x, y, z, 1, 3)
  mapping SUIT voxels to MNI coordinates.

- output_file:

  Path for the output SUIT-space volume. If NULL, writes to a temporary
  file.

- interpolation:

  Interpolation method: `"nearest"` (default, for parcellations/labels)
  or `"linear"` (for continuous maps). Note that `"linear"` uses a
  pure-R trilinear loop and can be slow for large volumes.

## Value

Path to the output SUIT-space NIfTI file (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
suit_vol <- transform_mni_to_suit(
  input_volume = "Buckner2011_7Networks.nii.gz",
  deformation_field = "tpl-SUIT_from-MNI152NLin6AsymC_mode-image_xfm.nii"
)
atlas <- create_cerebellar_from_volume(input_volume = suit_vol)
} # }
```
