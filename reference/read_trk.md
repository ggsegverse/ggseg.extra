# Read TrackVis TRK file

Parse a TrackVis `.trk` file and extract all streamlines.

## Usage

``` r
read_trk(file)
```

## Arguments

- file:

  Path to a `.trk` file.

## Value

A list of matrices, one per streamline. Each matrix has columns x, y, z.

## See also

[`read_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/read_tractography.md)
for format auto-detection
