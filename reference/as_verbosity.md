# Coerce a value to a verbosity level

Converts logical, numeric, or character input to an integer verbosity
level: `0L` (silent), `1L` (standard), or `2L` (debug).

## Usage

``` r
as_verbosity(x)
```

## Arguments

- x:

  Value to coerce. Logical `FALSE` becomes `0L`, `TRUE` becomes `1L`. A
  number above 2 is capped at `2L`. Anything else - a negative number,
  an unrecognised string, `NA`, `NULL`, or a value that is not length
  1 - falls back to the default `1L`.

## Value

Integer `0L`, `1L`, or `2L`

## Examples

``` r
as_verbosity(FALSE)
#> [1] 0
as_verbosity(TRUE)
#> [1] 1
as_verbosity(2)
#> [1] 2
```
