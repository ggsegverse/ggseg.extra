# ggseg.extra 1.9.9.9109

## Documentation

- The documentation now describes the lookup table's two declaring columns
  in one place and the same way everywhere. The lookup tables tutorial has a
  section on `type` and `hemi`: the values each takes, that anything else is
  an error, that `NA` leaves a label to the fallback, and how
  `write_lut()` stores both in a lookup table file. The whole-brain,
  subcortical and cerebellar tutorials point to it from where they introduce
  the table.

- `create_wholebrain_from_volume()` listed only `"cortical"` and
  `"subcortical"` as `type` values in its classification section, though
  `"cerebellar"` has been accepted throughout.

# ggseg.extra 1.9.9.9108

## New features

- `write_lut()` now writes a lookup table's `hemi` column, and `read_lut()`
  reads it back. Until now only `type` survived a trip through a file, so a
  declared hemisphere had to live in the build script. A table carrying
  `hemi` is written with a comment line naming its fields,
  `# idx label R G B A type hemi`, and each row then holds every field, with
  `NA` where it declares nothing. FreeSurfer skips the comment and reads only
  the first six fields, so the file is still a colour table to it.

  A table whose only extra column is `type` is written exactly as before, so
  existing lookup table files do not change.

# ggseg.extra 1.9.9.9107

## Bug fixes

- A lookup table whose `hemi` column holds a value that is not a hemisphere
  is now an error in `create_wholebrain_from_volume()`,
  `create_subcortical_from_volume()` and `create_cerebellar_from_volume()`.
  A mistyped value used to be treated as though the row declared nothing, so
  the hemisphere was read from the label's name instead and the column was
  ignored without a word. `NA` and an empty string still mean "not declared".
  The check runs before any other work, as the one on `type` does.

# ggseg.extra 1.9.9.9106

## New features

- A lookup table's `hemi` column now sets the hemisphere in
  `create_subcortical_from_volume()` and `create_cerebellar_from_volume()`,
  not only for cortical parcels in `create_wholebrain_from_volume()`. A row
  the column leaves `NA`, or a table without the column, has the hemisphere
  read from the label's name as before. The whole-brain pipeline passes the
  column on to its subcortical and cerebellar builds; it used to write them a
  lookup table file, which has no field for it.

## Bug fixes

- A label is no longer given a hemisphere because the letters `lh` or `rh`
  occur inside a word. `Entorhinal` and `area-rhinal` came out as right and
  any label containing `lh` as left, in subcortical, cerebellar and tract
  atlases. `lh` and `rh` are now read only as a prefix, a suffix, or a token
  between separators, as in `ctx-lh-entorhinal`. Labels that relied on the
  loose match now get no hemisphere; declare it with a `hemi` column.

# ggseg.extra 1.9.9.9105

## Bug fixes

- `create_wholebrain_from_volume()` now stops on a lookup table whose `type`
  column holds anything other than `"cortical"`, `"subcortical"`,
  `"cerebellar"` or `NA`. A mistyped value -- `"Cortical"`, `"cortex"`,
  `"cerebellum"` -- matched nothing, so the label was treated as undeclared
  and classified by the vertex-count fallback or assumed subcortical. The
  warnings that followed described the fallback, not the typo, and the label
  could land in the wrong sub-atlas. The check runs before any projection, so
  the error arrives in seconds rather than after the surface work. `NA` still
  means "not declared" and is classified as before.

# ggseg.extra 1.9.9.9104

## Bug fixes

- `tube_radius = "density"` no longer silently produces a uniform tube at the
  widest setting. The radius is meant to follow how many streamlines pass each
  point of the centerline, but a tract derived from a volume has no
  streamlines -- only the centerline pulled out of the volume -- so every
  point counted exactly itself, the density was 1 throughout, and the radius
  collapsed to the *maximum* of `density_radius_range`. The documentation
  recommends `"density"` for tracts with many streamlines, so a reader
  following it on a volume-derived atlas got the widest possible tube and no
  indication of it.

  Uniform density carries no information, so the radius is now the middle of
  the range, which is what the existing all-zero branch already answered with
  for the same reason, and the case is reported rather than assumed. A bundle
  whose streamlines cover different stretches of the centerline is unaffected.

# ggseg.extra 1.9.9.9103

## Breaking changes

- Cerebellar region names are normalised the way every other pipeline does
  it. The cerebellar pipeline had its own `clean_cerebellar_region()` instead
  of the shared `label_to_region()`, so within a single built package the three
  pipelines disagreed:

  | pipeline    | region         | label              |
  |-------------|----------------|--------------------|
  | cortical    | `region 174`   | `lh_Region_174`    |
  | subcortical | `region 099`   | `Right_Region_099` |
  | cerebellar  | `Region_100`   | `right_Region_100` |

  Worse, neither function stripped `midline`, which is a hemisphere value this
  package itself assigns -- so **every** cerebellar region in the ggsegverse
  was named `midline_<something>`, with the hemisphere leaking into the region
  name. `label_to_region()` now strips `vermis` and `midline` alongside
  `left`/`right`, and the cerebellar pipeline uses it.

  Region names in the seven `ggsegCerebellum` atlases change on their next
  rebuild: `midline_M1L` becomes `m1l`, `Vermis_VIIAt` becomes `viiat`. The
  `label` column is unchanged, because labels are built from
  `sanitize_label()` rather than from the normalised region -- which is also
  how the other pipelines do it, and was the remaining inconsistency.

## Bug fixes

- A cerebellar atlas where no region got a hemisphere now says so. The
  hemisphere is read from each region's name, falling back to `midline`, so a
  parcellation that writes the side another way gets `midline` throughout in
  silence. All seven shipped atlases are in that state, `nettekoven32` and
  `nettekoven68` included, whose names carry the side as `M1L` and `M1R` --
  a trailing letter with no separator, which the suffix pattern deliberately
  does not match, since matching a bare trailing `L` or `R` would bind any
  label ending in those letters. The remedy named is a `hemi` column or
  `Left_`/`Right_`/`Vermis_` naming.

# ggseg.extra 1.9.9.9102

## Bug fixes

- The large-atlas warning no longer fires on most atlases. Its budget was
  `max(10000, 50 * regions)` regardless of what kind of atlas it was, which
  flagged **76 of the 109 atlases installed here**, shipped and polished ones
  included -- and its advice could not clear it, because polishing a dense
  subcortical atlas does not bring it under a cortical allowance. A warning
  that fires on seven atlases in ten teaches the reader to ignore warnings.

  The budget is now per atlas type, because the types differ by about
  seven times in how many vertices a region naturally needs. Measured across
  those 109 atlases, the per-region medians are 225 (cerebellar), 293
  (cortical), 646 (subcortical) and 1675 (tract). Each budget sits just
  above its type's 90th percentile, so the warning flags the heaviest tenth
  of a family rather than the bulk of it: 9 atlases instead of 76, and the
  nine are the genuine outliers -- `aal3_cortical` at 207k vertices,
  `schaefer*_100` at 106k, `yeo7` at 85k across fourteen regions.

  The advice now names `atlas_polish()`, which is the single call that wraps
  the two the message used to spell out.

# ggseg.extra 1.9.9.9101

## Bug fixes

- `create_wholebrain_from_volume()` now says when it assumed a label is
  subcortical. A label in the volume that reached no cortical vertex is put in
  the subcortical bucket, which is a reasonable default -- a structure the
  cortical surface does not see is usually deep -- but it is a default, not a
  measurement, and it was applied in silence.

  Reported separately from the existing vertex-count warning, because the two
  are different claims: that one says a label was sized and found small, this
  one says a label was never measured at all. With only the first reported, a
  run could announce fourteen vertex-count guesses while nineteen labels ended
  up subcortical, leaving the other five unaccounted for. On FreeSurfer's own
  shipped `aseg` there are 31 such labels.

- The context silhouette of an axial or coronal slice is labelled `cortex`
  rather than `cortex_`. `extract_hemi_from_view()` returns `NULL` for every
  view but sagittal, and `paste0("cortex_", NULL)` left a trailing underscore
  that users saw in `atlas_geom()`. Both spellings match `context_pattern()`,
  so nothing downstream changes; existing cortex snapshots are renamed on the
  next build and redrawn once.

# ggseg.extra 1.9.9.9100

## Bug fixes

- The tract pipelines now name what they dropped, truncated or could not
  match, instead of leaving a lower count as the only trace.

  A tract whose centerline is degenerate produced no mesh and was filtered
  away in silence on the tractography path; it is now named. The volume path
  did report its drops, but only when `verbose` was set, so a quiet run lost
  the label without a word there too. Neither is gated on `verbose` any more:
  a tract missing from the atlas is not progress chatter.

  A `.trk` file whose header declares more streamlines than it holds is
  reported rather than read short in silence. A declared count of `0` means
  "not recorded, read to end of file" in the TrackVis specification, so it is
  not a promise and stays quiet.

  A `tract_names` length that does not match the number of tracts is now named
  where it happens. It used to surface from `furrr` as `Can't recycle length 3
  and length 2 at location 2`, which mentions neither the tracts, nor
  `tract_names`, nor the lookup table the names usually come from -- a lookup
  table with a row per tract it does not have being the normal way to get
  there.

# ggseg.extra 1.9.9.9099

## Breaking changes

- `skip_existing` now defaults to `FALSE`. A step cache is stamped with the
  pipeline's format version, which says which ggseg.extra wrote it and nothing
  about what it was built from, so reusing one could not tell that the volume
  or lookup table had changed. Running a step costs time; reusing it can cost
  correctness, so the default is now the expensive one and reuse is asked for.

  Resuming an interrupted build still works, either by passing
  `skip_existing = TRUE` or by leaving the finished steps out of `steps`.

- Reuse is now reported. Both ways a cache is reused -- `skip_existing`, and a
  step left out of `steps` -- say so, naming the step and that it was not
  checked against the current inputs. The second is the path
  `skip_existing = FALSE` does not close, because a step that was never
  requested reuses its cache regardless, and it is how the documented
  two-phase workflow continues a build.

## Bug fixes

- `cleanup` no longer deletes a cache the next run needs. It and
  `skip_existing` used to contradict each other: a run that stopped early
  wrote a stamped cache and then deleted the directory holding it, so the
  continuation run aborted with "Step 1 was not run but required files are
  missing". This broke the package's own advice --
  `create_wholebrain_from_volume()` tells callers to run the first steps and
  inspect the label split before continuing -- and every subcortical atlas
  repository already passed `cleanup = FALSE` to work around it. A run that
  stops short of the last step now keeps its working directory, and says which
  steps can reuse it.

# ggseg.extra 1.9.9.9098

## New features

- A lookup table can now declare which hemisphere a cortical parcel belongs
  to, with a `hemi` column alongside the existing optional `type` column, and
  `create_wholebrain_from_volume()` honours it.

  This fixes a parcel being emitted for both hemispheres. A cortical label
  carries no hemisphere of its own -- the prefix in `lh_bankssts` comes from
  whichever surface the vertices landed on -- so a parcel whose voxels cross
  the midline is sampled onto both surfaces and becomes two regions the
  parcellation never had. ggsegShen has one: 96.5% of `Region_174`'s 826
  voxels are left of the midline, and the right-hemisphere region was built
  from the 3.5% that spill across.

  Hemisphere is taken from what the table declares, never inferred from the
  voxels. A voxel majority would be a guess made silently on every build; a
  column is a fact the atlas author can see and correct, which is the same
  reasoning behind `type` and `lut_classify_anatomy()`. Where no column is
  given the label's own name is read, covering the `Left-`, `lh.`, `_L` and
  FreeSurfer `ctx-lh-` spellings. A label that declares nothing is left alone,
  so a table naming each structure once for both hemispheres keeps producing
  `lh_` and `rh_` as it should.

  Atlases must declare it to benefit. ggsegShen, for instance, already
  computes the hemisphere from each parcel's centroid and then drops it for
  cortical labels; passing it as a `hemi` column is all that is needed there.

# ggseg.extra 1.9.9.9097

## Bug fixes

- A `.mgz` volume no longer loses every structure whose label id is above 255.
  `tessellate_remap_label()` exists precisely to handle those ids -- FreeSurfer
  caps `mri_tessellate`'s label argument at 255, so the label is isolated into
  a volume of its own and tessellated as 1 -- but it isolated it with
  `RNifti::readNifti()`, which cannot read `.mgz`. The structure then failed to
  tessellate and was absent from the atlas.

  This is the normal case for FreeSurfer thalamic nuclei, hippocampal subfields
  and brainstem substructures, and `.mgz` is a documented input whose own
  examples use `aseg.mgz`.

  The isolated label is now written back as `.mgz`, carrying the original
  volume's voxel-to-world affine. Keeping the format matters twice over: the
  FreeSurfer tools read `.mgz` natively -- a label at or below 255 is already
  handed the `.mgz` untouched -- and reading through `read_volume()` instead
  would hand back a plain array with no header to inherit, so the mask would be
  written with a default affine and the structure would be tessellated
  somewhere other than where it is.

  Verified against a real `aseg.mgz`: an above-255 label now produces a mesh
  identical to the one built from the same volume as NIfTI, 4058 vertices and
  8112 faces about the same centroid, where before it produced none.

# ggseg.extra 1.9.9.9096

## Bug fixes

- A structure that fails to tessellate is now reported whether or not
  `verbose` is set. `subcort_mesh_one()` caught the error and warned only when
  `verbose = TRUE`, so with it off the structure was simply absent from the
  finished atlas with no signal at all. A verbosity flag should silence
  progress chatter, not data loss. The warning now also says what to check.

# ggseg.extra 1.9.9.9095

## Bug fixes

- A mistyped label in `labels$cortical` or `labels$cerebellar` is no longer
  ignored in silence. `create_wholebrain_from_volume()` checked only
  `labels$subcortical`; the other two were `intersect()`ed against the atlas
  and whatever did not match was dropped without a word.

  That is worse than it sounds. The override does not merely fail -- the label
  it was meant to classify is left unclaimed and falls through to automatic
  classification, so an explicit instruction is quietly replaced by a guess
  from the surface vertex count.

  All three are now checked through one path, which is also the point: three
  near-identical branches are how only one of them came to be validated. The
  warning names the argument and the labels it could not find.

# ggseg.extra 1.9.9.9094

## Bug fixes

- The cerebellar and cortical pipelines could ship a region that has no shape.
  `core` names an atlas's regions and the geometry holds their shapes, and a
  label in one but not the other is an atlas that claims a region it cannot
  draw. Nothing complained at build time -- `print()` still counted the region
  -- so it surfaced much later as `geom_brain()` warning that some data was not
  merged properly.

  The cerebellar case is reachable through `rescue_orphaned_region()`, which
  hands a region with no surface vertices the five nearest ones and reports
  success; five vertices do not survive polygon building, so the row stayed in
  `core` and never reached the geometry. A 2362-voxel region was lost this way
  in two atlas repositories.

  Only the subcortical pipeline reconciled the two, which is why the other two
  could do this at all. That check is now shared
  (`drop_labels_without_geometry()`) and runs in all three. It also prunes the
  fields the subcortical version left behind -- `vertices_df` and `vol_idx`
  alongside `core`, `palette` and `meshes_df` -- so a dropped region cannot
  leave a palette entry or a mesh without a `core` row. For the cerebellar
  pipeline it runs after the deep nuclei are merged in, whose geometry is not on
  the flatmap.

  Dropped labels are named, not silently removed, and a build left with no
  region it can draw aborts rather than produce an empty atlas.

