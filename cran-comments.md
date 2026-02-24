## R CMD check results

0 errors | 0 warnings | 0 notes

## First submission

This is the first CRAN submission for ggseg.extra.

## Downstream dependencies

There are currently no reverse dependencies on CRAN.

## Notes for reviewers

### System dependencies

This package provides atlas creation pipelines for brain imaging data.
Many functions require FreeSurfer (<https://surfer.nmr.mgh.harvard.edu/>)
and are only available on Linux and macOS. Functions requiring system
software use `\dontrun{}` in examples because they cannot execute without
these external tools installed. Utility functions that do not require
system dependencies have executable examples.

### Suggested packages

Several suggested packages (e.g., 'ciftiTools', 'freesurferformats',
'gifti') are checked at runtime with `rlang::check_installed()` before
use.
