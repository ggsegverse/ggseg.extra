# Reduce an atlas's vertex count

Drops vertices from region geometry while keeping its topology, so an
atlas costs less to store and to draw.

## Usage

``` r
atlas_simplify(
  atlas,
  keep = 0.05,
  labels = NULL,
  exclude = NULL,
  close_gaps = TRUE
)
```

## Arguments

- atlas:

  A `ggseg_atlas` object with 2D geometry.

- keep:

  Proportion of vertices to retain, between 0 and 1. Lower is smaller
  and blockier; near 1 is an effective no-op.

- labels, exclude:

  Regex selecting which labels to simplify, or which to leave alone.
  Give at most one.

- close_gaps:

  Whether to hand back any sliver the simplification opens between
  neighbouring regions. Simplification is topology-aware, so on geometry
  straight out of a pipeline, whose neighbours share their boundary
  vertex for vertex, it opens none and this does nothing. It earns its
  keep on geometry that has been reshaped since - rounded off by
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
  or traced region by region from separate masks - where the rings no
  longer agree and the shared edge comes apart. With `TRUE`, the
  default, area that no longer belongs to any region but borders two of
  them is given back to one of them.

## Value

The `ggseg_atlas`, in the representation it arrived in.

## Details

This is about size, not shape. The silhouette an atlas draws behind its
structures usually carries the bulk of the vertices, so it is the part
worth simplifying; tiny deep structures have few to spare. Use `labels`
or `exclude` to say which.

## See also

[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
to round shapes off, and
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
to grow or shrink them. Simplify first and smooth afterwards, so the
smoothing has the last word on the outline.

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Halve the atlas, sparing the structures.
atlas <- atlas_simplify(my_atlas, keep = 0.5, labels = "^cortex")
} # }
```
