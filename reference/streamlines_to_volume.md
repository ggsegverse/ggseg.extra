# Convert streamlines/centerline to volumetric representation

Creates a 3D volume where voxels containing tract coordinates are
labeled. Uses a template volume to define the output space dimensions
and voxel size.

## Usage

``` r
streamlines_to_volume(
  centerline,
  template_file,
  label_value = 1L,
  radius = 2,
  coords_are_voxels = FALSE
)
```

## Arguments

- centerline:

  Matrix with x, y, z columns

- template_file:

  Path to template volume (.mgz, .nii) that defines the output space

- label_value:

  Integer label value to assign to tract voxels (default 1)

- radius:

  Dilation radius in voxels to thicken the tract (default 2)

- coords_are_voxels:

  Logical. If TRUE, coordinates are already in voxel space (1-indexed).
  If FALSE (default), coordinates are in RAS space and will be
  transformed using the volume's vox2ras matrix.

## Value

3D array in RAS+ orientation, tract voxels set to label_value

## Details

The vox2ras matrix maps to the file's **native** voxel layout, so the
tract volume is built in native orientation, then reoriented to RAS+ at
the end for consistent downstream use.
