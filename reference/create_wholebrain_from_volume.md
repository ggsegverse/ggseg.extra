# Create atlas from whole-brain volumetric parcellation

**\[experimental\]**

Build a brain atlas from a single volumetric parcellation (NIfTI/MGZ)
that contains both cortical and subcortical regions. Cortical regions
are projected onto the fsaverage5 surface via FreeSurfer's
`mri_vol2surf` and rendered as surface views, while subcortical regions
go through the mesh-based subcortical pipeline.

Requires FreeSurfer.

## Usage

``` r
create_wholebrain_from_volume(
  input_volume,
  verbose = get_verbose(),
  regheader = lifecycle::deprecated(),
  ...,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  labels = list(),
  projection_opts = list(),
  cortical_opts = list(),
  subcortical_opts = list(),
  cerebellar_opts = list(),
  steps = NULL,
  cleanup = NULL,
  skip_existing = NULL
)
```

## Arguments

- input_volume:

  Path to volumetric parcellation in MNI152 space (.mgz, .nii, .nii.gz).

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

- regheader:

  **\[deprecated\]** Use `projection_opts = list(registration = )`
  instead. `TRUE` maps to `"header"`, `FALSE` to `"mni152"`. Supplying
  both is an error.

- ...:

  **\[deprecated\]** The flat arguments that `labels`, `projection_opts`
  and `cerebellar_opts` replaced. Each is folded into the list that now
  holds it and raises a deprecation warning; supplying both the old
  argument and the list entry it maps to is an error rather than a
  precedence rule.

- input_lut:

  Path to FreeSurfer-style colour lookup table, or a data.frame with
  columns `idx`, `label`, `R`, `G`, `B`, `A`. An optional `type` column
  with values `"cortical"` or `"subcortical"` controls label
  classification (see **Label classification**). Voxel IDs not listed in
  the LUT are automatically zeroed out before surface projection (see
  **Volume pre-processing**). If NULL, generic names and no palette.

