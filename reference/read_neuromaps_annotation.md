# Read neuromaps annotation files

Reads neuromaps GIFTI metric files (`.func.gii`) and converts them to
the standard annotation format used by the cortical atlas pipeline.

## Usage

``` r
read_neuromaps_annotation(gifti_files, label_table = NULL, n_bins = NULL)
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

- n_bins:

  Number of quantile bins for continuous data. When `NULL` (default),
  auto-detected via Sturges' rule (`1 + log2(n)`, clamped to 5–20).
  Ignored for integer parcellation data.

## Value

A tibble with columns: hemi, region, label, colour, vertices

## Details

Automatically detects whether data contains integer parcel IDs
(parcellation) or continuous values (brain map). For parcellations,
vertex value 0 is treated as medial wall. For continuous data, NaN
vertices are medial wall and values are discretized into quantile bins
via `n_bins`.

Files must be in fsaverage5 space (10,242 vertices per hemisphere). Use
`space = "fsaverage"` with `density = "10k"` when fetching from
neuromaps.

## Examples

``` r
if (FALSE) { # \dontrun{
files <- neuromapr::fetch_neuromaps_annotation(
  "abagen", "genepc1", "fsaverage", density = "10k"
)
atlas_data <- read_neuromaps_annotation(files, n_bins = 7)
} # }
```
