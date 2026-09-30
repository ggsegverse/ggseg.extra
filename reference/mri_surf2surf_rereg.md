# Re-register an annotation file

Annotation files are subject specific. Most are registered for
fsaverage, but we recommend using fsaverage5 for the mesh plots in
ggseg3d, as these contain a decent balance in number of vertices for
detailed rendering and speed.

## Usage

``` r
mri_surf2surf_rereg(
  subject,
  annot,
  hemisphere = c("lh", "rh"),
  target_subject = "fsaverage5",
  output_dir = as.character(fs::path(freesurfer::fs_subj_dir(), subject, "label")),
  verbose = get_verbose(),
  hemi = lifecycle::deprecated()
)
```

## Arguments

- subject:

  subject the original annotation file is registered to

- annot:

  annotation file name (as found in subjects_dir)

- hemisphere:

  hemisphere (one of "lh" or "rh")

- target_subject:

  subject to re-register the annotation (default fsaverage5)

- output_dir:

  Where to put the intermediate files. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), from
  `options("ggseg.extra.output_dir")` or `GGSEG_EXTRA_OUTPUT_DIR`.

- verbose:

  How much to print: `0` silent, `1` progress (the default), `2` adds
  FreeSurfer's own output. `TRUE` and `FALSE` mean `1` and `0`. Falls
  back to `options("ggseg.extra.verbose")`, then `GGSEG_EXTRA_VERBOSE`.

- hemi:

  **\[deprecated\]** Use `hemisphere` instead.

## Value

nothing

## Examples

``` r
if (FALSE) { # \dontrun{
# For help see:
freesurfer::fs_help("mri_surf2surf")

mri_surf2surf_rereg(
  subject = "bert",
  annot = "aparc.DKTatlas",
  target_subject = "fsaverage5"
)
} # }
```