- atlas_name:

  Name for the atlas. If NULL, derived from the input filename.

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- labels:

  Named list routing labels to a sub-pipeline, overriding the lookup
  table's `type` column and the vertex-count heuristic. Entries:

  - `cortical`: label names to force as cortical.

  - `subcortical`: label names to force as subcortical.

  - `cerebellar`: label names to send through the cerebellar SUIT
    flatmap pipeline, using the bundled surfaces from
    [`suit_flatmap_path()`](https://ggsegverse.github.io/ggseg.extra/reference/suit_flatmap_path.md)
    and
    [`suit_3d_path()`](https://ggsegverse.github.io/ggseg.extra/reference/suit_3d_path.md).

  Unnamed or unknown entries error. Replaces the `cortical_labels`,
  `subcortical_labels` and `cerebellar_labels` arguments.

- projection_opts:

  Named list of volume-to-surface projection settings, with these
  entries and defaults:

  - `subject` (`"fsaverage5"`) and `registration` (`"header"`): the
    target surface subject and how the volume is aligned to it. Read
    **Registration** below before relying on the default.

  - `projfrac` (`0.5`) and `projfrac_range` (`c(0, 1, 0.1)`): how deep
    through the cortical ribbon to sample, passed on to `mri_vol2surf`.
    Set `projfrac_range` to `NULL` to sample the single depth `projfrac`
    instead.

  - `min_vertices` (`50`): how much surface a label needs before the
    vertex-count heuristic calls it cortical. Only reached for labels
    that `labels` and a `type` column leave unclassified; see **Label
    classification**.

  Unknown entries error. Replaces the flat `subject`, `registration`,
  `projfrac`, `projfrac_range` and `min_vertices` arguments.

- cortical_opts:

  Named list of extra arguments forwarded to the cortical sub-pipeline.
  Allowed entry: `views`. Unknown entries error. Leave empty to use
  defaults.

- subcortical_opts:

  Named list of extra arguments forwarded to
  [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md).
  Any argument of that function may be set here except those managed by
  the wholebrain pipeline (`input_volume`, `input_lut`, `atlas_name`,
  `output_dir`, `verbose`, `cleanup`, `skip_existing`). Use this to tune
  `vertex_size_limits`, `decimate`, `slabs`. The deprecated
  `dilate`/`tolerance`/`smoothness` entries trigger a lifecycle warning
  and are no longer applied.

- cerebellar_opts:

  Named list of extra arguments forwarded to
  [`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md).
  Any argument of that function may be set here except those managed by
  the wholebrain pipeline (`input_volume`, `input_lut`, `atlas_name`,
  `output_dir`, `verbose`, `cleanup`, `skip_existing`).

  One entry is not forwarded: `cerebellar_space` is consumed here, and
  names the space `input_volume`'s cerebellar labels are in. The flatmap
  they are drawn on is in SUIT space, so anything else is transformed
  with the matching
  [`suit_deformation_field()`](https://ggsegverse.github.io/ggseg.extra/reference/suit_deformation_field.md)
  first. Nothing in a NIfTI header records a volume's space, so `"suit"`
  is an assumption rather than a detection: set it if your volume is in
  an MNI space. See
  [`suit_deformation_field()`](https://ggsegverse.github.io/ggseg.extra/reference/suit_deformation_field.md)
  for the spaces available.

- steps:

  Which pipeline steps to run. Default NULL runs all steps. Steps are:

  - 1: Project volume onto surface

  - 2: Split labels into cortical/subcortical/cerebellar

  - 3: Run cortical pipeline

  - 4: Run subcortical pipeline

  - 5: Run cerebellar pipeline

  Use `steps = 1:2` to run projection and split only.

- cleanup:

  Remove intermediate files after atlas creation. If not specified, uses
  `options("ggseg.extra.cleanup")` or the `GGSEG_EXTRA_CLEANUP`
  environment variable. Default is TRUE.

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

## Value

A named list with elements `cortical`, `subcortical`, and `cerebellar`,
each a `ggseg_atlas` object (or NULL if no regions of that type exist).

## Label classification

The pipeline must know which labels are cortical (rendered on the
surface) and which are subcortical (rendered as 3D meshes / 2D slices).
Three mechanisms are available, applied in priority order:

1.  **Function arguments** (highest priority): `cortical_labels` and
    `subcortical_labels` override everything for the specified labels.

2.  **LUT `type` column**: If the colour lookup table has a `type`
    column with values `"cortical"` or `"subcortical"`, that
    classification is used for any labels not covered by the function
    arguments. This is the recommended approach for reproducible atlas
    creation.

3.  **Vertex-count heuristic** (fallback): Labels with at least
    `min_vertices` vertices on the surface projection are classified as
    cortical; the rest as subcortical. It measures how much surface a
    label covers rather than where the label sits, so a small cortical
    parcel and a deep structure look the same to it. It warns whenever
    it runs; treat that warning as a request to declare the labels
    instead.

[`lut_classify_anatomy()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_classify_anatomy.md)
writes the `type` column for a lookup table that has none, by reading
each label's position in FreeSurfer's `aparc+aseg`. Run it once while
authoring the atlas and commit the column it returns: a declared
classification is reviewable in a diff, where an inferred one is not.

## Volume pre-processing

Before surface projection, the volume is filtered so that only voxel IDs
listed in the LUT are kept; all other non-zero voxels are zeroed out.
This prevents unlisted structures (e.g. white matter, ventricle masks)
from bleeding onto the cortical surface during label dilation.

The subcortical pipeline also gets a brain-outline reference to draw as
grey context behind its structures, under FreeSurfer's cortex labels 3
(left) and 42 (right). By default that is the atlas's own cortical
voxels, split by hemisphere at the volume's midline: left-hemisphere
voxels map to label 3, right-hemisphere to label 42.

A parcellation that covers both banks of every sulcus makes a solid
mantle that way, and no amount of polishing can put sulci into a
silhouette that never had any. When the cortical labels hold more than
1.5 times the voxels of a cortical ribbon, the context is taken from
FreeSurfer's `aseg` instead, where sulcal CSF is unlabelled: its ribbon
is resampled onto this volume's own grid through the two headers
(`mri_vol2vol --regheader --nearest`) and written wherever no structure
claims the voxel. An atlas whose cortical labels are already a ribbon,
such as one derived from a surface, keeps its own.

A ribbon is 2.5-3 mm thick, so a volume sampled more coarsely than that
cannot hold one: the resampled ribbon breaks into islands and the
silhouette with it. The substitution is declined when the resampled
ribbon is not at least a voxel thick through most of itself, and the
atlas's own cortical labels are used, as they were before.

Either way, the `aseg` cerebellar cortex and brain stem are added to the
context, so the posterior fossa is not drawn as empty space behind an
atlas that reaches below the tentorium or one whose cerebellum lives in
a separate atlas. Cerebellar white matter is left out: without it the
cerebellum stays a foliated shell rather than a solid lump that merges
with the occipital lobe.

When no usable `aseg` is available - no FreeSurfer, no `aseg.mgz` for
the subject, a failed resampling, or a ribbon that does not land inside
this volume, which is what a volume in some other space looks like - the
midline split is used and the pipeline warns.

## Human oversight

This is the most complex pipeline in ggsegExtra and the one most likely
to need manual correction. Recommended workflow:

1.  Run `steps = 1:2` first to project the volume and classify labels.

2.  Inspect `result$cortical_labels` and `result$subcortical_labels`. If
    the automatic split is wrong, either add a `type` column to the LUT
    or use `cortical_labels` / `subcortical_labels` to override.

3.  Run the full pipeline once you are satisfied with the split.

4.  Visually inspect the resulting atlas with `ggseg()` / `ggseg3d()`.

The cortical surface projection uses FreeSurfer's cortex label
(`{hemi}.cortex.label`) to prevent label dilation into the medial wall.
This file ships with fsaverage5 and is always required. Cortex vertices
left without a listed label take the most common label of their
neighbours. Everything outside the cortex label becomes the `unknown`
medial wall, which the cortical atlas keeps as grey context geometry
rather than as a region.

## Registration

`fsaverage` lives in MNI305, so an MNI152 volume projected with
`"header"` samples roughly 2 mm off, uniformly, anteriorly and
inferiorly. Every atlas in the ggsegverse was built that way. For
reference maps meant for visualisation that error is usually acceptable,
which is why it remains the default.

`"mni152"` removes it, but only for volumes on the grid
`mni152.register.dat` was built for: 1 mm, left-handed (LAS). tkregister
coordinates are derived from the volume's own voxel order, size and
field of view, so the same matrix applied to a right-handed volume
mirrors left and right, and applied to an LAS volume of another
resolution mislocates regions (7.7% of vertices at 1.5 mm, about 28% at
4 mm, measured against the same volume resampled to 1 mm first). Both
mistakes produce an atlas that still looks anatomically plausible, so an
unsuitable grid is refused rather than warned about. To use `"mni152"`
with such a volume, resample it onto the 1 mm LAS MNI152 grid first.

No header identifies the space an arbitrary volume is in, so the
registration you name is applied to whatever you pass. A volume sitting
on the target subject's exact voxel grid warns, that being a claim a
header does support, but a volume in some other non-MNI152 space cannot
be detected.

`mni152.register.dat` targets the FSL/SPM MNI152 (NLin6) 1 mm template.
Volumes in other MNI152 variants, such as the NLin2009cAsym template
`ggsegJulich` uses, keep a sub-millimetre residual rather than the
roughly 2 mm the transform corrects. It is registered against
`fsaverage`, so `subject` must share fsaverage's conformed geometry,
which the `fsaverageN` subjects do; for any other subject, supply your
own register.dat or LTA file.

FreeSurfer's own `INFO` and `WARNING` lines about the registration are
only visible with `verbose = TRUE`.

## Examples

``` r
if (FALSE) { # \dontrun{
# --- Recommended: LUT with type column ---
lut <- data.frame(
  idx   = c(10, 11, 49, 50, 101:148),
  label = c("Left-Thalamus", "Left-Caudate",
            "Right-Thalamus", "Right-Caudate",
            paste0("cortical_region_", 1:48)),
  type  = c(rep("subcortical", 4), rep("cortical", 48)),
  R = sample(50:220, 52, TRUE),
  G = sample(50:220, 52, TRUE),
  B = sample(50:220, 52, TRUE),
  A = 255L
)

result <- create_wholebrain_from_volume(
  input_volume = "my_atlas.nii.gz",
  input_lut = lut,
  atlas_name = "my_atlas",
  subcortical_opts = list(vertex_size_limits = c(3e6, 3e7))
)
result$cortical   # surface-based cortical atlas
result$subcortical # mesh-based subcortical atlas

# --- Without type column: automatic classification ---
result <- create_wholebrain_from_volume(
  input_volume = "atlas.nii.gz",
  input_lut = "atlas_LUT.txt",
  atlas_name = "auto_atlas"
)

# --- Inspect classification before full run ---
result <- create_wholebrain_from_volume(
  input_volume = "atlas.nii.gz",
  input_lut = "atlas_LUT.txt",
  steps = 1:2
)
result$cortical_labels
result$subcortical_labels

# --- Overriding classification and projection ---
# `labels` forces a label down a particular pipeline; `projection_opts`
# holds everything about getting the volume onto the surface.
result <- create_wholebrain_from_volume(
  input_volume = "atlas.nii.gz",
  input_lut = "atlas_LUT.txt",
  labels = list(
    cerebellar = c("Left-Cerebellum-Cortex", "Right-Cerebellum-Cortex")
  ),
  projection_opts = list(registration = "mni152", subject = "fsaverage6"),
  cerebellar_opts = list(cerebellar_space = "MNI152NLin6AsymC")
)
} # }
```
