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

The affixes recognised are `Left`/`Right`, `left`/`right`, `lh`/`rh` and
`L`/`R`, as a prefix or a suffix, separated by `-`, `_`, `.` or a space.
A label is never stripped to nothing, so a structure genuinely named
"left" keeps its name.

## Examples

``` r
label_to_region("Left-Thalamus")
#> [1] "thalamus"
label_to_region("Central_Lateral-Lateral_Posterior_Left")
#> [1] "central lateral lateral posterior"
label_to_region(c("Pu_Left", "SNc_PBP_VTA_Right"))
#> [1] "pu"          "snc pbp vta"
```
