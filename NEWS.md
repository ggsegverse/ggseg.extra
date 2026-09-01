# ggseg.extra 1.9.9.9015

## Minor improvements and fixes

- The anatomical context silhouette is now taken from a single slice for
  every view, never projected through the slab. Projecting it unions every
  sulcus the slab passes through and fills them in, so the grey brain came
  out as a smooth blob rather than a gyrified mantle; the deeper the slab,
  the worse it got. `cortex_slice_for_slab()` already chose a representative
  slice - the densest cortex slice within the slab - for axial and coronal
  views as well as sagittal, but only the sagittal branch used it. Structures
  are still projected through the slab, so small deep ones continue to show
  up in every view that passes through them.

- `create_tract_from_volume()` no longer sweeps the whole label volume once
  per tract. It collected each tract's voxels with `which(arr == label)`, so a
  35-tract atlas made 35 full passes over the array; the voxels are now
  gathered in a single pass and grouped by label, and the voxel-to-world
  affine is applied after thinning rather than before, so it transforms at
  most `4000` points per tract instead of every voxel. Output is unchanged.

## New features

- The grey anatomical silhouette behind a 2D view is now taken from the slice
  in the slab holding the most cortex, rather than from the slab midpoint. The
  silhouette is context, so it should be chosen for legibility — and a
  midpoint can land somewhere with almost nothing to draw. A mid-sagittal slab
  centred on the midline cuts the interhemispheric fissure:
  `cvs_avg35_inMNI152` has 797 cortical voxels at x=128 against 6703 four
  voxels away, so the outline came out in fragments while the structures in
  front of it were fine. Widening the slab could not fix it, since only the
  structures project through the slab. Ties are broken toward the midpoint, so
  a slab whose slices are equally informative keeps the position it had
  before.

# ggseg.extra 1.9.9.9014

## New features

- `project_volume_anatomical()` now warns when `protect_cortex` removes a
  label entirely. The guard blocks the atlas from overwriting the cortical
  ribbon and cerebral white matter, which is right for deep grey structures
  but erases a white-matter atlas from the only tissue it describes — and it
  did so silently. ggsegJHU's ICBM-DTI-81 atlas shipped for a release with its
  right superior longitudinal fasciculus missing outright, with nothing in the
  build output to show it. The warning names the lost labels and points at
  `protect_cortex = FALSE`.

## Bug fixes

- `write_lut()` no longer truncates label names to 29 characters. FreeSurfer
  parses its colour tables on whitespace and its own `FreeSurferColorLUT.txt`
  carries names up to 47 characters, so the cap corrupted every long label --
  and silently merged any two that were identical up to the cut. Julich-Brain's
  `Ch_123_(Basal_Forebrain)_right` came back as `Ch_123_Basal_Forebrain_righ`,
  losing the hemisphere suffix and with it the hemisphere.

- `clean_region_name()` now strips the same hemisphere affixes that
  `detect_hemi()` recognises, including the `L_`/`R_` prefix convention and
  `_left`/`_right` suffixes. Where the two disagreed the hemisphere ended up in
  `region` as well as `hemi`: `R_Fx` gave hemi `"right"` but region `"r fx"`,
  so the two halves of one structure looked like two unrelated structures to
  anything grouping on `region` -- including the new
  `ggseg.formats::atlas_view_select()`. A name that is _only_ a hemisphere word
  is left alone rather than stripped to nothing.

# ggseg.extra 1.9.9.9013

## New features

- `atlas_smooth()` gains `method`. The default `"close"` is the existing
  morphological closing, which rounds outlines but fills any hole narrower than
  the smoothing distance -- on a thin cortical ribbon that erases the sulci.
  `"chaikin"`, `"ksmooth"` and `"spline"` come from `smoothr::smooth()` and move
  vertices rather than dilating the shape, so enclosed holes stay open. Use
  `"close"` for solid shapes such as tract tubes and one of the others where the
  geometry has holes worth keeping.
- `atlas_smooth(smoothness =)` is now a 0--1 strength shared by every `method`,
  mapped internally onto each method's native parameter, so the same value means
  a comparable amount of smoothing whichever one is chosen. Values outside
  0--1 are an error carrying the conversion rule, rather than being silently
  reinterpreted: divide an old `method = "close"` distance by 5.

