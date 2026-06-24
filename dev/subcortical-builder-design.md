# Design: easier subcortical atlas creation in ggseg.extra

Status: implemented (P0–P2); see "Decisions taken" below
Author: drafted with Claude, 2026-06-01
Motivating work: ggsegFreeSurfer `data-raw/make_{thalamus,hippoamyg,brainstem,hypothalamus,hcpa}.R`

## Decisions taken (during implementation)

- **`aseg_context_labels()` dropped.** Rather than ship a curated default
  context-label vector, `aseg_context()` treats _every_ non-focus label as
  context automatically and subtracts the focus set with exact, case-sensitive
  `^(…)$` matching. This resolves §4.1's open question (focus exclusion is
  automatic) and §8's "defaults as data vs functions" — there is no default
  list to expose, so no companion function is needed. `aseg_hidden_labels()`
  is still exported (the stripped-structure set genuinely is a curated list).
- **Orchestrator extension (§4.6) implemented.** `create_subcortical_from_volume()`
  accepts `views = list(labels = …, coronal = …, …)` (expanded via
  `subcortical_views()`) and `context = list(focus = …, …)` (applied via
  `aseg_context()` after the 2D build); both thread through
  `create_wholebrain_from_volume()`'s `subcortical_opts`.

## 1. Problem

Five subcortical atlases were built in ggsegFreeSurfer with near-identical
scripts. Each is ~300-400 lines, and roughly 100 of those lines are copied
verbatim between scripts. Worse, two non-obvious failure modes are baked into
every copy and must be re-discovered by anyone writing a sixth atlas:

- **Axis-frame mismatch.** View slabs are indexed into the volume, but
  `read_volume(reorient = TRUE)` (what `create_subcortical_from_volume()` uses
  internally) returns a _different_ axis order than `RNifti::readNifti()`.
  Computing a bounding box from the RNifti array points the coronal/axial slabs
  at the wrong slices. This silently dropped the brainstem's coronal views and
  broke the hypothalamus atlas entirely (every view came out empty) until
  diagnosed.
- **Case-insensitive context matching.** `atlas_region_contextual()` matches
  patterns case-insensitively, so a context pattern containing `"Thalamus"`
  also matches `hypothalamus` and demotes the focus regions to context. This
  produced a 0-region atlas until traced.

If the common 80% lived in ggseg.extra, both traps would be fixed once, and a
new atlas would be a ~30-line script instead of ~350.

## 2. Audit — shared vs varying

### Identical (or near-identical) across the scripts

| Block                                                                                                                                                                                                                                                                                         | ~Lines | Scripts                                      |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | -------------------------------------------- |
| Post-process cleanup: `atlas_region_op` cortex/WM punch → 9× `atlas_region_remove` (White-Matter, WM-hypointensities, -Ventricle, -Vent$, CSF, Cerebral-Cortex, choroid-plexus, vessel, CC\_) → `atlas_region_contextual` → drop empty views → `atlas_view_gather` → two-stage `atlas_smooth` | ~50    | 5/5                                          |
| `slab()` view-builder closure                                                                                                                                                                                                                                                                 | ~12    | 5/5                                          |
| bbox→views computed in the projection frame                                                                                                                                                                                                                                                   | ~10    | 5/5                                          |
| `parse_fs_lut()` + combined-LUT assembly                                                                                                                                                                                                                                                      | ~30    | thalamus, hippoamyg, hcpa                    |
| `fs()` `system2` wrapper + `mri_vol2vol` register + embed-in-aseg skeleton                                                                                                                                                                                                                    | ~40    | thalamus, hippoamyg, brainstem, hypothalamus |

### Genuinely per-atlas (the 20% that should stay in the script)

- Segmentation source (`segment_subregions`, the hypothalamus CNN, an aseg split)
- Label handling: hemi id offsets (hippoamyg `+30000/+40000`), A/P split (hcpa),
  or none (thalamus, brainstem)
- LUT: stock `FreeSurferColorLUT.txt` vs custom prefixed entries
- The **focus** label set and which neighbours remain as context
- View counts / orientations and per-atlas smoothing strength

## 3. Existing API to build on (do not duplicate)

ggseg.formats already provides the atomic ops:
`atlas_region_op`, `atlas_region_remove`, `atlas_region_keep`,
`atlas_region_contextual`, `atlas_context_remove`, `atlas_region_rename`,
`atlas_core_add`, `atlas_view_remove`, `atlas_view_keep`, `atlas_view_gather`,
`atlas_view_remove_small`, `atlas_view_remove_region`.

