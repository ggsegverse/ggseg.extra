# Read FreeSurfer color table

Read a FreeSurfer color lookup table file (e.g.,
`FreeSurferColorLUT.txt` or `ASegStatsLUT.txt`). These files map label
indices to region names and RGBA colours.

## Usage

``` r
read_ctab(path)
```

## Arguments

- path:

  Path to the color table file.

## Value

A data.frame with columns: idx, label, R, G, B, A.

## See also

[`get_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/get_ctab.md)
to read and add hex colours,
[`write_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/write_ctab.md)
to write

## Examples

``` r
ctab_file <- tempfile()
writeLines(c(
  "  0  Unknown                         0   0   0   0",
  "  1  Left-Cerebral-Cortex          205 130 176   0"
), ctab_file)
read_ctab(ctab_file)
#>   idx                label   R   G   B A
#> 1   0              Unknown   0   0   0 0
#> 2   1 Left-Cerebral-Cortex 205 130 176 0
```