## Bug fixes

- 2D atlas geometry no longer loses its holes. `coords2sf()` grouped
  coordinates by `(.subid, .id)`, but `.subid` is the ring index within a
  polygon (1 = exterior, >1 = holes) and `.id` the polygon index, so every ring
  became its own solid polygon and every enclosed hole was filled. A thin
  cortical ribbon came out as a blob: the sagittal fsaverage slice measured
  20,117 against a true area of 17,481, with 44 of its 137 rings surviving.
  Rings are now assembled as exterior-plus-holes, and the area matches exactly.
  This affects every atlas built through `get_contours()` -- cortical,
  subcortical, wholebrain and tract -- so rebuilt atlases will differ from ones
  built before this fix.

- Tract 2D projections are no longer drawn in the wrong plane. `streamlines_to_volume()`
  built each tube in the template's native voxel layout and relied on
  `RNifti::orientation(nii) <- "RAS"` to convert it. For `.mgz` templates that
  assignment was a silent no-op — `read_volume()` returns a bare array carrying
  no affine, so `orientation()` reports `"RAS"` whatever the layout — while the
  anatomical reference _was_ converted, being read through
  `read_volume(reorient = TRUE)`. With an LIA template such as FreeSurfer's
  `aseg.mgz`, voxel axes 2 and 3 ended up swapped between the two, so axial
  projections were drawn over coronal anatomy and sagittal ones appeared
  rotated 90°. The volume is now reoriented explicitly.

- Tract 2D projections are no longer offset from the anatomical reference.
  `center_meshes()` translates centerlines to the origin for 3D display, and the
  snapshot step rasterised those translated coordinates as though they were
  world RAS, shifting every tract relative to the anatomy. The translation is
  now recorded and undone before rasterising; 3D output is unchanged.

- Sagittal cortex reference slices now come from their own slab rather than a
  fixed plane, matching what axial and coronal already did. A sagittal slab at
  an explicit position previously had its silhouette drawn somewhere else. An
  explicit `cortex_x` still wins, and hemisphere-named views fall back to their
  lateral positions when the slab holds no cortex to choose from.

- The anatomical reference for tract atlases now includes the brainstem,
  cerebellar cortex and deep grey structures alongside the cortical ribbon, so
  tracts descending out of the cerebrum are drawn against anatomy instead of
  empty space. White matter is excluded, cerebral and cerebellar alike: tracts
  run through it, and filling it would bury them. Excluding cerebellar white
  matter also keeps the cerebellum a foliated shell like the cerebral ribbon
  instead of a solid mass that merges with the occipital lobe in sagittal
  views.

- `create_tract_from_volume()` and `create_tract_from_tractography()` now honour
  `atlas_name` for the atlas object itself, not only for the output directory.
  The finished atlas previously took the name derived from its tract labels
  (e.g. `"tracts"`), ignoring what the caller asked for.

# ggseg.extra 1.9.9.9012

## New features

- `prepare_subcortical_mni152()` embeds a subcortical parcellation supplied in
  fixed FSL-MNI152 space into a FreeSurfer subject's `aseg` (via the known
  `mni152.register.dat` transform), replacing the lumped aseg structures the
  parcels subdivide and returning a merged volume plus a matching colour table
  ready for `create_subcortical_from_volume()`. It is the fixed-registration
  counterpart to `prepare_subcortical_anatomical()`, which instead computes an
  `mri_coreg` registration to `cvs_avg35_inMNI152`; use this one when the atlas
  already lives in a standard MNI152 template and should keep `fsaverage5`
  context. `aseg_subcortical_labels()` returns the lumped subcortical structure
  ids a finer parcellation typically subdivides.

- `create_tract_from_volume()` builds a white-matter tract atlas from a
  volumetric tract _label map_ (one integer label per tract) rather than from
  streamlines: each tract's voxel cloud is reduced to a principal-curve
  centerline and handed to `create_tract_from_tractography()`, which builds the
  3D tubes and 2D projection. This suits probabilistic tract atlases distributed
  as NIfTI label volumes (e.g. AtlasTrack). Adds `princurve` to Suggests.

## Bug fixes

- `create_tract_from_tractography()` no longer errors when `input_tracts` is an
  in-memory list of coordinate matrices: the setup log interpolated the matrices
  into a `{.path}` inline style, which `cli` cannot format as file paths.