# ggseg.extra 1.9.9.9093

## Bug fixes

- `create_wholebrain_from_volume()` now says when the surface projection did
  not deliver a cortical parcel it was asked for. Projecting a volume onto a
  surface loses parcels in two ways, and both used to read as success.

  A parcel can land on no vertex at all. It then has no row in the atlas, and
  the only trace is a region count lower than the lookup table's. Rebuilding
  ggsegShen, 12 of its 214 cortical parcels vanished this way without a word;
  they are not slivers either -- the largest is 621 voxels against a median
  parcel of 595.

  And a parcel whose voxels cross the midline can land on *both* surfaces, so
  one entry in the lookup table becomes an `lh_` and an `rh_` region that the
  parcellation never had. In ggsegShen this happened to one parcel, 96.5% of
  whose voxels are left of the midline: the right-hemisphere region was built
  from the 3.5% that spill across.

  Neither is necessarily wrong -- a lookup table that names a structure once
  for both hemispheres is *meant* to produce `lh_` and `rh_` -- so both are
  reported rather than refused, with the names and the per-hemisphere vertex
  counts. Whether the split report applies is read off the labels themselves,
  so a bilateral lookup table stays quiet instead of listing every label it
  has.

# ggseg.extra 1.9.9.9092

Both fixes were found by building the 26 ggsegverse atlas repositories against
1.9.9.9091. Each one stopped a shipped atlas repository from being rebuilt at
all.

## Bug fixes

- `create_wholebrain_from_volume()` could not build an atlas whose lookup
  table carried a label with a space in it -- the Neuromorphometrics tables
  ggsegMiccai uses are full of them ("Right Accumbens Area"). The pipeline
  writes its own intermediate lookup table for the subcortical pipeline to
  read straight back, and the `write_lut()` guard added in 1.9.9.9084 refused
  those labels rather than corrupting them. Correct for a table a user asked
  for; wrong for one the pipeline hands itself. It now sanitises them first,
  which is what `build_atlas_components()` does to the same labels further
  down, so the finished atlas is unchanged.

  The guard was right about the danger. `read_lut()` splits on whitespace, so
  the label and its colour channels came back one field out of step -- the
  previously released ggsegMiccai subcortical atlas was built from a
  colour-shifted table. The round trip is now lossless.

  The abort also came after the cortical half of the pipeline had finished, so
  about two minutes of work was discarded for a defect present in the input.

- A subcortical rebuild reused projection snapshots drawn from a different
  volume, then failed tracing them with "No contours were extracted from any
  region" -- blaming the regions for a stale cache. This stopped ggsegMars,
  ggsegHammersmith and ggsegMiccai.

  The volume and lookup table `create_wholebrain_from_volume()` hands down to
  the subcortical pipeline are deliberately not cache-stamped, as
  `cache_format_version()` documents. Snapshots instead carry a signature of
  what they were drawn from, which catches a stale one "whether the pipeline
  changed or only its inputs did" -- but that check lives inside the step that
  draws them, and a reusable `slabs.rds` made the pipeline skip the step
  entirely. The machinery was right; it was unreachable.

  Step 4 now short-circuits only when it was excluded from `steps` on purpose.
  When it was requested, each snapshot is checked against its signature and
  only what moved is redrawn: ggsegMiccai's stale directory is repaired in
  3.3s, and a rebuild with nothing to do costs 1.4s rather than 0.

- A changed `slabs` argument is honoured on a cached rebuild. It used to be
  dropped silently, because the step that consumes it was the one being
  skipped.

# ggseg.extra 1.9.9.9091

## Documentation

- `vignette("ggseg.extra")` opens with the shortest path from an annotation
  file to a plot -- create, polish, plot -- which existed nowhere as four
  consecutive lines, and names `sitrep()` as the thing to run before starting
  a pipeline that needs FreeSurfer.

- `vignette("ggseg.extra")` and `vignette("atlas-workflows")` both explained
  the cortical two-step pipeline and the subcortical slicing, in the same
  order, so a new user met each twice before reaching a tutorial. The detail
  now lives once, in `atlas-workflows`, which has the diagrams; the getting
  started guide keeps the format-to-function table and points there.
  `atlas-workflows` likewise no longer restates which pipelines need
  FreeSurfer, which `vignette("system-setup")` and `sitrep()` own.

  No content was dropped -- the duplicated prose became cross-references, so
  each fact still has exactly one home.

- `vignette("atlas-workflows")` now lets its six diagrams carry the
  structure. The prose that restated them in words is gone: the narrative
  opening, "different formats flow through different creation functions but
  converge on a `ggseg_atlas`" (which is the first flowchart), the
  step-1-then-step-2 narration (the second), the cortical-versus-subcortical
  framing (the third), and the 2D/3D compatibility walk-through (the sixth).
  What no diagram shows is kept beside the one it belongs to -- the
  orthographic camera placement and back-face culling, the boundary-face rule,
  `subcortical_slabs()` and the `steps` shortcuts, the SUIT entry points, and
  the whole performance section. All eight headings remain and the file is 30
  lines shorter.

- Six inaccuracies in those diagrams, found by checking them against the code
  rather than against their previous selves:

  - `fig-input-formats` is captioned "All atlas creation pathways" and drew 11
    of the 12 creators -- `create_tract_from_volume()` was missing.
  - its alt text said seven input types where the diagram draws eight.
  - `fig-subcortical` showed the input as a volume "+ Color Table" as though a
    lookup table were required; `input_lut` defaults to `NULL`.
  - `fig-tracts` drew only the `.trk`/`.tck` route, omitting the volumetric
    tract label map that `create_tract_from_volume()` reads. The prose said
    "your input is a tractography file" to match.
  - `fig-output-compatibility` labelled a node `ggseg / Flat 2D plots`, which
    reads as `ggseg()` -- defunct since ggseg 2.0.0. It names `geom_brain` now.
  - `fig-cortical-fork` numbered its stages "Step 1" and "Step 2" like the
    subcortical and tract diagrams, where `steps` is a real argument. The
    cortical creators have no `steps` formal, so the numbering invited a call
    that does not exist.

  Verified unchanged in the same pass: the step counts (`subcort_total_steps()`
  is 6 and `tract_total_steps()` is 4, so "Steps 1-3"/"4-6" and
  "Step 1"/"Steps 2-4" and the `steps = 1:3` and `steps = 1` shortcuts are all
  right), and the format table in `vignette("ggseg.extra")`, which lists all
  twelve creators with nothing stale.

# ggseg.extra 1.9.9.9090

## Minor changes

- `R/atlas_wholebrain.R` was 2556 lines holding three concerns that share
  almost no state. It is now three files, with no change to any function:

  - `R/atlas_wholebrain.R` (2087 lines) -- orchestration, argument grouping,
    validation and the five pipeline steps.
  - `R/wholebrain_context.R` (335) -- the `aseg` cortical-ribbon subsystem:
    whether the ribbon is resolved or has been filled solid, and the context
    volume it becomes. Pure array geometry with its own calibration story.
  - `R/surface_dilation.R` (141) -- reading a cortex mask, masking an overlay
    to it, and growing labels across vertex adjacency. None of it is
    whole-brain specific; any surface pipeline that fills unlabelled vertices
    uses it.

  The 4269-line test file split the same way, into
  `test-wholebrain_context.R` and `test-surface_dilation.R`, with the three
  fixtures they share moved to `helper-wholebrain.R`.

# ggseg.extra 1.9.9.9089

## Minor changes

- The three label-stamping loops now make one pass instead of one whole-array
  scan per label. `wholebrain_prepare_subcortical_volume()`,
  `wholebrain_prepare_cerebellar_volume()` and `subcort_cortex_volume()` each
  walked the volume once per label, which is roughly 10^9 comparisons for a
  400-parcel atlas on a 1 mm grid. On that case the subcortical remap drops
  from 5.8s to 0.13s, about 44x, with byte-identical output -- checked against
  the old loops over 600 randomised volumes including `NA` voxels, repeated
  source indices and empty label sets.

## Documentation

- `cortical_build_sf_projected()` has tests. It was mocked out in all three of
  its callers' test files, so the function that stitches mesh projection into
  the cortical pipeline was never run. Its `st_combine()` is now documented as
  the geometry-type normalisation it is -- combining a single `POLYGON` yields
  a `MULTIPOLYGON`, and a column mixing the two breaks `st_coordinates()` --
  because a reviewer reasonably read it as a no-op and proposed deleting it.

- `wholebrain_prepare_subcortical_volume()` and
  `wholebrain_prepare_cerebellar_volume()` likewise had tests only as mocks;
  both now have real ones covering the remap, the drop of unlisted labels and
  the per-label value. `subcort_cortex_volume()` had no tests at all and now
  covers the cortex labels, the cerebellum and brainstem span, exclusion of
  everything else, and `NA` voxels.

# ggseg.extra 1.9.9.9088

## Breaking changes

Everything deprecated during the 1.9.9.90xx dev cycle has been removed rather
than carried forward. The last release was 1.6 and there are no tags or
releases in between, so none of it ever shipped: these are deprecations
against versions no user could have installed, and keeping them only froze
mistakes made during development.

Removed functions, with their replacements:

| Removed | Use instead |
|---|---|
| `read_ctab()` | `read_lut()` |
| `write_ctab()` | `write_lut()` |
| `is_ctab()` | `is_lut()` |
| `get_ctab()` | `get_lut()` |
| `is_verbose()` | `get_verbose()` |
| `setup_sitrep()` | `sitrep()` |
| `subcortical_views()` | `subcortical_slabs()` |
| `atlas_github_actions()` | `ggseg_atlas_github_actions()` |

Removed arguments, with their replacements:

- `create_subcortical_from_volume(views = )` and
  `create_tract_from_tractography(views = )` -- use `slabs`.
- `create_cerebellar_from_volume(volume = )` -- use `input_volume`.
- `create_wholebrain_from_volume(regheader = )` -- use
  `projection_opts = list(registration = )`.
- `mri_surf2surf_rereg(hemi = )` -- use `hemisphere`. Existing calls keep
  working: with the formal gone, `hemi =` partial-matches `hemisphere`.
- `registration = NULL` in `project_volume_anatomical()` and
  `prepare_subcortical_mni152()` -- name `"header"` or `"mni152"`. `NULL` meant
  opposite things in the two functions, which is why it was retired. It is
  now rejected by `check_registration_spec()`, which
  `project_volume_anatomical()` reaches before it shells out to `mri_convert`
  rather than after.

Flat arguments that were folded into a list and are no longer accepted at all:

- `tube_radius`, `tube_segments`, `n_points` and `centerline_method` in
  `create_tract_from_tractography()` -- use `tube_opts`. Note
  `create_tract_from_volume()` keeps its own `n_points` formal; that one is
  current.
- `cortical_labels`, `subcortical_labels` and `cerebellar_labels` in
  `create_wholebrain_from_volume()` -- use `labels`.
- `projfrac`, `projfrac_range`, `subject`, `registration` and `min_vertices`
  there -- use `projection_opts`. `cerebellar_space` -- use `cerebellar_opts`.
- `dilate`, `smoothness`, `tolerance` and `smooth_refinements` in every
  creator -- these are post-creation steps: `atlas_polish()`, or
  `atlas_simplify()`, `atlas_smooth()` and `atlas_dilate()` individually.

**Atlas build scripts are the thing most likely to notice.** Around 19 atlas
repositories still pass one of these spellings from `data-raw/`, most often
`tolerance` or `smoothness` into a `create_*()` call. Those calls warned
before and now abort with "unused argument", naming the creator.

## Minor changes

- `check_post_creation_dots()` is gone; the creators call
  `rlang::check_dots_empty()` instead. A mistyped or misplaced argument is
  still caught against the creator rather than ignored -- there is simply
  nothing accepted any more -- and the message now reports the offending
  values, not just their names:

  ```
  Error in create_cortical_from_annotation("lh.aparc.annot", tolerance = 0.1) :
    `...` must be empty.
  x Problematic argument:
  * tolerance = 0.1
  ```

  rlang was already in Imports, and it takes the creator's name from the
  condition's `call` rather than from an argument, so there is no parameter
  for a caller's own dots to collide with and no per-creator name to keep in
  step with the function it sits in.

- The two cli messages that told users to pass `cortical_labels`,
  `subcortical_labels` or `cerebellar_labels` -- the step-1:2 inspect
  guidance and the vertex-count classification warning -- now name
  `labels = list(cortical = , subcortical = , cerebellar = )`. Following the
  old advice after this release would have produced a hard error at exactly
  the moment the user was trying to work out what went wrong.

- `project_volume_anatomical()` validates `registration` before reading any
  volume or shelling out to `mri_convert`, rather than after.

- `SUBCORT_MANAGED_ARGS` and `CEREBELLAR_MANAGED_ARGS` became identical once
  the deprecated `volume` alias went, and are now one
  `SUB_PIPELINE_MANAGED_ARGS`. `resolve_labels()` and
  `resolve_projection_opts()` were verbatim copies of `resolve_opts()` and are
  gone; `create_wholebrain_from_volume()` calls the shared helper directly, as
  the tract creator already did.

- `resolve_opts()` moved to `R/utils_atlas.R` and `R/arg_groups.R` is gone,
  the rest of that file having been the deprecation plumbing.

- `lifecycle` stays in Imports and the `experimental` badges are untouched, so
  deprecations can be done properly once there is a release to deprecate
  against.

# ggseg.extra 1.9.9.9087

## Documentation

- Six examples now run under `R CMD check` instead of sitting inside
  `\dontrun{}`: `atlas_simplify()`, `atlas_smooth()`, `atlas_polish()`,
  `atlas_dilate()`, `count_vertices()` and `context_pattern()`. The five
  geometry verbs use `ggseg::dk()`, a real 70-region cortical atlas, behind
  `@examplesIf requireNamespace("ggseg")`; the slowest takes about two
  seconds. `context_pattern()` is pure string work and needed no fixture, and
  its example now shows the anchoring that keeps `Left-Cerebral-Cortex` out of
  the match.

  This is the gap that let the deprecated `ggseg()` calls survive a commit
  written to remove them: an example inside `\dontrun{}` is never executed, so
  nothing notices when the API it demonstrates stops working. The
  `atlas_polish()` and `atlas_simplify()` examples also print the vertex count
  before and after, so the figures the documentation quotes are now produced
  by the check rather than asserted.

  One executed call per topic, since three `atlas_polish()` calls on a
  70-region atlas took 6.3s and earned a "CPU time > 5s" NOTE. The
  illustrative variations stay in `\dontrun{}`, as do the remaining examples
  that need an input file, a FreeSurfer installation or a network fetch.

# ggseg.extra 1.9.9.9086

## Documentation

- Stopped teaching `ggseg()` in the three places 1.9.9.9083 missed. It has
  called `lifecycle::deprecate_stop()` since ggseg 2.0.0, so it always errors.
  `create_wholebrain_from_volume()`'s "Human oversight" section, the cerebellar
  tutorial and the whole-brain tutorial now point at `plot()` for an overview
  and `ggplot() + geom_brain()` for a figure. The two remaining mentions in
  `vignette("legacy-conversion")` describe the old system in the past tense and
  are correct.

- Corrected two documented defaults that were stated backwards. The whole-brain
  tutorial named `"mni152"` as the `registration` default when it is
  `"header"` -- in the same paragraph that warns the choice "moves every vertex
  by about 2 mm, so getting it wrong yields an atlas that looks right and is
  not". `vignette("post-processing")` said `atlas_region_remove()` matches
  labels by default when it matches `region`, so every call in the example pipe
  matched nothing; the calls now pass `match_on = "label"`.

