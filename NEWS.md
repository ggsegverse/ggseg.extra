# ggseg.extra 2.0.0

This is the first CRAN release of ggseg.extra, the atlas-building package of
the ggsegverse, renamed and restructured from 'ggsegExtra' for the ggsegverse
2.0 architecture. Every pipeline now returns a single `ggseg_atlas` object
holding 2D polygons and 3D meshes together, and geometry shaping has moved out
of atlas creation into cheap post-creation verbs you can retune without
rebuilding. Twelve `create_*()` entry points cover cortical, subcortical,
cerebellar, whole-brain and white-matter tract atlases, built from FreeSurfer
annotations and labels, GIFTI, CIFTI, neuromaps, NIfTI/MGZ parcellation volumes
and tractography files.

## Breaking changes

- The package is `ggseg.extra`; the old `ggsegExtra` name is gone from the
  code and the documentation.

- Geometry shaping is no longer part of atlas creation. `dilate`,
  `smoothness`, `tolerance` and `smooth_refinements` are not accepted by any
  `create_*()` function; use `atlas_polish()`, or `atlas_simplify()`,
  `atlas_smooth()` and `atlas_dilate()` individually on the finished atlas.
  Atlas build scripts that still pass one of these spellings abort with
  "unused argument", naming the creator.

- The `ggseg.extra.tolerance` and `ggseg.extra.smoothness` options and their
  `GGSEG_EXTRA_*` environment variables are removed, as nothing reads them.

- The colour-table functions are named after lookup tables: `read_lut()`,
  `write_lut()`, `is_lut()` and `get_lut()`. The `read_ctab()`, `write_ctab()`,
  `is_ctab()` and `get_ctab()` spellings are removed.

- `sitrep()` replaces `setup_sitrep()`, and `ggseg_atlas_github_actions()`
  replaces `atlas_github_actions()`; the old names are removed.

- `subcortical_slabs()` replaces `subcortical_views()`, and the volumetric
  `views` argument of `create_subcortical_from_volume()` and
  `create_tract_from_tractography()` is `slabs`. The cortical creators' `views`
  argument, which selects standard panels, is unrelated and unchanged.

- Related arguments are grouped into lists, and the flat spellings are no
  longer accepted: `tube_opts` in `create_tract_from_tractography()`; `labels`,
  `projection_opts`, `cortical_opts`, `subcortical_opts` and `cerebellar_opts`
  in `create_wholebrain_from_volume()`. `cortical_opts` accepts only `views`.

- `create_cerebellar_from_volume()` takes `input_volume` as its first argument,
  as every sibling creator does, and `read_neuromaps_volume()` takes `breaks`
  second and `output_dir` last.

- `mri_surf2surf_rereg()` takes `hemisphere` rather than `hemi`.

- `registration` means one thing across the package: `"mni152"`, `"header"`, or
  a path to a register.dat or LTA file, in `prepare_subcortical_mni152()`,
  `project_volume_anatomical()` and `create_wholebrain_from_volume()`. The
  ambiguous `registration = NULL` and the `regheader` argument are gone; pass
  `projection_opts = list(registration = )`.

- In `create_subcortical_from_volume()` the lookup table decides what is a
  region and what is context, the grey anatomy the regions are drawn against.
  Nothing is recognised by its id or its name. A row of the table is a region;
  a row whose optional `context` column is `TRUE` is context, keeps its name,
  is traced on a single slice in each view so that a cortical ribbon keeps its
  folds, and gets no 3D mesh; a label in the volume that the table does not
  list is context too, named for its id (`context_0002`). With no table, every
  label is a region. To get the cortex as context, mark its rows:
  `lut$context <- grepl("Cortex", lut$label)`. Context that is not wanted is
  removed afterwards with `atlas_context_remove()`.

- `create_cortical_from_neuromaps()`, `read_neuromaps_annotation()` and
  `read_neuromaps_volume()` bin a continuous map through `breaks`, which
  replaces `n_bins`: a single number for that many quantile bins, increasing
  numbers as the bin edges, or a function that takes the map's values and
  returns the edges. Left out, it gives quantile bins counted by Sturges' rule.
  Both hemispheres are binned on one set of edges, so a bin means the same
  range of values on either side.

- `read_tractography()` returns `.trk` streamlines in RAS world millimetres,
  applying the header's voxel size, voxel order and voxel-to-world transform,
  and agrees with 'nibabel' on its reference files. It used to return the
  numbers as stored, which misplaced `.trk` tracts. Big-endian files are read
  too. `create_tract_from_tractography()` therefore no longer accepts
  `coord_space = "voxel"` for tractography files; it still applies to
  streamlines passed as coordinate matrices.

