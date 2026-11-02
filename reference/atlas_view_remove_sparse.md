# Drop the views a build left nearly empty

Slabs tile the bounding box of an atlas's labels, so a slab can land
where almost none of the structures are and come back holding a region
or two against a full anatomical backdrop. This drops those views,
counting what each one actually holds rather than naming the views to
remove.

## Usage

``` r
atlas_view_remove_sparse(atlas, min_regions = 5)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with 2D geometry.

- min_regions:

  Smallest number of drawn regions a view may hold and still be kept. A
  view with fewer is dropped.

## Value

The `ggseg_atlas`, in the representation it arrived in.

## Details

Count, do not name. A build script that names the views to drop goes
stale silently: rename a slab or lay the slabs out again and the pattern
matches nothing, the panel survives, and the only sign is a thin view in
the finished atlas. Counting degrades to dropping nothing instead.

Context does not count. A view showing nothing but the grey brain is the
case this exists to remove, so only labels that are drawn as regions are
counted; see
[`ggseg.formats::atlas_context()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_context.html).

Run this after the regions have been removed, not before. A slab full of
ventricles looks well populated to the builder and renders empty once
[`ggseg.formats::atlas_region_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
has taken the ventricles out. The pipeline already discards slabs that
no labelled voxel falls into, which is the same policy at a threshold of
zero, applied to the volume before anything is traced.

## See also

[`ggseg.formats::atlas_view_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
to drop views by name, and
[`ggseg.formats::atlas_view_remove_small()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
to drop slivers within a view rather than the view itself.

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
[`atlas_view_region_counts()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_view_region_counts.md),
[`count_vertices()`](https://ggsegverse.github.io/ggseg.extra/reference/count_vertices.md)

## Examples

``` r
aseg <- ggseg.formats::aseg()

# How many regions each view is carrying
atlas_view_region_counts(aseg)
#>   axial_3   axial_4   axial_5   axial_6 coronal_1 coronal_2  sagittal 
#>        23        26        27        15        22        22        15 

atlas_view_remove_sparse(aseg, min_regions = 5)
#> 
#> ── aseg ggseg atlas ────────────────────────────────────────────────────────────
#> Type: subcortical
#> Regions: 18
#> Hemispheres: left, NA, right
#> Views: axial_3, axial_4, axial_5, axial_6, coronal_1, coronal_2, sagittal
#> Palette: ✔
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (meshes)
#> ────────────────────────────────────────────────────────────────────────────────
#>    hemi            region                  label              display
#> 1  left cerebellum cortex Left-Cerebellum-Cortex    cerebellum cortex
#> 2  left          thalamus          Left-Thalamus             thalamus
#> 3  left           caudate           Left-Caudate              caudate
#> 4  left           putamen           Left-Putamen              putamen
#> 5  left          pallidum          Left-Pallidum             pallidum
#> 6  <NA>        brain stem             Brain-Stem           brain stem
#> 7  left       hippocampus       Left-Hippocampus          hippocampus
#> 8  left          amygdala          Left-Amygdala             amygdala
#> 9  left    accumbens area    Left-Accumbens-area            accumbens
#> 10 left         ventraldc         Left-VentralDC ventral diencephalon
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
