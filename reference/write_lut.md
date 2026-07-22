# Write FreeSurfer LUT

Write a LUT to file in FreeSurfer format.

**\[deprecated\]**

`write_ctab()` was renamed to `write_lut()` for consistency with
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`get_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md),
[`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md),
[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md),
and
[`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md).

## Usage

``` r
write_lut(x, path)

write_ctab(x, path)
```

## Arguments

- x:

  A data.frame with columns: idx, label, R, G, B, A.

- path:

  Path to write to.

## Value

Invisibly returns the lines written.

## See also

[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)

## Examples

``` r
ct <- data.frame(
  idx = 0:1, label = c("Unknown", "Region1"),
  R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
)
out <- tempfile()
write_lut(ct, out)
```
