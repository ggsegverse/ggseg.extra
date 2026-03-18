# Get verbose setting

Returns the verbosity level from option, environment variable, or
default. Checks in order: `ggseg.extra.verbose` option,
`GGSEG_EXTRA_VERBOSE` env var, then defaults to `1L`.

## Usage

``` r
get_verbose()
```

## Value

Integer `0L`, `1L`, or `2L`

## Details

Verbosity levels:

- `0` — Silent: no console output

- `1` — Standard (default): pipeline progress and step summaries

- `2` — Debug: includes FreeSurfer command output

Logical values are accepted for backward compatibility (`FALSE` = 0,
`TRUE` = 1).

## Examples

``` r
get_verbose()
#> [1] 1
options(ggseg.extra.verbose = 0)
get_verbose()
#> [1] 0
options(ggseg.extra.verbose = NULL)
```
