# Extract centerline from streamlines

Compute a single representative path from a bundle of streamlines.
Useful for creating a tube mesh that summarises a tract.

## Usage

``` r
extract_centerline(streamlines, method = c("mean", "medoid"), n_points = 50)
```

## Arguments

- streamlines:

  A list of Nx3 matrices (one per streamline), or a single matrix if you
  have just one streamline.

- method:

  How to compute the centerline: `"mean"` averages point-wise,
  `"medoid"` selects the most representative streamline.

- n_points:

  Number of points to resample the centerline to.

## Value

A matrix with `n_points` rows and 3 columns (x, y, z).

## Details

The `"mean"` method resamples all streamlines to the same number of
points and averages coordinates. The `"medoid"` method picks the single
streamline that's most similar to all others (minimises total distance).
