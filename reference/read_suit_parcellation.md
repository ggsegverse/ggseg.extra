# Read SUIT cerebellar parcellation from GIFTI

**\[experimental\]**

Reads GIFTI label files containing cerebellar parcellations and returns
a data frame compatible with `build_atlas_components()`. Handles
SUIT-specific label conventions where regions are prefixed with "Left",
"Right", or "Vermis".

## Usage

``` r
read_suit_parcellation(gifti_files)
```

## Arguments

- gifti_files:

  Character vector of paths to GIFTI label files.

## Value

A tibble with columns: `hemi`, `region`, `label`, `colour`, `vertices`
(list-column of 0-indexed integer vectors).

## Examples

``` r
if (FALSE) { # \dontrun{
parcellation <- read_suit_parcellation("Lobules-SUIT.label.gii")
} # }
```
