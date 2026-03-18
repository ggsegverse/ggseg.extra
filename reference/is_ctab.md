# Check if object is a color table

Check if object is a color table

## Usage

``` r
is_ctab(x)
```

## Arguments

- x:

  Object to check.

## Value

TRUE if x is a data.frame with the required color table columns.

## Examples

``` r
ct <- data.frame(
  idx = 0L, label = "Unknown",
  R = 0L, G = 0L, B = 0L, A = 0L
)
is_ctab(ct)
#> [1] TRUE
is_ctab(data.frame(x = 1))
#> [1] FALSE
```
