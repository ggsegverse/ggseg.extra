# Add rows to a FreeSurfer LUT

Append custom label entries to a LUT (as read by
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)).
Scalar inputs are recycled to the length of `idx`. Useful for adding
custom subregion labels (e.g. hemisphere-prefixed or split structures)
before passing the table to
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md).

## Usage

``` r
lut_add(lut, idx, label, R, G, B, A = 0L)
```

## Arguments

- lut:

  A LUT data.frame (passes
  [`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)).

- idx:

  Integer label indices to add.

- label:

  Character region labels.

- R, G, B, A:

  Integer colour channels (0-255); `A` defaults to `0`.

## Value

`lut` with the new rows appended (a `type` column, if present, is filled
with `NA` for the new rows).

## See also

[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md),
[`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md)

## Examples

``` r
ct <- data.frame(
  idx = 0L, label = "Unknown", R = 0L, G = 0L, B = 0L, A = 0L
)
lut_add(ct, idx = 20001:20002,
        label = c("Left-Hippocampus-ant", "Left-Hippocampus-post"),
        R = c(220, 60), G = c(190, 140), B = c(30, 200))
#>     idx                 label   R   G   B A
#> 1     0               Unknown   0   0   0 0
#> 2 20001  Left-Hippocampus-ant 220 190  30 0
#> 3 20002 Left-Hippocampus-post  60 140 200 0
```
