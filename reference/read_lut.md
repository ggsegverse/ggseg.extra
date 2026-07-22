# Read FreeSurfer LUT

Read a FreeSurfer color lookup table file (e.g.,
`FreeSurferColorLUT.txt` or `ASegStatsLUT.txt`). These files map label
indices to region names and RGBA colours.

**\[deprecated\]**

`read_ctab()` was renamed to `read_lut()` for consistency with
[`get_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md),
[`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md),
[`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md),
[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md),
and
[`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md).

## Usage

``` r
read_lut(path)

read_ctab(path)
```

## Arguments

- path:

  Path to the LUT file.

## Value

A data.frame with columns: idx, label, R, G, B, A, and optionally type
when a 7th field is present.

## See also

[`get_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md)
to read and add hex colours,
[`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
to write,
[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md)
and
[`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md)
to build one up

## Examples

``` r
lut_file <- tempfile()
writeLines(c(
  "  0  Unknown                         0   0   0   0",
  "  1  Left-Cerebral-Cortex          205 130 176   0"
), lut_file)
read_lut(lut_file)
#>   idx                label   R   G   B A
#> 1   0              Unknown   0   0   0 0
#> 2   1 Left-Cerebral-Cortex 205 130 176 0
```
