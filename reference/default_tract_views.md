# Default tract atlas view configuration

Creates projection views optimized for white matter tract visualization.
Tracts typically span large portions of the brain, so projections cover
wider ranges than subcortical views.

## Usage

``` r
default_tract_views(dims)
```

## Arguments

- dims:

  Volume dimensions (3-element vector)

## Value

data.frame with columns: name, type, start, end
