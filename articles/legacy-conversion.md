# Converting legacy atlases

If you have atlases from older versions of ggseg or ggseg3d, this
vignette explains how to convert them to the current `ggseg_atlas`
format.

``` r

library(ggseg.formats)
library(ggseg)
library(ggseg3d)
```

## The old system

Previous versions used separate objects for 2D and 3D rendering:

- `ggseg_atlas` objects for 2D plots with
  [`ggseg()`](https://ggsegverse.github.io/ggseg/reference/ggseg.html)
- `ggseg3d_atlas` objects for 3D plots with
  [`ggseg3d()`](https://ggsegverse.github.io/ggseg3d/reference/ggseg3d.html)

Atlas packages exported pairs like `dk` and `dk_3d`, or `yeo7` and
`yeo7_3d`. You had to remember which object to use with which package.

## The current system

The current system uses a single `ggseg_atlas` object that works with
both packages. One atlas, both renderers.

## Converting old atlases

Use
[`convert_legacy_brain_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/convert_legacy_brain_atlas.html)
to convert old atlas objects:

### From a ggseg3d_atlas only

``` r

unified <- convert_legacy_brain_atlas(atlas_3d = old_atlas_3d)

ggseg3d(atlas = unified)
```

### From both 2D and 3D objects

``` r

unified <- convert_legacy_brain_atlas(
  atlas_2d = old_atlas,
  atlas_3d = old_atlas_3d
)

ggplot() + geom_brain(atlas = unified)

ggseg3d(atlas = unified)
```

### From a 2D ggseg_atlas only

``` r

unified <- convert_legacy_brain_atlas(atlas_2d = old_atlas)

ggplot() + geom_brain(atlas = unified)
```

This atlas works with ggseg but not ggseg3d (no 3D vertex data).

## Specifying atlas type

The function auto-detects atlas type from the structure. Override if
needed:

``` r

unified <- convert_legacy_brain_atlas(
  atlas_2d = old_atlas,
  atlas_3d = old_atlas_3d,
  atlas_name = "my_atlas",
  type = "cortical"
)
```

Valid types: “cortical”, “subcortical”, “tract”.

## Batch conversion

When converting many atlas packages, load the `.rda` files into isolated
environments to avoid name collisions:

``` r

env <- new.env()
load("data/my_atlas.rda", envir = env)
atlas_2d <- env[["my_atlas"]]

result <- convert_legacy_brain_atlas(atlas_2d = atlas_2d)

save(my_atlas = result, file = "data/my_atlas.rda", compress = "xz")
```

Always save with `compress = "xz"` for significant file size reduction.

## Post-conversion checklist

After converting, verify the result:

``` r

stopifnot(is_ggseg_atlas(result))

nrow(result$core)
length(result$palette)
```

Each converted atlas package needs these updates:

- **DESCRIPTION**: Add `ggseg.formats` to `Depends`, remove
  `ggseg`/`ggseg3d` from `Depends`
- **R/data.R**: Update roxygen2 docs to reference `ggseg_atlas` format
- **R/-package.R**: Add `@import ggseg.formats`
- **tests**: Use
  [`is_ggseg_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/is_ggseg_atlas.html)
  and
  [`geom_brain()`](https://ggsegverse.github.io/ggseg/reference/ggbrain.html)
  instead of legacy
  [`is_ggseg_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/is_ggseg_atlas.html)
  and
  [`ggseg()`](https://ggsegverse.github.io/ggseg/reference/ggseg.html)
- **R/sysdata.rda**: Delete. Palettes are embedded in the atlas object
  (`atlas$palette`), not stored separately in `brain_pals`

## Lessons learned from batch conversion

The ggseg ecosystem converted 19 atlas packages using this function. Key
findings:

### 3D data is not always preserved

Subcortical atlases that only had 3D mesh data (no 2D sf geometry) lose
their meshes during conversion. The converter cannot round-trip
standalone meshes back into the new format. These atlases need
recreation from source FreeSurfer files using
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md).

Cortical 3D atlases fare better — vertex indices can be inferred from
mesh coordinates — but the result is still approximate. Recreation
produces more accurate vertex mappings.

### Palette entries may not match core rows exactly

Some converted atlases have palette entries for labels absent from
`core` (e.g., `"lh_unknown"`, `"rh_???"`, or labels with special
characters). This is normal: the palette retains all labels from the
original annotation, while `core` only contains labels that have
geometry.
[`is_ggseg_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/is_ggseg_atlas.html)
emits an informational message but still validates.

### Labels with special characters lose sf coverage

Atlases like Brainnetome have labels containing slashes (e.g.,
`"A9/46d_L"`). These labels may exist in `core` but have no matching
polygon geometry, reducing sf coverage below 100%. This is a data issue
in the source atlas, not a conversion bug.

### Skip ggseg3d tests for atlases without 3D data

If a converted atlas has no vertices or meshes,
[`ggseg3d()`](https://ggsegverse.github.io/ggseg3d/reference/ggseg3d.html)
will error. Either omit the 3D test entirely or guard it:

``` r

it("renders with ggseg3d", {
  skip_if_not_installed("ggseg3d")
  skip_if(is.null(my_atlas$geometry$vertices), "No 3D data")
  p <- ggseg3d::ggseg3d(atlas = my_atlas)
  expect_s3_class(p, "htmlwidget")
})
```

## Troubleshooting

**No vertices inferred**: The mesh coordinates don’t align with the
brain surface. Check that `surface` matches what was used to create the
3D atlas.

**Wrong hemisphere assignment**: The function infers hemisphere from the
`hemi` column. If this is missing or wrong, set it manually after
conversion.

**Type detection fails**: Set `type` explicitly.

## When to recreate instead

Converting works for getting legacy atlases running with ggseg 2.0, but
recreating from source data produces better results. Use the creation
functions if you have access to the original neuroimaging files:

- [`create_cortical_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_annotation.md)
  — from FreeSurfer annotation files
- [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
  — from volumetric segmentation
- [`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
  — from tractography files
- [`create_cortical_from_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cortical_from_labels.md)
  — from individual label files

See the
[cortical](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-cortical-atlas.md),
[subcortical](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-subcortical-atlas.md),
[tract](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-tract-atlas.md),
and
[label-based](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-label-atlas.md)
atlas tutorials.
