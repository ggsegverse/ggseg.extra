# RStudio project template binding

Backs the "Create ggseg brain atlas" entry in the RStudio New Project
wizard, declared in
`inst/rstudio/templates/project/create-ggseg-atlas.dcf`. RStudio
resolves the `Binding:` field against the package's exports, so this
must be exported even though it is not meant to be called directly — use
[`setup_atlas_repo()`](https://ggsegverse.github.io/ggseg.extra/reference/setup_atlas_repo.md)
instead.

## Usage

``` r
new_project_setup_atlas_repo(path, ...)
```

## Arguments

- path:

  Directory RStudio creates for the new project.

- ...:

  Template parameters supplied by the wizard, notably `atlas_name`.

## Value

Invisible `NULL`, called for its side effects.
