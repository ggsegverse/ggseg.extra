# ggseg.extra 1.9.9.9005

## Subcortical atlas builder helpers

New thin compositions of the existing `ggseg.formats` atlas ops and the
volume reader, distilled from the repeated boilerplate in the
`ggsegFreeSurfer` subcortical build scripts:

- `subcortical_slabs()` builds a slab table from the bounding box of
  a set of labels, reading the volume in the **same** frame the builder
  uses so coronal/axial/sagittal slabs can't be pointed at the wrong
  slices.
- `aseg_context()` collapses the standard post-processing chain (punch
  cortical white matter, strip the structures `aseg` doesn't draw, demote
  everything outside `focus` to grey context, drop empty views) into one
  call. The focus set is subtracted from the context set with exact,
  case-sensitive matching, so a region is never swallowed by a context
  entry that is a substring of its name (e.g. `Thalamus` vs
  `hypothalamus`). `aseg_hidden_labels()` returns the default stripped set.
- `lut_add()` / `lut_combine()` append and merge FreeSurfer-style colour
  tables (validating with `is_lut()` and warning on index clashes) for
  atlases that add custom prefixed labels.
- `create_subcortical_from_volume()` gained two opt-in arguments: `slabs`
  now also accepts a `subcortical_slabs()` list spec (e.g.
  `slabs = list(labels = 801:810, coronal = 3)`), and a new `context`
  argument runs `aseg_context()` on the finished 2D atlas (e.g.
  `context = list(focus = "Hippocampus")`). Both thread through
  `create_wholebrain_from_volume()`'s `subcortical_opts`.

## sf smoothing moves out of atlas creation

Pipeline-time simplification of 2D sf geometry was the most common reason
to re-run an otherwise expensive `create_*()` pipeline (10+ minutes for
volumetric atlases). All `create_*()` functions now return raw,
unsmoothed sf polygons. The (cheap) `atlas_smooth()` post-processing
step is the single place where simplification level is decided, so you
can iterate freely on a cached atlas:

```r
atlas <- create_cortical_from_annotation(...) |>
  atlas_smooth(keep = 0.2, exclude = "cortex_")
```

- 3D mesh smoothing (tessellation, FreeSurfer `mris_smooth`, decimation)
  is unchanged.
- `tolerance`, `smoothness` and `smooth_refinements` on every
  `create_*()` function are now soft-deprecated. Supplying any of them
  emits a `lifecycle::deprecate_warn()` and the value is otherwise
  ignored.
- `atlas_smooth()` gained `labels` / `exclude` regex arguments so the
  brain-outline geometry can stay crisp while everything else is
  simplified.
- `atlas_smooth()` also gained a `smoothness` argument that applies a
  positive-then-negative `sf::st_buffer()` (morphological closing)
  after vertex simplification. This restores the rounded sulcal curves
  the old pipeline `smoothness` argument produced, but as a per-region,
  post-atlas operation. Pass `keep = NULL` to skip vertex reduction and
  only round off voxel-edge stair-steps.
- The "large atlas" warning text now points at `atlas_smooth()` instead
  of the deprecated `tolerance` argument.
- `create_wholebrain_from_volume()` no longer injects a default
  `smooth_refinements = 2L` into the cerebellar sub-pipeline.

## API naming and argument consistency pass

A pass over the atlas-builder family (`create_cortical_from_*()`,
`create_subcortical_from_volume()`, `create_cerebellar_from_*()`,
`create_wholebrain_from_volume()`, `create_tract_from_tractography()`) and
the LUT helpers to make the API "as similar as possible" across atlas
types. Old names/arguments keep working with a `lifecycle::deprecate_warn()`.

- **Fixed:** `create_cortical_from_labels()` and
  `create_tract_from_tractography()` silently dropped region names when
  `input_lut` was a FreeSurfer-style LUT **file path**, because the parser
  only looked for a `region` column and files parse into an `idx`/`label`
  schema instead. It now falls back to `label` when `region` is absent.
- **Renamed** the colour-table reader/writer family for consistency with
  the already-dominant `input_lut` vocabulary used by every atlas builder:
  `read_ctab()` -> `read_lut()`, `write_ctab()` -> `write_lut()`,
  `is_ctab()` -> `is_lut()`, `get_ctab()` -> `get_lut()`. `lut_add()` and
  `lut_combine()` are unchanged.
- **Renamed** `create_cerebellar_from_volume()`'s `volume` argument to
  `input_volume`, matching its `create_subcortical_from_volume()` and
  `create_wholebrain_from_volume()` siblings.
- **Renamed** `mri_surf2surf_rereg()`'s `hemi` argument to `hemisphere`,
  matching the cortical builders. The default order (`"lh"` first) is
  unchanged.
