# Report on the ggseg.extra setup

Checks the system dependencies and R packages the creation pipelines
need, then reports which pipelines are ready and what to install for the
ones that are not.

## Usage

``` r
sitrep(detail = c("simple", "minimal", "full"))
```

## Arguments

- detail:

  How much to show, from least to most:

  - `"minimal"`: the pipeline readiness summary only

  - `"simple"` (the default): system checks and pipeline readiness

  - `"full"`: the above plus install commands, paths, options and
    FreeSurfer diagnostics

## Value

Invisibly, a list of check results.

## Examples

``` r
sitrep()
#> ✖ FreeSurfer not configured
#> ✖ fsaverage5 not found
#> ✔ R packages: freesurferformats, gifti, ciftiTools, RNifti, Rvcg, neuromapr, and princurve
#> ✔ SUIT surfaces (bundled)
#> 
#> 
#> ── Pipeline readiness (9/13) 
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
#> ✔ from volume
#> Whole-brain
#> ✖ from volume: needs FreeSurfer, fsaverage5
#> Cerebellar
#> ✔ from GIFTI
#> ✔ from annotation
#> ✖ from volume: needs FreeSurfer
#> ✔ MNI to SUIT transform
#> 
#> ℹ 9/13 pipelines ready
#> ℹ Run `sitrep("full")` for install instructions
sitrep("full")
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
#> ✖ fsaverage5 not found
#> ℹ Ships with FreeSurfer in $SUBJECTS_DIR
#> ✔ R packages: freesurferformats, gifti, ciftiTools, RNifti, Rvcg, neuromapr, and princurve
#> ✔ SUIT surfaces (bundled)
#> 
#> 
#> ── Pipeline options 
#>   verbose: 1
#>   cleanup: TRUE
#>   skip_existing: FALSE
#>   output_dir: /tmp/Rtmp9jnKKE
#> 
#> ℹ Set via `options(ggseg.extra.<name> = value)` or environment variables
#>   `GGSEG_EXTRA_<NAME>`
#> ℹ See `vignette("pipeline-configuration")` for details
#> 
#> 
#> ── Pipeline readiness (9/13) 
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
#> ✔ from volume
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
#> ℹ 9/13 pipelines ready
```
