# Read annotation data from files

Reads FreeSurfer annotation files and extracts region information
including vertices, colours, and labels for both hemispheres.

## Usage

``` r
read_annotation_data(annot_files)
```

## Arguments

- annot_files:

  Character vector of paths to annotation files. Files should follow
  FreeSurfer naming convention with `lh.` or `rh.` prefix (e.g.,
  `c("lh.aparc.annot", "rh.aparc.annot")`).

## Value

A tibble with columns: hemi, region, label, colour, vertices

## Examples

``` r
if (FALSE) { # \dontrun{
atlas_data <- read_annotation_data(c(
  "path/to/lh.aparc.annot",
  "path/to/rh.aparc.annot"
))
} # }
```
