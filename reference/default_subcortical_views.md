# Default subcortical atlas view configuration

Creates projection views calibrated for subcortical structures. Uses
anatomically-calibrated ranges based on typical aseg label positions.

## Usage

``` r
default_subcortical_views(dims)
```

## Arguments

- dims:

  Volume dimensions (3-element vector)

## Value

data.frame with columns: name, type, start, end
