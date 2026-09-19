# Simplify and smooth an atlas against a vertex budget

**\[experimental\]**

The two things a finished atlas usually needs at once: fewer vertices,
and its voxel staircase rounded off. Doing them separately means
deciding which order they go in, and the answer is not obvious -
rounding *adds* vertices, so smoothing after simplifying undoes some of
the reduction, while simplifying after smoothing replaces the new curves
with straight chords and puts the staircase back.

`atlas_polish()` owns that order so a build does not have to rediscover
it.

## Usage

``` r
atlas_polish(
  atlas,
  keep = 0.1,
  smoothness = 0.4,
  method = c("close", "chaikin", "ksmooth", "spline"),
  labels = NULL,
  exclude = NULL,
  close_gaps = TRUE
)
```

## Arguments

- atlas:

  A `ggseg_atlas`.

- keep:

  Proportion of the original vertices to aim for. See details.

- smoothness:

  Smoothing strength between 0 and 1, passed to
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md).

- method:

  Smoothing method, passed to
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md).
  `"close"` rounds solid shapes; the others keep holes open.

- labels:

  Optional regex. Only matching labels are polished.

- exclude:

  Optional regex. Matching labels are left alone.

- close_gaps:

  Whether to hand back the slivers the operations open between
  neighbouring regions. See
  [`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md).

## Value

The `ggseg_atlas`, simplified and rounded.

## Details

`keep` is a budget on the result, not on an intermediate: the atlas is
simplified to `keep` of the vertices it arrived with, then rounded under
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)'s
`"preserve"` budget, which simplifies the rounding back towards that
same count.

It is a dial rather than a guarantee, and the low end is the loose end.
Simplification will not take a ring below the handful of vertices that
holds its shape, so an atlas of many small rings lands well above what
was asked. On `ggsegJHU`'s tract atlas (14,667 vertices):

|  |  |  |  |
|----|----|----|----|
| `keep` | asked | [`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md) alone | `atlas_polish()` |
| 0.05 | 733 | 2,636 | 3,989 |
| 0.10 | 1,467 | 3,341 | 4,890 |
| 0.20 | 2,933 | 4,729 | 6,437 |
| 0.50 | 7,334 | 8,570 | 10,417 |

Most of that gap is the floor, not the rounding:
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
on its own misses the same target the same way. Rounding then adds
roughly a third more, which the `"preserve"` budget takes back only as
far as the floor allows. Ask for what you want, then look at what you
got.

## See also

[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
and
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
for the separate steps, when a build needs to interleave them
differently.

Other atlas geometry:
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# The usual shape of a build: the context silhouette and the structures
# want different budgets, so they get a call each.
atlas <- my_atlas |>
  atlas_polish(
    keep = 0.4,
    smoothness = 0.4,
    method = "chaikin",
    labels = "^cortex"
  ) |>
  atlas_polish(keep = 0.1, smoothness = 0.4, exclude = "^cortex")
} # }
```
