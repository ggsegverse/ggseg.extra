# Changelog

## ggseg.extra 1.9.9.9007

### Bug fixes

- [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md)
  no longer errors on float-typed parcellation volumes. Sampling labels
  at the SUIT surface forced an integer
  [`vapply()`](https://rdrr.io/r/base/lapply.html) template, so a double
  array — e.g. the SUIT volume written by
  [`transform_mni_to_suit()`](https://ggsegverse.github.io/ggseg.extra/reference/transform_mni_to_suit.md)
  — aborted the build. The volume is now coerced to integer before
  sampling.
- [`read_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/read_tractography.md)
  reads `.trk` files whose header track count is `0`. The TrackVis
  format uses `0` to mean “count not recorded, read to end of file”; the
  reader previously trusted the count and returned no streamlines,
  yielding an empty atlas. It now reads to the end of the file and
  treats a positive count as an upper bound.
- [`create_cortical_from_neuromaps()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_neuromaps.md)
  /
  [`read_neuromaps_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/read_neuromaps_volume.md)
  no longer abort with `'breaks' are not unique` when a continuous map
  has tied values (common for thresholded maps or maps with many zeros).
  Duplicate quantile breaks are collapsed and the bin count is reduced
  with a warning; an all-medial-wall hemisphere now errors with a clear
  message.
- Tract atlases built from in-memory streamline matrices (e.g.
  `create_tract_from_tractography(input_tracts = list(cst = matrix(...)))`)
  now detect voxel- versus RAS-space correctly. Detection previously
  flattened the matrices and always assumed RAS, misplacing voxel-space
  tracts.
- [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
  now reads the voxel-to-world affine from FreeSurfer `.mgz` headers
  correctly, and warns instead of silently falling back to an
  approximate origin-centering heuristic when a template’s affine cannot
  be read.
- [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  derives a default `atlas_name` of `aseg` (not `aseg.nii`) from a
  `.nii.gz` input.
- `mri_info` is now called with a shell-quoted volume path, so
  cerebellar deep-nuclei meshing works for volume paths that contain
  spaces.
- Contour extraction (subcortical and tract 2D geometry) no longer
  crashes on empty or all-`NA` region rasters, keeps the valid contours
  when only some region geometries are empty, and reports a clear error
  when no region yields any contour instead of a cryptic `dplyr`
  failure.
- Verbosity and boolean options parse spelled-out strings consistently:
  `GGSEG_EXTRA_VERBOSE=false` now silences output, and string values
  such as `"yes"` or `"1"` are honored across the explicit, option, and
  environment-variable channels.

## ggseg.extra 1.9.9.9005

### Bug fixes

- `read_volume()` now reorients FreeSurfer `.mgz` volumes to RAS+,
  matching its long-standing behaviour for NIfTI inputs. Previously only
  `niftiImage` objects were reoriented, so `.mgz` volumes
  (e.g. FreeSurfer’s LIA-oriented `aseg.mgz`) reached the RAS+-assuming
  projection code still in LIA order. Subcortical atlases built directly
  from a `.mgz` therefore came out left-right flipped in axial views,
  top-bottom flipped in coronal, and 90-degrees rotated in sagittal;
  atlases built from reoriented `.nii.gz` volumes (and tract atlases,
  whose geometry is already in scanner RAS) were unaffected. Volumes
  whose header carries no valid RAS information fall back to native
  voxel order.

### Subcortical atlas builder helpers

New thin compositions of the existing `ggseg.formats` atlas ops and the
volume reader, distilled from the repeated boilerplate in the
`ggsegFreeSurfer` subcortical build scripts:

- [`subcortical_slabs()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
  builds a slab table from the bounding box of a set of labels, reading
  the volume in the **same** frame the builder uses so
  coronal/axial/sagittal slabs can’t be pointed at the wrong slices.
- [`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)
  collapses the standard post-processing chain (punch cortical white
  matter, strip the structures `aseg` doesn’t draw, demote everything
  outside `focus` to grey context, drop empty views) into one call. The
  focus set is subtracted from the context set with exact,
  case-sensitive matching, so a region is never swallowed by a context
  entry that is a substring of its name (e.g. `Thalamus` vs
  `hypothalamus`).
  [`aseg_hidden_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_hidden_labels.md)
  returns the default stripped set.
- [`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md)
  /
  [`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md)
  append and merge FreeSurfer-style colour tables (validating with
  [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)
  and warning on index clashes) for atlases that add custom prefixed
  labels.
- [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  gained two opt-in arguments: `slabs` now also accepts a
  [`subcortical_slabs()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
  list spec (e.g. `slabs = list(labels = 801:810, coronal = 3)`), and a
  new `context` argument runs
  [`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)
  on the finished 2D atlas (e.g.
  `context = list(focus = "Hippocampus")`). Both thread through
  [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)’s
  `subcortical_opts`.

### sf smoothing moves out of atlas creation

Pipeline-time simplification of 2D sf geometry was the most common
reason to re-run an otherwise expensive `create_*()` pipeline (10+
minutes for volumetric atlases). All `create_*()` functions now return
raw, unsmoothed sf polygons. The (cheap)
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
post-processing step is the single place where simplification level is
decided, so you can iterate freely on a cached atlas:

``` r

atlas <- create_cortical_from_annotation(...) |>
  atlas_smooth(keep = 0.2, exclude = "cortex_")
```

- 3D mesh smoothing (tessellation, FreeSurfer `mris_smooth`, decimation)
  is unchanged.
- `tolerance`, `smoothness` and `smooth_refinements` on every
  `create_*()` function are now soft-deprecated. Supplying any of them
  emits a
  [`lifecycle::deprecate_warn()`](https://lifecycle.r-lib.org/reference/deprecate_soft.html)
  and the value is otherwise ignored.
- [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  gained `labels` / `exclude` regex arguments so the brain-outline
  geometry can stay crisp while everything else is simplified.
- [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  also gained a `smoothness` argument that applies a
  positive-then-negative
  [`sf::st_buffer()`](https://r-spatial.github.io/sf/reference/geos_unary.html)
  (morphological closing) after vertex simplification. This restores the
  rounded sulcal curves the old pipeline `smoothness` argument produced,
  but as a per-region, post-atlas operation. Pass `keep = NULL` to skip
  vertex reduction and only round off voxel-edge stair-steps.
- The “large atlas” warning text now points at
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
  instead of the deprecated `tolerance` argument.
- [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
  no longer injects a default `smooth_refinements = 2L` into the
  cerebellar sub-pipeline.

### API naming and argument consistency pass

A pass over the atlas-builder family (`create_cortical_from_*()`,
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md),
`create_cerebellar_from_*()`,
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md),
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md))
and the LUT helpers to make the API “as similar as possible” across
atlas types. Old names/arguments keep working with a
[`lifecycle::deprecate_warn()`](https://lifecycle.r-lib.org/reference/deprecate_soft.html).

- **Fixed:**
  [`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md)
  and
  [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
  silently dropped region names when `input_lut` was a FreeSurfer-style
  LUT **file path**, because the parser only looked for a `region`
  column and files parse into an `idx`/`label` schema instead. It now
  falls back to `label` when `region` is absent.
- **Renamed** the colour-table reader/writer family for consistency with
  the already-dominant `input_lut` vocabulary used by every atlas
  builder:
  [`read_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
  -\>
  [`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
  [`write_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
  -\>
  [`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md),
  [`is_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)
  -\>
  [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md),
  [`get_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md)
  -\>
  [`get_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md).
  [`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md)
  and
  [`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md)
  are unchanged.
- **Renamed**
  [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md)’s
  `volume` argument to `input_volume`, matching its
  [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  and
  [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
  siblings.
- **Renamed**
  [`mri_surf2surf_rereg()`](https://ggsegverse.github.io/ggseg.extra/reference/mri_surf2surf_rereg.md)’s
  `hemi` argument to `hemisphere`, matching the cortical builders. The
  default order (`"lh"` first) is unchanged.
- **Renamed** the volumetric `views` argument to `slabs` on
  [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  and
  [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md),
  and
  [`subcortical_views()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
  to
  [`subcortical_slabs()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
  to match. This distinguishes it from the cortical builders’ `views` (a
  character vector selecting standard panels), which is unchanged and
  unrelated.
- **Reordered** arguments across all five builder families onto one
  shared layout: primary input(s), `input_lut`, `atlas_name`,
  `output_dir`, type-specific structural arguments, refinement arguments
  (`vertex_size_limits`, `dilate`, `decimate`), the deprecated
  `tolerance`/`smoothness`/`smooth_refinements` trio, `cleanup`,
  `verbose`, `skip_existing`, `steps`, then any function-specific
  trailing arguments. Every call site in this package’s own tests,
  vignettes, and examples already used named arguments for everything
  but the first one or two positional inputs, so this should be a no-op
  for callers doing the same; it is a silent behaviour change for any
  positional call beyond that.
- Internal:
  [`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)’s
  `cortical_opts` allow-list is now derived reflectively from
  [`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md)’s
  formals (matching how `subcortical_opts`/`cerebellar_opts` already
  worked) instead of a hand-maintained constant that could drift.

### Anatomical-context coregistration helpers

- New
  [`coregister_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/coregister_volume.md)
  wraps `mri_coreg` to align an atlas volume to a FreeSurfer subject’s
  T1 grid (default `cvs_avg35_inMNI152`), returning a reusable LTA file.
- New
  [`project_volume_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/project_volume_anatomical.md)
  resamples each atlas label with trilinear interpolation onto the
  target `aparc+aseg` grid, takes the argmax across labels, and produces
  a merged volume that combines the source `aparc+aseg` (anatomical
  brain-outline context) with the user’s atlas labels. It returns a
  `list(volume, lut, id_offset)`: the merged volume *and* a colour table
  aligned to it (FreeSurfer names for the surviving `aparc+aseg` context
  labels plus the user’s labels at their shifted ids), so the context
  regions render with names
  [`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)
  recognises.
- New
  [`prepare_subcortical_anatomical()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_anatomical.md)
  chains both in a single call, returning the same
  `list(volume, lut, id_offset)`.
  [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  now accepts that list directly as `input_volume`, unpacking the
  matching colour table for you (an explicit `input_lut` still wins).
- Removes the ~50 lines of per-atlas boilerplate previously hand-rolled
  in `ggsegShen` and `ggsegHO` build scripts.
- `id_offset` parameter (default `200L`) shifts every input label ID in
  the merged volume so they don’t collide with FreeSurfer `aparc+aseg`
  IDs (e.g. an atlas where `11` means “Putamen” while FS uses `11` for
  “Caudate”). The returned colour table is shifted in lock-step.
- `protect_cortex` parameter (default `TRUE`) keeps `aparc+aseg` cortex
  voxels (labels 1000-2999) and cortical white matter (`2`, `41`) intact
  even when the user’s argmax wins above `threshold` — this preserves
  the brain-outline geometry that the subcortical pipeline draws as
  anatomical context.
- The per-voxel argmax streams the running winner across labels instead
  of materialising an `n_voxels x n_labels` probability matrix, so
  projecting a many-region atlas (e.g. Shen-268 onto a 256^3 grid) no
  longer needs tens of gigabytes of memory.

## ggseg.extra 1.9.9.9004

### Template-based atlas repo scaffolding

- [`setup_atlas_repo()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_atlas_repo.md)
  now downloads the atlas template from
  [ggsegverse/ggseg-atlas-template](https://github.com/ggsegverse/ggseg-atlas-template)
  instead of bundling template files inside the package. This makes the
  template a single source of truth that can be updated independently.
- The generated scaffold includes all modern atlas repo conventions:
  Quarto README, Bootstrap 5 pkgdown config, code-quality workflow,
  render-readme workflow, update-codemeta workflow, and AI agent
  instructions.
- `data-raw/create-atlas.R` now scaffolds all pipeline methods
  (cortical, subcortical, cerebellar, tract, wholebrain) with commented
  sections.
- Falls back to a bundled minimal template when offline.
- Rich CLI messaging throughout the scaffolding process.

## ggseg.extra 1.9.9.9003

### Large-atlas warning

- `warn_if_large_atlas()` now scales its threshold with region count via
  `per_region = 50` (threshold =
  `max(max_vertices, per_region * n_regions)`). Prevents spurious
  warnings for high-resolution parcellations (e.g. Kong 1000-parcel)
  where `keep_shapes = TRUE` sets a ~40 vertices/region floor.
- Fixed the follow-up hint which previously suggested raising
  `tolerance` to reduce vertices; lower values simplify more
  aggressively.

### Deep cerebellar nuclei support

- [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md)
  now detects deep cerebellar nuclei (Dentate, Interposed, Fastigial)
  that have volume voxels but no SUIT surface vertices. These are
  tessellated as individual 3D meshes with proper tkRAS-to-MNI
  coordinate transform, and rendered as smoothed coronal projection sf
  geometries in a separate “nuclei” view.
- Orphaned surface parcels (e.g. buckner17 17Networks_14) that are too
  small for any SUIT vertex to land on are now rescued by assigning the
  nearest surface vertex, keeping them on the flatmap.
- Voxel neighbor fill radius expanded from 1 to 3 (configurable) to
  better capture small regions during volume-to-surface sampling.
- Restored colour auto-fill in
  [`read_suit_parcellation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_suit_parcellation.md)
  and
  [`read_neuromaps_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/read_neuromaps_volume.md).

### Cerebellar atlas type and SUIT flatmap pipeline

New “cerebellar” atlas type added across the ggseg ecosystem
(ggseg.formats, ggseg, ggseg3d). Cerebellar atlases use SUIT flatmap sf
polygons for 2D rendering and per-region meshes for 3D (like
subcortical).

Three creation pipelines:

- [`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md)
  creates from GIFTI label files + SUIT flatmap surface.
- [`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md)
  creates from FreeSurfer `.annot` files on the SUIT cerebellar
  surface + SUIT flatmap.
- [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md)
  creates from a NIfTI cerebellar segmentation volume + SUIT 3D surface
  (for vol-to-surf sampling) + SUIT flatmap. Includes per-region 3D mesh
  tessellation.

Supporting functions:

- [`read_suit_parcellation()`](https://ggsegverse.github.io/ggseg.extra/reference/read_suit_parcellation.md)
  reads SUIT-format GIFTI labels with automatic hemisphere detection
  (Left/Right/Vermis).
- [`ggseg_data_cerebellar()`](https://ggsegverse.github.io/ggseg.formats/reference/ggseg_data_cerebellar.html)
  (ggseg.formats) creates the data container.
- [`is_cerebellar_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/is_ggseg_atlas.html)
  (ggseg.formats) type predicate.

### Boundary triangle splitting

Boundary triangles (where vertices belong to different atlas regions)
are now split into sub-polygons along edge midpoints instead of being
assigned wholesale to a single region. This eliminates the sawtooth
artifacts at region borders that resulted from the triangular mesh
geometry.

- **2-region boundaries**: triangle is split at the midpoints of the two
  cross-boundary edges — the majority region gets a quadrilateral, the
  minority region gets a triangle.
- **3-region boundaries**: triangle is divided into three quadrilaterals
  meeting at the centroid.
- Default `tolerance` increased from 0.5 to 1 — the smoother borders
  tolerate higher simplification without visible degradation.

### Bug fixes

- `ensure_fs_compatible_nifti()` no longer errors when the NIfTI header
  cannot be read (e.g. `.mgz` files or nonexistent paths). It now falls
  through gracefully and lets downstream FreeSurfer commands handle the
  file.

## ggseg.extra 2.0.1

### Cortical pipeline: mesh projection

The cortical atlas pipeline now projects inflated mesh triangles
directly to 2D polygons via orthographic projection, replacing the
screenshot-based contour extraction from v2.0.0.

- **Much faster** — atlas creation completes in ~5 seconds instead of
  minutes.
- **Cleaner geometry** — no pixel staircase artifacts from
  rasterisation.
- **Fewer dependencies** — no FreeSurfer rendering, ImageMagick, or
  Chrome needed for 2D geometry (FreeSurfer is still required to *read*
  annotation files).
- **Better small-region visibility** — boundary faces are assigned to
  the smallest neighbouring region so tiny parcels are not swallowed by
  their neighbours.
- **Smooth region borders** — boundary triangles (vertices in different
  regions) are split along edge midpoints so each region gets a clean
  polygon slice, eliminating the sawtooth artifacts from whole-triangle
  assignment.

### Breaking changes

- Removed `method`, `snapshot_dim`, `smoothness`, and `steps` parameters
  from all `create_cortical_from_*()` functions. The pipeline always
  reads data and projects to 2D in one pass — no step-based control
  needed.
- Changed default `tolerance` from 0.5 to 1 — the triangle-splitting
  approach produces smoother borders that tolerate higher
  simplification.

### Lighter dependency footprint

- Moved `chromote`, `htmlwidgets`, `magick`, `smoothr`, `terra`,
  `RNifti`, and `freesurfer` from Imports to Suggests. Users who only
  need the cortical pipeline no longer need these packages installed.
  They are checked at runtime and requested when needed (subcortical,
  tract, and volumetric pipelines).

### New internals

- Added `R/mesh-projection.R` with the full geometric projection
  algorithm: orthonormal view basis computation, backface culling,
  per-face label assignment, and triangle-to-polygon union via sf.

## ggseg.extra 2.0.0

- Major rewrite of atlas creation pipelines with modular step-based
  architecture
- Added GIFTI (`.label.gii`) and CIFTI (`.dlabel.nii`) annotation
  support
- Added neuromaps surface and volume annotation pipelines
- Added whole-brain atlas creation from volumetric parcellations
- Added white-matter tract atlas creation from tractography files
- Added three-level verbosity control (silent/standard/debug)
- Deprecated `ggseg_atlas_repos()`, `install_ggseg_atlas()`, and
  `install_ggseg_atlas_all()` in favour of ‘ggseg.hub’
- Moved
  [`convert_legacy_brain_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/convert_legacy_brain_atlas.html)
  to ‘ggseg.formats’ (re-exported)
- Removed rgdal, purrr, reticulate, and tidyr dependencies
- Replaced reticulate/kaleido snapshots with chromote
- Protected all parallel operations against multicore fork crashes
- Removed dead FreeSurfer wrapper functions
- Fixed read_ctab for multi-word labels
- Fixed subcortical label classification in whole-brain pipeline

## ggseg.extra 1.6

### 1.6.0

- Removed rgdal dependency, replaced with sf/terra
  ([\#49](https://github.com/ggsegverse/ggseg.extra/issues/49),
  [\#59](https://github.com/ggsegverse/ggseg.extra/issues/59))
- Fixed r-universe API calls (JSON array format change)
- Fixed vignette build issues with conditional evaluation for suggested
  packages
- Replaced reticulate/kaleido with webshot2 for plotly screenshots
- Updated system setup vignette with new requirements
- Added documentation for parallel processing and progress bars
- Added note about freesurfer dev version requirement
- Updated CITATION to use bibentry()
- Updated pkgdown site with ggseg brand styling
- Fixed mris_label2annot example documentation

## ggseg.extra 1.5

### 1.5.33.003

- small bug fix that prevented calls to FreeSurfer
- Possibility to initiate new atlas project from the RStudio Project GUI

### ggseg.extra 1.5.33

- removes purrr dependency
- used ggseg [r-universe](https://ggsegverse.r-universe.dev/#builds) as
  install repo for install functions

### ggseg.extra 1.5.32

- non-standard columns in 3d atlas are retained in 2d atlas
- Freesurfer annotation file custom S3 class implemented
- progressbar for region snapshots

### ggseg.extra 1.5.3

- Added pipeline functions for:
  - creating ggseg3d-atlas from annotation files
  - creating ggseg3d-atlas from volumetric files
  - creating ggseg-atlas from cortical ggseg3d-atlas
  - creating ggseg-atlas from volumetric files
- Added a `NEWS.md` file to track changes to the package.
