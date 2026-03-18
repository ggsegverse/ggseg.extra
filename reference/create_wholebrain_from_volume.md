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
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  projfrac = 0.5,
  projfrac_range = c(0, 1, 0.1),
  subject = "fsaverage5",
  regheader = TRUE,
  min_vertices = 50L,
  cortical_labels = NULL,
  subcortical_labels = NULL,
  cortical_views = c("lateral", "medial", "superior", "inferior"),
  subcortical_views = NULL,
  decimate = 0.5,
  tolerance = NULL,
  smoothness = NULL,
  cleanup = NULL,
  verbose = get_verbose(),
  skip_existing = NULL,
  steps = NULL
)
```

## Arguments

- input_volume:

  Path to volumetric parcellation in MNI152 space (.mgz, .nii, .nii.gz).

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

- projfrac:

  Cortical depth fraction for projection (0 = white surface, 1 = pial
  surface). Only used when `projfrac_range` is NULL. Default 0.5.

- projfrac_range:

  Numeric vector `c(min, max, delta)` for multi-depth projection via
  `mri_vol2surf --projfrac-max`. Samples at multiple cortical depths and
  takes the maximum label value at each vertex, giving much better
  surface coverage than single-depth projection. Default `c(0, 1, 0.1)`.
  Set to NULL to use single-depth `projfrac` instead.

- subject:

  Target surface subject. Default "fsaverage5".

- regheader:

  If TRUE (default), assumes volume RAS coordinates match the subject
  space and uses `--regheader`. Works well for standard MNI152-space
  volumes. If FALSE, uses FreeSurfer's `--mni152reg` registration (may
  produce noisy results due to surf2surf resampling).

- min_vertices:

  Minimum total vertex count across hemispheres for a label to be
  classified as cortical by the vertex-count heuristic (see **Label
  classification**). Ignored when `type` column or explicit label
  vectors are provided. Default 50.

- cortical_labels:

  Character vector of label names to force as cortical. Highest
  priority; overrides LUT `type` and the vertex-count heuristic.

- subcortical_labels:

  Character vector of label names to force as subcortical. Highest
  priority; overrides LUT `type` and the vertex-count heuristic.

- cortical_views:

  Views for cortical sub-pipeline. Default
  `c("lateral", "medial", "superior", "inferior")`.

- subcortical_views:

  Views for subcortical sub-pipeline. Default NULL (auto-detected).

- decimate:

  Mesh decimation ratio for subcortical meshes (0-1). Default 0.5.

- tolerance:

  Simplification tolerance for 2D polygons. Higher values produce
  simpler shapes with fewer vertices (typical range: 0.1–2). Passed to
  [`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html).
  If not specified, uses `options("ggseg.extra.tolerance")` or the
  `GGSEG_EXTRA_TOLERANCE` environment variable. Default is 1.

- smoothness:

  Smoothing factor for 2D contours. Higher values produce smoother
  region boundaries (typical range: 3–15). Passed to
  [`smoothr::smooth()`](https://strimas.com/smoothr/reference/smooth.html).
  If not specified, uses `options("ggseg.extra.smoothness")` or the
  `GGSEG_EXTRA_SMOOTHNESS` environment variable. Default is 5.

- cleanup:

  Remove intermediate files after atlas creation. If not specified, uses
  `options("ggseg.extra.cleanup")` or the `GGSEG_EXTRA_CLEANUP`
  environment variable. Default is TRUE.

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

- skip_existing:

  Skip generating output files that already exist, allowing interrupted
  atlas creation to resume. If not specified, uses
  `options("ggseg.extra.skip_existing")` or the
  `GGSEG_EXTRA_SKIP_EXISTING` environment variable. Default is TRUE.

- steps:

  Which pipeline steps to run. Default NULL runs all steps. Steps are:

  - 1: Project volume onto surface

  - 2: Split labels into cortical/subcortical

  - 3: Run cortical pipeline

  - 4: Run subcortical pipeline

  Use `steps = 1:2` to run projection and split only.

## Value

A named list with elements `cortical` and `subcortical`, each a
`ggseg_atlas` object (or NULL if no regions of that type exist).

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
    cortical; the rest as subcortical.

## Volume pre-processing

Before surface projection, the volume is filtered so that only voxel IDs
listed in the LUT are kept; all other non-zero voxels are zeroed out.
This prevents unlisted structures (e.g. white matter, ventricle masks)
from bleeding onto the cortical surface during label dilation.

Cortical voxels are also used to generate the brain-outline reference
geometry for the subcortical pipeline. The volume's orientation matrix
(`xform`) is used to split cortical voxels by hemisphere:
left-hemisphere voxels map to FreeSurfer label 3 (left cortex) and
right-hemisphere to label 42 (right cortex).

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
This file ships with fsaverage5 and is always required.

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
  atlas_name = "my_atlas"
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
} # }
```
