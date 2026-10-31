# ggseg.extra: Create Brain Atlases for the 'ggsegverse' Plotting Ecosystem

Create brain atlas data sets compatible with the 'ggsegverse' plotting
packages. Provides pipelines for building cortical, subcortical,
white-matter tract, and cerebellar atlases from 'FreeSurfer' annotation
files, 'GIFTI' and 'CIFTI' surface formats, 'neuromaps', cerebellar
flatmaps, and volumetric 'NIfTI' images. The atlases it builds are
intended for visualising results as general anatomical guidance, not as
a source of precision geometry for analysis. Mowinckel & Vidal-Piñeiro
(2020)
[doi:10.1177/2515245920928009](https://doi.org/10.1177/2515245920928009)
.

## What these atlases are for

These atlases are built for visualising results. They are there to give
general anatomical guidance — roughly where in the brain an effect sits,
and which structures neighbour it. They are not a source of precision
geometry. Nothing here is meant to be measured from: not volumes, not
surface areas, not distances, and not the exact boundary between two
neighbouring parcels. An analysis that needs those numbers should take
them from the annotation, surface or volume the atlas was built from,
never from the atlas.

That positioning buys the pipelines one specific kind of slack, and no
more. Acceptable by design: vertices that sit a millimetre or so from
where the source data puts them, shape lost to mesh smoothing and
decimation, corners rounded off by polygon simplification (the `keep`
argument of
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
and
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)),
and the difference between an atlas's own silhouette and the same
parcellation resampled onto a shared surface. Not acceptable, and not
excused by it: anything categorically wrong. A region drawn on the wrong
hemisphere, a label attached to the wrong structure, or a region missing
from a view where it is anatomically present is a bug, however tight the
tolerance on its vertices. A tool that puts the left hippocampus on the
right is not being imprecise; it is giving confident wrong guidance,
which is worse than giving none. Please report those as bugs.

## What a 3D plot shows

Cortical and cerebellar atlases do not carry their own 3D geometry. They
store vertex indices. A cortical atlas records, for each region, which
vertices of the fsaverage5 surface it claims (0 to 10241 per
hemisphere); a cerebellar atlas records which vertices of the SUIT
surface it claims (0 to 28934). Rendering either in 3D therefore draws
fsaverage5's or SUIT's anatomy with the atlas's labels painted onto it.
The cortical shape of the brain the parcellation came from is never
shown, and cannot be. Registration decides only which vertices each
region claims.

Subcortical and white-matter tract atlases are different. Those carry a
real mesh per structure, tessellated from the source volume or from
streamlines, so the 3D geometry is their own. A cerebellar atlas built
from a volume carries meshes for its deep nuclei for the same reason:
those sit off the flatmap surface.

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

- <https://ggsegverse.github.io/ggseg.extra/>

- <https://github.com/ggsegverse/ggseg.extra>

- Report bugs at <https://github.com/ggsegverse/ggseg.extra/issues>

## Author

**Maintainer**: Athanasia Mo Mowinckel <a.m.mowinckel@psykologi.uio.no>
([ORCID](https://orcid.org/0000-0002-5756-0223)) (Github: drmowinckels)

Authors:

- Athanasia Mo Mowinckel <a.m.mowinckel@psykologi.uio.no>
  ([ORCID](https://orcid.org/0000-0002-5756-0223)) (Github:
  drmowinckels)

Other contributors:

- Didac Vidal-Piñeiro <d.v.pineiro@psykologi.uio.no>
  ([ORCID](https://orcid.org/0000-0001-9997-9156)) \[contributor\]

- John Muschelli <muschellij2@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-6469-1750)) \[contributor\]

- Center for Lifespan Changes in Brain and Cognition (LCBC), University
  of Oslo \[copyright holder\]
