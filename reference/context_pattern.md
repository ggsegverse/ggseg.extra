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
context_pattern(atlas = NULL)
```

## Arguments

- atlas:

  Optional `ggseg_atlas`. When given, the pattern matches that atlas's
  own context shapes; when `NULL`, the default, it matches the names the
  pipelines generate.

## Value

A regular expression, as a length-one character vector.

## Details

A backdrop reaches an atlas two ways, and this matches both, because
from a plotting point of view they are the same thing.

The pipelines generate one for the surface a parcellation does not
cover: `lh_cortex` / `rh_cortex` on a cortical surface, `cerebellum` on
the SUIT flatmap, and `cortex`, `cortex_left` or `cortex_right` from the
volumetric slice tracing of a tract atlas.

A subcortical build takes its context from its lookup table instead: a
row marked `context` keeps its own name, and a label the table does not
list is named `context_` and its id, such as `context_0002`. Only the
second kind has a name this pattern can know; see below for the first.

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

## Asking the atlas instead

Give it an atlas and it stops going by names: the pattern then matches
exactly the shapes that atlas draws without their being one of its
regions, whatever they are called. That is the form to use on a
subcortical atlas, where the lookup table names the context and so no
fixed spelling can know it.

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md),
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
and
[`atlas_dilate()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_dilate.md)
do the asking for you when handed the function itself:
`exclude = context_pattern`, with no brackets, means "this atlas's
context", and works in the middle of a pipe.

## See also

[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md),
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
and
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md),
which take it as `labels` or `exclude`.

## Examples

``` r
context_pattern()
#> [1] "^([lr]h_)?cortex|^cerebellum$|^context_[0-9]+$|(^|_)unknown$|(^|_)[?]{3}$|medial[ _.-]?wall$"

# What it does and does not match: the backdrop, not a cortex structure.
labels <- c("lh_cortex", "cerebellum", "lh_unknown", "Left-Cerebral-Cortex")
grepl(context_pattern(), labels, ignore.case = TRUE)
#> [1]  TRUE  TRUE  TRUE FALSE

# Asked of an atlas, it matches whatever that atlas draws as context.
context_pattern(ggseg.formats::dk())
#> [1] "^(lh_unknown|rh_unknown)$"

# The usual shape of a build: backdrop and structures, each its own way.
if (FALSE) { # \dontrun{
atlas <- my_atlas |>
  atlas_polish(
    keep = 0.4,
    smoothness = 0.4,
    method = "chaikin",
    labels = context_pattern
  ) |>
  atlas_polish(keep = 0.1, smoothness = 0.4, exclude = context_pattern)
} # }
```
