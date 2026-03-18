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
  hemi = c("lh", "rh"),
  target_subject = "fsaverage5",
  output_dir = file.path(fs_subj_dir(), subject, "label"),
  verbose = get_verbose()
)
```

## Arguments

- subject:

  subject the original annotation file is registered to

- annot:

  annotation file name (as found in subjects_dir)

- hemi:

  hemisphere (one of "lh" or "rh")

- target_subject:

  subject to re-register the annotation (default fsaverage5)

- output_dir:

  Directory to store intermediate files (screenshots, masks, contours).
  Defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

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
