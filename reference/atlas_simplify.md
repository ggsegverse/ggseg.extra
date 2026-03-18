# Simplify atlas 2D contours

Reduce vertex count in the sf geometry of a `ggseg_atlas` object using
Douglas-Peucker simplification. Higher `tolerance` values produce
simpler shapes with fewer vertices. This avoids re-running the full
atlas creation pipeline.

## Usage

``` r
atlas_simplify(atlas, tolerance = 0.5)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with sf data.

- tolerance:

  Simplification tolerance passed to
  [sf::st_simplify(dTolerance)](https://r-spatial.github.io/sf/reference/geos_unary.html).
  Typical range 0.1–2. Default 0.5.

## Value

A modified `ggseg_atlas` with simplified sf geometry.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- atlas_simplify(my_atlas, tolerance = 1)
plot(atlas)
} # }
```
