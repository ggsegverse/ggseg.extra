# Get verbose setting

Returns the verbosity level from option, environment variable, or
default. Checks in order: `ggseg.extra.verbose` option,
`GGSEG_EXTRA_VERBOSE` env var, then defaults to `1L`.

## Usage

``` r
get_verbose(verbose = NULL)
```

## Arguments

- verbose:

  Optional explicit level, which wins over the option and the
  environment variable. `NULL`, the default, consults those instead.

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
get_verbose(2)
#> [1] 2

# The option is read when no explicit level is given. options() returns
# the previous value, so the caller's setting can be put back; resetting
# to NULL instead would discard it.
old <- options(ggseg.extra.verbose = 0)
get_verbose()
#> [1] 0
options(old)
```
