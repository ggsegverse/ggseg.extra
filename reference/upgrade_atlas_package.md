# Upgrade the atlases an atlas package ships

Rewrites every atlas in a package's `R/sysdata.rda` through
[`ggseg.formats::as_ggseg_atlas()`](https://ggsegverse.github.io/ggseg.formats/reference/as_ggseg_atlas.html),
which brings it to the current object representation and schema. Nothing
is recomputed: no source volume is read, no surface is projected, no
geometry is touched. The atlas comes out with the same core table, the
same palette and the same geometry it went in with, in the shape the
installed `ggseg.formats` expects.

## Usage

``` r
upgrade_atlas_package(path = ".", dry_run = TRUE, repair = FALSE)
```

## Arguments

- path:

  Path to the atlas package. Defaults to the working directory.

- dry_run:

  If `TRUE` (the default), report what would change and write nothing.

- repair:

  If `TRUE`, run the migration verbs on an atlas the current constructor
  refuses, and upgrade the result. Off by default: a repair changes
  stored data, where an upgrade does not. Some published atlases need it
  – `ggsegAal`'s `.aal3_cerebellum` carries the pre-vocabulary `hemi`
  value `"middle"` and no verb that validates will touch it.

## Value

Invisibly, a data frame with one row per atlas object: its name, the
schema it carried, the schema it now carries, and whether its contents
verified identical.

## Details

This is deliberately **not** a rebuild. Re-running a package's
`data-raw` scripts reruns the pipeline, which picks up every pipeline
fix since the atlas was last built and is not output-identical – the
MCALT cerebellar atlas changed eight labels the last time it was
rebuilt, and `label` is the key every user's data joins on. Upgrading
changes the container; rebuilding changes the contents. Do them as
separate pieces of work, so that when something moves you know which one
moved it.

It also works for packages that cannot be rebuilt at all: those whose
source volumes were never committed, or whose build script points at a
machine that is not yours.

## Examples

``` r
if (FALSE) { # \dontrun{
# See what would change
upgrade_atlas_package("~/workspace/ggseg/atlases/ggsegSchaefer")

# Do it
upgrade_atlas_package(
  "~/workspace/ggseg/atlases/ggsegSchaefer",
  dry_run = FALSE
)
} # }
```
