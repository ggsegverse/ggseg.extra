# Create a new ggseg atlas package

Scaffold an R package for distributing a brain atlas. Downloads a modern
template from the
[ggseg-atlas-template](https://github.com/ggsegverse/ggseg-atlas-template)
GitHub repository and customises it for your atlas. The generated
package follows ggseg conventions and includes GitHub Actions workflows,
pkgdown configuration, a test suite, and a multi-method scaffold for
building your atlas.

## Usage

``` r
setup_atlas_repo(
  path,
  open = rlang::is_interactive(),
  rstudio = TRUE,
  github_actions = TRUE,
  atlas_name = NULL
)
```

## Arguments

- path:

  Where to create the package. If the directory exists, it must be
  empty.

- open:

  If TRUE, opens the new project in RStudio. Default is TRUE when
  running interactively.

- rstudio:

  If TRUE, creates an `.Rproj` file for RStudio users.

- github_actions:

  If TRUE (default), adds the shared ggsegverse workflows via
  [`use_atlas_github_actions()`](https://ggsegverse.github.io/ggseg.extra/reference/use_atlas_github_actions.md).

- atlas_name:

  Name of the atlas (lowercase, no spaces). The package name becomes
  `ggseg{AtlasName}`. If NULL, derived from the directory name (e.g.,
  path `ggsegDkt` becomes atlas name `dkt`).

## Value

Invisibly returns the path to the created package.

## Details

The package will be named `ggseg{AtlasName}` (e.g., `ggsegSchaefer` for
a Schaefer parcellation). After creation, edit the files in `data-raw/`
to build your atlas, then run `devtools::document()` and
`devtools::check()`.

If the template cannot be downloaded (e.g. no internet), a minimal
bundled fallback is used instead. Both paths produce the same GitHub
Actions workflows, which are written by
[`use_atlas_github_actions()`](https://ggsegverse.github.io/ggseg.extra/reference/use_atlas_github_actions.md)
from templates bundled in this package rather than copied from the atlas
template.

## DESCRIPTION defaults

The template carries a placeholder author, down to an ORCID of
`0000-0000-0000-0000` that roxygen warns about on every render. If you
have set the `usethis.description` option, those fields are written into
the new package instead, so you do not retype what R already knows:

    options(usethis.description = list(
      "Authors@R" = person(
        "Jane", "Doe",
        email = "jane@example.com",
        role = c("aut", "cre"),
        comment = c(ORCID = "0000-0002-1825-0097")
      ),
      Language = "en-GB"
    ))

A field the template already declares is replaced; one it does not is
added. `Package`, `Title`, `Description`, `URL` and `BugReports` are the
exceptions – the scaffold derives those from the atlas name, and a
stored default would rename the package out from under you.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create atlas package in a new directory
setup_atlas_repo("ggsegDkt", "dkt")

# Create in current directory, derive name from path
setup_atlas_repo("ggsegMyatlas")

# Specify full path
setup_atlas_repo("~/projects/ggsegSchaefer", "schaefer")

# Without opening in RStudio
setup_atlas_repo("ggsegHarvard", "harvard", open = FALSE)
} # }
```
