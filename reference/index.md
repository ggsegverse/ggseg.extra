# Package index

## Create Brain Atlases

Functions to create brain atlases for ggseg and ggseg3d

- [`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md)
  **\[maturing\]** : Create cortical atlas from FreeSurfer annotation
- [`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md)
  **\[experimental\]** : Create cortical atlas from a CIFTI file
- [`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md)
  **\[experimental\]** : Create cortical atlas from GIFTI annotation
  files
- [`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md)
  **\[experimental\]** : Create brain atlas from label files
- [`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md)
  **\[experimental\]** : Create cortical atlas from a neuromaps
  annotation
- [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  **\[experimental\]** : Create brain atlas from subcortical
  segmentation
- [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
  **\[experimental\]** : Create brain atlas from white matter tracts
- [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
  **\[experimental\]** : Create atlas from whole-brain volumetric
  parcellation

## Atlas Manipulation

Functions to manipulate and manage brain atlases

- [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
  : Simplify atlas 2D contours
- [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  : Smooth atlas 2D contours

## Atlas Repository

Create and manage ggseg atlas packages

- [`setup_atlas_repo()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_atlas_repo.md)
  : Create a new ggseg atlas package
- [`setup_sitrep()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_sitrep.md)
  : Check ggseg.extra setup status

## Color Tables

Read, write, and manipulate FreeSurfer color tables

- [`read_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/read_ctab.md)
  : Read FreeSurfer color table
- [`write_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/write_ctab.md)
  : Write FreeSurfer color table
- [`is_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/is_ctab.md)
  : Check if object is a color table
- [`get_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/get_ctab.md)
  : Read color table and add hex colours

## Utilities

General package utilities

- [`read_annotation_data()`](https://ggsegverse.github.io/ggseg.extra/reference/read_annotation_data.md)
  : Read annotation data from files
- [`read_cifti_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_cifti_annotation.md)
  : Read CIFTI annotation file
- [`read_gifti_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_gifti_annotation.md)
  : Read GIFTI annotation files
- [`read_neuromaps_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_neuromaps_annotation.md)
  : Read neuromaps annotation files
- [`read_neuromaps_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/read_neuromaps_volume.md)
  : Read neuromaps volume annotation via surface projection
- [`reexports`](https://ggsegverse.github.io/ggseg.extra/reference/reexports.md)
  [`convert_legacy_brain_atlas`](https://ggsegverse.github.io/ggseg.extra/reference/reexports.md)
  : Objects exported from other packages
- [`read_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/read_tractography.md)
  : Read tractography file
- [`mri_surf2surf_rereg()`](https://ggsegverse.github.io/ggseg.extra/reference/mri_surf2surf_rereg.md)
  : Re-register an annotation file
- [`get_verbose()`](https://ggsegverse.github.io/ggseg.extra/reference/get_verbose.md)
  : Get verbose setting
- [`is_verbose()`](https://ggsegverse.github.io/ggseg.extra/reference/is_verbose.md)
  : Get verbosity level
- [`as_verbosity()`](https://ggsegverse.github.io/ggseg.extra/reference/as_verbosity.md)
  : Coerce a value to a verbosity level
