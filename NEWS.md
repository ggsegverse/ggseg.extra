# ggseg.extra 1.9.9.9144

This section becomes the 2.0.0 release notes at submission. It is the first
CRAN release of ggseg.extra, the atlas-building package of
the ggsegverse, renamed and restructured from 'ggsegExtra' for the ggsegverse
2.0 architecture. Every pipeline now returns a single `ggseg_atlas` object
holding 2D polygons and 3D meshes together, and geometry shaping has moved out
of atlas creation into cheap post-creation verbs you can retune without
rebuilding. Twelve `create_*()` entry points cover cortical, subcortical,
cerebellar, whole-brain and white-matter tract atlases, built from FreeSurfer
annotations and labels, GIFTI, CIFTI, neuromaps, NIfTI/MGZ parcellation volumes
and tractography files.

## Breaking changes

- The package is `ggseg.extra`; the old `ggsegExtra` name is gone.

- `ggseg.formats` moves from `Imports` to `Depends`, so
  `library(ggseg.extra)` attaches the whole atlas vocabulary. The
  re-exports are gone with it, so `ggseg.extra::atlas_view_keep()` and the
  like no longer resolve -- call them unqualified, or as
  `ggseg.formats::atlas_view_keep()`.

- A label the lookup table does not list is not drawn. Declare a label to
  draw it.

- A `context` value other than yes or no names a group, and every row
  carrying that name is traced as one silhouette called after it.

- In `create_subcortical_from_volume()` the lookup table decides what is a
  region and what is context; nothing is recognised by id or name. A row
  whose `context` column is `TRUE` is context. Mark the cortex with
  `lut$context <- grepl("Cortex", lut$label)`, and drop context you do not
  want with `atlas_context_remove()`.

- Geometry shaping is no longer part of atlas creation. `dilate`,
  `smoothness`, `tolerance` and `smooth_refinements` are rejected by every
  `create_*()`; use `atlas_polish()`, or `atlas_simplify()`,
  `atlas_smooth()` and `atlas_dilate()` on the finished atlas.

- The `ggseg.extra.tolerance` and `ggseg.extra.smoothness` options and their
  `GGSEG_EXTRA_*` environment variables are removed.

- `atlas_smooth()` and `atlas_polish()` default to `method = "chaikin"`,
  which preserves sulci. **Atlases smoothed with the default want
  rebuilding**; pass `method = "close"` for the old behaviour.

- `atlas_smooth()` and `atlas_simplify()` do one thing each; `keep` belongs
  to `atlas_simplify()`.

- `atlas_view_remove_sparse()` drops the views a build left nearly empty,
  counting what each view holds rather than naming views to remove.
  `atlas_view_region_counts()` reports the counts.

- The colour-table functions are named after lookup tables: `read_lut()`,
  `write_lut()`, `is_lut()` and `get_lut()`. The `*_ctab()` spellings are
  removed.

- `sitrep()` replaces `setup_sitrep()`, and `ggseg_atlas_github_actions()`
  replaces `atlas_github_actions()`.

- The volumetric creators take `views`, and `subcortical_views()` builds the
  table: each row is one view of the built atlas, its `name` becoming the
  `view` that `ggseg.formats::atlas_views()` reports. The `slabs` spelling
  used during the 2.0 dev cycle is deprecated and still works.

- Related arguments are grouped into lists: `tube_opts` in
  `create_tract_from_tractography()`; `labels`, `projection_opts`,
  `cortical_opts`, `subcortical_opts` and `cerebellar_opts` in
  `create_wholebrain_from_volume()`.

- `create_cerebellar_from_volume()` takes `input_volume` first, and
  `read_neuromaps_volume()` takes `breaks` second and `output_dir` last.

- `mri_surf2surf_rereg()` takes `hemisphere` rather than `hemi`.

- `registration` means one thing across the package: `"mni152"`, `"header"`,
  or a path to a register.dat or LTA file. `registration = NULL` and
  `regheader` are gone; pass `projection_opts = list(registration = )`.

