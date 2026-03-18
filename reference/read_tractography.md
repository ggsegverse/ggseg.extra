# Read tractography file

Load streamlines from a tractography file. Supports TrackVis (`.trk`)
and MRtrix (`.tck`) formats. The file format is detected from the
extension.

## Usage

``` r
read_tractography(file)
```

## Arguments

- file:

  Path to a `.trk` or `.tck` file.

## Value

A list of matrices, one per streamline. Each matrix has N rows (points
along the streamline) and 3 columns (x, y, z coordinates).

## See also

[`read_trk()`](https://ggsegverse.github.io/ggseg.extra/reference/read_trk.md),
[`read_tck()`](https://ggsegverse.github.io/ggseg.extra/reference/read_tck.md)
for format-specific readers

## Examples

``` r
if (FALSE) { # \dontrun{
streamlines <- read_tractography("bundle.trk")
} # }
```
