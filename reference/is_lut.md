# Check if object is a LUT

Check if object is a LUT

## Usage

``` r
is_lut(x)
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
