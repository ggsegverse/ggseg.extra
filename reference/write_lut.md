# Write FreeSurfer LUT

Write a LUT to file in FreeSurfer format.

## Usage

``` r
write_lut(x, path)
```

## Arguments

- x:

  A data.frame with columns: idx, label, R, G, B, A, and optionally
  type, hemi and context. Their values must be single words.

- path:

  Path to write to.

## Value

Invisibly returns the lines written.

## Details

The declared columns `type`, `hemi` and `context` are written after the
colours, so that
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
reads them back. FreeSurfer reads only the first six fields of a line
and skips comments, so the file stays a valid colour table for it.

A table with `type` alone gets it as a 7th field, left off rows that
have none. A table with `hemi` or `context` gets a comment line naming
the fields, and every row then carries each one, written as `NA` where
it declares nothing. Other columns are not written.

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
