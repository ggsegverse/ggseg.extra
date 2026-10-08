# Tutorial: Creating a tract atlas

Tract atlases represent white matter pathways derived from diffusion MRI
tractography. Unlike cortical or subcortical atlases where regions are
contiguous surfaces, tracts are tube-like structures that follow
streamline bundles through the brain.

The pipeline reads tractography files, computes a centerline for each
tract, wraps it in a tube mesh, and (optionally) creates 2D projection
views.

This tutorial recreates the TRACULA atlas — the same pipeline behind
`data-raw/make_tracula_atlas.R` in ggseg.formats.

## What you need

- FreeSurfer installed with TRACULA training data (`trctrain/`)

``` r

library(ggseg.extra)
library(dplyr)
```

## Finding tractography files

TRACULA training data ships with FreeSurfer in the `trctrain/`
directory. Each `.trk` file contains streamlines for one tract:

``` r

fs_dir <- freesurfer::fs_dir()
tract_dir <- file.path(fs_dir, "trctrain", "hcp", "mgh_1017", "mni")

tract_files <- list.files(tract_dir, pattern = "\\.trk$", full.names = TRUE)
aseg_file <- file.path(tract_dir, "aparc+aseg.nii.gz")

length(tract_files)
#> [1] 42
```

The `aparc+aseg.nii.gz` provides cortex outlines for 2D projections. If
it’s missing, you can still create a 3D-only atlas.

## Creating the atlas

