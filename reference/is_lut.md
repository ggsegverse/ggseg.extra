# Check if object is a LUT

**\[deprecated\]**

`is_ctab()` was renamed to `is_lut()` for consistency with
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md),
[`get_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md),
[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md),
and
[`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md).

## Usage

``` r
is_lut(x)

is_ctab(x)
```

## Arguments

- x:

  Object to check.

## Value

TRUE if x is a data.frame with the required LUT columns.

## Examples

``` r
ct <- data.frame(
  idx = 0L, label = "Unknown",
  R = 0L, G = 0L, B = 0L, A = 0L
)
is_lut(ct)
#> [1] TRUE
is_lut(data.frame(x = 1))
#> [1] FALSE
```