- **Renamed** the volumetric `views` argument to `slabs` on
  `create_subcortical_from_volume()` and `create_tract_from_tractography()`,
  and `subcortical_views()` to `subcortical_slabs()` to match. This
  distinguishes it from the cortical builders' `views` (a character vector
  selecting standard panels), which is unchanged and unrelated.
- **Reordered** arguments across all five builder families onto one
  shared layout: primary input(s), `input_lut`, `atlas_name`, `output_dir`,
  type-specific structural arguments, refinement arguments
  (`vertex_size_limits`, `dilate`, `decimate`), the deprecated
  `tolerance`/`smoothness`/`smooth_refinements` trio, `cleanup`, `verbose`,
  `skip_existing`, `steps`, then any function-specific trailing arguments.
  Every call site in this package's own tests, vignettes, and examples
  already used named arguments for everything but the first one or two
  positional inputs, so this should be a no-op for callers doing the same;
  it is a silent behaviour change for any positional call beyond that.
- Internal: `create_wholebrain_from_volume()`'s `cortical_opts` allow-list
  is now derived reflectively from `create_cortical_from_annotation()`'s
  formals (matching how `subcortical_opts`/`cerebellar_opts` already
  worked) instead of a hand-maintained constant that could drift.

## Anatomical-context coregistration helpers

- New `coregister_volume()` wraps `mri_coreg` to align an atlas volume to
  a FreeSurfer subject's T1 grid (default `cvs_avg35_inMNI152`), returning
  a reusable LTA file.
- New `project_volume_anatomical()` resamples each atlas label with
  trilinear interpolation onto the target `aparc+aseg` grid, takes the
  argmax across labels, and produces a merged volume that combines the
  source `aparc+aseg` (anatomical brain-outline context) with the user's
  atlas labels. It returns a `list(volume, lut, id_offset)`: the merged
  volume _and_ a colour table aligned to it (FreeSurfer names for the
  surviving `aparc+aseg` context labels plus the user's labels at their
  shifted ids), so the context regions render with names `aseg_context()`
  recognises.
- New `prepare_subcortical_anatomical()` chains both in a single call,
  returning the same `list(volume, lut, id_offset)`.
  `create_subcortical_from_volume()` now accepts that list directly as
  `input_volume`, unpacking the matching colour table for you (an explicit
  `input_lut` still wins).
- Removes the ~50 lines of per-atlas boilerplate previously hand-rolled in
  `ggsegShen` and `ggsegHO` build scripts.
- `id_offset` parameter (default `200L`) shifts every input label ID in
  the merged volume so they don't collide with FreeSurfer `aparc+aseg`
  IDs (e.g. an atlas where `11` means "Putamen" while FS uses `11` for
  "Caudate"). The returned colour table is shifted in lock-step.
- `protect_cortex` parameter (default `TRUE`) keeps `aparc+aseg` cortex
  voxels (labels 1000-2999) and cortical white matter (`2`, `41`)
  intact even when the user's argmax wins above `threshold` — this
  preserves the brain-outline geometry that the subcortical pipeline
  draws as anatomical context.
- The per-voxel argmax streams the running winner across labels instead of
  materialising an `n_voxels x n_labels` probability matrix, so projecting a
  many-region atlas (e.g. Shen-268 onto a 256^3 grid) no longer needs tens
  of gigabytes of memory.

# ggseg.extra 1.9.9.9004

## Template-based atlas repo scaffolding

- `setup_atlas_repo()` now downloads the atlas template from
  [ggsegverse/ggseg-atlas-template](https://github.com/ggsegverse/ggseg-atlas-template)
  instead of bundling template files inside the package. This makes the
  template a single source of truth that can be updated independently.
- The generated scaffold includes all modern atlas repo conventions:
  Quarto README, Bootstrap 5 pkgdown config, code-quality workflow,
  render-readme workflow, update-codemeta workflow, and AI agent instructions.
- `data-raw/create-atlas.R` now scaffolds all pipeline methods (cortical,
  subcortical, cerebellar, tract, wholebrain) with commented sections.
- Falls back to a bundled minimal template when offline.
- Rich CLI messaging throughout the scaffolding process.

# ggseg.extra 1.9.9.9003

## Large-atlas warning

- `warn_if_large_atlas()` now scales its threshold with region count via
  `per_region = 50` (threshold = `max(max_vertices, per_region * n_regions)`).
  Prevents spurious warnings for high-resolution parcellations (e.g. Kong
  1000-parcel) where `keep_shapes = TRUE` sets a ~40 vertices/region floor.
- Fixed the follow-up hint which previously suggested raising `tolerance`
  to reduce vertices; lower values simplify more aggressively.

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
  needed for 2D geometry (FreeSurfer is still required to _read_ annotation
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
