# Combine FreeSurfer LUTs

Row-binds several LUTs (as read by
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
or built with
[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md))
into one, aligning columns (a `type` column present in only some tables
is filled with `NA`) and warning on duplicate label indices.

## Usage

``` r
lut_combine(...)
```

## Arguments

- ...:

  LUT data.frames, each passing
  [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md).
  `NULL` inputs are dropped.

## Value

A single combined LUT.

## See also

[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md)

## Examples

``` r
a <- data.frame(idx = 0L, label = "Unknown", R = 0L, G = 0L, B = 0L, A = 0L)
b <- data.frame(idx = 1L, label = "Region1", R = 5L, G = 5L, B = 5L, A = 0L)
lut_combine(a, b)
#>   idx   label R G B A
#> 1   0 Unknown 0 0 0 0
#> 2   1 Region1 5 5 5 0
```
