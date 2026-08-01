# Add ggsegverse GitHub Actions workflows to a package

Writes caller stubs for the shared workflows maintained in
[ggsegverse/.github](https://github.com/ggsegverse/.github) into
`.github/workflows/`. Each stub is a short `uses:` block, so a package
picks up changes to the shared workflow without needing to be updated
itself.

## Usage

``` r
use_atlas_github_actions(
  workflows = atlas_github_actions(),
  path = ".",
  overwrite = FALSE
)
```

## Arguments

- workflows:

  Names of workflows to add. Defaults to all of the above.

- path:

  Path to the package. Defaults to the working directory.

- overwrite:

  Overwrite workflows that already exist. Default is FALSE, which leaves
  existing files untouched and reports them.

## Value

Invisibly, the paths written.

## Details

Run this on a newly scaffolded atlas package, or on an existing one to
replace hand-maintained workflows with the shared set.
[`setup_atlas_repo()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_atlas_repo.md)
calls it for you unless `github_actions = FALSE`.

The workflows written by default are:

- `R-CMD-check` — multi-platform `R CMD check`

- `code-quality` — air, lintr, and goodpractice

- `pkgdown` — build and deploy the documentation site

- `render-readme` — re-render `README.qmd` on change

- `update-codemeta` — refresh `codemeta.json` when DESCRIPTION changes

## Examples

``` r
if (FALSE) { # \dontrun{
# Add the full set to the package in the working directory
use_atlas_github_actions()

# Add just one, replacing any existing copy
use_atlas_github_actions("pkgdown", overwrite = TRUE)
} # }
```
