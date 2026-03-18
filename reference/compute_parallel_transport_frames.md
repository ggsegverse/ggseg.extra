# Compute parallel transport frames along curve

Uses the parallel transport method to compute stable perpendicular
frames along a 3D curve, avoiding the twisting artifacts of
Frenet-Serret frames.

## Usage

``` r
compute_parallel_transport_frames(curve)
```

## Arguments

- curve:

  Matrix with N rows and 3 columns

## Value

List with tangents, normals, and binormals matrices
