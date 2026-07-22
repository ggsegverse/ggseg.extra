# Download SUIT deformation field for MNI-to-SUIT transforms

**\[experimental\]**

Downloads the nonlinear deformation field needed to transform volumes
from MNI152 space to SUIT cerebellar space. The files are cached in the
user's data directory so they only need to be downloaded once.

Two MNI templates are supported:

- `"MNI152NLin6AsymC"`: FSL MNI152 template (used by FreeSurfer). Use
  this for FreeSurfer's Buckner cerebellar atlases.

- `"MNI152NLin2009cSymC"`: ICBM 2009c symmetric template.

## Usage

``` r
suit_deformation_field(
  template = c("MNI152NLin6AsymC", "MNI152NLin2009cSymC"),
  cache_dir = NULL
)
```

## Arguments

- template:

  Which MNI template the source volume is in. Default
  `"MNI152NLin6AsymC"` (FreeSurfer/FSL).

- cache_dir:

  Directory for caching downloaded files. Defaults to
  `tools::R_user_dir("ggseg.extra", "data")`.

## Value

Path to the downloaded deformation field NIfTI file.

## Examples

``` r
if (FALSE) { # \dontrun{
xfm <- suit_deformation_field()
suit_vol <- transform_mni_to_suit(mni_volume, xfm)
} # }
```
