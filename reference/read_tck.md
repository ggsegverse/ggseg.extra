# Read MRtrix TCK file

Parse an MRtrix `.tck` file and extract all streamlines.

## Usage

``` r
read_tck(file)
```

## Arguments

- file:

  Path to a `.tck` file.

## Value

A list of matrices, one per streamline. Each matrix has columns x, y, z.

## See also

[`read_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/read_tractography.md)
for format auto-detection
