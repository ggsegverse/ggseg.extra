# Write FreeSurfer color table

Write a color table to file in FreeSurfer format.

## Usage

``` r
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

[`read_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/read_ctab.md),
[`is_ctab()`](https://ggsegverse.github.io/ggseg.extra/reference/is_ctab.md)

## Examples

``` r
ct <- data.frame(
  idx = 0:1, label = c("Unknown", "Region1"),
  R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
)
out <- tempfile()
write_ctab(ct, out)
```
