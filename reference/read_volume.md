# Read neuroimaging volume file

Reads volume data from common neuroimaging formats including FreeSurfer
MGZ and NIfTI. By default, reorients to RAS+ so that dim1 =
Left-to-Right, dim2 = Posterior-to-Anterior, dim3 =
Inferior-to-Superior.

## Usage

``` r
read_volume(file, reorient = TRUE)
```

## Arguments

- file:

  Path to volume file (.mgz, .nii, .nii.gz)

- reorient:

  If TRUE (default), reorient the volume to RAS+ and return a plain
  array. If FALSE, return an RNifti niftiImage in the file's native
  orientation (preserves header for downstream use).

## Value

3D array (reorient=TRUE) or niftiImage (reorient=FALSE)

## Details

When `reorient = FALSE`, returns an RNifti niftiImage preserving the
file's native orientation and header metadata.
