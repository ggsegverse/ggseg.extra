# Smooth atlas 2D contours

Apply kernel smoothing to the sf geometry of a `ggseg_atlas` object.
Higher `smoothness` values produce rounder region boundaries. This
avoids re-running the full atlas creation pipeline.

## Usage

``` r
atlas_smooth(atlas, smoothness = 5)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with sf data.

- smoothness:

  Smoothing bandwidth passed to [smoothr::smooth(method =
  "ksmooth")](https://strimas.com/smoothr/reference/smooth.html).
  Typical range 3–15. Default 5.

## Value

A modified `ggseg_atlas` with smoothed sf geometry.

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- atlas_smooth(my_atlas, smoothness = 10)
plot(atlas)
} # }
```