ggseg.extra provides: `create_subcortical_from_volume`, `atlas_smooth`,
`read_volume(file, reorient = TRUE)` (internal), `coregister_volume`,
`detect_hemi`/`clean_region_name` (internal).

The new helpers should be thin compositions of these, not reimplementations.

## 4. Proposed new API (modular)

Priorities: P0 = biggest duplication + correctness, P1 = useful, P2 = optional.

### 4.1 `aseg_context()` — P0

Collapses the ~50-line cleanup chain into one call.

```r
aseg_context(
  atlas,
  focus,                       # regex (or char vector) of labels to KEEP as coloured core
  match_on = "label",
  punch_white_matter = TRUE,   # atlas_region_op("^cortex" - "White-Matter$" -> "cortex")
  remove = aseg_hidden_labels(),   # default = the 9 patterns we strip everywhere
  context = aseg_context_labels(), # default = standard aseg neighbours -> grey context
  drop_empty_views = TRUE
)
```

Behaviour:

1. If `punch_white_matter`, run the cortex/WM difference into `cortex`.
2. Remove every pattern in `remove`.
3. Demote every `context` label to context, **excluding anything matching
   `focus`** (this is where the case-insensitivity bug gets handled centrally —
   the focus set is subtracted from the context set with explicit word-boundary
   logic, so `hypothalamus` can never be eaten by a `Thalamus` context entry).
4. If `drop_empty_views`, remove views with no `focus` polygon.

Exported companions returning the curated default vectors so users can tweak:
`aseg_hidden_labels()`, `aseg_context_labels()`.

Open question: should `focus` exclusion from `context` be automatic (recommended)
or require the user to keep the lists disjoint themselves?

### 4.2 `subcortical_views()` — P0 (also fixes the axis-frame trap)

```r
subcortical_views(
  volume,                      # path or array
  labels,                      # focus label ids/patterns defining the bbox
  coronal = 0, axial = 0, sagittal = 0,   # number of slabs per orientation
  reorient = TRUE,             # MUST match create_subcortical_from_volume()
  pad = 0
)  # -> data.frame(name, type, start, end) ready for create_subcortical_from_volume()
```

Behaviour: read the volume with the **same** `reorient` the builder uses, compute
the label bbox in that frame, and emit evenly-spaced slabs. Because it owns the
frame, the user never indexes the volume by hand and the RNifti-vs-read_volume
mismatch cannot happen. Encapsulates the per-script `slab()` closure.

### 4.3 LUT helpers — P1 (build on the existing reader)

ggseg.extra **already** has the FreeSurfer LUT reader — `read_ctab(path)`
(plus `get_ctab()` to add hex, `is_ctab()`, `write_ctab()`). The scripts'
hand-rolled `parse_fs_lut()` is a straight reimplementation and should just be
deleted in favour of `read_ctab()`. (A canonical reader arguably belongs in the
`freesurfer` package, but `read_ctab` exists and works today.)

What's genuinely missing are the _assembly_ helpers used when adding custom
entries (hippoamyg hemi-prefixed labels, hcpa A/P parts):

```r
lut_add(lut, idx, label, rgb)          # append rows to a ctab (recycling rgb); validates is_ctab
lut_combine(...)                       # rbind several ctabs into one, checking for idx clashes
```

These compose with `read_ctab()`:

```r
combined <- lut_combine(
  read_ctab(lut_file),
  lut_add(idx = 20001:20004, label = c("Left-Hippocampus-ant", ...), rgb = ...)
)
```

### 4.5 FreeSurfer prep helpers — P2 (separate tier)

These shell out to FreeSurfer, so they pull a system dependency into ggseg.extra
(Suggests + runtime check, not Imports). Keep them clearly optional or as a
documented recipe rather than core API.

```r
register_to_template(src_mgz, target_mgz, xfm, out, interp = "nearest")  # mri_vol2vol wrapper
embed_labels_in_aseg(aseg, sublabels, replace = NULL, hemi_offset = NULL) # stamp sub-seg into aseg
```

`embed_labels_in_aseg` covers the three observed cases via args: plain stamp
(brainstem, hypothalamus), hemi id remap (hippoamyg), and — with a `split=`
callback — the A/P split (hcpa).

### 4.6 Improve the existing orchestrator — P2 (not a new function)

