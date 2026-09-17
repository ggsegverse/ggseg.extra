# Classify lookup-table labels as cortical, subcortical, or cerebellar

Fills in a lookup table's `type` column by reading where each label sits
in FreeSurfer's `aparc+aseg`, rather than by matching label names. This
is an authoring tool: run it once while building an atlas, write the
`type` column it returns into the lookup table, and commit that. A
declared classification is reviewable in a diff and reproducible without
FreeSurfer; the vertex-count fallback in
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
is neither.

## Usage

``` r
lut_classify_anatomy(
  volume,
  lut,
  subject = "cvs_avg35_inMNI152",
  min_cortical = 0.6,
  min_cerebellar = 0.5,
  min_fraction = 0.05,
  verbose = get_verbose()
)
```

## Arguments

- volume:

  Path to the labelled atlas volume (`.nii`, `.nii.gz` or `.mgz`), in
  the space its header claims.

- lut:

  A lookup table: a path to a LUT file, or a data.frame with `idx` and
  `label` columns. Any existing `type` column is replaced.

- subject:

  FreeSurfer subject to take the `aparc+aseg` from. The default sits in
  MNI152 space, which is where most published parcellations are
  distributed.

- min_cortical:

  Minimum share of a label's labelled grey matter that must be cortical
  ribbon for the label to be called cortical.

- min_cerebellar:

  Minimum share of a label's labelled grey matter that must be
  cerebellar cortex for the label to be called cerebellar.

- min_fraction:

  Minimum share of a label's *own voxels* that must sit on the winning
  tissue, whatever the grey-matter share says. This is what stops one
  ribbon voxel from making a white-matter label cortical.

- verbose:

  Verbosity level: `0` (silent), `1` (standard progress, default), or
  `2` (debug, includes FreeSurfer output). Logical values are accepted
  (`TRUE` = 1, `FALSE` = 0). If not specified, uses the value from
  `options("ggseg.extra.verbose")` or the `GGSEG_EXTRA_VERBOSE`
  environment variable.

## Value

The lookup table as a data.frame, with a `type` column of `"cortical"`,
`"subcortical"` or `"cerebellar"`. Labels the volume does not carry are
typed `"subcortical"`, matching how
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
treats a label that never reaches the surface, and warned about. The
background label `idx = 0` is left `NA`.

## Details

`aparc+aseg` is resampled onto the volume's own grid with
`mri_vol2vol --regheader --nearest`, which goes through the two headers
and invents no transform. Each label is then judged on the share of the
*labelled grey matter* it touches - cortical ribbon, deep grey,
cerebellar cortex or brainstem - ignoring white matter and the voxels
`aparc+aseg` does not label at all. That normalisation is what makes the
test independent of a label's size: a volume clustered on EPI data
reaches past the edge of FreeSurfer's brain, so a superficial parcel can
be mostly unlabelled and still unambiguously cortical in the grey it
does touch.

Cerebellum is separated first, because a label straddling the tentorium
reads as part cortical. A label that touches no labelled grey matter at
all, and one whose winning tissue is under `min_fraction` of its own
voxels, are both called subcortical: the share alone would let a single
stray ribbon voxel decide an otherwise unlabelled label.

## See also

[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md),
which consumes the `type` column;
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
and
[`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
to read and write the table.

## Examples

``` r
if (FALSE) { # \dontrun{
# Authoring an atlas: classify once, then commit the column.
lut <- read_lut("julich_LUT.txt")
lut <- lut_classify_anatomy("julich_mpm.nii.gz", lut)
table(lut$type)
write_lut(lut, "julich_LUT.txt")

# create_wholebrain_from_volume() then reads the column instead of
# falling back to counting surface vertices.
create_wholebrain_from_volume(
  input_volume = "julich_mpm.nii.gz",
  input_lut = "julich_LUT.txt"
)
} # }
```
