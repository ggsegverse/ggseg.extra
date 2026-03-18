# Compute streamline density for tract bundles

Calculates how many streamlines pass through each point along the
centerline.

## Usage

``` r
compute_streamline_density(streamlines, centerline, search_radius = 2)
```

## Arguments

- streamlines:

  List of streamline matrices

- centerline:

  Centerline matrix (Nx3)

- search_radius:

  Radius around centerline points to count streamlines

## Value

Numeric vector of density values (one per centerline point)
