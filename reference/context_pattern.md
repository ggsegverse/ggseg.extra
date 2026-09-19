# The label pattern that matches an atlas's brain silhouette

**\[experimental\]**

The grey outline drawn behind an atlas's structures is labelled
`cortex`, and almost every polish step treats it differently from the
structures – a silhouette wants rounding that keeps its sulci, the
structures want their staircase taken off. That means writing the same
pattern twice per build, in every build, and the pattern has to agree
with what the pipelines actually label it.

This is that pattern, in one place. Use it rather than retyping
`"^cortex"`, so a change of convention is one release rather than one
edit per atlas repository.

## Usage

``` r
context_pattern()
```

## Value

A regular expression, as a length-one character vector.

## Details

Anchored and case-sensitive on purpose. A loose `"cortex"` also matches
`Cerebellar_Cortex_*` and `Left-Cerebral-Cortex`, which are structures,
not the silhouette.

## Examples

``` r
# The usual shape of a build: silhouette and structures, each its own way.
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
