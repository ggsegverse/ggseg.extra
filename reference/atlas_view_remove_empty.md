# Drop the views that draw no region at all

A view holding nothing but the grey anatomical backdrop takes up room in
the layout and carries a title while showing none of the atlas. This
drops those views.

## Usage

``` r
atlas_view_remove_empty(atlas)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with 2D geometry.

## Value

The `ggseg_atlas`, in the representation it arrived in. An atlas with no
empty view is returned unchanged.

## Details

Empty is usually a consequence of editing rather than of the build: take
the ventricles out of an `aseg`, or prune small depictions, and a view
whose only content was those regions is left drawing nothing.

Takes the atlas once, on purpose.
[`ggseg.formats::atlas_views_empty()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_views_empty.html)
reports the same views without removing them, and pairing the two by
hand would mean naming the atlas twice — which reads as a pipe but is
not one, and in a longer pipeline measures the atlas *before* the
editing that emptied the view. Asking this verb instead means the atlas
it measures is always the atlas it changes.

This is the zero case of
[`atlas_view_remove_sparse()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_remove_sparse.md),
which drops views a build left *thin* against a threshold. Reach for
this one when the threshold is not a judgement call: a view drawing no
region is empty by definition, not by a choice of `min_regions`.

## See also

[`ggseg.formats::atlas_views_empty()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_views_empty.html)
to see which views these are without removing them, and
[`atlas_view_remove_sparse()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_remove_sparse.md)
for views that are thin rather than empty.

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
[`atlas_view_region_counts()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_region_counts.md),
[`atlas_view_remove_sparse()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_remove_sparse.md),
[`count_vertices()`](https://ggsegverse.github.io/ggseg.extra/reference/count_vertices.md)

## Examples

``` r
aseg <- ggseg.formats::aseg()

# Nothing to do: every aseg view draws something
ggseg.formats::atlas_views_empty(aseg)
#> character(0)
atlas_view_remove_empty(aseg)
#> 
#> ── aseg ggseg atlas ────────────────────────────────────────────────────────────
#> Type: subcortical
#> Regions: 18
#> Hemispheres: left, midline, right
#> Views: axial_2, coronal_2, sagittal_left
#> Palette: ✔
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (meshes)
#> ────────────────────────────────────────────────────────────────────────────────
#>       hemi            region                  label              display
#> 1     left cerebellum cortex Left-Cerebellum-Cortex    cerebellum cortex
#> 2     left          thalamus          Left-Thalamus             thalamus
#> 3     left           caudate           Left-Caudate              caudate
#> 4     left           putamen           Left-Putamen              putamen
#> 5     left          pallidum          Left-Pallidum             pallidum
#> 6  midline        brain stem             Brain-Stem           brain stem
#> 7     left       hippocampus       Left-Hippocampus          hippocampus
#> 8     left          amygdala          Left-Amygdala             amygdala
#> 9     left    accumbens area    Left-Accumbens-area            accumbens
#> 10    left         ventraldc         Left-VentralDC ventral diencephalon
#>        structure
#> 1     cerebellum
#> 2  basal ganglia
#> 3  basal ganglia
#> 4  basal ganglia
#> 5  basal ganglia
#> 6      brainstem
#> 7         limbic
#> 8         limbic
#> 9  basal ganglia
#> 10  diencephalon
#> ... with 19 more rows
```
