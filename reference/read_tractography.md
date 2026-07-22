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

## Details

Format-specific readers are used internally depending on the file
extension: `.trk` (TrackVis) and `.tck` (MRtrix).

## Examples

``` r
if (FALSE) { # \dontrun{
streamlines <- read_tractography("bundle.trk")
} # }
```
