# Getting started with ggseg.extra

ggseg.extra provides pipelines for creating brain atlas data sets
compatible with the ggseg and ggseg3d plotting packages. It supports
multiple neuroimaging input formats:

| Function                                                                                                                     | Input                                     | Use case                                       |
|------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|------------------------------------------------|
| [`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md) | FreeSurfer `.annot` files                 | Cortical parcellations (DK, DKT, Yeo networks) |
| [`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md)         | Individual `.label` files                 | Custom region combinations                     |
| [`create_cortical_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_gifti.md)           | GIFTI `.label.gii` files                  | Cortical parcellations in GIFTI format         |
| [`create_cortical_from_cifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_cifti.md)           | CIFTI `.dlabel.nii` files                 | HCP-style cortical parcellations               |
| [`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md)   | Neuromaps `.func.gii` or `.nii` files     | Brain maps and parcellations from neuromaps    |
| [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)   | Volumetric segmentation                   | Subcortical structures (thalamus, amygdala)    |
| [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)     | Volumetric parcellation with colour table | Combined cortical + subcortical atlases        |
| [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)   | Tractography files (`.trk`, `.tck`)       | White matter tracts                            |

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

### Fast iteration vs. full pipeline

Each creation function uses a `steps` parameter to control how much of
the pipeline runs. For cortical atlases, `steps = 1` reads the
annotation and returns 3D vertex data in seconds. The full pipeline
(`steps = 1:8`) adds 2D polygon extraction, which requires FreeSurfer
and Chrome and takes longer.

``` r
annot_files <- file.path(
  freesurfer::fs_dir(),
  "subjects",
  "fsaverage5",
  "label",
  c("lh.aparc.annot", "rh.aparc.annot")
)

atlas_3d_only <- create_cortical_from_annotation(
  input_annot = annot_files,
  steps = 1
)

atlas_full <- create_cortical_from_annotation(
  input_annot = annot_files,
  output_dir = "my_atlas",
  steps = 1:8
)
```

Start with 3D-only to verify your inputs look right, then run the full
pipeline when you’re ready for 2D geometry.

### Post-processing

Raw atlases often contain regions you don’t need (white matter,
ventricles, unknown labels) and views that don’t show your structures
well. The `atlas_region_*` and `atlas_view_*` helpers from ggseg.formats
handle cleanup without rebuilding from scratch. See
[`vignette("post-processing")`](https://ggsegverse.github.io/ggseg.extra/articles/post-processing.md)
for the full toolkit.

## System requirements

Creating atlases (as opposed to using pre-built ones) requires:

- [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/) for reading
  neuroimaging formats
- [ImageMagick](https://imagemagick.org/) for 2D geometry extraction
- Chrome or Chromium for 3D screenshots

Run
[`setup_sitrep()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_sitrep.md)
to check your setup, or see
[`vignette("system-setup")`](https://ggsegverse.github.io/ggseg.extra/articles/system-setup.md)
for installation details and parallel processing setup.

## Tutorials

The package includes step-by-step tutorials that walk through complete
atlas creation pipelines:

- [Cortical
  atlas](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-cortical-atlas.md)
  — from FreeSurfer annotation files
- [Label-based
  atlas](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-label-atlas.md)
  — from individual label files
- [Neuromaps
  atlas](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-neuromaps-atlas.md)
  — from neuromaps surface or volume data
- [Subcortical
  atlas](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-subcortical-atlas.md)
  — from volumetric segmentation
- [Tract
  atlas](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-tract-atlas.md)
  — from tractography data

See also
[`vignette("pipeline-configuration")`](https://ggsegverse.github.io/ggseg.extra/articles/pipeline-configuration.md)
for controlling verbosity, parallelism, and output directories.