There is already a high-level orchestrator: `create_wholebrain_from_volume()`,
which classifies a LUT into cortical/subcortical/cerebellar and dispatches to the
per-type `create_*_from_volume()` builders, returning a list of atlases. So the
work here is to **extend what exists**, not add a parallel
`create_subcortical_atlas()`.

Two extension points, both opt-in (defaults preserve current behaviour):

1. **`create_subcortical_from_volume()`** gains optional post-processing +
   view-from-labels arguments, so the common path needs no separate calls:
   - `views` already accepts a data.frame; also accept a spec it can pass to
     `subcortical_views()` internally (e.g. `views = list(focus = 801:810,
coronal = 3, axial = 2)`), removing the hand-rolled bbox/`slab()` code and
     the frame trap.
   - an optional `context = list(focus = ..., ...)` that runs `aseg_context()` on
     the result before returning. When `NULL` (default) nothing changes.
2. **`create_wholebrain_from_volume()`** threads those through its
   `subcortical_opts` (it already forwards opts to the subcortical builder), so
   the whole-brain path benefits for free.

This keeps one orchestrator, makes the helpers the implementation underneath, and
avoids a second entry point that would drift from the first. Build it only after
4.1-4.3 land and have been used to refactor the five scripts.

## 5. Correctness fixes to fold in

- **read_volume frame** — solved structurally by `subcortical_views()` owning the
  read. No user-facing change to `read_volume` needed, but document the reorient
  contract on `create_subcortical_from_volume`.
- **`atlas_region_contextual()` case sensitivity** — add an `ignore.case`
  argument (default keeps current behaviour to avoid breaking callers) and/or a
  `whole_word`/boundary option; document the `Thalamus`⊃`hypothalamus` footgun.
  Lives in ggseg.formats. `aseg_context()` sidesteps it regardless by subtracting
  `focus` from the context set.

## 6. Migration — what each script becomes

Illustrative (hypothalamus), prep unchanged, post-build collapses:

```r
hyp_raw <- create_subcortical_from_volume(
  input_volume = seg_file, input_lut = lut_file, atlas_name = "hypothalamus",
  views = subcortical_views(seg_file, labels = 801:810, coronal = 3, axial = 2),
  output_dir = data_raw, dilate = 3
)

hyp <- hyp_raw |>
  aseg_context(focus = "hypothalamus") |>
  atlas_region_rename("^[lr] ", "")
```

(The two-stage `atlas_smooth` body/cortex calls stay inline — they're short and
the strengths vary per atlas, so a wrapper wasn't worth it.) ~120 lines of
post-processing + view code → ~12. The FreeSurfer prep (register/embed) stays in
the script unless 4.5 is adopted.

## 7. Phasing

1. **Phase 1 (P0):** `aseg_context()`, `subcortical_views()`, `aseg_hidden_labels()`,
   `aseg_context_labels()`. Refactor all 5 ggsegFreeSurfer scripts to use them
   (also swap their `parse_fs_lut()` for `read_ctab()`); rebuild and diff the
   atlases (must be byte-identical or visibly equivalent).
2. **Phase 2 (P1):** `lut_add()` / `lut_combine()`; `ignore.case` on
   `atlas_region_contextual`.
3. **Phase 3 (P2):** FreeSurfer prep helpers and/or extending
   `create_subcortical_from_volume()` / `create_wholebrain_from_volume()` with the
   opt-in view/context args, only if demand is clear.

## 8. Open questions

- Are these subcortical-specific, or should `aseg_context`/`subcortical_views`
  generalise to cerebellar/wholebrain builders too (which already exist)?
- Defaults: hardcode the FreeSurfer aseg label sets, or make them data objects
  users can inspect/extend? (Leaning: exported functions returning the vectors.)
- `focus` spec: regex vs explicit label vector vs both via `match_on`.
- Do we want the FreeSurfer-dependent prep in ggseg.extra at all, or in a small
  companion (keeps ggseg.extra free of a FreeSurfer Suggests)?

## 9. Testing

- Unit: `subcortical_views()` bbox/slab math on a synthetic labelled array
  (incl. a reorient round-trip assertion); `aseg_context()` on a small synthetic
  atlas (focus retained as core, context demoted, hidden removed, focus never
  demoted even when its name is a superstring of a context entry).
- Integration: rebuild the five ggsegFreeSurfer atlases via the helpers and
  assert region counts / view sets / context-behind-core invariant match the
  current committed atlases.
