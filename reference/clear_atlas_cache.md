# Clear an atlas's build cache

**\[experimental\]**

Removes the intermediates a build left under `output_dir`, so the next
run recomputes from the source files rather than reusing anything.

A build reuses what it finds, which is what makes `skip_existing` worth
having on a pipeline that takes minutes. The cache knows the format that
wrote it, the version of this package, and what each step was given, and
recomputes when any of those move. It cannot know that a source file was
regenerated in place within the same second and at the same size, or
that you want to see a build from nothing. Clear it when you want to be
sure.

## Usage

``` r
clear_atlas_cache(
  atlas_name = NULL,
  output_dir = get_output_dir(),
  force = FALSE
)
```

## Arguments

- atlas_name:

  Name of the atlas whose cache to clear. `NULL` clears every atlas
  under `output_dir`, which is only sensible when `output_dir` is a
  directory kept for builds.

- output_dir:

  Where the build wrote its intermediates. Defaults to the
  `ggseg.extra.output_dir` option, as a build does.

- force:

  Remove the directory even when it holds files this package did not
  write. `FALSE`, the default, refuses rather than delete your data.

## Value

Invisibly, the paths removed.

## Examples

``` r
if (FALSE) { # \dontrun{
# after changing a lookup table the pipeline cannot see into
clear_atlas_cache("shen268_subcortical", output_dir = "data-raw")

# start a build from nothing
clear_atlas_cache("glasser", output_dir = "data-raw")
create_cortical_from_annotation(annot, atlas_name = "glasser")
} # }
```
