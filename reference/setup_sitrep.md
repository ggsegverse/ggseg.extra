# Check ggseg.extra setup status

Performs diagnostic checks to verify that system dependencies and
environment variables required by ggseg.extra are properly configured.

## Usage

``` r
setup_sitrep(detail = c("simple", "full"))
```

## Arguments

- detail:

  Character. Level of detail to display:

  - `"simple"` (default): Quick pass/fail overview

  - `"full"`: Detailed diagnostics including
    [`freesurfer::fs_sitrep()`](https://rdrr.io/pkg/freesurfer/man/fs_sitrep.html)

## Value

Invisibly returns a list with check results.

## Examples

``` r
setup_sitrep()
#> ✖ FreeSurfer not configured
#> ✖ ImageMagick not found
#> ✔ Chrome/Chromium
#> ✖ fsaverage5 not found
#> 
#> ── Pipeline options 
#> verbose: 1
#> cleanup: TRUE
#> skip_existing: TRUE
#> tolerance: 1
#> smoothness: 5
#> output_dir: /tmp/Rtmp6Us5V5
#> 
#> ✖ Missing requirements for atlas creation
#> ℹ Run `setup_sitrep("full")` for details
setup_sitrep("full")
#> 
#> ── FreeSurfer Setup Report ──
#> 
#> ── FreeSurfer Directory 
#> • Unable to detect
#> 
#> ── Source script 
#> • Unable to detect
#> 
#> ── License File 
#> • Unable to detect
#> 
#> ── Subjects Directory 
#> • Unable to detect
#> 
#> ── Verbose mode 
#> • TRUE
#> ! Determined from: `Default value`
#> 
#> ── MNI functionality 
#> • Unable to detect
#> 
#> ── Output Format 
#> • "nii.gz"
#> ! Determined from: `Default value`
#> 
#> ── System Information 
#> • Operating System: "x86_64-pc-linux-gnu"
#> • R Version: "4.5.3 (2026-03-11)"
#> • Shell: "/bin/bash"
#> 
#> ── Testing R and FreeSurfer Communication 
#> ✖ FreeSurfer installation not detected
#> • Use `options(freesurfer.home = '/path/to/freesurfer')` to set location
#> ✖ ImageMagick not found
#> ℹ Install from <https://imagemagick.org/script/download.php>
#> ✔ Chrome/Chromium: /usr/bin/google-chrome
#> ✖ fsaverage5 not found
#> 
#> ── Pipeline options 
#>   verbose: 1
#>   cleanup: TRUE
#>   skip_existing: TRUE
#>   tolerance: 1
#>   smoothness: 5
#>   output_dir: /tmp/Rtmp6Us5V5
#> 
#> ℹ Set via `options(ggseg.extra.<name> = value)` or environment variables
#>   `GGSEG_EXTRA_<NAME>`
#> ℹ See `vignette("pipeline-configuration")` for details
#> 
#> ✖ Missing requirements for atlas creation
```
