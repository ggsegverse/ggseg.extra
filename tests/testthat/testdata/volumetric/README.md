# Volumetric Test Data

Test data for volumetric (subcortical) atlas creation pipelines.

## Files

- `aseg.mgz` - Cropped subcortical segmentation (74x56x43 voxels)
- `lut.txt` - Color lookup table for the segmentation labels

## Contents

The `aseg.mgz` file contains a cropped region from the FreeSurfer fsaverage5 
aseg.mgz, including only:

| Label | Structure       | Hemisphere |
|-------|-----------------|------------|
| 10    | Thalamus        | Left       |
| 18    | Amygdala        | Left       |
| 49    | Thalamus        | Right      |
| 54    | Amygdala        | Right      |

**Source:** Derived from FreeSurfer fsaverage5 subject 
(`$FREESURFER_HOME/subjects/fsaverage5/mri/aseg.mgz`), cropped at 0-based
voxel offset (91, 108, 88).

**Geometry:** The crop originally shipped with `ras_good_flag = -1`, i.e. no
RAS information, so `read_volume()` could not orient it and every test using
it exercised the native-voxel-order path that real FreeSurfer output never
takes. The header now carries the parent's conformed LIA direction with the
translation shifted by the crop offset:

```
-1  0  0   37
 0  0  1  -40
 0 -1  0   20
```

The offset was recovered by matching the cropped array against the parent
volume, which is bit-identical at that position, so the affine is derived
rather than assumed. Voxel data is unchanged.

**Citation:** Fischl B, Salat DH, Busa E, Albert M, Dieterich M, Haselgrove C, 
van der Kouwe A, Killiany R, Kennedy D, Klaveness S, Montillo A, Makris N, 
Rosen B, Dale AM. Whole brain segmentation: automated labeling of 
neuroanatomical structures in the human brain. Neuron. 2002 Jan 31;33(3):341-55.
