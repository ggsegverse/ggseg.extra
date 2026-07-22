# Standard FreeSurfer aseg labels stripped from a subcortical atlas

The default set of
[`ggseg.formats::atlas_region_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
patterns applied by
[`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md):
structures the FreeSurfer `aseg` carries but that a subcortical atlas
does not draw (white matter, ventricles, CSF, the cortical ribbon,
corpus callosum pieces, choroid plexus, vessels).

## Usage

``` r
aseg_hidden_labels()
```

## Value

A character vector of regex patterns (matched against labels).

## See also

[`aseg_context()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_context.md)

## Examples

``` r
aseg_hidden_labels()
#> [1] "White-Matter"       "WM-hypointensities" "-Ventricle"        
#> [4] "-Vent$"             "CSF"                "Cerebral-Cortex"   
#> [7] "choroid-plexus"     "vessel"             "CC_"               
```
