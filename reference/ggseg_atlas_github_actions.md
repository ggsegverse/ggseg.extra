# Workflows [`use_atlas_github_actions()`](https://ggsegverse.github.io/ggseg.extra/reference/use_atlas_github_actions.md) can write

**\[deprecated\]**

`atlas_github_actions()` was renamed to `ggseg_atlas_github_actions()`.
It takes no atlas and returns GitHub Actions workflow names, so the
`atlas_*` prefix put it among the verbs that reshape an atlas.

## Usage

``` r
ggseg_atlas_github_actions()

atlas_github_actions()
```

## Value

A character vector of workflow names.

## Examples

``` r
ggseg_atlas_github_actions()
#> [1] "R-CMD-check"     "code-quality"    "pkgdown"         "render-readme"  
#> [5] "update-codemeta"
```
