# ggseg.extra: Create Brain Atlases for the 'ggsegverse' Plotting Ecosystem

Create brain atlas data sets compatible with the 'ggsegverse' plotting
packages. Provides pipelines for building cortical, subcortical,
white-matter tract, and cerebellar atlases from 'FreeSurfer' annotation
files, 'GIFTI' and 'CIFTI' surface formats, 'neuromaps', cerebellar
flatmaps, and volumetric 'NIfTI' images.

## Getting started

[`sitrep()`](https://ggsegverse.github.io/ggseg.extra/reference/sitrep.md)
reports whether this machine has what each pipeline needs. Run it first
— most pipelines want FreeSurfer, and some want Connectome Workbench or
an optional R package.

Pick the creator that matches the input you have:

- **Cortical surface** —
  [`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md)
  for a FreeSurfer `.annot`,
  [`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md)
  or
  [`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md)
  for surface formats,
  [`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md)
  for hand-drawn `.label` files, and
  [`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md)
  for a neuromaps annotation.

- **Subcortical** —
  [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  from a segmentation volume such as FreeSurfer's `aseg`.

- **Cerebellar** —
  [`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md),
  [`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md)
  or
  [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md),
  all onto the SUIT flatmap.

- **White-matter tract** —
  [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
  from streamlines, or
  [`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md)
  from a tract label map.

- **Whole brain at once** —
  [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md),
  which splits one volume across the three pipelines above.

A freshly built atlas usually carries more vertices than a plot needs.
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
simplifies and rounds it off in one call;
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
and
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
are the separate steps.
[`count_vertices()`](https://ggsegverse.github.io/ggseg.extra/reference/count_vertices.md)
is the number to watch.

To ship an atlas as its own package,
[`setup_atlas_repo()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_atlas_repo.md)
scaffolds the repository and
[`use_atlas_github_actions()`](https://ggsegverse.github.io/ggseg.extra/reference/use_atlas_github_actions.md)
adds its workflows.

## See also

Useful links:

- <https://github.com/ggsegverse/ggseg.extra>

- Report bugs at <https://github.com/ggsegverse/ggseg.extra/issues>

## Author

**Maintainer**: Athanasia Mo Mowinckel <a.m.mowinckel@psykologi.uio.no>
([ORCID](https://orcid.org/0000-0002-5756-0223)) (drmowinckels)

Other contributors:

- Didac Vidal-Piñeiro <d.v.pineiro@psykologi.uio.no>
  ([ORCID](https://orcid.org/0000-0001-9997-9156)) \[contributor\]

- John Muschelli <muschellij2@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-6469-1750)) \[contributor\]

- Center for Lifespan Changes in Brain and Cognition (LCBC), University
  of Oslo \[copyright holder\]
