# Extract subcortical labels from a CIFTI file

**\[experimental\]**

CIFTI dense label files in grayordinate space (such as fsLR 91k) store
subcortical parcels as voxels rather than surface vertices, so
[`read_cifti_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_cifti_annotation.md)
and
[`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md)
cannot use them. `read_cifti_subcortical()` writes those voxels to a
NIfTI label volume and builds the matching colour table from the CIFTI
label table.

The volume keeps the CIFTI's voxel grid and transform. Grayordinate
files are in MNI152NLin6Asym (FSL's MNI152), at 2 mm for 91k and 1.6 mm
for 170k, so the result can go to
[`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md)
for grey-brain context, or straight to
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md).
Label ids that reuse FreeSurfer `aseg` ids (as HCP-style files often do)
must be shifted before
[`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md),
which refuses colliding ids.

## Usage

``` r
read_cifti_subcortical(cifti_file, output_file = tempfile(fileext = ".nii.gz"))
```

## Arguments

- cifti_file:

  Path to a `.dlabel.nii` CIFTI file with subcortical voxels.

- output_file:

  Path for the NIfTI label volume. Defaults to a temporary `.nii.gz`
  file.

## Value

A list with `volume`, the path to the written NIfTI, and `lut`, a
data.frame with columns `idx`, `label`, `R`, `G`, `B` and `A` covering
the labels present in the volume. `A` is 0 (opaque), following the
FreeSurfer colour table convention rather than the CIFTI alpha.

## See also

[`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md),
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)

## Examples

``` r
if (FALSE) { # \dontrun{
subcortex <- read_cifti_subcortical("atlas.dlabel.nii")
merged <- prepare_subcortical_mni152(
  input_volume = subcortex$volume,
  labels = subcortex$lut$idx,
  lut = subcortex$lut
)
atlas <- create_subcortical_from_volume(input_volume = merged)
} # }
```
