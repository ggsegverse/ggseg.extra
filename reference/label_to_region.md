# Derive an atlas `region` from a label

The rule every atlas pipeline here uses to fill the `region` column:
strip the hemisphere affix, turn brackets, hyphens, underscores and
slashes into spaces, lower-case the result and squeeze runs of
whitespace.

## Usage

``` r
label_to_region(label_name, remove_hemi = TRUE, normalize = TRUE)
```

## Arguments

- label_name:

  Character vector of labels.

- remove_hemi:

  Strip hemisphere affixes (default `TRUE`).

- normalize:

  Lower-case and convert separators to spaces (default `TRUE`).

## Value

A character vector of region names.

## Details

Exported because atlas build scripts need to reproduce it exactly. A
script that adds a `name` column keyed on `region`, for instance, has to
key on what the pipeline will actually derive; re-implementing the rule
by hand is how a key silently stops matching (an underscore handled but
a hyphen not, and one region joins to `NA`).

The affixes stripped here must match the ones `detect_hemi()`
recognises. Where they disagree the hemisphere ends up in `region` as
well as `hemi`: `detect_hemi()` reads the `L_`/`R_` convention, so
`R_Fx` correctly gave hemi `"right"`, while this function left the
prefix in place and produced region `"r fx"`. Two hemispheres of one
structure then look like two different structures, since `region` is
what pairs them.

## Examples

``` r
label_to_region("Left-Thalamus")
#> [1] "thalamus"
label_to_region("Central_Lateral-Lateral_Posterior_Left")
#> [1] "central lateral lateral posterior"
label_to_region(c("Pu_Left", "SNc_PBP_VTA_Right"))
#> [1] "pu"          "snc pbp vta"
```
