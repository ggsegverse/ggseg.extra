# Decimate a mesh using quadric edge decimation

Reduces the number of faces in a triangular mesh while preserving
topology and shape. Requires the Rvcg package.

## Usage

``` r
decimate_mesh(mesh, percent = 0.5)
```

## Arguments

- mesh:

  list with `vertices` (data.frame x,y,z) and `faces` (data.frame i,j,k,
  1-indexed)

- percent:

  Target face count as proportion of original (0-1)

## Value

Decimated mesh in the same format
