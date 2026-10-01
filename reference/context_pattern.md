# The label pattern that matches an atlas's backdrop

**\[experimental\]**

The grey drawn behind an atlas's structures is not a structure, and
almost every polish step treats it differently – a backdrop wants
rounding that keeps its sulci, the structures want their staircase taken
off. That means writing the same pattern twice per build, in every
build, and the pattern has to agree with what the pipelines actually
label it.

This is that pattern, in one place. Use it rather than retyping the
spellings below, so a change of convention is one release rather than
one edit per atlas repository.

## Usage

``` r
context_pattern()
```

## Value

A regular expression, as a length-one character vector.

## Details

A backdrop reaches an atlas two ways, and this matches both, because
from a plotting point of view they are the same thing.

The pipelines generate one for the surface a parcellation does not
cover: `lh_cortex` / `rh_cortex` on a cortical surface, `cerebellum` on
the SUIT flatmap, and `cortex`, `cortex_left` or `cortex_right` from the
volumetric slice tracing.

A parcellation can also carry its own – an annotation's `unknown`, `???`
or medial-wall region. Those arrive as regions and are demoted to
backdrop during the build, so an atlas's medial wall is as much the grey
behind the structures as a generated silhouette is.

Anchored on purpose. A loose `"cortex"` also matches
`Cerebellar_Cortex_*` and `Left-Cerebral-Cortex`, which are structures;
anchoring at the start is what excludes them, so the pattern is safe to
use case-insensitively, as
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
and
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
do.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
and
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
which take it as `labels` or `exclude`.

## Examples

``` r
context_pattern()
#> [1] "^([lr]h_)?cortex|^cerebellum$|(^|_)unknown$|(^|_)[?]{3}$|medial[ _.-]?wall$"

# What it does and does not match: the backdrop, not a cortex structure.
labels <- c("lh_cortex", "cerebellum", "lh_unknown", "Left-Cerebral-Cortex")
grepl(context_pattern(), labels, ignore.case = TRUE)
#> [1]  TRUE  TRUE  TRUE FALSE

# The usual shape of a build: backdrop and structures, each its own way.
if (FALSE) { # \dontrun{
atlas <- my_atlas |>
  atlas_polish(
    keep = 0.4,
    smoothness = 0.4,
    method = "chaikin",
    labels = context_pattern()
  ) |>
  atlas_polish(keep = 0.1, smoothness = 0.4, exclude = context_pattern())
} # }
```
