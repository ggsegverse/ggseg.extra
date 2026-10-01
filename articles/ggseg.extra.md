# Getting started with ggseg.extra

ggseg.extra provides pipelines for creating brain atlas data sets
compatible with the ggseg and ggseg3d plotting packages. It supports
multiple neuroimaging input formats:

| Function | Input | Use case |
|----|----|----|
| [`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md) | FreeSurfer `.annot` files | Cortical parcellations (DK, DKT, Yeo networks) |
| [`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md) | Individual `.label` files | Custom region combinations |
| [`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md) | GIFTI `.label.gii` files | Cortical parcellations in GIFTI format |
| [`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md) | CIFTI `.dlabel.nii` files | HCP-style cortical parcellations |
| [`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md) | Neuromaps `.func.gii` or `.nii` files | Brain maps and parcellations from neuromaps |
| [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md) | Volumetric segmentation | Subcortical structures (thalamus, amygdala) |
| [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md) | Volumetric parcellation with colour table | Combined cortical + subcortical atlases |
| [`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md) | GIFTI labels on the SUIT surface | Cerebellar parcellations |
| [`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md) | FreeSurfer `.annot` on the SUIT surface | Cerebellar parcellations |
| [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md) | Volumetric cerebellar segmentation | Cerebellar parcellations, with 3D meshes |
| [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md) | Tractography files (`.trk`, `.tck`) | White matter tracts |
| [`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md) | Volumetric tract labels | Tracts given as a segmentation rather than streamlines |

All functions produce a `ggseg_atlas` object that works with both ggseg
(2D) and ggseg3d (3D).

### What’s inside a ggseg_atlas

Every atlas contains:

- **Core metadata** — region names, hemisphere labels, and the mapping
  between region names and annotation labels.
- **Colour palette** — extracted from your input files or
  auto-generated.
- **3D data** — vertex indices for cortical atlases, or meshes for
  subcortical and tract atlases.
- **2D geometry** (optional) — sf polygon outlines for flat brain plots.

### Cortical pipeline

The cortical pipeline reads annotation data and projects inflated mesh
triangles directly to 2D polygons via orthographic projection. This
completes in seconds and needs no external rendering dependencies:

``` r

annot_files <- file.path(
  freesurfer::fs_dir(),
  "subjects",
  "fsaverage5",
  "label",
  c("lh.aparc.annot", "rh.aparc.annot")
)

atlas <- create_cortical_from_annotation(
  input_annot = annot_files,
  output_dir = "my_atlas"
)
```

### Subcortical and tract pipelines

These build 3D meshes from a volume, then get their 2D view by slicing:
the pipeline cuts the volume along the slabs you choose and traces each
structure’s outline in each cut. Both are controlled by a `steps`
argument, so you can stop after the meshes (`steps = 1:3` for
subcortical, `steps = 1` for tract) while iterating, then run the
default for the slices as well.

### Post-processing

Raw atlases often contain regions you don’t need (white matter,
ventricles, unknown labels), views that don’t show your structures well,
and outlines that still follow the voxel grid. The `atlas_region_*` and
`atlas_view_*` verbs curate the first two and
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
shapes the third, all without rebuilding from scratch. See
[`vignette("post-processing")`](https://ggsegverse.github.io/ggseg.extra/articles/post-processing.md)
for the full toolkit and `?atlas-verbs` for the vocabulary.

## System requirements

Using pre-built atlases requires nothing beyond R. Creating your own
atlases may require additional R packages and system tools depending on
the pipeline:

- **Cortical** (annotation/label files) — no system tools needed; uses
  the `freesurferformats` R package to read files and projects mesh to
  2D directly.
- **Subcortical / whole-brain** —
  [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/); contours are traced
  from the projection itself, with no image round-trip.
- **Tract** — no system tools; reads tractography files with R packages.

All heavier dependencies (`freesurfer`, `Rvcg`, `terra`, etc.) are in
Suggests and only loaded when needed.

Run
[`sitrep()`](https://ggsegverse.github.io/ggseg.extra/reference/sitrep.md)
to check your setup, or see
[`vignette("system-setup")`](https://ggsegverse.github.io/ggseg.extra/articles/system-setup.md)
for details.

## Tutorials

Step-by-step tutorials that walk through complete atlas creation
pipelines, one per input format, live on the [package
website](https://ggsegverse.github.io/ggseg.extra/) under *Tutorials*.
They are not shipped with the installed package because they need
FreeSurfer subject data and network access to build.

See also
[`vignette("pipeline-configuration")`](https://ggsegverse.github.io/ggseg.extra/articles/pipeline-configuration.md)
for controlling verbosity, parallelism, and output directories.
