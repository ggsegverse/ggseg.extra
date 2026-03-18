# Read GIFTI annotation files

Reads GIFTI annotation (`.label.gii`) files and extracts region
information including vertices, colours, and labels. Returns data in the
same format as
[`read_annotation_data()`](https://ggsegverse.github.io/ggseg.extra/reference/read_annotation_data.md)
for use with the cortical atlas pipeline.

## Usage

``` r
read_gifti_annotation(gifti_files)
```

## Arguments

- gifti_files:

  Character vector of paths to `.label.gii` files.

## Value

A tibble with columns: hemi, region, label, colour, vertices

## Details

Hemisphere is detected from filename patterns: `lh.`, `rh.`, `.L.`,
`.R.`

## Examples

``` r
if (FALSE) { # \dontrun{
atlas_data <- read_gifti_annotation(c(
  "lh.aparc.label.gii",
  "rh.aparc.label.gii"
))
} # }
```
