# Generate tube mesh from centerline

Build a 3D tube mesh around a path. The tube follows the centerline with
consistent orientation (no twisting) using parallel transport frames.
Useful for visualising tracts as smooth tubes rather than raw
streamlines.

## Usage

``` r
generate_tube_mesh(centerline, radius = 0.5, segments = 8)
```

## Arguments

- centerline:

  A matrix with N rows and columns x, y, z defining the path the tube
  follows.

- radius:

  Tube radius. Either a single value for uniform thickness, or a vector
  of length N to vary the radius along the path.

- segments:

  Number of segments around the tube circumference. Higher values make
  smoother tubes but larger meshes.

## Value

A list with:

- `vertices`: data.frame with x, y, z columns

- `faces`: data.frame with i, j, k columns (1-indexed triangle vertices)

- metadata: list with n_centerline_points, centerline, tangents
