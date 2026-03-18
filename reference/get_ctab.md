# Read color table and add hex colours

Reads a FreeSurfer color lookup table and adds hex colour codes for use
in plotting.

## Usage

``` r
get_ctab(color_lut)
```

## Arguments

- color_lut:

  Path to a color table file, or a data.frame that passes
  [`is_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/is_ctab.md).

## Value

A data.frame with the original columns plus `roi` (zero-padded index)
and `color` (hex colour code).

## See also

[`read_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/read_ctab.md),
[`is_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/is_ctab.md)

## Examples

``` r
ct <- data.frame(
  idx = 0:1, label = c("Unknown", "Region1"),
  R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
)
get_ctab(ct)
#>   idx   label   R   G   B A  roi   color
#> 1   0 Unknown   0   0   0 0 0000 #000000
#> 2   1 Region1 205 130 176 0 0001 #CD82B0
```