- `create_wholebrain_from_volume()` registers MNI152 volumes to the surface
  subject with FreeSurfer's `average/mni152.register.dat` rather than assuming
  the two spaces coincide. Each `fsaverage5` vertex samples a point about
  2 mm away, so cortical atlases built from MNI152 volumes with earlier
  versions must be rebuilt.

- Subcortical and tract contours are traced from the projection matrix itself
  rather than from a PNG of it (#139), so geometry is exact in voxel
  coordinates instead of in pixels of a 400x400 canvas. **Atlases built with
  earlier versions produce different geometry and need rebuilding**, and
  distance-valued arguments -- `atlas_dilate(amount = )` and
  `atlas_smooth(smoothness = )` -- now mean voxels everywhere rather than
  canvas pixels, so values tuned against the canvas want retuning.

- The subcortical pipeline has six steps and the tract pipeline four; the
  contour-smoothing and vertex-reduction steps that stopped doing anything are
  gone. `steps` is bounds-checked and errors on a value above the last step.

- `skip_existing` defaults to `FALSE`. A step cache records which ggseg.extra
  wrote it and nothing about what it was built from, so reuse is now asked for
  rather than assumed, and every reuse is reported naming the step.

- Cerebellar region names come from the shared `label_to_region()`, which now
  strips `vermis` and `midline` alongside `left` and `right`, so the three
  pipelines agree. Cerebellar region names change on the next rebuild:
  `midline_M1L` becomes `m1l` and `Vermis_VIIAt` becomes `viiat`. The `label`
  column is unchanged.

- The cerebellar flatmap gets a `cerebellum` backdrop, and perimeter regions
  are no longer inflated to reach the flatmap edge, so they stop where the
  parcellation says they stop. Rebuilding a published cerebellar atlas
  produces slightly different geometry.

- Every cortical atlas keeps its `unknown` medial wall as grey context rather
  than as a region: its outline draws behind the parcels, but it carries no
  `core` row, no palette entry and no 3D vertices.

- 2D atlas geometry keeps its holes. `coords2sf()` had been assembling every
  polygon ring as a solid polygon of its own, filling enclosed holes, so a
  cortical ribbon came out as a blob; rings are now assembled as exterior plus
  holes. Every atlas built through `get_contours()` differs from one built
  before this fix.

- `atlas_smooth()` and `atlas_simplify()` do one thing each: smoothing decides
  how round an outline is, simplification how many vertices it costs. `keep`
  belongs to `atlas_simplify()` only.

- The cortical creators have no `method`, `snapshot_dim` or `steps` arguments;
  the mesh-projection pipeline reads and projects in one pass.

- `ggseg_atlas_repos()`, `install_ggseg_atlas()` and
  `install_ggseg_atlas_all()` are removed; installing atlases is 'ggsegverse's
  job. `convert_legacy_brain_atlas()` lives in 'ggseg.formats' and is
  re-exported here.

- The dependency footprint is much lighter. ImageMagick and a headless browser
  are not needed at all, so `chromote`, `magick` and `htmlwidgets` are gone
  along with `rgdal`, `purrr`, `reticulate` and `tidyr`. `freesurfer`,
  `freesurferformats`, `ciftiTools`, `gifti`, `RNifti`, `Rvcg`, `terra`,
  `smoothr`, `princurve`, `rgl`, `neuromapr`, `ggseg` and `future` are all
  Suggests, checked at run time with `rlang::check_installed()` and requested
  only by the pipeline that needs them. `freesurfer` is required at
  `>= 1.8.1.902`, which is currently only on r-universe (#72, #98), and
  `ciftiTools` at `>= 0.17.4`.

## New features

- Cerebellar atlases are a first-class atlas type across the ecosystem, with
  SUIT flatmap polygons for 2D and per-region meshes for 3D.
  `create_cerebellar_from_gifti()`, `create_cerebellar_from_annotation()` and
  `create_cerebellar_from_volume()` build them from GIFTI label files,
  FreeSurfer `.annot` files on the SUIT surface, or a NIfTI cerebellar
  segmentation, and `read_suit_parcellation()` reads SUIT-format GIFTI labels
  with Left/Right/Vermis hemisphere detection.

- Deep cerebellar nuclei (Dentate, Interposed, Fastigial) that have volume
  voxels but no SUIT surface vertices are tessellated as individual 3D meshes
  with a tkRAS-to-MNI transform and drawn as a separate coronal `nuclei` view.
  Surface parcels too small for any SUIT vertex to land on are rescued onto the
  flatmap.

- `create_wholebrain_from_volume()` builds cortical, subcortical and cerebellar
  sub-atlases from a single volumetric parcellation, classifying each label
  from the lookup table's declaration and reporting what it had to infer.

- `create_tract_from_tractography()` builds a white-matter tract atlas from
  `.trk`/`.tck` files or in-memory coordinate matrices, and
  `create_tract_from_volume()` builds one from a volumetric tract label map by
  reducing each tract's voxel cloud to a principal-curve centerline. Both
  produce 3D tubes and 2D slice projections.

- `create_cortical_from_cifti()` and `read_cifti_annotation()` read CIFTI dense
  label files, `read_cifti_subcortical()` extracts a CIFTI file's subcortical
  voxels into a NIfTI label volume plus colour table ready for the subcortical
  pipelines (#85), and GIFTI `.label.gii` annotations are supported throughout.

- `create_cortical_from_neuromaps()`, `read_neuromaps_annotation()` and
  `read_neuromaps_volume()` build atlases from neuromaps surface and volume
  annotations, binning continuous maps into regions.

- The cortical pipeline projects inflated mesh triangles straight to 2D
  polygons by orthographic projection. Atlas creation takes about five seconds
  rather than minutes, the geometry carries no rasterisation staircase, and
  reading `.annot` files needs only the `freesurferformats` package.

- Boundary triangles whose vertices belong to different regions are split along
  edge midpoints -- a quadrilateral and a triangle for a two-region boundary,
  three quadrilaterals meeting at the centroid for three -- so region borders
  are clean rather than sawtoothed, and boundary faces go to the smallest
  neighbouring region so tiny parcels survive.

- `atlas_polish()` simplifies and smooths in one call against a stated vertex
  budget, owning the order the two have to run in so a build does not have to
  rediscover it (#186).

- `atlas_smooth()` gains `method` -- the default morphological `"close"` plus
  `"chaikin"`, `"ksmooth"` and `"spline"`, which move vertices rather than
  dilating the shape and so keep enclosed holes open -- a `smoothness` strength
  on one 0--1 scale shared by every method, and `vertex_budget` to choose
  between preserving the starting vertex count and rounding freely.

- `atlas_dilate()` grows or shrinks region geometry on a finished atlas, the
  post-creation counterpart of the old build-time dilation.

- `count_vertices()` reports how many polygon vertices each region carries,
  which is the figure the large-atlas warning quotes and `atlas_simplify()`
  brings down.

- `context_pattern()` gives the label pattern matching an atlas's context, in
  one place rather than retyped into every build. Given an atlas it matches
  exactly the context that atlas draws, whatever its shapes are called;
  without one it matches the names the pipelines generate. `atlas_polish()`,
  `atlas_simplify()`, `atlas_smooth()` and `atlas_dilate()` accept a function
  as `labels` or `exclude` and ask it about the atlas they are given, so
  `exclude = context_pattern` means "this atlas's context" and works in the
  middle of a pipe.

- A cortical parcellation that covers only part of the mantle gets the rest of
  it as a silhouette to sit on (#285). Every vertex no label claims becomes one
  `lh_cortex`/`rh_cortex` region per hemisphere, drawn behind the parcellation
  and carrying no colour or legend entry. A sparse cerebellar parcellation
  likewise gets a single `cerebellum` backdrop.

- `label_to_region()` is exported: it is the rule the pipelines use to fill an
  atlas's `region` column from its labels, so a build script adding metadata
  keyed on `region` can key on what the pipeline actually derives.

- A lookup table can declare `type` (`"cortical"`, `"subcortical"`,
  `"cerebellar"`) and `hemi` columns, which `create_wholebrain_from_volume()`,
  `create_subcortical_from_volume()` and `create_cerebellar_from_volume()`
  honour rather than guessing. `write_lut()` writes both and `read_lut()` reads
  them back, so a declaration survives a round trip through a file and stays a
  FreeSurfer-readable colour table. A declared hemisphere is what stops a
  midline-crossing parcel becoming two regions the parcellation never had.

- `lut_classify_anatomy()` fills a lookup table's `type` column by resampling
  FreeSurfer's `aparc+aseg` onto the volume's own grid and judging each label
  on the share of labelled grey matter it touches, rather than by matching
  names -- an authoring tool whose output you commit and review in a diff.

- `lut_generate_colors()` builds a palette for a lookup table that ships names
  only. Colours are assigned per structure, so a structure's two hemispheres
  share one, with hues spread around the circle and stepped through three
  luminances; `by` colours each group of a column from the whole circle, which
  is the whole-brain case. Out-of-gamut clipping that would hand two structures
  the same colour is an error naming `chroma` and `luminance`.

- `lut_add()` and `lut_combine()` append and merge FreeSurfer-style colour
  tables, validating with `is_lut()` and warning on index clashes.

- `subcortical_slabs()` builds a slab table from the bounding box of a set of
  labels, reading the volume in the same frame the builder uses, and
  `create_subcortical_from_volume(slabs = )` accepts that spec directly.

- A lookup table says more than names and colours. Alongside `type` and
  `hemi`, `read_lut()` and `write_lut()` carry a `context` column, kept
  separate from `type` so a whole-brain table can say both which atlas a label
  belongs to and what role it plays there. A table passed as a data.frame may
  also carry a `names` column, the display name of each region; every atlas
  the pipelines build has `names` in its `core`, falling back to the region.
  `aseg_subcortical_labels()` returns the lumped structure ids a finer
  parcellation subdivides.

- `coregister_volume()` wraps `mri_coreg` to align an atlas volume to a
  FreeSurfer subject's T1 grid, returning a reusable LTA file.
  `project_volume_anatomical()` resamples each label onto the target
  `aparc+aseg` grid, takes the per-voxel argmax and returns a merged volume
  plus an aligned colour table, and `prepare_subcortical_anatomical()` chains
  both. `id_offset` keeps input ids from colliding with FreeSurfer's, and
  `protect_cortex` keeps the cortical ribbon and cortical white matter intact
  for the brain-outline context. The lookup table it returns, like the one
  from `prepare_subcortical_mni152()`, has `context` filled in: the
  FreeSurfer anatomy is context and the labels are regions.

- `prepare_subcortical_mni152()` embeds a parcellation supplied in fixed
  FSL-MNI152 space into a subject's `aseg` via the known
  `mni152.register.dat` transform, replacing the lumped structures the parcels
  subdivide. `create_subcortical_from_volume()` accepts the returned
  `list(volume, lut, id_offset)` directly as `input_volume`.

- `create_wholebrain_from_volume()` gains
  `cerebellar_opts = list(cerebellar_space = )`, so an MNI cerebellar volume is
  transformed with
  the matching SUIT deformation field before it is sampled onto the flatmap
  rather than being drawn onto a flatmap it does not correspond to.

- `create_tract_from_tractography()` and `create_tract_from_volume()` gain
  `coord_space`, to declare whether streamline coordinates are `"voxel"`
  indices or RAS world `"mm"` instead of relying on a heuristic that cannot
  always tell; the space in force is reported at `verbose >= 1`.

- The brain silhouette behind a whole-brain subcortical atlas is a gyrified
  mantle rather than a solid blob: it is taken from FreeSurfer's `aseg` ribbon,
  resampled onto the atlas volume's own grid, wherever the parcellation's own
  cortical labels are solid, and the `aseg` cerebellar cortex and brain stem
  fill the posterior fossa. An atlas whose own labels are already a ribbon
  keeps them, the substitution is declined on grids too coarse to carry a
  ribbon, and the pipeline reports which silhouette it drew in every case.

- `setup_atlas_repo()` scaffolds an atlas package from the
  ggsegverse/ggseg-atlas-template repository, with a Quarto README, pkgdown
  config, shared CI workflows and a `data-raw/create-atlas.R` covering all five
  pipelines, falling back to a bundled minimal template when offline. It fills
  DESCRIPTION from the `usethis.description` option when one is set.

- `use_atlas_github_actions()` adds the shared ggsegverse GitHub Actions
  workflows to a package as short caller stubs, and
  `ggseg_atlas_github_actions()` lists what is available.

- `sitrep()` reports whether each of the 13 pipelines is ready to run, naming
  the FreeSurfer binaries, subjects and optional R packages each one needs.

- Verbosity has three levels -- silent, standard, debug -- resolved from an
  explicit argument, the `ggseg.extra.verbose` option or `GGSEG_EXTRA_VERBOSE`,
  with `get_verbose()` and `as_verbosity()` as the accessors. `cleanup` and
  `output_dir` resolve the same way.

- Pipeline intermediates are cached per step with a `cache_manifest.rds`
  recording the cache format version that wrote them, so a cache written by an
  older ggseg.extra is recomputed rather than silently reused. Subcortical
  projection snapshots additionally carry a signature of the voxels, slab and
  volume dimensions they were drawn from, and only what moved is redrawn.

- Volumetric and tract builds parallelise through `furrr`, and
  `plan(multicore)` is used as given: on an eight-core machine
  `create_subcortical_from_volume()` goes from 337s sequential to 171s with
  four forked workers.

- The `atlas_*` manipulation verbs from ggseg.formats are re-exported, along
  with `ggseg_atlas()` and `is_ggseg_atlas()`, so `library(ggseg.extra)` is
  enough to build, curate and validate an atlas (#186).

- `decimate` reduces per-region 3D mesh vertex counts with `Rvcg` in the
  subcortical and cerebellar pipelines, and `vertex_size_limits` filters
  finished 2D polygons by vertex count.

- `read_lut()` and `read_tractography()` are exported, so the formats the
  pipelines consume can be read and inspected on their own, alongside
  `read_annotation_data()`, `read_cifti_annotation()`,
  `read_cifti_subcortical()`, `read_gifti_annotation()`,
  `read_neuromaps_annotation()`, `read_neuromaps_volume()` and
  `read_suit_parcellation()`. Volume reading reorients FreeSurfer `.mgz`
  volumes to RAS+ as it has always done for NIfTI.

## Improvements

- The large-atlas warning has a per-atlas-type vertex budget, each sitting just
  above its type's 90th percentile measured across 109 installed atlases, so it
  flags the heaviest tenth of a family rather than seven atlases in ten, and
  its advice names `atlas_polish()`.

- Data loss is reported whatever the verbosity. A structure that fails to
  tessellate, a tract whose centerline is degenerate, a label dropped for too
  few voxels, deep-nuclei data with no `vol_idx`, a missing FreeSurfer
  installation and a dropped cerebellar nucleus are all named rather than left
  as a lower count; `verbose` silences progress chatter only.

- `create_wholebrain_from_volume()` says what it inferred and what it lost: how
  many labels it classified by surface vertex count rather than from a
  declaration, which labels it assumed subcortical because they reached no
  cortical vertex, which cortical parcels the projection did not deliver, and
  which parcels landed on both surfaces, with per-hemisphere vertex counts.

- A mistyped label in any of `labels$cortical`, `labels$subcortical` and
  `labels$cerebellar` is reported rather than dropped, and a `type` or `hemi`
  column holding a value that is not one of the accepted ones is an error
  raised before any projection work.

- `lh` and `rh` are read as a hemisphere only as a prefix, a suffix, or a token
  between separators, so `Entorhinal` is no longer right-hemisphere and a label
  merely containing `lh` is no longer left.

- A region named in `core` but absent from the geometry is dropped from all of
  `core`, `palette`, `meshes_df`, `vertices_df` and `vol_idx` in every
  pipeline, with the dropped labels named, rather than shipping an atlas that
  claims a region it cannot draw; a build left with nothing to draw aborts.

- `atlas_smooth()` no longer multiplies an atlas's vertex count: rounded corners
  are taken down to the two or three segments that read the same at plotting
  size. `atlas_smooth()` and `atlas_simplify()` close the hairline gaps they
  would otherwise open along shared boundaries, leaving genuine anatomical gaps
  open, controlled by `close_gaps`. `atlas_simplify()` preserves row order,
  which is draw order.

- The grey outline behind a subcortical atlas sorts to the bottom layer in
  every view, including the per-hemisphere `cortex_left`/`cortex_right` names
  the sagittal panels use, so it no longer paints over its own structures.
  `is_cortex_outline()` matches case-insensitively and remains anchored.

- The default subcortical projection slabs tile the bounding box of the atlas's
  own labels -- three coronal, three axial, one sagittal -- rather than slice
  indices calibrated on a 256-cube, so no panel is empty and no structure is
  missing from every view whatever the voxel size. The default sagittal slab is
  clipped to the left of the midline and named `sagittal_left`, so left
  structures are not drawn beneath their right twins.

- The anatomical context silhouette is taken from a single representative slice
  per view rather than projected through the slab, from the slice holding the
  most cortex for axial and coronal and the thinnest section for sagittal, and
  it is never dilated -- all three of which used to flatten the mantle into a
  blob.

- Label ids that collide with the FreeSurfer cortex, cerebellum and brainstem
  indices the silhouette uses are moved onto free values before the volume and
  lookup table are written, so a real structure no longer absorbs the
  silhouette. `project_volume_anatomical()` and `prepare_subcortical_mni152()`
  share one exact guard against a parcel id merging into a surviving context
  structure, checked early for whatever `protect_cortex` shields.

- `registration = "mni152"` refuses a volume stored in right-handed (RAS) voxel
  order rather than silently mirroring left and right, and registered surface
  projections pass `--srcsubject`, so labels come back as integers rather than
  being resampled into fractional values.

- Volume handling is honest about what it can place: `read_volume()` says when
  it cannot orient an MGZ, `coord_to_voxel()`'s fallback reads the voxel size
  from the header rather than assuming a 1 mm isotropic grid, and
  `create_tract_from_volume()` declares `coord_space = "mm"` rather than
  leaving a space it built itself to be inferred.

- FreeSurfer's own output travels with a failure. stderr is captured whatever
  the verbosity, echoed at `verbose >= 2`, quoted in the error with braces
  escaped, and chained as `Caused by error:` by `read_fs_surface()`,
  `tessellate_smooth_mesh()`, `subcort_mesh_one()` and
  `resample_volume_to_grid()`. A failing command carries the condition class
  `ggseg_extra_fs_command_error`. A missing `mris_convert` aborts naming the
  binary rather than returning a mesh with faces pointing at vertices that do
  not exist.

- A build with `cleanup = TRUE` cannot delete files it did not write. Every
  `create_*()` function stops before doing any work when its working folder,
  `output_dir/atlas_name`, already holds files and was not made by an earlier
  build. `atlas_name` must be a single name: an empty name, `".."` or one
  containing a path separator is an error.

- Mistakes are reported before the expensive work. The cortical creators
  reject a view or hemisphere they do not know, the tract creators check for
  `input_aseg` before reading a streamline, an unusable `breaks` is rejected
  before anything is downloaded, and `read_neuromaps_volume()` reports a
  missing volume before projecting.

- `cleanup` no longer deletes a cache the next run needs: a run that stops
  short of the last step keeps its working directory and says which steps can
  reuse it, which is what the documented two-phase inspect-then-continue
  workflow needs.

- Arguments are validated before work starts rather than failing deep inside a
  pipeline: `steps` (whole numbers, in range), `smoothness` (type and length),
  `decimate`, `registration`, `tube_segments`, and the grouped lists, with an
  invalid grouped list reported against the argument the caller actually
  passed and a sub-pipeline option passed at the top level told where it
  belongs.

- Every function orders its arguments the same way -- the ones without
  defaults, then the ones with real defaults, then `...`, then everything
  defaulting to `NULL` or an empty list -- and mistyped or misplaced arguments
  are caught by `rlang::check_dots_empty()`, which reports the offending value
  rather than just its name.

- Pipelines are faster where it counts. The three label-stamping loops make one
  pass over the volume instead of one per label, about 44x on a 400-parcel
  atlas with byte-identical output; `create_tract_from_volume()` gathers all
  tracts' voxels in a single sweep and applies the affine after thinning; the
  per-voxel argmax in `project_volume_anatomical()` streams the running winner
  instead of materialising an `n_voxels x n_labels` matrix;
  `read_tractography()` reads `.tck` files without a quadratic slow-down; and
  `set_sphere_voxels()` fills with one matrix-indexed assignment.

- Pipelines report their total run time the way cli reports each step
  (`Pipeline completed [1m 15s]`), progress labels interpolate the real step
  total, extracting contours no longer attaches terra to the search path where
  it masked `describe()` and `extract()`, and a relative `output_dir` is made
  absolute on every platform whether or not the directory already exists.

## Bug fixes

- `create_subcortical_from_volume()`, `create_tract_from_tractography()` and
  `create_tract_from_volume()` return the atlas they built, instead of running
  every step, reporting success and returning `NULL`.

- `read_tractography()` reads a `.tck` file from where its header says the
  track data starts, instead of straight after the `END` line, which shifted
  every coordinate by one column in files that pad the header. Coordinates are
  loaded in one pass, which is considerably faster on large files.

- `create_tract_from_tractography()` turns streamlines to run the same way
  before computing a centerline. A bundle stored in both directions, as most
  are, used to be shortened or collapsed to a point.

- The default sagittal views of a tract atlas show the hemisphere they are
  named for; `sagittal_left` and `sagittal_right` were on each other's side.
  They are placed from where the brain sits in `input_aseg`, so a volume that
  is not a 256-voxel, 1 mm cube gets views that cover it.

- `create_tract_from_tractography()` names an atlas after its tract, or
  `"tracts"` when there are several, instead of after the temporary directory.

- `read_neuromaps_volume()`, and `create_cortical_from_neuromaps()` for a
  volume, keep a parcellation a parcellation: a volume of whole-number labels,
  or one given a `label_table`, is sampled with nearest-neighbour
  interpolation instead of being blended into fractions and cut into bins.

- An atlas built from a `.nii.gz` volume without an `atlas_name` is named
  after the file, not `<name>_nii`.

- `prepare_subcortical_mni152()` reports a FreeSurfer step that produced
  nothing, and `project_volume_anatomical()` and `create_tract_from_volume()`
  read a lookup table file the way the rest of the package does, so a file
  written by `write_lut()` works.

- `sitrep()` no longer reports `create_cortical_from_annotation()` as needing
  FreeSurfer, and suggests installing neuromapr from CRAN.

- `read_lut()` reads a label containing a space as a single token rather than
  backtracking into a valid-looking parse that shifted every colour channel one
  field along, and `write_lut()` holds `label` and all five numeric columns to
  the standard that keeps a row readable, so the round trip is lossless. Label
  names are no longer truncated to 29 characters, which used to lose a
  hemisphere suffix and silently merge long labels.

- `tessellate_remap_label()` writes its isolated label back as `.mgz` carrying
  the original affine, so a `.mgz` volume no longer loses every structure whose
  label id is above 255 -- the normal case for FreeSurfer thalamic nuclei,
  hippocampal subfields and brainstem substructures.

- A subcortical rebuild no longer reuses projection snapshots drawn from a
  different volume and then fails to trace them; each snapshot is checked
  against its signature and only what moved is redrawn, and a changed `slabs`
  argument is honoured on a cached rebuild.

- Running `steps = 1:4` on a subcortical atlas with an existing cache no longer
  deletes every snapshot in it.

- Contours are no longer traced from files belonging to a different slab
  configuration: images the current configuration cannot name are cleared once
  the slabs are known, and a contour file matching none of the atlas's views
  aborts naming the unmatched files.

- Subcortical and tract 2D views are no longer upside down, mirrored or drawn
  in the wrong plane, and contours record that their y-axis points up.

- Tract 2D projections line up with the anatomical reference: the translation
  `center_meshes()` applies for 3D display is undone before rasterising, and
  the volume is reoriented explicitly rather than relying on an assignment that
  is a no-op for `.mgz`.

- Tract 2D projections reuse the same centerline as the 3D tube rather than
  recomputing a different 50-point one, `n_points` reaches the tube in
  `create_tract_from_volume()`, and `atlas_name` names the atlas object and not
  only the output directory.

- `tube_radius = "density"` reports uniform density and uses the middle of
  `density_radius_range` rather than silently producing the widest possible
  tube, including for a tract given as a single `N x 3` matrix.

- `read_tractography()` aborts rather than fabricating coordinates for a `.trk`
  file truncated mid-streamline, reports a header that declares more
  streamlines than the file holds, and reads to the end of the file when the
  declared count is `0`, as the TrackVis specification intends. A
  `tract_names` length that does not match the number of tracts is reported
  where it happens.

- `create_wholebrain_from_volume()` no longer leaves white holes in the
  cortical atlas: the volume is filtered to the lookup table before projection,
  and cortex vertices left unlabelled take the most common label of their
  neighbours. Lookup table entries the volume never carries are dropped before
  classification, and cortex is split at the correct 1-based midline voxel.

- `create_wholebrain_from_volume()` builds an atlas whose lookup table carries
  labels with spaces in them, sanitising them for the intermediate table it
  hands itself, so Neuromorphometrics-style tables round-trip without shifting
  colours.

- The brain silhouette behind a subcortical atlas is no longer built from the
  atlas's own parcels when their ids land between 1000 and 2999; the plain
  `aseg` cortex labels win whenever the volume carries both.

- `create_cerebellar_from_volume()` builds from float-typed parcellation
  volumes, `volume` is forwarded by `create_cerebellar_from_gifti()` and
  `create_cerebellar_from_annotation()` so their atlases carry 3D meshes, and
  `decimate` is honoured by all three cerebellar creators. Trilinear resampling
  skips non-finite deformation coordinates rather than failing.

- `create_cortical_from_neuromaps()` honours `label_table` on the volume path,
  and neither it nor `read_neuromaps_volume()` aborts with
  `'breaks' are not unique` on a map with tied values; duplicate quantile
  breaks are collapsed with a warning and an all-medial-wall hemisphere
  errors clearly.

- `create_cortical_from_labels()` and `create_tract_from_tractography()` keep
  region names when `input_lut` is a FreeSurfer-style file path, falling back
  to `label` where there is no `region` column.

- `read_cifti_annotation()` and `create_cortical_from_cifti()` work on real
  CIFTI files, reading label names from the label table's row names, warn when
  a file carries labelled subcortical voxels the cortical pipeline ignores
  (#85), and warn when a file holds more than one label map.

- `atlas_dilate()` with a negative `amount` large enough to erode a region away
  warns naming the regions lost and removes them from `core`, the palette and
  the geometry, so the result still validates as a `ggseg_atlas`.

- `project_volume_anatomical()` warns when `protect_cortex` removes a label
  entirely, naming the lost labels -- the defect that shipped ggsegJHU's
  ICBM-DTI-81 atlas with its right superior longitudinal fasciculus missing.

- Annotation files whose colour table already defines an `unknown` region no
  longer produce a duplicate label, and parcellations that name their medial
  wall (`FreeSurfer_Defined_Medial_Wall`, `medialwall`, `???`) are treated as
  context while parcels such as `medialorbitofrontal` stay regions.

- Contour extraction no longer crashes on empty or all-`NA` region rasters,
  keeps the valid contours when only some are empty, and reports a clear error
  when no region yields a contour.

- `freesurferformats` is checked before use in every path that needs it,
  `decimate_mesh()` guards `rgl` as well as `Rvcg`, and
  `ensure_fs_compatible_nifti()` falls through gracefully when a NIfTI header
  cannot be read.

- `prepare_subcortical_mni152()` converts the aseg through
  `freesurfer::mri_convert()` rather than working around it (#118), and
  `mri_info` is called with a shell-quoted path so volume paths containing
  spaces work; region names containing `()` or `/` are handled throughout.

- Boolean and verbosity options parse spelled-out strings consistently across
  the explicit, option and environment-variable channels, so
  `GGSEG_EXTRA_VERBOSE=false` silences output and `"yes"`/`"1"` are honoured.
  `as_verbosity()` falls back as documented for a value that is not length 1,
  and reads a factor by its label.

- The bundled atlas template generates a package that passes `R CMD check`:
  placeholders are bare identifiers that parse as R, the scaffolded build
  script calls the current API, the licence declaration matches the shipped
  `LICENSE`, `.lintr` excludes `data-raw/`, and the generated workflows run on
  pull requests. `setup_atlas_repo()` no longer copies the template's own
  `.github/` directory or rewrites files under `.git`, and reports failed
  copies.

## Documentation

- Six vignettes -- getting started, pipeline configuration, post-processing,
  system setup, legacy conversion, contributing -- and, on the package website,
  an atlas creation workflows article with six verified diagrams plus nine
  step-by-step tutorials covering the cortical, label, subcortical, cerebellar,
  whole-brain, tract, neuromaps, lookup-table and atlas-publishing workflows.
  Each fact has one home.

- The tutorials are built from reproducible `.qmd.orig` sources, plot the atlas
  at each stage of a build with vertex counts beside it, and teach the current
  API: `atlas_polish()`, `context_pattern()`, `plot()` for an overview and
  `ggplot() + geom_brain()` for a figure, rather than the defunct `ggseg()`.
  Five of them are knitted on every pull request.

- `vignette("post-processing")` leads with `atlas_polish()` and covers
  polishing a context silhouette and a structure core as the separate problems
  they are: the thin ribbon gently with `method = "chaikin"`, the solid nuclei
  more firmly with the default `close`.

- Examples for `atlas_simplify()`, `atlas_smooth()`, `atlas_polish()`,
  `atlas_dilate()`, `count_vertices()` and `context_pattern()` run under
  `R CMD check`, so the figures the documentation quotes are produced rather
  than asserted, and a test parses every documented example and asserts that
  each argument it names is one the function accepts.

- Help pages are scannable: each `@param` says what to pass in a sentence or
  two with the reasoning moved to `@details`, the twelve `create_*()` functions
  share `@family atlas creation` and point at `atlas_polish()`, every creator
  describes what its returned object holds, and the four anatomical
  coregistration functions say which to reach for and why.

- The reference index groups geometry shaping, curation and file reading under
  their own headings, the re-exported `atlas_*` verbs have a visible
  `?atlas-verbs` page naming each verb and what it changes, and the website
  separates conceptual **Articles** from step-by-step **Tutorials**.

- The package-level help topic maps the five pipeline families to their
  creators and points at `sitrep()`, `atlas_polish()` and
  `setup_atlas_repo()`, and the README shows a four-line first atlas and states
  the `freesurfer >= 1.8.1.902` floor.

- Reading annotation files needs the `freesurferformats` R package, not a
  FreeSurfer installation, and `SystemRequirements` no longer claims FreeSurfer
  for the tract pipelines, which never call it.

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