- Fixed two recipes that silently did nothing.
  `vignette("legacy-conversion")` showed `save(my_atlas = result, ...)`, which
  writes an object called `result` -- `save()` takes names from the expression,
  it does not rename -- so a batch conversion produced `.rda` files
  disagreeing with their own filenames. Its `ggseg3d` test guard tested
  `my_atlas$geometry$vertices`, and a `ggseg_atlas` has no `geometry` element,
  so the guard always skipped: exactly what it existed to prevent.

- The whole-brain tutorial no longer teaches `cortical_labels`,
  `subcortical_labels`, `cerebellar_labels` or a bare `min_vertices`. All four
  were retired into `labels` and `projection_opts`, and the tutorial was the
  only long-form place the current forms could be taught.

- The whole-brain tutorial's step 3 described an 8-step cortical pipeline doing
  "screenshots, contour extraction, smoothing". There is no such pipeline and
  no screenshots; it was the last surviving description of the removed
  rendering step.

- The neuromaps tutorial passed `exclude = "cortex_"`, which matched nothing on
  an atlas whose context label is `lh_unknown`. It now uses
  `context_pattern()`, which `vignette("post-processing")` already says to use
  in preference to typing the pattern by hand.

- Twelve `create_*()` functions gained `@family atlas creation` and a
  `@seealso` pointing at `atlas_polish()`. `@family` had been used exactly once
  in the package, so every creator but one was unreachable from its siblings.

- Eight creators returned "A `ggseg_atlas` object." and nothing more; they now
  describe what the object holds, as four of their siblings already did.
  `create_wholebrain_from_volume()` and `create_tract_from_tractography()` also
  document what a partial run returns, which is not a `ggseg_atlas`.

- Removed references to unexported functions from exported documentation:
  `build_atlas_components()` from `read_suit_parcellation()`, `detect_hemi()`
  from `label_to_region()` (replaced with the rule itself), and
  `get_cleanup()`/`get_output_dir()` from `get_verbose()`.

- `mri_surf2surf_rereg()` documented `output_dir` with the shared template,
  which describes intermediate files in `tempdir()`. It writes its output
  annotation into FreeSurfer's `SUBJECTS_DIR` by default, which now says so.
  Its `@return nothing` was also wrong -- it returned the exit status visibly,
  and now returns it invisibly.

- `get_verbose()`'s examples reset `ggseg.extra.verbose` to `NULL` rather than
  to its previous value, discarding whatever the user had set. They now restore
  it.

- `create_cortical_from_labels()` described `views` identically to its four
  siblings while defaulting to two views where they default to four.

- Two `@examples` called `ggseg3d()` unqualified. It is in Imports, not
  attached, so a reader copying either one got "could not find function".

- README gains a four-line first atlas, names `sitrep()`, states the
  `freesurfer >= 1.8.1.902` floor that DESCRIPTION enforces, and carries an
  `experimental` lifecycle badge rather than `stable` -- nearly every function
  in the package carries an experimental badge.

- The package-level help topic only reprinted the DESCRIPTION. It now maps the
  five pipeline families to their creators, and points at `sitrep()`,
  `atlas_polish()` and `setup_atlas_repo()`.

# ggseg.extra 1.9.9.9085

## Breaking changes

- `create_cerebellar_from_volume()` takes `input_volume` as its first
  argument. It previously took `decimate` first, with `input_volume` after
  `...` and therefore name-only, so
  `create_cerebellar_from_volume("Buckner7.nii.gz")` bound the path to
  `decimate` and aborted with "`input_volume` is required" -- naming the
  argument the caller had just supplied. Every sibling creator takes its
  input first. Calls that name `input_volume` are unaffected; a call that
  passed `decimate` by position must now name it.

- `read_neuromaps_volume()` takes `n_bins` second and `output_dir` last,
  matching the order its own `@param` block already documented and the
  order `read_neuromaps_annotation()` uses. `read_neuromaps_volume(f, 7)`
  previously set `output_dir` to `7`.

- `cortical_opts` in `create_wholebrain_from_volume()` now accepts only
  `views`, which is what its documentation already promised and the only
  entry the cortical sub-pipeline ever read. Other names passed validation
  and were then silently discarded -- including the deprecated
  post-creation arguments, which the `subcortical_opts` and
  `cerebellar_opts` paths do forward.

## Bug fixes

- `volume` is forwarded by `create_cerebellar_from_gifti()` and
  `create_cerebellar_from_annotation()`. Both declared it and neither passed
  it on, so the documented promise -- "per-region meshes are tessellated
  using FreeSurfer tools and included in the atlas for 3D rendering" -- never
  happened and the atlas came back with no meshes, silently.

- `decimate` is honoured by all three cerebellar creators. All three declared
  it, none read it, and the one place it applies hardcoded `percent = 0.5`,
  so neither a different factor nor `NULL` to skip decimation had any effect.
  It is now validated with `validate_decimate()` before any work starts, as
  the subcortical pipeline already did.

- `n_points` reaches the tube in `create_tract_from_volume()`. It was honoured
  when fitting the principal curve and then not passed to
  `create_tract_from_tractography()`, whose own default is 50 -- so
  `n_points = 200` fit a 200-point centerline and threw 150 points away. An
  explicit `tube_opts = list(n_points = )` still wins.

- `create_tract_from_volume()` now declares `coord_space = "mm"` rather than
  leaving it to be inferred. It builds world coordinates itself, so there was
  nothing to infer, and `detect_coords_are_voxels()` classifies any bundle
  inside `[0, 300]` -- which a unilateral tract usually is -- as voxel. The
  package's own documentation warns that a wrong guess "places the tract in
  the wrong space and produces a plausible-looking atlas".

- `label_table` is honoured for a volumetric neuromaps parcellation.
  `create_cortical_from_neuromaps()` dropped it on the volume path, so the
  regions came back as `parcel_1`, `parcel_2` and so on with no warning.

- Two cerebellar warnings fired only when `verbose` was on: deep-nuclei data
  with no `vol_idx` column, and FreeSurfer being absent when deep nuclei need
  tessellating. Both drop structures from the finished atlas, which is not
  progress chatter, and both now warn unconditionally.

## Minor changes

- Removed three arguments that were accepted and never read: `width` and
  `height` from `snapshot_cortex_slice()` (leftovers from the PNG-canvas era;
  no caller passed them), and `detail` from `check_pipeline_options()` and
  `install_hints` from `make_pipeline()`, both internal.
# ggseg.extra 1.9.9.9084

## Bug fixes

- `read_lut()` silently misread a LUT line whose label contained a space.
  The label capture was lazy and the pattern anchored, so instead of failing
  the match backtracked into a different, valid-looking parse and every
  colour channel shifted one field along: `"1 Region 10 20 30 40 50 60"` read
  back as label `"Region 10"` with `R = 20, G = 30, B = 40, A = 50`. The
  label is now matched as a single whitespace-free token, and a line like
  that falls into the existing "unparseable line" warning. `read_ctab()` and
  `lut_classify_anatomy()` go through the same reader and were classifying
  the wrong thing.

- `write_lut()` wrote rows that `read_lut()` then dropped. `check_writable_type()`
  existed precisely to prevent that kind of silent round-trip loss, but
  guarded only the `type` column. An `NA`, negative or fractional colour
  channel wrote a field the reader cannot match, and because the pattern is
  anchored the whole row vanished -- label and colours with it. `label` and
  the five numeric columns are now held to the same standard.

- Running `steps = 1:4` on a subcortical atlas with an existing cache deleted
  every snapshot in it. `subcort_resolve_snapshots()` threw away the slab
  table it had just read whenever no step above 4 was requested, and the
  expected-filename set then collapsed to the single string `"_.rda"`, so
  `prune_stale_snapshots()` deleted the lot and reported it as clearing up
  after an earlier slab configuration. Contour extraction in a later run then
  traced an empty directory. The cached slab table is now always returned,
  and naming snapshots without one is an error rather than a silent empty
  set.

- `tube_radius = "density"` silently produced a uniform tube of 0.6 for a
  tract given as a single `N x 3` matrix -- a documented input form, and what
  `create_tract_from_volume()` produces. `Filter()` over a matrix iterates it
  column by column, so no element was a matrix, the density came out all
  zero, and `resolve_tube_radius()` fell back to the midpoint of its range,
  eight times thinner than the default.

- A `.trk` file truncated mid-streamline fabricated coordinates rather than
  failing: `matrix()` recycled the short read, so the final streamline came
  back with invented points. `read_tractography()` now aborts naming how many
  values were expected and how many were read.

- `atlas_dilate()` with a negative `amount` large enough to erode a region
  away returned an atlas that no longer passed `ggseg.formats::ggseg_atlas()`.
  The empty geometry was dropped while `core` and `palette` went on claiming
  the region. It now warns naming the regions lost and removes them from all
  three, so the result can still be rebuilt and saved.

- `create_tract_from_volume()` reported dropped tracts only when called with
  a literal `verbose = TRUE`. The guard was `isTRUE(verbose)`, and `verbose`
  carries the integer levels `0L`/`1L`/`2L`, none of which `isTRUE()` accepts
  -- so labels dropped for too few voxels or a failed centerline fit were
  never mentioned at any real verbosity.

## Minor changes

- `as_verbosity()` now keeps the contract it documents. A value that is not
  length 1, including `NULL`, fell through to base R errors (`'length = 2' in
  coercion to 'logical(1)'`) rather than the documented fallback, and a
  factor was read by its level index, so `factor("2")` gave `1L` where `"2"`
  gives `2L`. Both now fall back, or read, as described. The `@param` text
  also claimed numeric input was clamped to 0--2; negatives have always
  fallen back to `1L` instead, and it now says so.

- `validate_steps()` aborted with "must be whole numbers" only after
  `as.integer()` had already made them whole. `steps = 2.9` silently ran step
  2 and `steps = "2"` was accepted. Both are now refused.

- `check_smoothness()` gained the type and length checks its siblings
  `check_simplify_args()` and `check_dilate_args()` already had.
  `smoothness = NA` silently returned the atlas unsmoothed, `"0.5"` passed
  validation and failed deep inside the smoother, and a length-2 value raised
  a base R condition-length error.

# ggseg.extra 1.9.9.9083

## Breaking changes

- `ggseg` moves from Imports to Suggests. It was imported for
  `ggseg::ggseg()` and `ggseg::position_brain()`, neither of which this package
  calls anywhere -- the only reference was the `@importFrom` itself. Plotting an
  atlas is the caller's business, and the tests and tutorials that do it are
  what Suggests is for.

## Bug fixes

- Two examples told readers to plot with `ggseg()`, which has called
  `lifecycle::deprecate_stop()` since ggseg 2.0.0 and therefore errors.
  `create_cortical_from_annotation()` and `create_cerebellar_from_gifti()` now
  end in `plot(atlas)`, matching the tract and subcortical examples. Both sat
  inside `\dontrun{}`, so `R CMD check` never ran them and nothing caught it;
  anyone copying one got an error.

- The neuromaps tutorial no longer chains ggplot2 onto `plot()`. `plot()` for an
  atlas is a base-graphics overview -- `par()`, `polygon()`, `mtext()`,
  returning the atlas invisibly -- so it draws no legend, and
  `plot(atlas, show.legend = FALSE) + theme_void()` was doing nothing twice
  over: `show.legend` reached `polygon()` and warned once per polygon, and the
  chaining evaluated to `NULL`, which the page printed. 1.9.9.9082 replaced the
  first half with `theme(legend.position = "none")`, which silenced the
  warnings while remaining just as inert and introduced the stray `NULL`. The
  call is now `plot(atlas_clean)`, and the section says what the overview is for
  and points at `ggplot() + geom_brain()` for a figure meant for publication.

# ggseg.extra 1.9.9.9082

## Documentation

- The neuromaps tutorial is re-knitted from its reconstructed source, which is
  what it needed to be trusted. Three things came out of actually running it.

  `plot(atlas, show.legend = FALSE)` does not hide a legend. `plot()` for an
  atlas takes `...`, so `show.legend` reaches base graphics and warns once per
  polygon -- 185 warnings on the Yeo fixture, and roughly 400 lines of them in
  the rendered page. The tutorial now uses
  `theme(legend.position = "none")`, which is what it meant.

  Two of its examples cannot run. `source = "schaefer"` and `source = "pet"`
  are not in the neuromaps registry, which ships 124 annotations and no
  parcellations at all, and the saving example would write package data. They
  are marked as shown rather than run, and the parcellation section says why,
  so a reader copying it does not meet an error.

  The page also predates the large-atlas advisory, which now appears where it
  applies.

# ggseg.extra 1.9.9.9081

## Documentation

- The re-exported `atlas_*` verbs render under **Curate an Atlas** rather than
  in a wall of names at the end of **Utilities**. They all share one help
  topic, so the section that happens to name any of its aliases pulls the whole
  block in -- which was Utilities, via `convert_legacy_brain_atlas`. Building
  the site is the only way to see that; the config looked right either way.

- The tutorials have their own navbar menu. All sixteen articles shared one
  **Articles** dropdown, so the seven atlas-creation tutorials -- the reason
  most people open the site -- sat eighth to fifteenth in it, below two
  headings. **Articles** now holds the conceptual guides and **Tutorials**
  holds the step-by-step ones, creating an atlas first.

# ggseg.extra 1.9.9.9080

## Breaking changes

- The cerebellar flatmap gets a backdrop too, and perimeter regions stop being
  inflated to reach the flatmap edge. Previously the surface no parcellation
  claimed was nothing, and `fill_inter_region_gaps()` expanded whichever
  regions bordered it outward to fill the rim. Now that surface is a
  `cerebellum` backdrop, so those regions stop where the parcellation says they
  stop. Measured on the SUIT anatomical parcellation, 18 of 27 regions change
  vertex count and a thin grey rim appears at the flatmap edge; the region
  count is unchanged. Rebuilding a published cerebellar atlas will produce
  slightly different geometry.

## New features

- `context_pattern()` matches every backdrop an atlas can have, not just the
  ones a pipeline generates. An annotation's medial wall is demoted to backdrop
  during the build exactly as a generated silhouette is, but the pattern did
  not match it, so `exclude = context_pattern()` protected nothing on an
  annotation atlas -- the case the cortical tutorial is built around. It now
  covers the generated names (`lh_cortex` / `rh_cortex`, `cerebellum`,
  `cortex_left` / `cortex_right`) and the carried ones (`unknown`, `???`,
  medial wall). On the Yeo fixture, `atlas_simplify(keep = 0.1, exclude =
  context_pattern())` now keeps the medial wall intact where before it
  simplified it along with everything else.

- A sparse cerebellar parcellation gets a backdrop, as a sparse cortical one
  now does. The flatmap is a single mesh with no hemisphere split, so it is one
  `cerebellum` region rather than one per hemisphere.

## Minor changes

- `is_cortex_outline()` matches case-insensitively, as `atlas_simplify()` and
  `atlas_smooth()` already did, so a parcellation's own backdrop sorts to the
  bottom layer whatever case its author used. Anchoring, not case, is what
  keeps `Cerebellar_Cortex_*` and `Left-Cerebral-Cortex` out.

- `context_region_pattern` and `context_pattern()` are documented as the
  different questions they answer -- "did the parcellation mean this as a
  structure?" against a source name, versus "is this geometry the backdrop?"
  against a finished atlas -- since the obvious reading is that one of them is
  redundant.