# ggseg.extra 1.9.9.9011

## Minor improvements and fixes

- Workflows written by `use_atlas_github_actions()` now run on pull requests.
  `pkgdown` previously had no pull request trigger at all, so a broken
  reference index or vignette could only fail after merging; `code-quality`
  filtered pull requests to those targeting `main`, so a stacked pull request
  skipped linting entirely. Neither publishes from a pull request: the shared
  workflows guard the pkgdown deploy on `github.event_name`, and the coverage
  badge and README commits on `github.ref`.

# ggseg.extra 1.9.9.9010

## New features

- `use_atlas_github_actions()` adds the shared ggsegverse GitHub Actions
  workflows to a package, in the style of `usethis::use_github_action()`.
  `atlas_github_actions()` lists what is available. Run it on a freshly
  scaffolded atlas package, or on an existing one to replace hand-maintained
  workflows with the shared set.
- `setup_atlas_repo()` gains `github_actions`, TRUE by default.

## Minor improvements and fixes

- Atlas packages now receive workflows as short caller stubs for the reusable
  workflows in `ggsegverse/.github`, rather than inline copies. The scaffold
  previously shipped 229 lines of inline workflow, none of which called the
  shared workflows, so every new package started out with CI that had already
  drifted.
- `setup_atlas_repo()` no longer copies the atlas template's `.github/`
  directory. That directory is the template's own infrastructure — its
  smoke-test workflow and the scripts driving it — and had been leaking into
  every generated package.
- The offline fallback now produces the same workflows as the downloaded
  template, since they no longer come from the template at all. Previously the
  fallback silently omitted CI.

# ggseg.extra 1.9.9.9009

## Bug fixes

- The bundled atlas template no longer generates a broken package. Template
  placeholders were spelled `{GGSEG}` / `{REPO}`, which R parses as brace
  blocks, so `air format` rewrote `.{GGSEG}` into a separate expression and
  split `library({REPO})` across lines. Generated packages had an accessor
  that returned nothing and a test suite that referenced an undefined object.
- `data-raw/create-atlas.R` in the scaffold now calls the current API. It
  previously used `read_freesurfer_lut()` (never exported), `color_lut`,
  `input_gifti`, `input_cifti`, and a tract `input_volume` argument, none of
  which exist, and omitted the required `source` / `desc` arguments to
  `create_cortical_from_neuromaps()`. Every uncommented section would have
  errored.

## Minor improvements and fixes

- Template placeholders are now bare identifiers (`ATLASNAME`, `PKGNAME`,
  `YEARNUM`) so template sources parse as valid R and cannot be rewritten by
  R tooling. `setup_atlas_repo()` still substitutes the legacy brace-wrapped
  spelling, so templates published before this change continue to work.
- Added `air.toml` excluding `inst/templates/` and `inst/rstudio/templates/`
  from formatting.
- The scaffold now includes an `atlas_smooth()` post-processing step and no
  longer passes the deprecated `tolerance` argument.
- Generated packages set `Config/Needs/website: ggsegverse/ggseg.docs` and use
  the `ggseg.docs` pkgdown template instead of an inlined bslib theme, and no
  longer set `LazyData` without a `data/` directory.
- Generated packages now pass `R CMD check` cleanly. The template declared
  `License: CC0` while shipping an MIT-style `LICENSE` file, which produced a
  NOTE in every new package; it now declares `MIT + file LICENSE`, matching
  both the bundled file and the other ggseg atlas packages.
- Generated packages ship a `.lintr` excluding `data-raw/`, so the
  deliberately commented-out scaffold no longer trips `commented_code_linter`.

# ggseg.extra 1.9.9.9008

## Minor improvements and fixes

- Tract 2D projections now reuse the same centerline as the 3D tube (built with
  the configured `n_points` / `centerline_method`) instead of recomputing a
  different 50-point mean centerline, so the two representations agree.
- `read_tractography()` reads `.tck` files without the previous quadratic
  slow-down on large bundles.
- `create_tract_from_tractography()` validates `tube_segments` (integer >= 3),
  and degenerate leading tract segments no longer yield `NaN` tube vertices.
