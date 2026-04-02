# ggseg.extra 1.9.9.9003

## Deep cerebellar nuclei support

- `create_cerebellar_from_volume()` now detects deep cerebellar nuclei
  (Dentate, Interposed, Fastigial) that have volume voxels but no SUIT
  surface vertices. These are tessellated as individual 3D meshes with
  proper tkRAS-to-MNI coordinate transform, and rendered as smoothed
  coronal projection sf geometries in a separate "nuclei" view.
- Orphaned surface parcels (e.g. buckner17 17Networks_14) that are too small
  for any SUIT vertex to land on are now rescued by assigning the nearest
  surface vertex, keeping them on the flatmap.
- Voxel neighbor fill radius expanded from 1 to 3 (configurable) to better
  capture small regions during volume-to-surface sampling.
- Restored colour auto-fill in `read_suit_parcellation()` and
  `read_neuromaps_volume()`.

## Cerebellar atlas type and SUIT flatmap pipeline

New "cerebellar" atlas type added across the ggseg ecosystem (ggseg.formats,
ggseg, ggseg3d). Cerebellar atlases use SUIT flatmap sf polygons for 2D
rendering and per-region meshes for 3D (like subcortical).

Three creation pipelines:

- `create_cerebellar_from_gifti()` creates from GIFTI label files + SUIT
  flatmap surface.
- `create_cerebellar_from_annotation()` creates from FreeSurfer `.annot`
  files on the SUIT cerebellar surface + SUIT flatmap.
- `create_cerebellar_from_volume()` creates from a NIfTI cerebellar
  segmentation volume + SUIT 3D surface (for vol-to-surf sampling) + SUIT
  flatmap. Includes per-region 3D mesh tessellation.

Supporting functions:

- `read_suit_parcellation()` reads SUIT-format GIFTI labels with automatic
  hemisphere detection (Left/Right/Vermis).
- `ggseg_data_cerebellar()` (ggseg.formats) creates the data container.
- `is_cerebellar_atlas()` (ggseg.formats) type predicate.

## Boundary triangle splitting

Boundary triangles (where vertices belong to different atlas regions) are now
split into sub-polygons along edge midpoints instead of being assigned wholesale
to a single region. This eliminates the sawtooth artifacts at region borders
that resulted from the triangular mesh geometry.

- **2-region boundaries**: triangle is split at the midpoints of the two
  cross-boundary edges — the majority region gets a quadrilateral, the minority
  region gets a triangle.
- **3-region boundaries**: triangle is divided into three quadrilaterals meeting
  at the centroid.
- Default `tolerance` increased from 0.5 to 1 — the smoother borders tolerate
  higher simplification without visible degradation.

## Bug fixes

- `ensure_fs_compatible_nifti()` no longer errors when the NIfTI header cannot
  be read (e.g. `.mgz` files or nonexistent paths). It now falls through
  gracefully and lets downstream FreeSurfer commands handle the file.

# ggseg.extra 2.0.1

## Cortical pipeline: mesh projection

The cortical atlas pipeline now projects inflated mesh triangles directly to 2D
polygons via orthographic projection, replacing the screenshot-based contour
extraction from v2.0.0.

- **Much faster** — atlas creation completes in ~5 seconds instead of minutes.
- **Cleaner geometry** — no pixel staircase artifacts from rasterisation.
- **Fewer dependencies** — no FreeSurfer rendering, ImageMagick, or Chrome
  needed for 2D geometry (FreeSurfer is still required to *read* annotation
  files).
- **Better small-region visibility** — boundary faces are assigned to the
  smallest neighbouring region so tiny parcels are not swallowed by their
  neighbours.
- **Smooth region borders** — boundary triangles (vertices in different regions)
  are split along edge midpoints so each region gets a clean polygon slice,
  eliminating the sawtooth artifacts from whole-triangle assignment.

## Breaking changes

- Removed `method`, `snapshot_dim`, `smoothness`, and `steps` parameters from
  all `create_cortical_from_*()` functions. The pipeline always reads data and
  projects to 2D in one pass — no step-based control needed.
- Changed default `tolerance` from 0.5 to 1 — the triangle-splitting approach
  produces smoother borders that tolerate higher simplification.

## Lighter dependency footprint

- Moved `chromote`, `htmlwidgets`, `magick`, `smoothr`, `terra`, `RNifti`, and
  `freesurfer` from Imports to Suggests. Users who only need the cortical
  pipeline no longer need these packages installed. They are checked at runtime
  and requested when needed (subcortical, tract, and volumetric pipelines).

## New internals

- Added `R/mesh-projection.R` with the full geometric projection algorithm:
  orthonormal view basis computation, backface culling, per-face label
  assignment, and triangle-to-polygon union via sf.

# ggseg.extra 2.0.0

- Major rewrite of atlas creation pipelines with modular step-based architecture
- Added GIFTI (`.label.gii`) and CIFTI (`.dlabel.nii`) annotation support
- Added neuromaps surface and volume annotation pipelines
- Added whole-brain atlas creation from volumetric parcellations
- Added white-matter tract atlas creation from tractography files
- Added three-level verbosity control (silent/standard/debug)
- Deprecated `ggseg_atlas_repos()`, `install_ggseg_atlas()`, and
  `install_ggseg_atlas_all()` in favour of 'ggseg.hub'
- Moved `convert_legacy_brain_atlas()` to 'ggseg.formats' (re-exported)
- Removed rgdal, purrr, reticulate, and tidyr dependencies
- Replaced reticulate/kaleido snapshots with chromote
- Protected all parallel operations against multicore fork crashes
- Removed dead FreeSurfer wrapper functions
- Fixed read_ctab for multi-word labels
- Fixed subcortical label classification in whole-brain pipeline

# ggseg.extra 1.6

## 1.6.0

- Removed rgdal dependency, replaced with sf/terra (#49, #59)
- Fixed r-universe API calls (JSON array format change)
- Fixed vignette build issues with conditional evaluation for suggested packages
- Replaced reticulate/kaleido with webshot2 for plotly screenshots
- Updated system setup vignette with new requirements
- Added documentation for parallel processing and progress bars
- Added note about freesurfer dev version requirement
- Updated CITATION to use bibentry()
- Updated pkgdown site with ggseg brand styling
- Fixed mris_label2annot example documentation

# ggseg.extra 1.5

## 1.5.33.003

- small bug fix that prevented calls to FreeSurfer
- Possibility to initiate new atlas project from the RStudio Project GUI

## ggseg.extra 1.5.33

- removes purrr dependency
- used ggseg [r-universe](https://ggsegverse.r-universe.dev/#builds) as install repo for install functions

## ggseg.extra 1.5.32

- non-standard columns in 3d atlas are retained in 2d atlas
- Freesurfer annotation file custom S3 class implemented
- progressbar for region snapshots

## ggseg.extra 1.5.3

- Added pipeline functions for:
  - creating ggseg3d-atlas from annotation files
  - creating ggseg3d-atlas from volumetric files
  - creating ggseg-atlas from cortical ggseg3d-atlas
  - creating ggseg-atlas from volumetric files
- Added a `NEWS.md` file to track changes to the package.
