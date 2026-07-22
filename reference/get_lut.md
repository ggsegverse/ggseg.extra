# Read LUT and add hex colours

Reads a FreeSurfer color lookup table and adds hex colour codes for use
in plotting.

**\[deprecated\]**

`get_ctab()` was renamed to `get_lut()` for consistency with
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md),
[`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md),
[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md),
and
[`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md).

## Usage

``` r
get_lut(lut)

get_ctab(color_lut)
```

## Arguments

- lut:

  Path to a LUT file, or a data.frame that passes
  [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md).

- color_lut:

  Path to a LUT file, or a data.frame that passes
  [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md).

## Value

A data.frame with the original columns plus `roi` (zero-padded index)
and `color` (hex colour code).

## See also

[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)

## Examples

``` r
ct <- data.frame(
  idx = 0:1, label = c("Unknown", "Region1"),
  R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
)
get_lut(ct)
#>   idx   label   R   G   B A  roi   color
#> 1   0 Unknown   0   0   0 0 0000 #000000
#> 2   1 Region1 205 130 176 0 0001 #CD82B0
```