- Cerebellar trilinear resampling skips non-finite deformation coordinates
  rather than raising an error, and a deep nucleus that cannot be converted to
  polygons is now reported instead of silently dropped.
- `create_wholebrain_from_volume()` splits cortex at the correct (1-based)
  midline voxel; the left/right boundary was previously off by one voxel.
- Reading a FreeSurfer LUT warns about malformed lines; `write_lut()`
  validates its input; `read_lut()`/`read_dpv()` fail with clear messages on
  malformed headers, and `read_dpv()` handles zero-face surfaces.
- CIFTI files with more than one label map warn that only the first is used.
- Annotation files whose colour table already defines an "unknown" region no
  longer produce a duplicate `unknown` label.
- Contour extraction reports a clear error when no region yields a contour
  instead of a cryptic downstream failure.
- Subcortical mesh tessellation honors the requested verbosity inside parallel
  workers.
- Reading a subcortical surface surfaces the underlying conversion error when
  the fallback reader is unavailable, and the interactive atlas preview warns
  on 3D render failures instead of failing silently.
- `setup_atlas_repo()` no longer rewrites files under a template's `.git`
  directory and reports failed file copies/renames.

# ggseg.extra 1.9.9.9007

## Bug fixes

- `create_cerebellar_from_volume()` no longer errors on float-typed
  parcellation volumes. Sampling labels at the SUIT surface forced an integer
  `vapply()` template, so a double array — e.g. the SUIT volume written by
  `transform_mni_to_suit()` — aborted the build. The volume is now coerced to
  integer before sampling.
- `read_tractography()` reads `.trk` files whose header track count is `0`. The
  TrackVis format uses `0` to mean "count not recorded, read to end of file";
  the reader previously trusted the count and returned no streamlines, yielding
  an empty atlas. It now reads to the end of the file and treats a positive
  count as an upper bound.
- `create_cortical_from_neuromaps()` / `read_neuromaps_volume()` no longer abort
  with `'breaks' are not unique` when a continuous map has tied values (common
  for thresholded maps or maps with many zeros). Duplicate quantile breaks are
  collapsed and the bin count is reduced with a warning; an all-medial-wall
  hemisphere now errors with a clear message.
- Tract atlases built from in-memory streamline matrices (e.g.
  `create_tract_from_tractography(input_tracts = list(cst = matrix(...)))`) now
  detect voxel- versus RAS-space correctly. Detection previously flattened the
  matrices and always assumed RAS, misplacing voxel-space tracts.
- `create_tract_from_tractography()` now reads the voxel-to-world affine from
  FreeSurfer `.mgz` headers correctly, and warns instead of silently falling
  back to an approximate origin-centering heuristic when a template's affine
  cannot be read.
- `create_subcortical_from_volume()` derives a default `atlas_name` of `aseg`
  (not `aseg.nii`) from a `.nii.gz` input.
- `mri_info` is now called with a shell-quoted volume path, so cerebellar
  deep-nuclei meshing works for volume paths that contain spaces.
- Contour extraction (subcortical and tract 2D geometry) no longer crashes on
  empty or all-`NA` region rasters, keeps the valid contours when only some
  region geometries are empty, and reports a clear error when no region yields
  any contour instead of a cryptic `dplyr` failure.
- Verbosity and boolean options parse spelled-out strings consistently:
  `GGSEG_EXTRA_VERBOSE=false` now silences output, and string values such as
  `"yes"` or `"1"` are honored across the explicit, option, and
  environment-variable channels.

# ggseg.extra 1.9.9.9005

## Bug fixes

- `read_volume()` now reorients FreeSurfer `.mgz` volumes to RAS+, matching
  its long-standing behaviour for NIfTI inputs. Previously only `niftiImage`
  objects were reoriented, so `.mgz` volumes (e.g. FreeSurfer's LIA-oriented
  `aseg.mgz`) reached the RAS+-assuming projection code still in LIA order.
  Subcortical
  atlases built directly from a `.mgz` therefore came out left-right flipped in
  axial views, top-bottom flipped in coronal, and 90-degrees rotated in
  sagittal; atlases built from reoriented `.nii.gz` volumes (and tract atlases,
  whose geometry is already in scanner RAS) were unaffected. Volumes whose
  header carries no valid RAS information fall back to native voxel order.

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
