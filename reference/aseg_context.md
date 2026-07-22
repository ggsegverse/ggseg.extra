# Reduce a subcortical atlas to focus regions on grey anatomical context

Applies the post-processing recipe shared by the FreeSurfer subcortical
atlases:

## Usage

``` r
aseg_context(
  atlas,
  focus,
  match_on = c("label", "region"),
  remove = aseg_hidden_labels(),
  punch_white_matter = TRUE,
  cortex = "^cortex",
  white_matter = "White-Matter$",
  drop_empty_views = TRUE
)
```

## Arguments

- atlas:

  A subcortical `ggseg_atlas`, e.g. from
  [`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md).

- focus:

  Regex matched (case-insensitively) against `match_on` identifying the
  regions to keep as coloured core; everything else becomes context.

- match_on:

  Column to match `focus` against: `"label"` or `"region"`.

- remove:

  Character vector of
  [`ggseg.formats::atlas_region_remove()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)
  patterns to strip before demoting context. Defaults to
  [`aseg_hidden_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_hidden_labels.md);
  pass `character(0)` to skip.

- punch_white_matter:

  If `TRUE`, subtract `white_matter` from the `cortex` silhouette.
  Skipped with a message if either pattern is absent.

- cortex, white_matter:

  Label patterns for the brain silhouette and the cerebral white matter
  used by the punch.

- drop_empty_views:

  If `TRUE`, remove views containing no focus region.

## Value

The post-processed `ggseg_atlas`.

## Details

1.  Punch the cerebral white matter out of the brain silhouette
    ([`ggseg.formats::atlas_region_op()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html))
    so slices show the cortical ribbon with the white-matter interior as
    a hole rather than a solid blob.

2.  Remove the structures `aseg` does not draw
    ([`aseg_hidden_labels()`](https://ggsegverse.github.io/ggseg.extra/reference/aseg_hidden_labels.md)).

3.  Demote every remaining structure that is **not** matched by `focus`
    to grey context, so only the focus regions are coloured.

4.  Optionally drop views left with no focus geometry.

The context demotion matches the leftover core labels exactly and
case-sensitively, so a focus region is never swallowed by a context
entry that happens to be a substring of its name (e.g. `Thalamus` vs
`hypothalamus`).

## See also

[`subcortical_views()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md),
[`ggseg.formats::atlas_region_contextual()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_manipulation.html)

## Examples

``` r
if (FALSE) { # \dontrun{
atlas <- create_subcortical_from_volume(
  input_volume = file.path(
    freesurfer::fs_subj_dir(), "fsaverage5", "mri", "aseg.mgz"
  ),
  atlas_name = "aseg"
)
aseg_context(atlas, focus = "Hippocampus")
} # }
```
