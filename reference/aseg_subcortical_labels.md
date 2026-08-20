# Lumped aseg subcortical structures a parcellation typically subdivides

The FreeSurfer `aseg` ids for the bilateral subcortical structures that
a finer subcortical parcellation replaces: thalamus, caudate, putamen,
pallidum, hippocampus, amygdala and nucleus accumbens (left and right).
Use as (or extend) the `replace_labels` argument of
[`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md)
— for example add `16L` (brain-stem) when a parcel covers it.

## Usage

``` r
aseg_subcortical_labels()
```

## Value

An integer vector of 14 `aseg` label ids.

## See also

[`prepare_subcortical_mni152()`](https://ggsegverse.github.io/ggseg.extra/reference/prepare_subcortical_mni152.md)

## Examples

``` r
aseg_subcortical_labels()
#>  [1] 10 49 11 50 12 51 13 52 17 53 18 54 26 58
c(aseg_subcortical_labels(), 16L) # add brain-stem
#>  [1] 10 49 11 50 12 51 13 52 17 53 18 54 26 58 16
```