- The cortical tutorial is re-knitted: with the medial wall now protected,
  simplification leaves 5,645 vertices rather than 5,189, and the claim that
  `exclude = context_pattern()` "leaves the brain-outline geometry crisp" is
  true for the first time.

# ggseg.extra 1.9.9.9079

## New features

- A cortical parcellation that covers only part of the mantle now gets the
  rest of it as a silhouette to sit on (#285). A handful of `.label` files
  used to produce an atlas of a few shapes floating in empty space, with
  nothing to say where on the brain they were. Every vertex no label claims
  becomes one region per hemisphere, `lh_cortex` / `rh_cortex`, drawn behind
  the parcellation.

  It is context, not a region: it is never added to `$core`, so it carries no
  colour and no legend entry, exactly as the volumetric pipelines' silhouette
  does. It applies to every cortical pipeline, but only appears where there is
  something to appear for -- an annotation that covers the mantle via a
  medial-wall region leaves nothing unlabelled and is unchanged. A
  parcellation that covers *nothing* is also unchanged, so a file that failed
  to read still errors rather than rendering as a plausible grey brain.

- `context_pattern()` matches the surface spelling as well as the volumetric
  one. It was `"^cortex"`, which matched the `cortex_left` that volumetric
  pipelines produce and nothing at all on a surface atlas -- so
  `exclude = context_pattern()` in the cortical, cerebellar, label and
  neuromaps tutorials excluded nothing, and the prose promising it would
  "leave the brain-outline geometry crisp" was untrue. Surface atlases label
  the silhouette `lh_cortex` / `rh_cortex`, because ggseg.formats reads a
  label's hemisphere off its prefix when laying views out, and
  `context_pattern()` now covers both.
# ggseg.extra 1.9.9.9078

## Documentation

- Argument lists are scannable again. Several help pages had grown an essay
  per argument: `atlas_smooth()` spent twelve lines of `@param` on
  `vertex_budget` and ten on `close_gaps`, and
  `project_volume_anatomical()` nine each on `registration` and
  `protect_cortex`. Each argument now says what it does and what to pass in a
  sentence or two, and the reasoning moved to `@details` under its own
  heading, where a reader who wants it can find it and a reader looking up one
  argument is not made to read it. `lut_generate_colors()` had 57 lines of
  prose before its first argument; it now has ten.

  Measured on the `\arguments` block, which is the part a reader scans:
  `atlas_smooth()` 49 lines to 24, `project_volume_anatomical()` 53 to 40,
  `lut_generate_colors()` 20 to 14.

- The `verbose`, `cleanup`, `skip_existing` and `output_dir` argument
  descriptions are shorter, which shows up on the twenty or so pages that
  share them.

- `?create_wholebrain_from_volume` described `cortical_labels`,
  `subcortical_labels` and `min_vertices` as current arguments in its **Label
  classification** section and told readers to "use `cortical_labels` /
  `subcortical_labels` to override" in its recommended workflow. They were
  retired into `labels` and `projection_opts` several dev versions ago, so the
  advice warned rather than worked.

- `?prepare_subcortical_anatomical` now says which of the four anatomical
  coregistration functions to reach for and why, and the others link to it.
  There was nothing distinguishing them, and their argument lists overlap
  heavily.

- The one remaining reference to the old package name `ggsegExtra` is gone.
# ggseg.extra 1.9.9.9077

## Documentation

- The documentation now teaches the API the package recommends.
  `atlas_polish()` and `context_pattern()` appeared in no vignette at all,
  although `?atlas_smooth` calls the first "what most builds want" and
  `?context_pattern` exists so that the silhouette pattern is not retyped.
  The pattern was instead hardcoded thirty-odd times in two incompatible
  spellings, `"^cortex"` in the volume tutorials and `"cortex_"` in the
  surface ones. Every one is now `context_pattern()`, and
  `vignette("post-processing")` leads with `atlas_polish()`.

- `vignette("post-processing")` no longer tells readers to call
  `ggseg_atlas()` while it is unreachable, and its inspection example no
  longer attaches ggseg.formats, since the verbs are re-exported. The same
  redundant `library(ggseg.formats)` is gone from six tutorials.

- "Atlas Creation Workflows" said twice, in prose and in two diagrams, that
  subcortical and tract atlases are 3D-only with "no meaningful 2D
  representation". Both pipelines build 2D slice geometry, and both tutorials
  ship the renders. The sections now explain where that 2D actually comes
  from -- slicing the volume rather than projecting a surface.

- "Reading annotation files needs FreeSurfer" was wrong in the README, two
  vignettes and a tutorial, all tracing back to one NEWS entry. It needs the
  `freesurferformats` R package. `SystemRequirements` also listed FreeSurfer
  for the tract pipelines, which never call it.

- `vignette("pipeline-configuration")`'s options table was missing
  `ggseg.extra.output_dir` and gave `verbose`'s default as `TRUE` rather than
  as a level on its 0/1/2 scale.

- `vignette("ggseg.extra")` linked to five tutorials that are not shipped with
  the installed package, so the links 404'd for anyone reading it in R. Its
  function table was also missing the three cerebellar creators and
  `create_tract_from_volume()`.

- `vignette("contributing")` duplicated seven sections of the publishing
  tutorial, down to scaffolding and CI, and pointed at
  `ggseg_atlas_repos()`/`install_ggseg_atlas()`, which moved to 'ggseg.hub'.
  It is now just the r-universe listing steps and a link, and sits beside the
  publishing tutorial rather than under "Legacy".

- `tutorial-neuromaps-atlas.qmd` and `tutorial-wholebrain-atlas.qmd` had no
  source: static fences and, for the first, hand-baked `<img>` tags, so their
  code was never run and their figures could not be regenerated. Both have a
  `.qmd.orig` again, and `dev/audit-tutorial-api.R` now fails on a tutorial
  that has neither a source nor live chunks.

# ggseg.extra 1.9.9.9076

## Breaking changes

- `atlas_github_actions()` is renamed `ggseg_atlas_github_actions()`. It takes
  no atlas and returns GitHub Actions workflow names, so the `atlas_*` prefix
  put it among the verbs that reshape an atlas -- the reference index had to
  exclude it by hand. The old name warns and still works.

- `setup_sitrep()` is renamed `sitrep()`. It reports on the setup rather than
  performing any, which put it beside `setup_atlas_repo()` under a prefix that
  creates things. The old name warns and still works.

## New features

- `ggseg_atlas()` and `is_ggseg_atlas()` are re-exported from ggseg.formats.
  The "Rebuilding the atlas" section of `vignette("post-processing")` has been
  telling readers to call `ggseg_atlas()`, which was imported but never
  exported -- anyone with only `library(ggseg.extra)` got
  `object 'ggseg_atlas' not found`.

## Minor changes

- The `atlas_*` manipulation verbs appear in the reference index. They are
  re-exports, so they lived on the internal `reexports` page while the section
  named "Atlas Manipulation" held six functions, none of them the ones
  `vignette("post-processing")` teaches. `?atlas-verbs` is now a visible page
  that names each verb and what it is for, grouped by what it changes.

- The reference index lists the `lut_*` names rather than the deprecated
  `read_ctab()`, `write_ctab()`, `is_ctab()` and `get_ctab()` aliases, and
  `subcortical_slabs()` rather than the deprecated `subcortical_views()`. The
  sections are regrouped so geometry shaping, curation and file reading are
  each their own heading.

- `sitrep()` reports `create_tract_from_volume()`, which was missing from the
  pipeline readiness list -- it claimed "12/12" while listing eleven creators
  and one transform. It is 13 now, and `princurve` is checked alongside the
  other optional packages.

# ggseg.extra 1.9.9.9075

## Breaking changes

- The subcortical pipeline has six steps, not nine, and the tract pipeline has
  four, not seven. Contour smoothing and vertex reduction stopped doing
  anything when geometry shaping moved out of atlas creation, but they kept
  their step numbers, their progress labels and — in
  `create_subcortical_from_volume()`'s help — the advice to
  "use `steps = 7:8` to iterate on smoothing and reduction parameters", which
  rebuilt an atlas to no effect. They are gone, and the steps after them have
  moved down: the subcortical 2D build is step 6 (was 9) and the tract build
  is step 4 (was 7). Steps 1-5 of the subcortical pipeline and 1-3 of the
  tract pipeline keep their meaning, so `steps = 1:3` for a 3D-only
  subcortical atlas is unaffected.

- `steps` is now bounds-checked. It only ever picked a default, so a value
  above the last step ran nothing and reported success; it errors now and
  names the range.

- `smooth_refinements` is no longer a formal of the six surface creators. It
  joins `dilate`, `smoothness` and `tolerance` in `...`, so it warns when
  supplied but no longer appears in any signature or help page.

- The `ggseg.extra.tolerance` and `ggseg.extra.smoothness` options (and their
  `GGSEG_EXTRA_*` environment variables) are removed. Nothing had read them
  since geometry shaping moved post-creation, yet `setup_sitrep("full")`
  listed them under "Pipeline options" and told you how to set them. Use
  `atlas_polish()`, `atlas_simplify()` and `atlas_smooth()` on the finished
  atlas.

## Minor changes

- Pipeline progress labels interpolate the step total rather than hardcoding
  it, which is how `1/9` and `2/7` survived two step-count changes.

- Invalid contour geometry is filtered in `extract_contours()`, where the
  contours are produced, rather than in a later pass-through step.

- "Completed step 5" is no longer "Completed steps 5".

- Ten unused `man-roxygen` templates are deleted, including `snapshot_dim`,
  which documented an option that went away with the rendering step.

# ggseg.extra 1.9.9.9074

## Developer-facing changes

### Minor changes

- The test helpers that stood in for `setup_atlas_dirs()` now call it. They
  returned two or three unrelated temporary directories, a shape the pipeline
  never sees: production nests `snapshots/` and `meshes/` under `base/`, which
  is why `finalize_atlas()` can clear the intermediates with a single recursive
  `unlink()` of `base`. Siblings survive that, so roughly forty tests ran
  against a layout in which cleanup was indistinguishable from a no-op. They
  are renamed `local_atlas_dirs()` and `local_subcort_dirs()`, since they no
  longer mock anything.

- A new `finalize_atlas()` test asserts that cleanup clears the nested
  directories, the behaviour the old helper shape could not detect.

# ggseg.extra 1.9.9.9073

## User-facing changes

### Minor changes

- The pre-knitted tutorials moved from `vignettes/` to `vignettes/articles/`,
  together with the `.qmd.orig` sources they are knitted from and the
  `figures/` they draw on. They were never shipped in the tarball --
  `.Rbuildignore` excluded them one pattern at a time -- and
  `vignettes/articles/` is where pkgdown expects website-only pages, so
  `vignettes/` now holds the six real vignettes and nothing else. **Every
  tutorial URL is unchanged**: pkgdown renders `vignettes/articles/x.qmd` to
  the same `articles/x.html` a top-level vignette would get, so no existing
  link breaks.

- The subcortical and tract tutorials now cover tidying the geometry, which
  only the cortical, label and cerebellar ones did. Both show `count_vertices()`
  before and after `atlas_simplify()` and `atlas_smooth()`, and both make the
  point the other tutorials do not have to: the context silhouette and the
  structures need **separate** passes. A single pass tuned for nuclei or tubes
  flattens the cortical ribbon into a blob, and `method = "chaikin"` is what
  keeps its sulci, because the default `close` fills any hole narrower than the
  smoothing distance. Both tutorials also show that the context carries most of
  the vertices, and that smoothing puts some back rather than removing them.

- The tract tutorial's key-parameter list presented `tube_radius`,
  `tube_segments` and `n_points` as arguments of
  `create_tract_from_tractography()`. #253 moved them into `tube_opts`, so the
  list now says so and shows the call.

# ggseg.extra 1.9.9.9072

## Developer-facing changes

### Minor changes

- Writing a cache manifest from a parallel worker now aborts instead of
  silently dropping rows. Stamping is a read-modify-write on state shared by
  every cache in a directory, so two workers each drop the other's rows; the
  documentation said main-thread-only but nothing enforced it, and with furrr
  throughout the pipelines a refactor that moved a stamp into a worker closure
  would have produced caches that merely look stale and get rebuilt -- hours
  of work lost, with the cause nowhere near the symptom.

  `setup_atlas_dirs()` claims the manifests for the calling process at the top
  of every pipeline, before any work, and `stamp_cache_files()` refuses unless
  the claim is held. One check covers both worker kinds from a single
  definition: a multisession worker has a fresh namespace and so holds no
  claim, and a forked worker inherits the parent's claim but not its pid.

# ggseg.extra 1.9.9.9071

## User-facing changes

### Minor changes

- The `create_tract_from_volume()` example passed `tube_radius = 3`, which
  #253 retired into `tube_opts`, so following the documentation produced a
  deprecation warning. It now passes `tube_opts = list(tube_radius = 3)`, and
  the `...` documentation names current arguments rather than retired ones.

## Developer-facing changes

### Minor changes

- A new test parses every documented example and asserts that each argument it
  names is one the function actually accepts. All 58 help topics wrap their
  examples in `\dontrun{}` -- they need FreeSurfer, a subject directory and
  hours -- so `R CMD check` executes no line of the package's primary API, and
  a renamed argument in any of the 24 pipeline entry points would have shipped
  a broken example with every check still green. That is how the
  `tube_radius` rot above was found.

  A function whose `...` forwards to another exported function declares the
  target rather than listing names, so an argument retired from the target
  stops being a formal there and is caught here. `\donttest{}` was considered
  and rejected: it runs under `--run-donttest`, where these examples would
  fail for want of FreeSurfer.

# ggseg.extra 1.9.9.9069

## User-facing changes

### Minor changes

- `create_tract_from_tractography()` gains `coord_space`, to declare whether
  streamline coordinates are `"voxel"` indices or RAS world `"mm"` instead of
  always inferring the space. Inference is a heuristic that cannot always
  tell, and getting it wrong does not error -- it places the tract in the
  wrong space and produces a plausible-looking atlas. The default `"infer"`
  keeps inferring.

- The coordinate space in force is reported at `verbose >= 1` whether it was
  declared or inferred, naming the same `"voxel"`/`"mm"` values `coord_space`
  takes, and the inferred message points at the argument.

## Developer-facing changes

### Minor changes

- The constants in `detect_coords_are_voxels()` (`-10`, `300`, `1.1`) are
  documented: what each bounds, and why the bounds overlap for a small bundle
  sitting entirely in the positive octant, which is the case `coord_space`
  exists for.

- `detect_tract_coord_space()` is now `resolve_tract_coord_space()`, since it
  settles the space rather than always detecting it.

# ggseg.extra 1.9.9.9068

## User-facing changes

### Minor changes

- The no-affine fallback in `coord_to_voxel()` no longer assumes a 1mm
  isotropic grid. It mapped world millimetres to voxel indices 1:1 around the
  volume centre, so on a 2mm grid every coordinate landed at twice its true
  distance from the centre -- a systematic scale error that the warning
  described only as streamlines that "may be placed at the wrong voxels". The
  voxel size now comes from the header (NIfTI `pixdim`, MGZ `xsize`/`ysize`/
  `zsize`) even when the full affine is unreadable.

## Developer-facing changes

### Minor changes

- `load_vox2ras_matrix()` is now `load_tract_grid()` and reports both the
  affine and the fallback voxel size, so its warning can say which fallback is
  in force: scaled by a recovered voxel size, or assuming 1mm because even
  that could not be read. It also now says that the volume is not reoriented
  to RAS on this path, which the old wording left out.

# ggseg.extra 1.9.9.9067

## User-facing changes

### Minor changes

- The three remaining places that catch a failing FreeSurfer command now chain
  the original condition rather than rewording its rendered message.
  `read_fs_surface()`, `tessellate_smooth_mesh()` and `subcort_mesh_one()`
  captured FreeSurfer's stderr and then dropped or re-rendered it, so the
  reason a mesh failed to build was lost by the time the warning reached the
  build log. They now report `Caused by error:` with the tool's own output,
  as `resample_volume_to_grid()` already did.

# ggseg.extra 1.9.9.9066

## User-facing changes

### Minor changes

- `aseg_context()` applies its hidden-label recipe as one pattern rather than
  one call per pattern. The recipe names structures an `aseg` may or may not
  carry, so most of its patterns match nothing on any given atlas; with
  ggseg.formats reporting a pattern that matches nothing, calling them one at
  a time would have produced a warning per miss. Behaviour is unchanged.

# ggseg.extra 1.9.9.9065

## User-facing changes

### Minor changes

- `count_vertices()` is now exported. It reports how many polygon vertices
  each region carries; `sum()` of it is the figure the `create_*()` pipelines
  warn about when an atlas is large, and the one `atlas_simplify()` brings
  down. Until now the only way to see that number was to trigger the warning.

## Developer-facing changes

### Minor changes

- The tutorials plot the atlas at each stage of the build rather than once at
  the end, so the effect of each step is visible. The cortical, label and
  cerebellar tutorials show the geometry before and after
  `atlas_simplify()`/`atlas_smooth()` with the vertex counts beside them; the
  subcortical and tract tutorials show the atlas as regions, views and
  fragments are removed.

- The cortical tutorial built its finished atlas from the *unsmoothed*
  polygons: it simplified and smoothed into a variable it then never used, so
  the atlas it told you to save was the 21,514-vertex one the pipeline warns
  about. It now carries the tidied atlas through, and saves 6,793 vertices.

- The label and tract tutorials wrote `plot(atlas) + scale_fill_viridis_d()`.
  `plot()` draws with base graphics and returns the atlas, so the scale was
  silently discarded and the figure never used the palette it advertised.
  Both now go through `ggplot() + geom_brain(atlas, aes(fill = region))`,
  which is the route that accepts a scale.

- The cerebellar tutorial removed `unknown` and `corpuscallosum`, neither of
  which a cerebellar parcellation contains. It now removes `region_28`, the
  unnamed midline strip the SUIT parcellation actually leaves behind.

- Two metadata joins in the tutorials had never matched. The cortical
  tutorial joined a network-name table on `label`, but the labels carry a
  hemisphere prefix (`lh_7Networks_1`), so the atlas it published still
  called its regions `7Networks_1`. The tract tutorial stripped `.prep` off
  its labels before joining, so every tract came out with an `NA` group.
  Both now join on a key that exists, and the tract table lists the tracts
  this training set actually ships.

- Corrected in the tutorials: the subcortical pipeline makes seven projection
  views, not six; the cerebellar pipeline does not simplify its polygons (the
  claim named an `rmapshaper` call that is not there); cerebellar regions come
  out as `I_IV` and `CrusI`, not "I-IV" and "Crus I"; and
  `setup_atlas_repo()` does read `usethis.description`, which it has since
  1.9.9.9062.

- The publishing tutorial pins `usethis.description` while it knits, so the
  example DESCRIPTION shows the template placeholder rather than the name and
  email of whoever last built the vignettes.

- The cortical tutorial no longer calls `atlas_region_contextual()` on the
  medial wall. The pipeline already sets it aside; the tutorial now says so,
  and shows the manual call for a parcellation whose leftovers are named
  something the pipeline does not recognise, such as `aparc`'s
  `corpuscallosum`.

# ggseg.extra 1.9.9.9064

## Deprecations

- `is_verbose()` is deprecated in favour of `get_verbose()`. An `is_` prefix
  on a function that returns `0L`, `1L` or `2L` invites `if (is_verbose())`,
  which is true at every level but silence -- it worked by coercion, which is
  worse than failing. `get_verbose()` now takes the same optional argument, so
  it resolves an explicit level or falls back to the option and the
  environment variable, exactly as `get_cleanup()` and `get_output_dir()` do.
  `as_verbosity()` remains the way to coerce a value without consulting the
  option.

# ggseg.extra 1.9.9.9063

- Internal: a failed `mri_vol2vol` resampling now reports what FreeSurfer
  said. `resample_volume_to_grid()` was lowering the verbosity it was given --
  so the error output was suppressed even when the caller asked for everything
  -- and then discarding the error itself, leaving both callers to report a
  bare "`mri_vol2vol` failed". It now passes the verbosity through and returns
  the condition that failed, which its two callers chain as the parent of
  their own warning and abort, so FreeSurfer's own message travels with them.

- Internal: a failing FreeSurfer command aborts with the condition class
  `ggseg_extra_fs_command_error`, so a caller can tell one from any other
  error. `run_cmd()` also stops reading the captured error log back on the
  success path, where nothing looked at it.

# ggseg.extra 1.9.9.9062

- Internal: the tract tutorial builds in CI, now that the image carries the
  one `trctrain` subject it uses. Five of the nine tutorials are executed on
  every pull request. Re-knitting it showed the committed page was stale in a
  way worth noting: it reported the atlas as `tracts` rather than `tracula`.

- Internal: tutorials knit at a pinned console width, so a narrow terminal and
  a runner no longer produce different line breaks throughout. Together with
  the path rewriting, a re-knit now differs only where the output does.

- Internal: the whole-brain pipeline gained an end-to-end test. Its tutorial
  cannot be built here -- Harvard-Oxford ships only with FSL -- so the
  pipeline is covered directly instead, asserting the default step set reaches
  the end and returns the three-way split rather than running everything and
  handing back nothing.

# ggseg.extra 1.9.9.9061

- `setup_atlas_repo()` fills the new package's DESCRIPTION from the
  `usethis.description` option when you have one set, instead of always
  writing the template's placeholder author and its invalid
  `0000-0000-0000-0000` ORCID. A field the template declares is replaced and
  one it does not is added; `Package`, `Title`, `Description`, `URL` and
  `BugReports` stay as the scaffold derived them.

# ggseg.extra 1.9.9.9060

- Internal: the cortical and cerebellar tutorials build in CI too. Cortical
  gained the reproducible source it never had -- its data was in the image all
  along -- and cerebellar fetches the 12 KB SUIT parcellation from the
  Diedrichsen Lab repository the deformation field already comes from. Four of
  the nine tutorials are now executed on every pull request rather than two.

- Internal: re-knitting a tutorial no longer bakes in the machine that did it.
  FreeSurfer's location and the session temp directory are rewritten to
  `$FREESURFER_HOME` and `<tempdir>`, so a laptop and a runner produce the same
  output and a diff means the output actually changed.

# ggseg.extra 1.9.9.9059

- Internal: a `tutorials` workflow now checks the tutorials on every pull
  request. It audits every vignette's code against the package API, and knits
  the two whose inputs a runner has. Pre-compiled tutorials were text nobody
  re-ran, which is how nine of them came to recommend an argument that had
  moved.

- Internal: the tutorial build no longer requires ImageMagick. It was needed
  when cortical polygons came from screenshots of a 3D scene; direct mesh
  projection replaced that, and the check only served to skip every tutorial
  on machines without it, the CI image included.

# ggseg.extra 1.9.9.9058

- The existing vignettes and tutorials now call the current API. They still
  showed `atlas_smooth(keep = )` from before simplification and smoothing were
  split, so the documented post-processing step errored; `keep` belongs to
  `atlas_simplify()`. `post-processing.Rmd` also called
  `atlas_view_remove_region_small()`, which is `atlas_view_remove_small()`, and
  passed `match_on` to `atlas_region_rename()`, which did not accept it at the
  time and did not need it either, since `"region"` is what it matches on by
  default.

- The bundled atlas repository template no longer scaffolds a build script
  whose smoothing step errors, for the same reason.

# ggseg.extra 1.9.9.9057

- Two new tutorials. *Lookup tables and colours* covers the `lut_*` family --
  building, reading, combining and colouring the table every volumetric
  pipeline asks for. *Publishing an atlas as a package* covers
  `setup_atlas_repo()`, `use_atlas_github_actions()` and the steps between a
  finished atlas and a repository that builds itself.

# ggseg.extra 1.9.9.9056

- `create_subcortical_from_volume()`, `create_tract_from_tractography()` and
  `create_tract_from_volume()` return the atlas they built again. They ran
  every step, reported the pipeline as completed and then returned `NULL`:
  when a stage was removed the ceiling on `steps` dropped, but the step the
  atlas assembly was gated on did not, so that step was never in the set. Each
  pipeline's step count is now one value used everywhere it is needed, rather
  than the same number written in three places, and the progress labels count
  to it too (`5/9`, not `5/8`).

# ggseg.extra 1.9.9.9055

- Extracting contours no longer attaches terra to your search path, where
  it masked functions such as `describe()` and `extract()`.

- `setup_sitrep()` lists optional packages by name; it printed raw
  `{.pkg ...}` markup instead.

- Building a subcortical atlas with `verbose = FALSE` no longer reports the
  stale slab images it removes.

- A relative `output_dir` for a subcortical, tract or whole-brain atlas is
  now made absolute on every platform. Before, it stayed relative unless the
  directory already existed, except on Windows.

- Pipelines report their total run time the way cli reports each step
  (`Pipeline completed [1m 15s]`), instead of in minutes rounded to one
  decimal, which showed anything under three seconds as "0 minutes".

- Internal: the test suite no longer hides messages or warnings. Calls that
  report several things are checked against snapshots, and the shared test
  helpers are split by topic.

# ggseg.extra 1.9.9.9054

- Every function orders its arguments the same way: the ones without
  defaults, then the ones with real defaults, then `...`, then everything
  defaulting to `NULL` or an empty list. Thirty-six did not, so reading two
  signatures side by side told you nothing about where to expect an
  argument.

  Nothing about the arguments themselves changed -- same functions, same
  argument names, same defaults, checked mechanically rather than by eye.
  Only their order moved, and only within a signature.

  Arguments that now sit after `...` have to be named. No call to any of
  these functions in the ggsegverse atlas repositories passes anything
  beyond the first argument by position, so none of them is affected.

- `load_cortex_mask()` had a required argument sitting after one with a
  default, which meant every caller had to pass the defaulted one too.

- `read_neuromaps_volume()` was called internally with three positional
  arguments, which the reorder would have quietly turned into a bin count
  handed over as a directory path. It and the other call sites where the
  second position changed meaning -- `setup_atlas_dirs()`,
  `setup_atlas_repo()`, `load_cortex_mask()` -- now name their arguments.

# ggseg.extra 1.9.9.9053

- `create_tract_from_tractography()` takes 12 arguments rather than 17.
  `tube_opts` holds `tube_radius`, `tube_segments`, `n_points` and
  `centerline_method` -- everything about turning a bundle of streamlines
  into a 3D tube mesh. The flat arguments still work, through `...`, and
  deprecate.

  `vertex_size_limits` stays where it was, next to `slabs`, despite the name
  suggesting it belongs with the mesh: it filters finished 2D polygons by
  vertex count and never touches the tube.

- Both restructured creators order their arguments the tidyverse way: the
  one required argument, then the arguments with real defaults, then `...`,
  then everything defaulting to `NULL` or an empty list. Those last must now
  be named, which every call site in the ggsegverse atlas repositories
  already does.

- The grouped lists say which function forwards their entries rather than
  restating that function's argument documentation, which would have drifted
  the moment either side changed. `cerebellar_opts` points at
  [create_cerebellar_from_volume()], and `projection_opts` at the
  **Registration** section rather than repeating it.

- The grouped-argument helpers moved to `R/arg_groups.R` and are shared, so
  the creators agree about what a deprecation looks like rather than each
  spelling it differently. Each creator names the version it was grouped in;
  the notice used to quote whichever version the helper was written for,
  which sent people to the wrong NEWS entry.

- An invalid grouped list is reported against the argument that was actually
  passed. `labels = "x"` said `labels_opts` must be a named list, naming an
  argument that does not exist.

- `tract_setup_pipeline()` is called with named arguments. Fifteen of them
  were passed by position, three of which (`verbose`, `cleanup`,
  `skip_existing`) sit next to each other and take the same kinds of value.

# ggseg.extra 1.9.9.9052

- `create_wholebrain_from_volume()` takes 13 arguments rather than 21. The
  ones that describe the same thing are grouped: `labels` holds the
  `cortical`/`subcortical`/`cerebellar` overrides, `projection_opts` holds
  `subject`, `registration`, `projfrac`, `projfrac_range` and
  `min_vertices`, and `cerebellar_space` joins `cerebellar_opts`. The
  function already built `list(cortical = , subcortical = , cerebellar = )`
  out of three flat arguments on its way in, so `labels` is the shape it
  wanted anyway.

  The flat arguments still work, through `...`, and warn. Supplying both an
  old argument and the list entry that replaced it is an error rather than a
  precedence rule: the two disagree about one setting, and quietly preferring
  either is how a build ends up not doing what its script says.

  Every call to this function in the ggsegverse atlas repositories names its
  arguments, so nothing depends on their order, and each of the ten was
  checked against the new signature.

- A sub-pipeline option passed at the top level says where it belongs.
  `decimate = 0.5` used to be met with R's `unused argument`, which does not
  mention that `subcortical_opts = list(decimate = 0.5)` is the way to say
  it. Two atlas build scripts pass exactly that and have been failing.

# ggseg.extra 1.9.9.9051

- `read_volume()` says so when it cannot orient an MGZ. The affine is the only
  thing that can place a bare array, and a conformed volume is typically LIA,
  so returning one in its native voxel order, without saying so, handed the
  projection code a volume whose axes were transposed -- which renders as a
  plausible brain rather than failing. `load_vox2ras_matrix()` already reported the same
  condition; the two now agree.

- FreeSurfer's stderr survives a failure. It was discarded at any verbosity
  below 2, which is the default, so a tool that died three hours into a build
  reported an exit code and a command string with the line saying why already
  thrown away. It is now captured whatever the verbosity, echoed at `verbose
  >= 2`, and its tail is quoted in the error. Braces in that output are
  escaped: `mri_info` prints matrices, and a bare brace turned the
  report of the failure into a second, unrelated failure.

- `freesurferformats` is checked before it is used. `read_volume()` guarded
  `RNifti` in one branch of the same `switch()` and not `freesurferformats` in
  the other; `write_projection_volume()` and `fill_surface_labels()` did not
  guard it at all.

- The volumetric test fixture has a header again. `aseg.mgz` is a crop of
  fsaverage5's, and the crop dropped its RAS information, so every test using
  it exercised the native-voxel-order path that real FreeSurfer output never
  takes -- and one test had come to depend on that, asserting the missing
  header warning against the shared fixture. The crop offset was recovered by
  matching against the parent volume, which is bit-identical at (91, 108, 88),
  so the restored affine is derived rather than assumed. Only the 16 header
  bytes covering the RAS block changed; voxel data, `dof`, `mr_params` and the
  footer tags are untouched. The test that wanted a volume with no header
  now writes its own.

# ggseg.extra 1.9.9.9050

- `read_volume()` documented a `niftiImage` return for `reorient = FALSE` that
  it has never produced: the header is consumed inside the function and every
  path ends at `drop(as.array())`. The roxygen now says so, and the one caller
  that named its result `template_nii` only ever wanted `dim()`.

- `decimate_mesh()` guarded `Rvcg` and then called `rgl::tmesh3d()` on the next
  line. `rgl` is the heavier install of the two and is routinely absent where
  `Rvcg` is present, so the check now covers both.

- `set_sphere_voxels()` fills the sphere with one matrix-indexed assignment
  instead of a per-voxel loop.

- `subcort_unpack_input()` is gone. It took `tolerance` and `smoothness`,
  discarded both, and described a deprecation warning that had already been
  removed; the call site uses `unpack_anatomical_input()` directly.

- The subcortical setup and validation calls name their eleven arguments, as
  the whole-brain path already did. `verbose`, `cleanup` and `skip_existing`
  sat adjacent and positional, where a transposition would have wired the
  pipeline up wrongly with no error anywhere.

- `.Rbuildignore` excluded `*.Rmd.orig`, but the precomputed vignette sources
  are `*.qmd.orig`, so all three shipped in the tarball without the vignettes
  they generate.

- `vignettes/figures/` no longer ships. Every one of its images belongs to a
  tutorial vignette that `.Rbuildignore` already excludes, and the six
  vignettes that do ship reference no images at all, so it was 2.9 MB of a
  4.7 MB tarball that nothing in the tarball could reach. pkgdown renders the
  tutorials from the repository, so the website is unaffected.

- The test suite stops printing to the console: `use_atlas_github_actions()`
  messages are suppressed where the message is not what is under test, and the
  MNI152 fixture carries a valid sform so FreeSurfer no longer warns that it
  cannot orient it. `helper.R` no longer attaches `tidyr` and `ggplot2`, which
  are Suggests packages that no test used.

# ggseg.extra 1.9.9.9049

- `README.md` is regenerated from `README.Rmd` rather than hand-edited, so
  the paragraph reflows the way knitr wraps it. The two were edited together
  when ImageMagick and Chrome left the prose, which left the text correct but
  the line breaks stale, and `render-readme` had a diff to push on every run.

# ggseg.extra 1.9.9.9048

- `chromote` is gone. Nothing has rendered through a headless browser since
  contours began being traced from the projection itself, so it leaves
  Suggests, `find_chrome_path()` goes, and `setup_sitrep()` no longer reports
  a missing Chrome as a problem or carries a `system` element.

- Snapshots are named `.rda`, which is what they have been on disk since the
  PNG round-trip was removed. `structure_snapshot_file()` still spelled them
  `.png`, and three mechanisms keyed on that name had been quietly doing
  nothing:

  - **Per-structure snapshot reuse.** The signature manifest is filtered by
    `file.exists()` before being written, so every structure signature was
    dropped and only the cortex silhouettes -- already named `.rda` -- were
    recorded. A rebuild redrew all 174 structure projections of an `aseg`
    every time, however little had changed.
  - **Stale-slab pruning.** `prune_stale_snapshots()` scanned for `.png` and
    so found nothing to prune, leaving the failure its comment describes --
    a contour traced into a view the current configuration has no slab for --
    unguarded.
  - **Derived-image clearing.** `drop_derived_images()` cleared the processed
    and mask directories, which no longer exist. Removed rather than fixed.

  `structure_snapshot_file()` now defers to `projection_file()`, so one place
  decides the spelling. Snapshot signatures recorded under the old `.png`
  keys will not match, so the first build after this redraws its snapshots
  once.

- `build_contour_sf()` no longer strips a `.png` extension that
  `extract_contours()` has already removed.

- CI stops installing what the image pipeline needed. The FreeSurfer
  container no longer downloads and unpacks the pinned ImageMagick 7
  AppImage, which existed only for a `has_magick()` probe that no longer
  exists. `hexSticker` leaves Suggests -- nothing in the package, tests,
  vignettes or build scripts referenced it, and it was the only path to the
  R `magick` package, so dropping it takes 18 packages out of the CI
  install tree. With those gone, `libmagick++-dev`,
  `libharfbuzz-dev`, `libfribidi-dev`, `libfontconfig1-dev`,
  `libtiff-dev` and `libjpeg-dev` leave the image: nothing left in the
  dependency tree names them in `SystemRequirements`.

- A pull request building the FreeSurfer image no longer overwrites the
  version tags it publishes. `freesurfer-tests` runs in
  `freesurfer-slim:7.4.1-r4.6` on every branch, and the build pushed that tag
  from any branch, so removing ImageMagick here replaced the image the other
  pull requests and `main` are tested against and broke `magick --version` in
  their smoke test. Only the default branch moves the version tags now; a
  pull request gets a tag of its own.

# ggseg.extra 1.9.9.9047

- `plan(multicore)` is no longer downgraded to `multisession`. The downgrade
  existed because fork corrupts chromote's websockets, and nothing has
  rendered through a headless browser since contours began being traced from
  the projection itself. The downgrade was what made parallelism stop paying:
  a `multisession` worker needs its own copy of the volume, and serialising
  67 MB of a 256^3 aseg costs more than the projection it was sent to
  compute. Measured on an 8-core machine against FreeSurfer's `bert`,
  `create_subcortical_from_volume()` goes from 337s sequential to 171s under
  `plan(multicore, workers = 4)`; the same run under `multisession` was
  slower than sequential.

- `plan(multisession)` no longer aborts a subcortical or tract build with
  "Cached ... was written by cache format none". Snapshots are written from
  parallel workers, and each worker stamped the cache manifest itself - a
  read-modify-write of one file shared by the whole directory, so workers
  dropped each other's rows and left projections the contour step then
  refused. The steps now collect the paths their workers wrote and stamp them
  on the main thread, which is where `stamp_cache_files()` always documented
  that it had to be called.

- `future` moves from Imports to Suggests. The package no longer calls it
  directly; `furrr` depends on it, so it is still installed.

# ggseg.extra 1.9.9.9046

- Tests call `describe()` bare again instead of qualifying every block as
  `testthat::describe()`. The masking was real but misattributed: `future`
  attaches the packages a global refers to, so the first `furrr` call over
  `terra` code runs `library(terra)` in the test process and terra's
  `describe()` takes over the search path. A single `describe <-
  testthat::describe` in `helper.R` sits below the search path in the lookup
  chain and fixes it for every file, whenever terra attaches.

- The FreeSurfer smoke test no longer asserts on `magick --version`. The
  package has not shelled out to ImageMagick since contours began being
  traced from the projection itself, and the published container has now
  dropped it, so the assertion fails on a binary nothing needs.

# ggseg.extra 1.9.9.9045

- `cortical_finalize()` is covered by tests, so both places an atlas can
  leave the package are (#81). Every `create_*()` reaches either it or
  `finalize_atlas()` -- checked by tracing the call graph, not by reading --
  and only the latter was tested. Between them they decide the thing the
  lite-atlas work cares about: nothing ships carrying sf.

  `sf` stays in `Imports`. The builders do real geometry with it, and
  `rmapshaper` depends on it; what the milestone wants is sf-free
  *plotting*, which the polygon output already gives.

# ggseg.extra 1.9.9.9044

- `prepare_subcortical_mni152()` converts the aseg with
  `freesurfer::mri_convert()` rather than working around it (#118). The
  wrapper used to error on arguments it no longer takes, and `fs_cmd()`'s
  input check could not parse FreeSurfer's `.mgz`, so the call went through
  `fs_cmd(validate_inputs = FALSE)`. The released wrapper now lists `mgz`
  among the formats it accepts, so the workaround and its explanation both
  go. Checked against a real `aseg.mgz`: the two produce byte-identical
  NIfTI.

  The other half of #118 stays as it is. It wants a flag-based
  `mri_vol2vol()`, which `freesurfer` still does not export, so that call
  keeps its `opts_after_outfile = TRUE` arrangement.

# ggseg.extra 1.9.9.9043

- Subcortical and tract contours are traced from the projection itself
  instead of a PNG of it (#139). **Atlases built with this produce different
  geometry and need rebuilding**, and build scripts need their distance-valued
  arguments re-tuned -- see below.

  A projection started life as a numeric matrix, went through `image()`, a PNG
  file, ImageMagick transparency, alpha extraction, a mask PNG, a decode back
  to pixels and a raster, and only then became polygons. Two bug classes came
  out of that: a PNG carries no coordinates, so whoever read it decided which
  way `y` ran, and masks written by the pipeline could carry a colour profile
  that the image reader refused. Both needed workarounds.

  The round trip also cost fidelity. It rendered onto a fixed 400x400 canvas,
  so a region whose true width:height is 2 came back as 1.985. Traced
  directly it is 2.0000, and the coordinates are the voxel indices rather
  than pixels of a canvas.

- **Distances now mean voxels.** The canvas scaled every atlas by
  `400 / max(dim)`, so the same `atlas_dilate(0.6)` was a different physical
  distance on every atlas -- 1.56 pixels per voxel on a 256-cube, 1.84 on a
  182x218 volume. In voxel space `0.6` is 0.6 voxels everywhere, usually
  0.6 mm. Values tuned against the old canvas want dividing by that atlas's
  old scale factor; `atlas_smooth(smoothness =)` is a distance too and moves
  the same way.

- The build-time `dilate` argument is no longer applied. It has been
  deprecated since 1.9.9.9016 in favour of `atlas_dilate()` on the finished
  atlas, which is where it belongs -- retuning it there does not mean
  rebuilding. Passing it still warns, and now says it is not applied.

- ImageMagick is no longer required. It leaves `SystemRequirements`, `magick`
  leaves `Suggests`, and `setup_sitrep()` no longer reports it or tells anyone
  to install it.

- The `processed/` and `masks/` directories are gone, and with them the
  image-processing step: subcortical builds run 8 steps rather than 9, tract
  builds 5 rather than 6.

# ggseg.extra 1.9.9.9042

- The `regheader` deprecation test no longer passes or fails according to what
  ran before it (#178). It asserted a warning, and lifecycle throttles an
  *indirect* deprecation warning -- one raised from inside the package rather
  than by the caller -- to once per session, which
  `lifecycle_verbosity = "warning"` does not lift. The direct call in the
  `registration_from_regheader()` tests above spent that one warning, so the
  test passed in the full suite and failed whenever
  `test-atlas_wholebrain.R` was run on its own, which is exactly when someone
  is iterating on that file. It now asserts the deprecation *error*, which
  carries no such budget.

# ggseg.extra 1.9.9.9041

- The atlas manipulation verbs are re-exported, so `library(ggseg.extra)` is
  enough to build an atlas (#186). `atlas_region_remove()`,
  `atlas_region_op()`, `atlas_view_gather()` and the rest belong to
  ggseg.formats, because they belong to the atlas format rather than to any
  one builder, but every build needs both packages. Across the atlas
  repositories 18 of them are already in use over 149 call sites, 26 of those
  written as `ggseg.formats::` -- authors reaching past a wall that did not
  need to be there.

  Only the `atlas_*` verbs come across. ggseg.formats also ships atlases named
  `dk`, `aseg`, `tracula` and `suit`, and so does ggseg; attaching the whole
  namespace would mask one set with the other depending on load order, which
  is a silently wrong atlas rather than an error.

  Twenty-four of the twenty-eight. `atlas_centerlines()`,
  `atlas_plot_palette()`, `atlas_structure_reorder()` and
  `atlas_view_select()` exist only in ggseg.formats' development build, so
  re-exporting them would stop this package building against the release its
  DESCRIPTION asks for. They follow when ggseg.formats releases them.

- New `context_pattern()` is the label pattern matching an atlas's brain
  silhouette, in one place instead of retyped into every build. Anchored and
  case-sensitive on purpose: a loose `"cortex"` also catches
  `Cerebellar_Cortex_*` and `Left-Cerebral-Cortex`, which are structures
  rather than the silhouette.

# ggseg.extra 1.9.9.9040

- New `atlas_polish()` simplifies and smooths in one call against a stated
  vertex budget (#186). Rounding a corner *adds* vertices, so the two fight:
  smoothing after simplifying undoes some of the reduction, and simplifying
  after smoothing replaces the new curves with straight chords and puts the
  staircase back. Which order to use was left to each caller to work out, and
  they disagreed -- ggseg.extra#155 advises simplify-then-smooth, while
  `ggsegBrainnetome`'s build script documents the opposite. `atlas_polish()`
  owns the order so a build does not have to rediscover it.

  `keep` is a dial rather than a promise, and its help says so with measured
  figures: a ring is never taken below the handful of vertices that holds its
  shape, so `keep = 0.05` on a tract atlas comes back nearer 0.27. Most of
  that gap is `atlas_simplify()`'s own floor, which misses the same target the
  same way; its help now says that too.

- `atlas_smooth()` gains `vertex_budget`. It has always simplified the
  rounding back to roughly the vertex count it started with -- without that,
  smoothing a simplified atlas can leave it larger than the raw one it came
  from -- but there was no argument for it and no mention of how it was done.
  `"preserve"` is that existing behaviour, now named; `"free"` rounds and
  stops there. Nothing changes for existing calls.

# ggseg.extra 1.9.9.9039

- Groundwork for tracing contours without the PNG round-trip (#139). No
  behaviour change: the cerebellar pipeline's way of reading a projection
  matrix into a raster is now a named `projection_raster()` rather than an
  idiom inlined in one function, so the subcortical and tract pipelines have
  something to move onto.

  The round-trip it will replace renders a projection onto a fixed 400x400
  canvas, so the anatomy arrives letterboxed, rescaled and quantised -- a
  region whose true width:height is 2 comes back as 1.985, in canvas pixels
  rather than voxels. Reading the matrix directly is exact. The gain is that
  fidelity rather than orientation: a PNG carries no coordinates, but the
  mask reader has pinned which way y runs since 1.9.9.9018, so nothing is
  upside down today. What changes is that the convention is now stated in one
  place both raster paths read, instead of separately in each.

# ggseg.extra 1.9.9.9038

- `registration` means one thing across the package. It was an argument in
  three exported functions with incompatible vocabularies, and
  `registration = NULL` silently meant "apply the MNI152 transform" in
  `prepare_subcortical_mni152()` and "trust the header" in
  `project_volume_anatomical()` -- opposite instructions under one spelling.

  All three now take `"mni152"`, `"header"`, or a path to a register.dat or
  LTA file, resolved by one function rather than three. Defaults keep each
  function's existing behaviour: `"mni152"` for
  `prepare_subcortical_mni152()`, `"header"` for
  `project_volume_anatomical()`. `NULL` still works and warns, naming the
  word that caller meant by it, so existing code keeps running while it moves
  over.

  `prepare_subcortical_mni152()` gains `"header"` and
  `project_volume_anatomical()` gains `"mni152"` as a side effect of sharing
  the vocabulary. No geometry changes and no atlas needs rebuilding.

# ggseg.extra 1.9.9.9037

- `create_wholebrain_from_volume()` gains `cerebellar_space`, and
  `cerebellar_labels` now produces a flatmap that matches its volume. Step 5
  samples onto the bundled SUIT surfaces, but the whole-brain path handed the
  cerebellar labels straight to `create_cerebellar_from_volume()` without
  transforming them, so an MNI volume was drawn onto a flatmap it did not
  correspond to -- something that looks like an atlas and is not one. Every
  caller that wanted a cerebellar atlas out of a whole-brain build had to
  know to bypass the argument that exists for exactly that purpose, run
  `steps = 1:4`, and call `transform_mni_to_suit()` by hand.

  `"MNI152NLin6AsymC"` or `"MNI152NLin2009cSymC"` now transform the volume
  with the matching `suit_deformation_field()` first. Nothing in a NIfTI
  header records which space a volume is in, and the two MNI templates need
  different deformation fields, so this cannot be detected and is not
  guessed. The default stays `"suit"`, taking the volume as already
  transformed, which is what the pipeline assumed before; a verbose run now
  says which space it is assuming rather than leaving it unsaid.

# ggseg.extra 1.9.9.9036

- `project_volume_anatomical()` no longer merges a parcel into a FreeSurfer
  structure without saying so. Parcels and context share one volume and one
  colour table, so a parcel id that equals a context id is indistinguishable
  from it afterwards: the table drops the context row and that structure's
  surviving voxels take the parcel's name and colour.
  `prepare_subcortical_mni152()` has aborted on this since 1.9.9.9018, but
  the projection path only checked the seven reserved cerebral white-matter
  and corpus-callosum ids, so with `protect_cortex = TRUE` a label of 800 or
  more at the default `id_offset = 200` landed on the protected cortical
  ribbon, and any id matching `aparc+aseg` at `id_offset = 0` collapsed, in
  silence.

  Both entry points now share one guard, and it is exact rather than
  conservative: only context that *survives* the merge can be mislabelled, so
  a context id the parcels overwrite completely is no longer reported as a
  collision. The old check could not tell the two apart and refused ids that
  were in fact safe.

  Whether a context id survives generally depends on argmax, threshold and
  cortex protection, so the full check has to wait for the merge. What
  `protect_cortex` shields does not depend on any of them, so those ids are
  checked before registration and fail there instead of minutes later. Both
  read one definition of what protection covers, and a test holds them to
  it, so the early check cannot drift into refusing an id that would have
  been safe.

# ggseg.extra 1.9.9.9035

- The grey brain outline behind a subcortical atlas no longer paints over its
  own structures in the sagittal panel. `arrange_contour_sf()` sorts the
  outline to the bottom layer by matching its label exactly against `cortex_`
  and `cortex`, but sagittal snapshots are named per hemisphere, so the
  outline arrives as `cortex_left` or `cortex_right`, missed the match and
  stayed last in the table. In `ggsegCraddock::adhd200_400_subcortical()` that
  is a blank grey silhouette with all twenty of its sagittal structures
  hidden behind it; every subcortical atlas built by this pipeline carries
  the same two labels. The match is now anchored rather than exact, which
  still cannot catch `Cerebellar_Cortex_*` and let cerebellum sort above the
  outline. Atlases need rebuilding to pick this up.

# ggseg.extra 1.9.9.9034

- `label_to_region()` is exported. It is the rule the pipelines use to fill an
  atlas's `region` column from its labels -- strip the hemisphere affix, turn
  brackets, hyphens, underscores and slashes into spaces, lower-case, squeeze
  whitespace -- and was internal as `clean_region_name()`. Build scripts need
  to reproduce it exactly: one that adds a `name` column keyed on `region` has
  to key on what the pipeline will actually derive, and re-implementing the
  rule by hand is how a key silently stops matching.

# ggseg.extra 1.9.9.9033

- New `lut_generate_colors()` builds a palette for a lookup table that ships
  names only, with every RGB channel `0 0 0 0`. Sent down a pipeline as-is
  such a table leaves the atlas without a palette, the plotting packages
  assign one, and the render comes back as large blocks of repeated hue.

  Colours are assigned per structure rather than per region, so a structure's
  two hemispheres share one the way FreeSurfer's own tables do. The
  hemisphere marker is read off with the same affix set the rest of the
  package pairs hemispheres by, so `Left-`, `rh_`, `L_`, `_right` and `-lh`
  all count, plus the `ctx-lh-` and `wm-rh-` prefixes FreeSurfer's cortical
  and white-matter tables use. A table written one way and read another
  silently ships two hues per structure and still renders, so this is one
  affix set rather than a second opinion about what a hemisphere looks
  like. Hues are spread evenly around the circle and stepped through
  three luminances, so neighbouring hues on a crowded wheel still separate.
  Rows with `idx = 0` are the background rather than a structure and are left
  as they are, which is what lets the output of `lut_classify_anatomy()` -
  where the background's `type` is `NA` - go straight in as `by = "type"`.

  `by` names a column whose groups are each coloured from the whole circle
  rather than from a slice of one shared circle. `by = "type"` is the
  whole-brain case: the cortical and subcortical rows become two atlases that
  are never plotted together, so a colour only has to be unique within an
  atlas.

  `grDevices::hcl()` clips out-of-gamut colours without saying so, which at a
  few hundred structures hands back two of them the identical colour. Two
  structures sharing a colour value reads as a rendering fault rather than a
  palette one, so it is an error instead, naming `chroma` and `luminance` as
  the way out - lower the chroma. Colours merely growing close is not an
  error: one chroma and three luminances hold only so many, and past roughly
  sixty structures that is the ramp's limit rather than a fault. The
  documentation says so.

- The post-processing vignette now covers polishing a context and a structure
  core separately. They are different problems: the `^cortex` context is a
  thin sulcal ribbon that exists to be a silhouette, the structures are solid
  nuclei. One undifferentiated pass smooths the ribbon's sulci shut and
  flattens it into a blob. The recipe is the context gently and with
  `method = "chaikin"`, which cuts corners without moving contour rings, and
  the core more firmly with the default `close`.

# ggseg.extra 1.9.9.9032

- The whole-brain cortical context only borrows FreeSurfer's `aseg` ribbon
  when the atlas's grid is fine enough to carry one. A ribbon is 2.5-3 mm
  thick; resampled onto a 4 mm grid it cannot keep a voxel across itself and
  the silhouette traced from it breaks into disconnected islands, which is
  less legible than the solid mantle it replaced. The pipeline now measures
  the resampled ribbon itself - the share of its voxels whose six face
  neighbours are all ribbon - and declines the substitution below 0.1, the
  value a 2.5 mm grid gives. Measured: Hammersmith and Julich (1 mm) 0.49,
  `Mcalt` (1.5 mm) 0.29, Craddock 200 and the ADHD-200 parcellations (4 mm)
  0.03. The 4 mm atlases keep their own cortical labels, as they did before
  the ribbon substitution existed.

- The cortical context now reports which silhouette it drew in every case,
  rather than only when it kept the atlas's own labels.


# ggseg.extra 1.9.9.9031

- The brain silhouette drawn behind a subcortical atlas is no longer built
  from the atlas's own parcels when their ids happen to land between 1000 and
  2999. `detect_cortex_labels()` read any label in that range as an
  `aparc+aseg` cortical parcellation, so a parcellation embedded in an aseg
  with its ids shifted into the 1000s had its parcels taken for left cortex
  and no right cortex at all, and the "brain outline" came out as a fragment
  of deep grey rather than the cortical ribbon. The plain-aseg cortex labels
  (3 and 42) now win whenever the volume carries both, which an `aparc+aseg`
  does not.

- New `lut_classify_anatomy()` fills in a lookup table's `type` column by
  reading where each label sits in FreeSurfer's `aparc+aseg`, rather than by
  matching label names. It is an authoring tool: run it once while building
  an atlas, commit the column it returns, and
  `create_wholebrain_from_volume()` reads the declaration instead of
  guessing. A declared classification is reviewable in a diff and
  reproducible without FreeSurfer; an inferred one is neither.

  `aparc+aseg` is resampled onto the volume's own grid with
  `mri_vol2vol --regheader --nearest`, and each label is judged on the share
  of the labelled grey matter it touches, ignoring white matter and the
  voxels `aparc+aseg` does not label. That normalisation is what makes the
  test independent of a label's size. On the Julich-Brain maps it gives 250
  cortical, 38 subcortical and 8 cerebellar labels, against the 119 / 135
  the vertex count produces for the same 294 parcels.

- Grey matter is defined as grey matter. The lateral, 3rd and 4th ventricles
  are CSF and are not deep grey, and cerebellar white matter is white matter,
  so neither counts towards the share. The cortical test is bounded to
  1000-2999 rather than being open-ended, so the white matter `wmparc` numbers
  from 3000 up cannot read as cortex.

- `create_wholebrain_from_volume()` now warns whenever it falls back to the
  vertex-count heuristic, naming how many labels it classified by size and
  pointing at `lut_classify_anatomy()`. The heuristic measures how much
  surface a label covers rather than where it sits, so a small cortical
  parcel and a deep structure look the same to it; on a fine parcellation it
  splits the atlas at the threshold rather than at the anatomy. It used to
  say so only under `verbose`.

- `write_lut()` writes the `type` column as a 7th field when the table has
  one, so a classification survives the round trip through `read_lut()`. The
  reader has always accepted the field.

- `min_vertices` is documented correctly. It was described as a count
  "across hemispheres", but the count is summed per label name, so a lookup
  table whose labels carry `_left` / `_right` suffixes only ever accumulates
  one hemisphere.

- The grey cortical silhouette `create_wholebrain_from_volume()` draws behind
  a subcortical atlas now has sulci and gyri when the parcellation it is built
  from cannot give it any. It came from the union of the atlas's own cortical
  labels, and a parcellation that covers both banks of every sulcus - the Julich
  maximum probability map holds 751,113 cortical voxels on the left alone - is a
  solid mantle in the volume, before any contour is traced or any polishing
  applied. The shape now comes from FreeSurfer's `aseg`, where sulcal CSF is
  unlabelled: it is resampled onto the atlas volume's own grid with
  `mri_vol2vol --regheader --nearest`, which goes through the two headers and
  invents no transform, and its cortical ribbon is written wherever no
  structure claims the voxel. This is where `ggsegHO`'s `ho_sub` silhouette
  has always come from.

  An atlas whose own cortical labels are already a ribbon keeps them, so a
  parcellation derived from a surface is untouched: another brain's ribbon
  would only replace sulci it already has. The two are told apart by how many
  voxels the cortical mask holds against the resampled ribbon in the same
  grid - the same anatomy measured the thin way. Measured: `MarsAtlas` 0.92,
  Miccai 1.33, Craddock 1.58, Mcalt 1.61, Julich 2.44, Hammersmith 2.23;
  anything from 1.5 up counts as solid.

  The parcels themselves are untouched; only the `cortex_` context changes.

  When no usable `aseg` is available - no FreeSurfer, no `aseg.mgz` for the
  subject, a failed resampling, or a ribbon that lands outside the volume
  because it is not in the space its header claims - the context falls back
  to the atlas's own cortical labels and says so.

- The grey context now fills the posterior fossa as well. Cortex alone stops
  at the tentorium, so a subcortical atlas that reaches below it - or one
  whose cerebellum has been split off into an atlas of its own, as
  `ggsegMcalt`'s has - was drawn against empty space where the cerebellum and
  brain stem should be. The `aseg` cerebellar cortex and brain stem are now
  written into the context alongside the cortical ribbon, for every
  whole-brain atlas, whether or not its cortical mantle needed replacing.

  Cerebellar white matter is deliberately left out. Filling it makes the
  cerebellum a solid lump that merges with the occipital lobe in sagittal
  views and reads as more subcortex; the cortex alone comes through as the
  foliated shell that makes it recognisable as cerebellum.

- Subcortical snapshot PNGs now carry a signature of what they were drawn
  from, and one whose signature does not match what the run would draw is
  redrawn rather than reused. A snapshot can go stale without the pipeline
  changing: `<view>_<label>.png` records which label and which slab, but not
  which *voxels* that label held, and both move underneath it -
  `reindex_reserved_subcort_idx()` can hand a structure a different index,
  and a rebuilt volume can hand an index different voxels. An atlas cache
  predating the reindexing reused `axial_1_Pallidum_l.png` drawn when 42
  meant Pallidum and now means the right cortical hemisphere, and rendered a
  nucleus as a solid hemisphere. The signature hashes the structure's voxels,
  the slab framing them, the volume's dimensions and the cache format
  version, so that class of bug cannot recur. The processed and mask copies
  made from a redrawn snapshot are dropped with it.

- The cache format version is now 2, because the intermediates the previous
  one cached are wrong rather than merely old: the context volume changed,
  and with it the cortex slice each view is taken at. Cached steps written by
  an earlier ggseg.extra are recomputed. Every whole-brain atlas has to be
  rebuilt to pick up the sulci; the bump and the snapshot signatures together
  are what make `skip_existing = TRUE` rebuild them rather than keep the old
  pictures.

- The subcortical pipeline no longer traces images left behind by a run with a
  different slab configuration. Snapshots, processed images and masks are read
  back whole - contour extraction traces every mask it finds - so a PNG named
  for a slab this run does not have was assembled into the atlas as a row with
  no view and no geometry, and `st_coordinates()` then failed at
  `atlas_view_gather()` with "number of columns of matrices must match". Any
  image this configuration cannot name is now cleared once the slabs are
  known, whether they were computed or loaded from cache.


# ggseg.extra 1.9.9.9030

- The subcortical and tract pipelines now abort when a contour file matches
  none of the views the atlas is being built from, naming the unmatched files
  and the views it knows about. Contours are read from the output directory
  rather than from the slab table, so rebuilding into a directory left over
  from a different slab layout silently carried the old contours into the
  atlas with no view; that failed much later, inside the view packing, with an
  error that said nothing about stale files.

- CI can now run the FreeSurfer-gated tests. A slim image
  (`ghcr.io/ggsegverse/freesurfer-slim`) carries the ten FreeSurfer binaries
  the package shells out to plus the fsaverage5 subject, and a container job
  runs the suite on it, failing if any FreeSurfer test skipped. New end-to-end
  tests build cortical, subcortical, and wholebrain atlases from the shipped
  fsaverage5 data.
- `create_wholebrain_from_volume()` now drops colour table entries the volume
  never carries before classifying labels. With the full FreeSurferColorLUT
  every entry that never projected, over a thousand of them, was
  reported as subcortical whether or not a single voxel held it.
- Reading a tessellated surface without `mris_convert` on the path now aborts
  with a pointer to the missing binary. The fallback reader cannot parse the
  QUAD surfaces `mri_tessellate` writes and used to hand back a mesh whose
  faces pointed at vertices that did not exist.


# ggseg.extra 1.9.9.9029

- `atlas_smooth()` no longer multiplies an atlas's vertex count. Rounding a
  corner replaces it with an arc, and the default morphological close lays
  down eight segments per quarter turn, so smoothing grew the geometry
  several times over and silently undid any `atlas_simplify()` that ran
  before it: on ggsegHO's `ho2_cort`, simplifying to 9812 vertices and then
  smoothing came back at 35682, larger than the 30878 it started from. The
  arcs are now taken back down to the two or three segments that read the
  same at plotting size, and the same pair of calls comes back at 13784.
  Geometry already as sparse as its shapes allow, such as a raw voxel
  tracing, keeps a little of the growth: simplification will not take a ring
  below the vertices it needs to stay itself.

- `atlas_smooth()` and `atlas_simplify()` no longer open gaps between
  neighbouring regions. Both reshape each region on its own, so a boundary
  shared with the region next door moved the other way for the neighbour and
  a hairline sliver opened along every shared edge; on ggsegHO's `ho2_cort`
  a single `atlas_smooth()` opened 111 of them in the lateral view alone.
  Each function now finds the holes it punched in ground the regions used to
  cover and hands them back, taking that view to none. Space that was
  already open between separate structures is anatomy and stays open, as
  does a shaving along the outside of the coverage. Pass
  `close_gaps = FALSE` for geometry that is not a coverage.

  On geometry straight out of a pipeline, whose neighbours share their
  boundary vertex for vertex, `atlas_simplify()` opens no gaps and the
  repair does nothing. It earns its keep on geometry reshaped since, such as
  an atlas already rounded off or one traced region by region from separate
  masks.

- `atlas_simplify()` no longer reshuffles the rows of a multi-view atlas.
  Row order is draw order, so a plain `atlas_simplify(atlas, keep = )` could
  paint a structure underneath the region it belongs on top of, and left
  each view's rows grouped in whatever order the views were simplified in.

# ggseg.extra 1.9.9.9028

- The default subcortical projection slabs are now framed on the bounding box
  of the atlas's own labels instead of slice indices calibrated on a 256^3
  1 mm conformed volume and rescaled by `dims[1] / 256`. A dimension ratio
  carries neither voxel size nor origin, and the x dimension was used to scale
  y and z, so on a 4 mm atlas volume the axial band sat about 30 mm too
  superior — above the subcortex entirely, so the only thing a panel could
  contain was a misclassified cortical parcel — and on 1.5 mm volumes the
  inferior 40 mm of the atlas, cerebellum and brainstem included, was never
  cut. The default is now three coronal and three axial slabs tiling the label
  bounding box plus one sagittal slab, and it guarantees that no panel is
  empty and no structure is missing from every view. Builds that pass `slabs`
  explicitly are unaffected.
- The default sagittal slab is clipped to the left of the midline rather than
  spanning the whole head, so left structures are no longer drawn underneath
  their right twins, and it is named `sagittal_left` so the panel is flipped
  to face the same way as the other views.

# ggseg.extra 1.9.9.9027

- `create_wholebrain_from_volume()` no longer fuses a subcortical structure
  with a whole hemisphere of cortex. The subcortical volume carries the
  cortical hemispheres alongside the structures, under the FreeSurfer cortex
  indices (3, 42) plus the cerebellum and brainstem indices the brain outline
  is extended with (7, 8, 16, 46, 47). Any atlas whose own LUT used one of
  those values for a real structure had that structure absorb the silhouette,
  so the cortex outline appeared as a labelled `core` region instead of grey
  context. Colliding labels are now moved onto free index values before the
  volume and LUT are written; labels, regions and palettes are unchanged.
  **Affected atlases must be rebuilt**: each of Julich, Hammersmith, Mcalt
  and Craddock has one structure carrying the silhouette.

# ggseg.extra 1.9.9.9026

- `registration = "mni152"` now refuses a volume stored in right-handed (RAS)
  voxel order instead of silently mirroring it. `mni152.register.dat` is a
  tkregister matrix tied to the left-handed (LAS) MNI152 grid, and tkreg
  coordinates come from the volume's own voxel order, so applying it across a
  change of handedness swaps left and right in the finished atlas — which
  still looks like a plausible brain. Volumes stored LAS, which is the usual
  MNI152 layout, are unaffected. Use `registration = "header"` or resample to
  the LAS grid for a right-handed volume.

# ggseg.extra 1.9.9.9025

- `create_wholebrain_from_volume()` now registers MNI152 volumes to the
  surface subject instead of assuming the two spaces coincide. The new
  `registration` argument replaces `regheader` and defaults to `"mni152"`,
  which applies FreeSurfer's `average/mni152.register.dat`; the old default
  passed `--regheader`, equating FSL/SPM MNI152 scanner RAS with the MNI305
  space `fsaverage` lives in and omitting the transform between them.
  **This changes cortical atlas geometry**: the point each `fsaverage5`
  vertex samples moves by a median of 1.96 mm (1.18-2.60 mm), anteriorly
  and superiorly, and on a Neuromorphometrics volume 18.2% (lh) and 20.6%
  (rh) of vertices come back with a different label, so cortical atlases
  built from MNI152 volumes with earlier versions must be rebuilt. Pass
  `registration = "header"` for volumes already in the target subject's own
  scanner RAS, or a path to a register.dat or LTA file for your own
  transform. Since no header identifies the space of an arbitrary volume,
  `"mni152"` warns when the volume sits on the target subject's exact voxel
  grid and errors when `subject` does not share `fsaverage`'s geometry.
- `regheader` is deprecated in `create_wholebrain_from_volume()`. `TRUE`
  maps to `registration = "header"` and `FALSE` to `registration =
  "mni152"`; supplying both is an error.
- Registered surface projections no longer come back as fractional values.
  The old `regheader = FALSE` escape hatch passed `--mni152reg` without
  `--srcsubject`, so `mri_vol2surf` sampled onto `fsaverage` and then used
  nearest-neighbour surf2surf averaging to reach the target subject,
  turning 63 distinct integer values into 1977 fractional ones. Every
  registered projection now passes `--srcsubject`, so no resampling
  happens. `read_neuromaps_volume()` had the same defect and was silently
  smoothing continuous maps.

# ggseg.extra 1.9.9.9024

- Cached pipeline intermediates now record the cache format version that
  wrote them, in a `cache_manifest.rds` sidecar in the step directory.
  Rebuilding an atlas after a pipeline fix no longer silently reuses output
  the old pipeline made: a cache written by an older ggseg.extra is
  recomputed when its step is among the requested `steps`, and stops the
  pipeline with the step to rerun when it is not. Stamped: the step caches,
  the contour files, and the processed-image and mask directories. Still
  reused whenever the file exists: the snapshot images, the subcortical mesh
  directory, and the lookup table and volume the wholebrain pipeline passes
  to the subcortical one, so a fix to any of those still needs its cache
  cleared by hand.

# ggseg.extra 1.9.9.9023

- Subcortical and tract atlases built with terra 1.9-46 came out upside down
  in their 2D views: coronal and sagittal slices had the brain stem pointing
  up and the cerebellum above the basal ganglia, and axial slices were
  mirrored front to back. Contour extraction read the snapshot masks with
  `terra::rast()`, which reads a PNG without map coordinates with y increasing
  upward, while `build_contour_sf()` still flipped the y-axis as if the
  coordinates were image rows. Masks are now decoded with ImageMagick into a
  raster with an explicit extent, so y always increases upward and nothing is
  flipped afterwards, whatever the terra version.
- Extracted contours now record that their y-axis points up. Cached
  `contours.rda`, `contours_smoothed.rda` and `contours_reduced.rda` from
  earlier versions stop the atlas assembly step with an error instead of
  drawing the atlas upside down; rerun the contour extraction steps to
  rebuild them. Snapshots and masks can be reused, including masks that carry
  an RGB colour profile on grey pixels.

# ggseg.extra 1.9.9.9022

- `create_wholebrain_from_volume()` no longer leaves white holes in the
  cortical atlas. Voxel ids missing from the lookup table, such as cerebral
  white matter, were projected onto the surface, and the vertices they won
  were then dropped without a region. The volume is now filtered to the
  lookup table before projection, as documented, and cortex vertices left
  without a listed label take the most common label of their neighbours
  wherever a labelled neighbour can be reached.
  Medial-wall vertices outside FreeSurfer's cortex label no longer keep
  whatever structure the projection hit there.

- Cortical atlases from every `create_cortical_from_*()` function and from
  `create_wholebrain_from_volume()` keep the `unknown` medial wall as grey
  context, the way `ggseg.formats::dk()` does: its outline is drawn behind
  the parcels, but it is no longer a region in `core`, the palette, or the
  3D vertices. Whole-brain atlases whose lookup table has a `type` column
  now get this medial wall too; it used to be dropped, leaving it white.
  Parcellations that name their medial wall (`FreeSurfer_Defined_Medial_Wall`,
  `medialwall`, `???`) are treated the same way, while parcels such as
  `medialorbitofrontal` stay regions.

# ggseg.extra 1.9.9.9020

- The bundled atlas-package template's README now renders the atlas with an
  evaluated `plot()` chunk, which ggseg.formats provides, instead of an
  unevaluated one that needed ggseg and theme tweaks. Mirrors
  ggsegverse/ggseg-atlas-template's README.

# ggseg.extra 1.9.9.9019

- The bundled atlas-package template imports only `is_ggseg_atlas()` from
  ggseg.formats instead of the whole package, so generated atlas packages
  pass the `goodpractice` check `no_import_package_as_a_whole`. Mirrors
  ggsegverse/ggseg-atlas-template#7.

# ggseg.extra 1.9.9.9018

- New `read_cifti_subcortical()` extracts the subcortical voxels of a CIFTI
  dense label file (such as fsLR 91k grayordinates) into a NIfTI label volume
  and colour table, ready for `prepare_subcortical_mni152()` or
  `create_subcortical_from_volume()` (#85). The volume carries the CIFTI
  voxel size in both qform and sform, so FreeSurfer places it correctly.

- `prepare_subcortical_mni152()` aborts when a parcel id is also an aseg id
  kept as context. The colour table used to drop that context id silently,
  so the aseg structure took the parcel's name and colour.

- ciftiTools is now required at `>= 0.17.4`, the first release whose
  `read_cifti()` reads every brain structure in the file by default.

- `read_cifti_annotation()` and `create_cortical_from_cifti()` work on real
  CIFTI files again. ciftiTools keeps label names as the row names of the label
  table rather than in a `Label` column, so every real `.dlabel.nii` failed
  with "arguments imply differing number of rows". The tests passed only
  because their mock label tables had that column.

- `read_cifti_annotation()` warns when a CIFTI file has labelled subcortical
  voxels, which the cortical pipeline ignores, instead of dropping them
  silently (#85).

- The `input_lut` documentation for `create_subcortical_from_volume()` and the
  atlas template now list the columns a data.frame LUT needs (`idx`, `label`,
  `R`, `G`, `B`, `A`); they said `region`.

# ggseg.extra 1.9.9.9017

- The README and CI now install freesurfer from `muschellij2/freesurfer`:
  the refactor it needed has been merged upstream, so the
  `drmowinckels/freesurfer@refactor` fork is no longer required (#72, #98).
  DESCRIPTION declares `Remotes: muschellij2/freesurfer`, so `pak` and
  `remotes` resolve the required version without extra steps.

- freesurfer is now required at `>= 1.8.1.902`. The CRAN release lacks
  `fs_sitrep()` and `fs_cmd(validate_inputs = )`, so an older install used to
  pass the installed-check and then fail mid-pipeline. Accepting the install
  prompt now installs from the ggsegverse r-universe instead of CRAN, whose
  release could never satisfy the check. `setup_sitrep()` reports an outdated
  freesurfer as missing and points at `muschellij2/freesurfer`.

# ggseg.extra 1.9.9.9016

## Post-creation geometry

Smoothing, dilation and vertex reduction are steps you apply to a finished
atlas, not settings baked into a build - retuning one should not cost a
rebuild.

- New `atlas_dilate()` grows or shrinks region geometry, the post-creation
  counterpart of the snapshot-stage dilation the pipelines applied. Dilate
  the structures and leave the context alone: a grey brain grown by even a
  little closes its sulci and flattens into a blob.

- `dilate` on the `create_*()` functions is deprecated in favour of
  `atlas_dilate()`. It is still honoured for now, so no atlas changes
  underfoot.

- `dilate`, `smoothness`, `tolerance` and `smooth_refinements` are no longer
  formals of the `create_*()` functions: they are caught in `...` instead, so
  they no longer appear in a signature or a help page while a call that still
  passes one keeps working and says so. Anything else in `...` is an error,
  as an unused argument always was. The notice for the smoothing arguments is
  the one they already had; only `dilate`'s is new.

- `atlas_smooth()` and `atlas_simplify()` now do one thing each.
  `atlas_smooth()` decides how round an outline is; `atlas_simplify()`
  decides how many vertices it costs. `keep` is gone from `atlas_smooth()`,
  and `atlas_simplify()` is no longer deprecated: it takes `labels` and
  `exclude` like the others.

  Having both in one function meant `atlas_smooth()` simplified to
  `keep = 0.05` unless told otherwise, so a call that asked only for
  smoothing quietly threw away 95% of the vertices - and a second call
  quietly threw away 95% of what the first left. That is how the bundled
  cortex silhouettes ended up as blobs. Run them in that order, too:
  simplifying a rounded outline replaces its curves with straight chords,
  putting the stair-step back.

- `aseg_context()` no longer leaves two brain silhouettes behind, and no
  longer punches a silhouette that does not need it.

  The white-matter punch writes its result to `cortex`, but
  `atlas_region_op()` only replaces rows already named that - so the operand
  it was derived from, which the pipelines call `cortex_`, survived and drew
  behind the ribbon as a second full-brain outline. One character apart,
  which is why it went unnoticed. The punch now consumes its operand.

  The punch is also skipped when the silhouette is already hollow. It exists
  to hollow out a solid outline; snapshot pipelines that trace the
  grey-matter ribbon hand over one that is already hollow, and differencing
  the white matter out of that removes about a quarter of the mantle,
  because the white matter abuts the ribbon rather than sitting inside it.
  Whole sections of outline went missing. Interior rings tell the two apart:
  a solid outline has none, a ribbon has hundreds.

  The silhouette is the largest label in a subcortical atlas, so this is
  also the biggest single thing in the file. Together with per-label
  simplification it takes the `ho_sub` atlas in ggsegHO from 89,657 vertices to
  34,103.
  Every atlas built through `aseg_context()` is affected, the bundled `aseg`
  included, and each needs rebuilding to benefit.

## Minor improvements and fixes

- Test `describe()` calls are namespace-qualified.
  `local_mocked_bindings(.package = "terra")` attaches terra, and terra
  exports a `describe()` of its own, which then masked `testthat`'s -
  turning
  later `describe()` blocks into GDAL calls on filenames that do not exist.
  The error aborted the file, so its remaining blocks never ran. Which files
  were hit depended on run order, which is why a helper-level pin did not
  hold; the call sites are qualified instead.

- The sagittal context slice is now the *thinnest* section of cortex in the
  slab, not the densest. Sagittal is the one view where picking the slice
  with the most cortex is actively wrong: area peaks at both tangential
  extremes - the medial wall by the midline, and the lateral surface - where
  the slice skims along the sheet and returns a solid blob. A true
  cross-section, the one that reads as a gyrified ribbon, is where the area
  is lowest. The ends of the slab are trimmed before the search so it cannot
  fall into the midline gap. Axial and coronal still take the densest slice,
  where the reasoning does not apply.

- The anatomical context silhouette is no longer dilated. `dilate` exists to
  keep small deep structures from vanishing, but it was applied to every
  snapshot in the directory, including the grey brain, where a two-pixel
  dilation closes the sulci and flattens the mantle. Structures are dilated
  as before. The exclusion is deliberately case-sensitive so a
  `Cerebellar_Cortex_*` parcel, which is a structure in its own right in some
  atlases, still gets dilated.

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

# ggseg.extra 1.9.9.9002

## Cortical pipeline: mesh projection

The cortical atlas pipeline now projects inflated mesh triangles directly to 2D
polygons via orthographic projection, replacing the screenshot-based contour
extraction that preceded it.

- **Much faster** — atlas creation completes in ~5 seconds instead of minutes.
- **Cleaner geometry** — no pixel staircase artifacts from rasterisation.
- **Fewer dependencies** — no FreeSurfer rendering, ImageMagick, or Chrome
  needed for 2D geometry. Reading `.annot` files needs the `freesurferformats`
  R package, not a FreeSurfer installation.
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

# ggseg.extra 1.9.9.9001

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