[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
reads each tractography file, computes a centerline, and generates a
tube mesh around it. The `input_aseg` provides cortex context for 2D
views:

``` r

tracula_raw <- create_tract_from_tractography(
  input_tracts = tract_files,
  input_aseg = aseg_file,
  atlas_name = "tracula"
)
#> Warning: Atlas has 58862 vertices (threshold: 10000)
#> ℹ Large atlases may be slow to plot and increase package size
#> ℹ Call `atlas_simplify(atlas, keep = 0.2)`, then `atlas_smooth(atlas)`, to tidy
#>   it and reduce vertices

tracula_raw
#> 
#> ── tracula ggseg atlas ─────────────────────────────────────────────────────────
#> Type: tract
#> Regions: 26
#> Hemispheres: midline, left, right
#> Views: axial_1, axial_2, axial_3, axial_4, axial_5, coronal_1, coronal_2,
#> coronal_3, coronal_4, coronal_5, coronal_6, sagittal_midline, sagittal_left,
#> sagittal_right
#> Palette: ✖
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (centerlines)
#> ────────────────────────────────────────────────────────────────────────────────
#>       hemi               region                label
#> 1  midline       acomm.bbr.prep       acomm.bbr.prep
#> 2  midline    cc.bodyc.bbr.prep    cc.bodyc.bbr.prep
#> 3  midline    cc.bodyp.bbr.prep    cc.bodyp.bbr.prep
#> 4  midline   cc.bodypf.bbr.prep   cc.bodypf.bbr.prep
#> 5  midline   cc.bodypm.bbr.prep   cc.bodypm.bbr.prep
#> 6  midline    cc.bodyt.bbr.prep    cc.bodyt.bbr.prep
#> 7  midline     cc.genu.bbr.prep     cc.genu.bbr.prep
#> 8  midline  cc.rostrum.bbr.prep  cc.rostrum.bbr.prep
#> 9  midline cc.splenium.bbr.prep cc.splenium.bbr.prep
#> 10    left          af.bbr.prep       lh.af.bbr.prep
#> ... with 32 more rows
```

``` r

plot(tracula_raw)
```

![All reconstructed tracts on every projection view the pipeline
produced, crowded and
overlapping.](figures/tutorial-tract-atlas-plot-raw-1.png)

Stage 1 — every tract on every view the pipeline made.

Key parameters, all passed together in `tube_opts`:

- **`tube_radius`** controls tube thickness. Larger values make tracts
  more visible at the cost of anatomical precision. It also takes
  `"density"`, to scale thickness by how many streamlines pass through
  each point.
- **`tube_segments`** controls the number of vertices around the tube
  circumference. Six gives hexagonal cross-sections; 12+ gives smoother
  tubes.
- **`n_points`** controls centerline resolution. More points capture
  finer curvature.

``` r

create_tract_from_tractography(
  input_tracts = tract_files,
  input_aseg = aseg_file,
  atlas_name = "tracula",
  tube_opts = list(tube_radius = 3, tube_segments = 12)
)
```

## Post-processing

### Selecting views

Keep the projections that show your tracts best:

``` r

tracula_raw <- tracula_raw |>
  atlas_view_keep(c(
    "axial_2",
    "axial_4",
    "coronal_3",
    "coronal_4",
    "sagittal"
  ))
```

``` r

plot(tracula_raw)
```

![The tracts on the seven retained projection views, two axial, two
coronal and three
sagittal.](figures/tutorial-tract-atlas-plot-views-1.png)

Stage 2 — down to the seven views that show the tracts; the `sagittal`
pattern keeps all three.

### Setting context regions

Add cortex as a background outline:

``` r

tracula_raw <- tracula_raw |>
  atlas_region_contextual("cortex", match_on = "label")
```

### Removing small fragments

After view selection, some tracts may appear as tiny slivers in certain
views. Remove fragments below a minimum area:

``` r

tracula_raw <- tracula_raw |>
  atlas_view_remove_small(
    min_area = 500,
    views = c("axial", "coronal")
  ) |>
  atlas_view_remove_small(min_area = 50)
#> ℹ Removed 98 geometries below area 500
#> ℹ Removed 12 geometries below area 50
```

``` r

plot(tracula_raw)
```

![The same views with the small cross-sectional fragments removed,
leaving the coherent tract
bodies.](figures/tutorial-tract-atlas-plot-despeckled-1.png)

Stage 3 — the specks are gone.

The specks were real geometry — a tract crossing an axial slab leaves a
dot where it passes through — but a dot carries no shape and reads as
noise, so dropping them costs nothing and quiets the figure
considerably.

The first call applies a higher threshold to axial and coronal views
(where tracts appear in cross-section and produce small dots). The
second call applies a lower threshold everywhere to catch remaining
slivers.

### Tidying the geometry

The tube outlines are still traced from mesh triangles, so every tract
edge is a staircase.
[`count_vertices()`](https://ggsegverse.github.io/ggseg.extra/reference/count_vertices.md)
gives the price, and says where it is being paid:

``` r

vertices <- count_vertices(tracula_raw)

sum(vertices)
#> [1] 26545
sum(vertices[grepl(context_pattern(), names(vertices))])
#> [1] 18673
```

Most of the atlas is the cortex silhouette rather than the tracts, which
is worth knowing before tuning anything: the `create_*()` functions warn
above ten thousand vertices, and on a tract atlas the context is usually
the reason.

Tidying is a separate post-processing step in two parts —
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
drops vertices,
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
rounds off what is left — and both are applied twice, because the
context and the tracts want different things. The silhouette is only
useful while its sulci survive, so it needs gentle settings; the tubes
can take firmer ones.

Simplify each separately:

``` r

tracula_raw <- tracula_raw |>
  atlas_simplify(keep = 0.5, labels = context_pattern) |>
  atlas_simplify(keep = 0.3, exclude = context_pattern)

sum(count_vertices(tracula_raw))
#> [1] 14927
```

Simplification is topology-aware, so neighbouring geometries lose the
same vertices and no gaps open between them. Keep an eye on the tracts
as you lower `keep`: a tube cross-section is a small ring to begin with,
and there is a point below which it stops reading as a tube and starts
reading as a polygon.

Then smooth each separately, and note the second argument:

``` r

tracula_raw <- tracula_raw |>
  atlas_smooth(
    smoothness = 0.35,
    labels = context_pattern,
    method = "chaikin"
  ) |>
  atlas_smooth(smoothness = 0.4, exclude = context_pattern)

sum(count_vertices(tracula_raw))
#> [1] 16191
```

``` r

plot(tracula_raw)
```

![The same seven views with the tracts drawn as smooth tapering bands
and a cortex silhouette that still shows its
sulci.](figures/tutorial-tract-atlas-plot-polished-1.png)

Stage 4 — simplified and smoothed. The tube edges are clean and the
silhouette still has its folds.

`method = "chaikin"` is not optional for the context. The default
`close` dilates and then erodes, which fills any hole narrower than the
smoothing distance — on a cortex silhouette those holes are the sulci,
so the default destroys exactly what the context is for. Chaikin’s
corner-cutting preserves rings instead.

Notice that the count went back up. Smoothing is not a reduction step:
chaikin subdivides each corner it cuts, and `close` resamples what it
traces. Simplify to set the budget, smooth to set the look, and read the
total after both rather than after either.

This atlas stays heavy even so — forty-two tracts across seven views,
each with its own silhouette, is a lot of geometry. If the total matters
more than the coverage, the levers are the same ones used above: fewer
views, or fewer tracts.

## Adding metadata

Join tract group information — which tracts are commissural, which are
projection fibres, which are association:

``` r

tracula_metadata <- data.frame(
  label = c(
    "lh.cst.bbr.prep", "rh.cst.bbr.prep",
    "lh.ilf.bbr.prep", "rh.ilf.bbr.prep",
    "lh.uf.bbr.prep", "rh.uf.bbr.prep",
    "lh.atr.bbr.prep", "rh.atr.bbr.prep",
    "acomm.bbr.prep",
    "cc.genu.bbr.prep", "cc.rostrum.bbr.prep", "cc.splenium.bbr.prep",
    "cc.bodyc.bbr.prep", "cc.bodyp.bbr.prep", "cc.bodypf.bbr.prep",
    "cc.bodypm.bbr.prep", "cc.bodyt.bbr.prep"
  ),
  region_pretty = c(
    "corticospinal tract", "corticospinal tract",
    "inferior longitudinal fasciculus", "inferior longitudinal fasciculus",
    "uncinate fasciculus", "uncinate fasciculus",
    "anterior thalamic radiation", "anterior thalamic radiation",
    "anterior commissure",
    "callosal genu", "callosal rostrum", "callosal splenium",
    "callosal body (central)", "callosal body (posterior)",
    "callosal body (prefrontal)", "callosal body (premotor)",
    "callosal body (temporal)"
  ),
  group = c(
    "projection", "projection",
    "association", "association",
    "association", "association",
    "projection", "projection",
    "commissural",
    "commissural", "commissural", "commissural",
    "commissural", "commissural", "commissural", "commissural",
    "commissural"
  )
)

core_with_meta <- tracula_raw$core |>
  left_join(tracula_metadata, by = "label") |>
  mutate(region = coalesce(region_pretty, region)) |>
  select(hemi, region, label, group)
```

## Rebuilding and saving

``` r

tracula <- ggseg_atlas(
  atlas = "tracula",
  type = "tract",
  palette = tracula_raw$palette,
  core = core_with_meta,
  data = tracula_raw$data
)

tracula
#> 
#> ── tracula ggseg atlas ─────────────────────────────────────────────────────────
#> Type: tract
#> Regions: 26
#> Hemispheres: midline, left, right
#> Views: axial_2, axial_4, coronal_3, coronal_4, sagittal_midline, sagittal_left,
#> sagittal_right
#> Palette: ✖
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (centerlines)
#> ────────────────────────────────────────────────────────────────────────────────
#>       hemi                     region                label       group
#> 1  midline        anterior commissure       acomm.bbr.prep commissural
#> 2  midline    callosal body (central)    cc.bodyc.bbr.prep commissural
#> 3  midline  callosal body (posterior)    cc.bodyp.bbr.prep commissural
#> 4  midline callosal body (prefrontal)   cc.bodypf.bbr.prep commissural
#> 5  midline   callosal body (premotor)   cc.bodypm.bbr.prep commissural
#> 6  midline   callosal body (temporal)    cc.bodyt.bbr.prep commissural
#> 7  midline              callosal genu     cc.genu.bbr.prep commissural
#> 8  midline           callosal rostrum  cc.rostrum.bbr.prep commissural
#> 9  midline          callosal splenium cc.splenium.bbr.prep commissural
#> 10    left                af.bbr.prep       lh.af.bbr.prep        <NA>
#> ... with 32 more rows
```

``` r

atlas_labels(tracula)
#>  [1] "acomm.bbr.prep"       "cc.bodyc.bbr.prep"    "cc.bodyp.bbr.prep"   
#>  [4] "cc.bodypf.bbr.prep"   "cc.bodypm.bbr.prep"   "cc.bodyt.bbr.prep"   
#>  [7] "cc.genu.bbr.prep"     "cc.rostrum.bbr.prep"  "cc.splenium.bbr.prep"
#> [10] "lh.af.bbr.prep"       "lh.ar.bbr.prep"       "lh.atr.bbr.prep"     
#> [13] "lh.cbd.bbr.prep"      "lh.cbv.bbr.prep"      "lh.cst.bbr.prep"     
#> [16] "lh.emc.bbr.prep"      "lh.fat.bbr.prep"      "lh.fx.bbr.prep"      
#> [19] "lh.ilf.bbr.prep"      "lh.mlf.bbr.prep"      "lh.or.bbr.prep"      
#> [22] "lh.slf1.bbr.prep"     "lh.slf2.bbr.prep"     "lh.slf3.bbr.prep"    
#> [25] "lh.uf.bbr.prep"       "mcp.bbr.prep"         "rh.af.bbr.prep"      
#> [28] "rh.ar.bbr.prep"       "rh.atr.bbr.prep"      "rh.cbd.bbr.prep"     
#> [31] "rh.cbv.bbr.prep"      "rh.cst.bbr.prep"      "rh.emc.bbr.prep"     
#> [34] "rh.fat.bbr.prep"      "rh.fx.bbr.prep"       "rh.ilf.bbr.prep"     
#> [37] "rh.mlf.bbr.prep"      "rh.or.bbr.prep"       "rh.slf1.bbr.prep"    
#> [40] "rh.slf2.bbr.prep"     "rh.slf3.bbr.prep"     "rh.uf.bbr.prep"

table(tracula$core$group, useNA = "ifany")
#> 
#> association commissural  projection        <NA> 
#>           4           9           4          25
```

The table above covers the tracts this training set names unambiguously;
the rest keep their raw labels and an `NA` group. Note the join key is
the label exactly as the pipeline wrote it, `.bbr.prep` and all — strip
the extension first and nothing matches, silently.

``` r

ggplot2::ggplot() +
  ggseg::geom_brain(atlas = tracula, ggplot2::aes(fill = region)) +
  ggplot2::scale_fill_viridis_d(na.value = "grey80") +
  ggplot2::theme_void()
```

![2D brain atlas plot showing white matter tracts including
corticospinal tract, uncinate fasciculus, and cingulum across axial,
coronal, and sagittal projection views, filled with a viridis colour
scale.](figures/tutorial-tract-atlas-plot-1.png)

Stage 5 — the finished atlas, drawn through ggplot2 with a viridis fill.

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) is the quick
look, using the atlas’s own palette.
[`geom_brain()`](https://ggsegverse.github.io/ggseg/reference/ggbrain.html)
is the route when you want to control the colours — map something to
`fill`, or a fill scale has nothing to colour and every region comes
back as `na.value`.
