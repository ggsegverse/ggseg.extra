# Write FreeSurfer LUT

Write a LUT to file in FreeSurfer format.

## Usage

``` r
write_lut(x, path)
```

## Arguments

- x:

  A data.frame with columns: idx, label, R, G, B, A, and optionally
  type, which is written as a 7th field so that
  [`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
  reads it back.

- path:

  Path to write to.

## Value

Invisibly returns the lines written.

## See also

[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md),
[`lut_classify_anatomy()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_classify_anatomy.md)
to fill in the type column

## Examples

``` r
ct <- data.frame(
  idx = 0:1, label = c("Unknown", "Region1"),
  R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
)
out <- tempfile()
write_lut(ct, out)
```
