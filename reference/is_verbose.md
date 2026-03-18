# Get verbosity level

Get verbosity level

## Usage

``` r
is_verbose(verbose = NULL)
```

## Arguments

- verbose:

  Optional explicit value. If NULL, reads from option/env via
  [`get_verbose()`](https://ggsegverse.github.io/ggseg.extra/reference/get_verbose.md).
  Accepts logical or integer (0/1/2).

## Value

Integer `0L`, `1L`, or `2L`

## Examples

``` r
is_verbose()
#> [1] 1
is_verbose(FALSE)
#> [1] 0
is_verbose(2)
#> [1] 2
```
