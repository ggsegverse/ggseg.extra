# Package index

## Create Brain Atlases

Functions to create brain atlases for ggseg and ggseg3d

- [`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md)
  **\[experimental\]** : Create cerebellar atlas from FreeSurfer
  annotation
- [`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md)
  **\[experimental\]** : Create cerebellar atlas from SUIT flatmap
- [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md)
  **\[experimental\]** : Create cerebellar atlas from volume
  segmentation
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
- [`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md)
  **\[experimental\]** : Create a white matter tract atlas from a label
  volume
- [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
  **\[experimental\]** : Create atlas from whole-brain volumetric
  parcellation

## Atlas Manipulation

Functions to manipulate and manage brain atlases

- [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  : Smooth and simplify atlas 2D contours

## Atlas Repository

Create and manage ggseg atlas packages

- [`setup_atlas_repo()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_atlas_repo.md)
  : Create a new ggseg atlas package

- [`setup_sitrep()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_sitrep.md)
  : Check ggseg.extra setup status

- [`use_atlas_github_actions()`](https://ggsegverse.github.io/ggseg.extra/reference/use_atlas_github_actions.md)
  : Add ggsegverse GitHub Actions workflows to a package

- [`atlas_github_actions()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_github_actions.md)
  :

  Workflows
  [`use_atlas_github_actions()`](https://ggsegverse.github.io/ggseg.extra/reference/use_atlas_github_actions.md)
  can write

## Color Tables

Read, write, and manipulate FreeSurfer color tables

- [`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
  [`read_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
  **\[deprecated\]** : Read FreeSurfer LUT
- [`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
  [`write_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
  **\[deprecated\]** : Write FreeSurfer LUT
- [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)
  [`is_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)
  **\[deprecated\]** : Check if object is a LUT
- [`get_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md)
  [`get_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md)
  **\[deprecated\]** : Read LUT and add hex colours
- [`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md)
  : Add rows to a FreeSurfer LUT
- [`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md)
  : Combine FreeSurfer LUTs

## Subcortical Helpers

Compose slice views and anatomical context for subcortical atlases

- [`subcortical_slabs()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
  [`subcortical_views()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
  **\[deprecated\]** : Build subcortical slabs from a label bounding box
- [`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)
  : Reduce a subcortical atlas to focus regions on grey anatomical
  context
- [`aseg_hidden_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_hidden_labels.md)
  : Standard FreeSurfer aseg labels stripped from a subcortical atlas

## Anatomical Coregistration

Align an atlas volume to a FreeSurfer subject for anatomical context

- [`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md)
  : Coregister an atlas volume to a FreeSurfer subject
- [`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md)
  : Project atlas labels onto FreeSurfer anatomical context
- [`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md)
  : Prepare an atlas for the subcortical pipeline with anatomical
  context
- [`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md)
  : Embed MNI152 subcortical parcels in a FreeSurfer aseg for grey-brain
  context
- [`aseg_subcortical_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_subcortical_labels.md)
  : Lumped aseg subcortical structures a parcellation typically
  subdivides

## Cerebellar Helpers

SUIT surfaces and MNI-to-SUIT transforms for cerebellar atlases

- [`suit_flatmap_path()`](https://ggsegverse.github.io/ggseg.extra/reference/suit_flatmap_path.md)
  : Path to bundled SUIT flatmap surface
- [`suit_3d_path()`](https://ggsegverse.github.io/ggseg.extra/reference/suit_3d_path.md)
  : Path to bundled SUIT 3D cerebellar surface
- [`suit_deformation_field()`](https://ggsegverse.github.io/ggseg.extra/reference/suit_deformation_field.md)
  **\[experimental\]** : Download SUIT deformation field for MNI-to-SUIT
  transforms
- [`transform_mni_to_suit()`](https://ggsegverse.github.io/ggseg.extra/reference/transform_mni_to_suit.md)
  **\[experimental\]** : Transform a volume from MNI space to SUIT
  cerebellar space
- [`read_suit_parcellation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_suit_parcellation.md)
  **\[experimental\]** : Read SUIT cerebellar parcellation from GIFTI

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
