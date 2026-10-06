# Read neuromaps annotation files

Reads neuromaps GIFTI metric files (`.func.gii`) and converts them to
the standard annotation format used by the cortical atlas pipeline.

## Usage

``` r
read_neuromaps_annotation(gifti_files, label_table = NULL, breaks = NULL)
```

## Arguments

- gifti_files:

  Character vector of paths to `.func.gii` files. Hemisphere is detected
  from BIDS filename patterns (`hemi-L`, `hemi-R`).

- label_table:

  Optional data.frame mapping integer parcel IDs to region names. Must
  have columns `id` (integer) and `region` (character). Optionally
  include `colour` (hex string). When `NULL`, regions are named
  `parcel_1`, `parcel_2`, etc. (parcellation) or `bin_1`, `bin_2`, etc.
  (continuous).

- breaks:

  How to cut a continuous map into bins. One of:

  - `NULL`, the default: quantile bins, as many as Sturges' rule gives
    for the number of vertices (`1 + log2(n)`), kept between 5 and 20.

  - A single number: that many quantile bins.

  - Increasing numbers: the edges of the bins.

  - A function that takes the map's finite values and returns the edges,
    such as `function(x) pretty(x, 6)` for round, equal-width bins.

  Quantile bins each hold about the same number of vertices. Both
  hemispheres are cut on the same edges, so a bin covers the same range
  of values on the left and on the right. Values outside edges you
  supply are left `unknown`, with a warning. Ignored for parcellation
  data.

## Value

A tibble with columns: hemi, region, label, colour, vertices

## Details

Automatically detects whether data contains integer parcel IDs
(parcellation) or continuous values (brain map). For parcellations,
vertex value 0 is treated as medial wall. For continuous data, NaN
vertices are medial wall and values are discretized into bins, which
`breaks` controls. Both hemispheres share one set of bin edges.

Files must be in fsaverage5 space (10,242 vertices per hemisphere). Use
`space = "fsaverage"` with `density = "10k"` when fetching from
neuromaps.

## Examples

``` r
if (FALSE) { # \dontrun{
files <- neuromapr::fetch_neuromaps_annotation(
  "abagen", "genepc1", "fsaverage", density = "10k"
)
atlas_data <- read_neuromaps_annotation(files, breaks = 7)
} # }
```
