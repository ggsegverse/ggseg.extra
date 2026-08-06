# Check ggseg.extra setup status

Performs diagnostic checks to verify that system dependencies and R
packages required by ggseg.extra are properly configured. Shows
per-pipeline readiness so you can see which atlas creation workflows are
available and what to install for the ones that aren't.

## Usage

``` r
setup_sitrep(detail = c("simple", "minimal", "full"))
```

## Arguments

- detail:

  Character. Level of detail to display:

  - `"minimal"`: Just the pipeline readiness summary

  - `"simple"` (default): System checks + pipeline readiness

  - `"full"`: Everything above + install commands, paths, options, and
    FreeSurfer diagnostics

## Value

Invisibly returns a list with check results.

## Examples

``` r
setup_sitrep()
#> ✖ FreeSurfer not configured
#> ✖ ImageMagick not found
#> ✔ Chrome/Chromium
#> ✖ fsaverage5 not found
#> ✔ R packages: {.pkg freesurferformats}, {.pkg gifti}, {.pkg ciftiTools}, {.pkg RNifti}, {.pkg Rvcg}, {.pkg neuromapr}
#> ✔ SUIT surfaces (bundled)
#> 
#> 
#> ── Pipeline readiness (8/12) 
#> Cortical
#> ✖ from annotation: needs FreeSurfer, fsaverage5
#> ✔ from GIFTI
#> ✔ from CIFTI
#> ✔ from neuromaps
#> ✔ from labels
#> Subcortical
#> ✖ from volume: needs FreeSurfer
#> Tract
#> ✔ from tractography
#> Whole-brain
#> ✖ from volume: needs FreeSurfer, fsaverage5
#> Cerebellar
#> ✔ from GIFTI
#> ✔ from annotation
#> ✖ from volume: needs FreeSurfer
#> ✔ MNI to SUIT transform
#> 
#> ℹ 8/12 pipelines ready
#> ℹ Run `setup_sitrep("full")` for install instructions
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
#> • R Version: "4.6.1 (2026-06-24)"
#> • Shell: "/bin/bash"
#> 
#> ── Testing R and FreeSurfer Communication 
#> ✖ FreeSurfer installation not detected
#> • Use `options(freesurfer.home = '/path/to/freesurfer')` to set location
#> ✖ ImageMagick not found
#> ℹ Install from <https://imagemagick.org/script/download.php>
#> ℹ macOS: `brew install imagemagick`
#> ✔ Chrome/Chromium: /usr/bin/google-chrome
#> ✖ fsaverage5 not found
#> ℹ Ships with FreeSurfer in $SUBJECTS_DIR
#> ✔ R packages: {.pkg freesurferformats}, {.pkg gifti}, {.pkg ciftiTools}, {.pkg RNifti}, {.pkg Rvcg}, {.pkg neuromapr}
#> ✔ SUIT surfaces (bundled)
#> 
#> 
#> ── Pipeline options 
#>   verbose: 1
#>   cleanup: TRUE
#>   skip_existing: TRUE
#>   tolerance: 0.05
#>   smoothness: 5
#>   output_dir: /tmp/Rtmp62vXCt
#> 
#> ℹ Set via `options(ggseg.extra.<name> = value)` or environment variables
#>   `GGSEG_EXTRA_<NAME>`
#> ℹ See `vignette("pipeline-configuration")` for details
#> 
#> 
#> ── Pipeline readiness (8/12) 
#> Cortical
#> ✖ from annotation: needs FreeSurfer, fsaverage5
#> ℹ `Install from https://surfer.nmr.mgh.harvard.edu/`
#> ℹ `Ships with FreeSurfer ($SUBJECTS_DIR/fsaverage5)`
#> ✔ from GIFTI
#> ✔ from CIFTI
#> ✔ from neuromaps
#> ✔ from labels
#> Subcortical
#> ✖ from volume: needs FreeSurfer
#> ℹ `Install from https://surfer.nmr.mgh.harvard.edu/`
#> Tract
#> ✔ from tractography
#> Whole-brain
#> ✖ from volume: needs FreeSurfer, fsaverage5
#> ℹ `Install from https://surfer.nmr.mgh.harvard.edu/`
#> ℹ `Ships with FreeSurfer ($SUBJECTS_DIR/fsaverage5)`
#> Cerebellar
#> ✔ from GIFTI
#> ✔ from annotation
#> ✖ from volume: needs FreeSurfer
#> ℹ `Install from https://surfer.nmr.mgh.harvard.edu/`
#> ✔ MNI to SUIT transform
#> 
#> ℹ 8/12 pipelines ready
```