- `breaks` replaces `n_bins` in `create_cortical_from_neuromaps()`,
  `read_neuromaps_annotation()` and `read_neuromaps_volume()`: a bin count,
  the edges, or a function returning them. Both hemispheres share one set of
  edges.

- `read_tractography()` returns `.trk` streamlines in RAS world millimetres
  and reads big-endian files. `create_tract_from_tractography()` no longer
  accepts `coord_space = "voxel"` for tractography files.

- `create_wholebrain_from_volume()` registers MNI152 volumes with
  FreeSurfer's `average/mni152.register.dat`. **Cortical atlases built from
  MNI152 volumes must be rebuilt.**

- Subcortical and tract contours are traced from the projection matrix
  rather than from a PNG of it (#139). **Atlases built with earlier versions
  need rebuilding**, and `atlas_dilate(amount = )` and
  `atlas_smooth(smoothness = )` now mean voxels rather than canvas pixels.

- The subcortical pipeline has six steps and the tract pipeline four, and
  `steps` is bounds-checked.

- `skip_existing` defaults to `FALSE`, and every reuse is reported naming
  the step.

- Cerebellar region names come from `label_to_region()`, which strips
  `vermis` and `midline` alongside `left` and `right`. Names change on the
  next rebuild; `label` is unchanged.

- The cerebellar flatmap gets a `cerebellum` backdrop, and perimeter regions
  are no longer inflated to the flatmap edge. Rebuilding changes geometry
  slightly.

- Every cortical atlas keeps its `unknown` medial wall as grey context: no
  `core` row, no palette entry, no 3D vertices.

- 2D geometry keeps its holes; `coords2sf()` assembles rings as exterior
  plus holes. Every atlas built through `get_contours()` differs from one
  built before.

- The cortical creators have no `method`, `snapshot_dim` or `steps`
  arguments.

- `ggseg_atlas_repos()`, `install_ggseg_atlas()` and
  `install_ggseg_atlas_all()` are removed; installing atlases is
  'ggsegverse's job. `convert_legacy_brain_atlas()` lives in 'ggseg.formats'
  and is re-exported here.

- The dependency footprint is much lighter. `chromote`, `magick`,
  `htmlwidgets`, `rgdal`, `purrr`, `reticulate` and `tidyr` are gone;
  `freesurfer` (>= 1.9.0), `freesurferformats`, `ciftiTools` (>= 0.17.4),
  `gifti`, `RNifti`, `Rvcg`, `terra`, `smoothr`, `princurve`, `rgl`,
  `neuromapr`, `ggseg` and `future` are Suggests, checked at run time.

- `region` is derived from the region's identifier rather than copied from
  it. A lookup table that declares a `region` column is used as given.
  `label` is unchanged.

- The core display column is `display`, following `ggseg.formats`.

- `hemi` is `"left"`, `"right"` or `"midline"` only. The vermis is
  `"midline"`; `"vermis"` and `"middle"` are still read as input.

## New features

- Cerebellar atlases are a first-class type, with SUIT flatmap polygons for
  2D and per-region meshes for 3D. `create_cerebellar_from_gifti()`,
  `create_cerebellar_from_annotation()` and `create_cerebellar_from_volume()`
  build them, and `read_suit_parcellation()` reads SUIT-format GIFTI labels.

- Deep cerebellar nuclei with volume voxels but no SUIT surface vertices are
  tessellated as individual meshes and drawn as a separate coronal `nuclei`
  view. Surface parcels too small for any SUIT vertex are rescued onto the
  flatmap.

- `create_wholebrain_from_volume()` builds cortical, subcortical and
  cerebellar sub-atlases from a single volumetric parcellation, classifying
  each label from the lookup table and reporting what it had to infer.

- `create_tract_from_tractography()` builds a tract atlas from `.trk`/`.tck`
  files or coordinate matrices, and `create_tract_from_volume()` from a
  volumetric tract label map via principal-curve centerlines. Both produce 3D
  tubes and 2D slice projections.

- `create_wm_from_volume()` builds a white-matter atlas from a label volume:
  the subcortical pipeline typed `"wm"`.

- `create_cortical_from_cifti()` and `read_cifti_annotation()` read CIFTI
  dense label files, and `read_cifti_subcortical()` extracts a CIFTI file's
  subcortical voxels into a NIfTI volume plus colour table (#85). GIFTI
  `.label.gii` annotations are supported throughout.

- `create_cortical_from_neuromaps()`, `read_neuromaps_annotation()` and
  `read_neuromaps_volume()` build atlases from neuromaps surface and volume
  annotations, binning continuous maps into regions.

- The cortical pipeline projects inflated mesh triangles straight to 2D
  polygons. Atlas creation takes about five seconds rather than minutes, and
  the geometry carries no rasterisation staircase.

- Boundary triangles spanning regions are split along edge midpoints, so
  borders are clean rather than sawtoothed, and boundary faces go to the
  smallest neighbouring region so tiny parcels survive.

- A cortical parcellation covering only part of the mantle gets the rest as a
  silhouette to sit on (#285): one `lh_cortex`/`rh_cortex` region per
  hemisphere, drawn behind the parcellation with no colour or legend entry. A
  sparse cerebellar parcellation gets a single `cerebellum` backdrop.

- `atlas_polish()` simplifies and smooths in one call against a stated vertex
  budget (#186).

- `atlas_smooth()` gains `method` -- `"close"`, `"chaikin"`, `"ksmooth"` and
  `"spline"`, the last three keeping enclosed holes open -- a `smoothness`
  strength on one 0--1 scale, and `vertex_budget`.

- `atlas_dilate()` grows or shrinks region geometry on a finished atlas.

- `count_vertices()` reports how many polygon vertices each region carries.

- `context_pattern()` gives the label pattern matching an atlas's context.
  `atlas_polish()`, `atlas_simplify()`, `atlas_smooth()` and `atlas_dilate()`
  accept a function as `labels` or `exclude`, so `exclude = context_pattern`
  works mid-pipe.

- `label_to_region()` is exported: the rule the pipelines use to fill an
  atlas's `region` column from its labels.

- A lookup table can declare `type`, `hemi` and `context` columns, which the
  creators honour rather than guessing; `write_lut()` and `read_lut()` carry
  them through a round trip as a FreeSurfer-readable colour table. A declared
  hemisphere stops a midline-crossing parcel becoming two regions.
  `aseg_subcortical_labels()` returns the lumped structure ids a finer
  parcellation subdivides.

- `lut_classify_anatomy()` fills a lookup table's `type` column by resampling
  FreeSurfer's `aparc+aseg` onto the volume's grid and judging each label on
  the grey matter it touches, rather than by matching names.

- `lut_generate_colors()` builds a palette for a names-only lookup table,
  assigning one colour per structure so its two hemispheres share it. `by`
  colours each group of a column from the whole circle.

- `lut_add()` and `lut_combine()` append and merge colour tables, warning on
  index clashes.

- `subcortical_slabs()` builds a slab table from the bounding box of a set of
  labels, and `create_subcortical_from_volume(slabs = )` accepts that spec
  directly.

- `coregister_volume()` aligns an atlas volume to a FreeSurfer subject's T1
  grid, `project_volume_anatomical()` resamples labels onto the target
  `aparc+aseg` grid, and `prepare_subcortical_anatomical()` chains both.
  `id_offset` avoids id collisions and `protect_cortex` keeps the ribbon
  intact for the brain outline.

- `prepare_subcortical_mni152()` embeds an FSL-MNI152 parcellation into a
  subject's `aseg` via `mni152.register.dat`.
  `create_subcortical_from_volume()` accepts its `list(volume, lut,
  id_offset)` directly as `input_volume`.

- `create_wholebrain_from_volume()` gains `cerebellar_opts =
  list(cerebellar_space = )`, so an MNI cerebellar volume is transformed with
  the matching SUIT deformation field before being sampled onto the flatmap.

- The tract creators gain `coord_space`, to declare whether streamline
  coordinates are `"voxel"` indices or RAS world `"mm"`.

- `create_wholebrain_from_volume(context_opts = list(silhouette = "aseg"))`
  substitutes FreeSurfer's gyrified `aseg` ribbon for the parcellation's own
  cortical labels. It is another subject's anatomy, so it is asked for rather
  than inferred, and the pipeline reports which silhouette it drew.

- `setup_atlas_repo()` scaffolds an atlas package from the
  ggseg-atlas-template repository, falling back to a bundled template when
  offline. `use_atlas_github_actions()` adds the shared workflows as caller
  stubs, and `ggseg_atlas_github_actions()` lists what is available.

- `sitrep()` reports whether each of the 13 pipelines is ready to run.

- `clear_atlas_cache()` removes build intermediates, refusing a directory
  holding files this package did not write.

- Verbosity has three levels, resolved from an argument, the
  `ggseg.extra.verbose` option or `GGSEG_EXTRA_VERBOSE`, with `get_verbose()`
  and `as_verbosity()` as accessors. `cleanup` and `output_dir` resolve the
  same way.

- Pipeline intermediates are cached per step, recording the cache format
  version that wrote them, so an older cache is recomputed rather than
  silently reused. Subcortical snapshots carry a signature of the voxels,
  slab and dimensions they were drawn from, and only what moved is redrawn.

- Volumetric and tract builds parallelise through `furrr`: on eight cores
  `create_subcortical_from_volume()` goes from 337s to 171s with four
  workers.

- The `atlas_*` verbs from ggseg.formats are re-exported, along with
  `ggseg_atlas()` and `is_ggseg_atlas()` (#186).

- `decimate` reduces per-region 3D mesh vertex counts, and
  `vertex_size_limits` filters finished 2D polygons by vertex count.

- The readers are exported: `read_lut()`, `read_tractography()`,
  `read_annotation_data()`, `read_cifti_annotation()`,
  `read_cifti_subcortical()`, `read_gifti_annotation()`,
  `read_neuromaps_annotation()`, `read_neuromaps_volume()` and
  `read_suit_parcellation()`. Volume reading reorients `.mgz` to RAS+ as it
  has for NIfTI.

## Improvements

- The flatmap projection is no longer cerebellum-specific: the surface path,
  backdrop label and small-area thresholds are supplied by the caller, so a
  second unfolded anatomy can reuse it. The thresholds have no defaults, being
  in the surface's own units. Cerebellar atlas building is unchanged.

- Every `create_*()` takes `min_coverage`: an atlas whose 2D geometry covers
  less than 80% of its `core` labels warns and names the labels with no shape.

- The large-atlas warning has a per-atlas-type vertex budget, each just above
  its type's 90th percentile across 109 installed atlases, and its advice
  names `atlas_polish()`.

- Data loss is reported whatever the verbosity: a structure that fails to
  tessellate, a degenerate centerline, a label dropped for too few voxels, a
  missing FreeSurfer installation and a dropped cerebellar nucleus are all
  named. `verbose` silences progress chatter only.

- `create_wholebrain_from_volume()` says what it inferred and what it lost:
  labels classified by vertex count rather than declaration, labels assumed
  subcortical, parcels the projection did not deliver, and parcels landing on
  both surfaces.

- A mistyped label in `labels$cortical`, `labels$subcortical` or
  `labels$cerebellar` is reported rather than dropped, and an unaccepted
  `type` or `hemi` value errors before any projection work.

- `lh` and `rh` are read as a hemisphere only as a prefix, a suffix, or a
  token between separators, so `Entorhinal` is no longer right-hemisphere.

- A region named in `core` but absent from the geometry is dropped from
  `core`, `palette`, `meshes_df`, `vertices_df` and `vol_idx`, with the
  dropped labels named; a build left with nothing to draw aborts.

- `atlas_smooth()` no longer multiplies an atlas's vertex count. It and
  `atlas_simplify()` close the hairline gaps they would otherwise open along
  shared boundaries while leaving genuine anatomical gaps open, controlled by
  `close_gaps`. `atlas_simplify()` preserves row order, which is draw order.

- The grey outline behind a subcortical atlas sorts to the bottom layer in
  every view, including the per-hemisphere `cortex_left`/`cortex_right` names,
  so it no longer paints over its own structures.

- The default subcortical slabs tile the bounding box of the atlas's own
  labels -- three coronal, three axial, one sagittal -- rather than indices
  calibrated on a 256-cube, so no panel is empty whatever the voxel size. The
  sagittal slab is clipped to the left of the midline and named
  `sagittal_left`.

- The context silhouette is taken from a single representative slice per view
  rather than projected through the slab, and is never dilated -- all of which
  used to flatten the mantle into a blob.

- Label ids colliding with the FreeSurfer indices the silhouette uses are
  moved onto free values before the volume and lookup table are written, so a
  real structure no longer absorbs the silhouette.

- `registration = "mni152"` refuses a volume in right-handed (RAS) voxel order
  rather than silently mirroring left and right, and registered surface
  projections pass `--srcsubject` so labels come back as integers.

- Volume handling is honest about what it can place: `read_volume()` says when
  it cannot orient an MGZ, `coord_to_voxel()`'s fallback reads the voxel size
  from the header, and `create_tract_from_volume()` declares
  `coord_space = "mm"`.

- FreeSurfer's own output travels with a failure: stderr is captured whatever
  the verbosity, quoted in the error and chained as `Caused by error:`. A
  failing command carries the condition class
  `ggseg_extra_fs_command_error`.

- A build with `cleanup = TRUE` cannot delete files it did not write: every
  `create_*()` stops when `output_dir/atlas_name` already holds files an
  earlier build did not make. `atlas_name` must be a single name.

- Mistakes are reported before the expensive work: an unknown view or
  hemisphere, a missing `input_aseg`, an unusable `breaks`, a missing volume.

- `cleanup` no longer deletes a cache the next run needs: a run stopping short
  of the last step keeps its working directory and says which steps can reuse
  it.

- Arguments are validated before work starts -- `steps`, `smoothness`,
  `decimate`, `registration`, `tube_segments` and the grouped lists -- with an
  invalid grouped list reported against the argument the caller passed.

- Every function orders its arguments the same way, and mistyped or misplaced
  arguments are caught by `rlang::check_dots_empty()`.

- Pipelines are faster where it counts: the label-stamping loops make one pass
  over the volume instead of one per label (about 44x on a 400-parcel atlas,
  byte-identical output), the per-voxel argmax streams the running winner, and
  `read_tractography()` reads `.tck` files without a quadratic slow-down.

- Pipelines report their total run time, extracting contours no longer
  attaches terra to the search path, and a relative `output_dir` is made
  absolute on every platform.

## Bug fixes

- Building an atlas warns when its vertex indices do not fit the vertex space
  its type implies. The 2D geometry is unaffected, so it warns rather than
  failing.

- `labels` and `exclude` are honoured exactly: geometry an operation was not
  asked to touch comes back byte-identical. `atlas_smooth()`,
  `atlas_simplify()`, `atlas_polish()` and `atlas_dilate()` previously
  rewrote excluded labels.

- Slivers reopened by smoothing or simplifying go to a label the operation
  was asked to touch, so they are closed rather than reverted.

- Subcortical 3D meshes are placed in the volume's own world coordinates.
  Tessellation emits tkRAS, which is the identity only for a conformed
  volume; for a volume in its own space the axes are permuted and, where the
  handedness differs, left and right are swapped.

- `mri_vol2vol` is given a transform FreeSurfer 8 accepts: the
  `mni152.register.dat` matrix is converted to an LTA against the volumes
  being registered. Affected `prepare_subcortical_mni152()` and
  `coregister_volume()`.

- A parcellation on a grid too coarse to carry a cortical ribbon is resampled
  onto the `aseg`'s grid rather than the `aseg` down to it, so the backdrop
  keeps its sulci instead of falling back to a solid mantle.

- `create_wholebrain_from_volume()` declares the backdrop it writes, so the
  subcortical atlas keeps its grey brain silhouette.

- An atlas whose lookup table carries no colours ships no palette, and says
  so, instead of one the pipeline invented. An atlas published with a palette
  still uses it.

- A step's cache records what it was built from -- the package version, the
  cache format and the step's own inputs -- and recomputes when any of it
  moves.

- `read_lut()` keeps a `context` group name instead of flattening it to
  `TRUE`, reads a label containing a space as a single token, and no longer
  truncates label names to 29 characters. `write_lut()` holds every column to
  a standard that keeps the round trip lossless.

- The workflow templates `use_atlas_github_actions()` writes resolve
  dependencies against the ggsegverse r-universe.

- `display` holds the source's own name for a region again, rather than a
  copy of the derived `region`.

- The cerebellar pipeline builds `label` from the source name rather than the
  derived region, so a published cerebellar atlas's join and palette key is
  not rewritten.

- The tract pipeline prunes snapshots its slabs cannot name, as the
  subcortical one did, so a projection left by an earlier slab configuration
  no longer aborts the build on a cache-format mismatch.

- The cerebellar orphan rescue only considers vertices the flatmap
  triangulation uses, so a region is no longer rescued onto a vertex that
  belongs to no face and then dropped for having no geometry. A structure
  that reaches no drawable vertex says so.

- `default_tract_slabs()` takes three axial and three coronal slabs, as
  `default_subcortical_slabs()` does, and drops the ones no label reaches.
  The three sagittal slabs stay for the commissural tracts.

- `create_subcortical_from_volume()`, `create_tract_from_tractography()` and
  `create_tract_from_volume()` return the atlas they built rather than
  `NULL`.

- `read_tractography()` reads a `.tck` file from where its header says the
  track data starts, aborts rather than fabricating coordinates for a
  truncated `.trk`, reports a header declaring more streamlines than the file
  holds, and reads to the end when the declared count is `0`.

- `create_tract_from_tractography()` turns streamlines to run the same way
  before computing a centerline, so a bundle stored in both directions is no
  longer shortened or collapsed. It also names an atlas after its tract
  rather than after the temporary directory.

- A tract atlas's `sagittal_left` and `sagittal_right` show the hemisphere
  they are named for, placed from where the brain sits in `input_aseg`.

- Tract 2D projections line up with the anatomical reference and reuse the
  same centerline as the 3D tube; `n_points` reaches the tube in
  `create_tract_from_volume()`.

- `tube_radius = "density"` uses the middle of `density_radius_range` rather
  than silently producing the widest possible tube.

- `read_neuromaps_volume()` keeps a parcellation a parcellation: a volume of
  whole-number labels, or one given a `label_table`, is sampled with
  nearest-neighbour interpolation instead of being blended and binned.

- An atlas built from a `.nii.gz` without an `atlas_name` is named after the
  file, not `<name>_nii`.

- `prepare_subcortical_mni152()` reports a FreeSurfer step that produced
  nothing, and the lookup-table readers accept a file `write_lut()` wrote.

- `sitrep()` no longer reports `create_cortical_from_annotation()` as needing
  FreeSurfer, and suggests installing neuromapr from CRAN.

- `tessellate_remap_label()` writes its isolated label back carrying the
  original affine, so a `.mgz` no longer loses every structure with a label
  id above 255 -- the normal case for thalamic nuclei, hippocampal subfields
  and brainstem substructures.

- A subcortical rebuild no longer reuses snapshots drawn from a different
  volume; each is checked against its signature, a changed `slabs` is
  honoured, and `steps = 1:4` no longer deletes every snapshot in the cache.

- Contours are no longer traced from files belonging to a different slab
  configuration, and a contour file matching none of the atlas's views aborts
  naming it.

- Subcortical and tract 2D views are no longer upside down, mirrored or drawn
  in the wrong plane, and contours record that their y-axis points up.

- `create_wholebrain_from_volume()` no longer leaves white holes in the
  cortical atlas: the volume is filtered to the lookup table before
  projection, unlabelled cortex vertices take their neighbours' most common
  label, and cortex is split at the correct 1-based midline voxel. It also
  handles lookup tables carrying labels with spaces.

- The brain silhouette behind a subcortical atlas is no longer built from the
  atlas's own parcels when their ids land between 1000 and 2999.

- `create_cerebellar_from_volume()` builds from float-typed volumes, `volume`
  is forwarded by the GIFTI and annotation creators so their atlases carry 3D
  meshes, and `decimate` is honoured by all three.

- `create_cortical_from_neuromaps()` honours `label_table` on the volume
  path, and tied values no longer abort with `'breaks' are not unique`.

- `create_cortical_from_labels()` and `create_tract_from_tractography()` keep
  region names when `input_lut` is a file path.

- `read_cifti_annotation()` and `create_cortical_from_cifti()` work on real
  CIFTI files, warn when a file carries subcortical voxels the cortical
  pipeline ignores (#85), and warn on more than one label map.

- `atlas_dilate()` with a negative `amount` large enough to erode a region
  away warns naming the regions lost and removes them, so the result still
  validates.

- `project_volume_anatomical()` warns when `protect_cortex` removes a label
  entirely, naming the lost labels.

- Annotation files whose colour table already defines `unknown` no longer
  produce a duplicate label, and parcellations naming their medial wall are
  treated as context while parcels such as `medialorbitofrontal` stay
  regions.

- Contour extraction no longer crashes on empty or all-`NA` rasters, keeps
  the valid contours when only some are empty, and errors clearly when none
  yields a contour.

- Suggested packages are checked before use in every path that needs them,
  and `ensure_fs_compatible_nifti()` falls through gracefully when a NIfTI
  header cannot be read.

- `prepare_subcortical_mni152()` converts the aseg through
  `freesurfer::mri_convert()` (#118), paths containing spaces work, and
  region names containing `()` or `/` are handled throughout.

- Boolean and verbosity options parse spelled-out strings consistently across
  the argument, option and environment-variable channels.

- The bundled atlas template generates a package that passes `R CMD check`,
  and `setup_atlas_repo()` no longer copies the template's own `.github/`
  directory or rewrites files under `.git`.

## Documentation

- `?ggseg.extra` states what these atlases are for: visualising results as
  general anatomical guidance, not precision geometry for analysis. It says
  which approximations are acceptable by design and which are bugs.

- Six vignettes -- getting started, pipeline configuration, post-processing,
  system setup, legacy conversion, contributing -- and, on the website, an
  atlas creation workflows article plus nine step-by-step tutorials covering
  every pipeline.

- The tutorials are built from reproducible `.qmd.orig` sources, plot the
  atlas at each stage of a build, and teach the current API. Five are knitted
  on every pull request.

- `vignette("post-processing")` leads with `atlas_polish()` and treats
  polishing a context silhouette and a structure core as separate problems.

- Examples for the geometry verbs run under `R CMD check`, and a test parses
  every documented example and asserts each argument it names is one the
  function accepts.

- Help pages are scannable: `@param` says what to pass, with reasoning in
  `@details`; the twelve `create_*()` functions share `@family atlas
  creation`; every creator describes what its returned object holds.

- The reference index groups geometry shaping, curation and file reading
  under their own headings, the re-exported `atlas_*` verbs have a visible
  `?atlas-verbs` page, and the website separates **Articles** from
  **Tutorials**.

- Reading annotation files needs the `freesurferformats` package, not a
  FreeSurfer installation, and `SystemRequirements` no longer claims
  FreeSurfer for the tract pipelines.

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
