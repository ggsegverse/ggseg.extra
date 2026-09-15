# freesurfer-slim

CI image for running the FreeSurfer-gated tests. Published as
`ghcr.io/ggsegverse/freesurfer-slim:<fs>-r<R>` by `freesurfer-image.yaml`.

## Why a subset

A full FreeSurfer install is 16-19 GB; the official Docker images are 5-14 GB
depending on version. ggseg.extra shells out to ten binaries and reads one
subject, so the image keeps only:

- `bin/`: mri_info, mri_convert, mri_coreg, mri_vol2vol, mri_vol2surf,
  mri_surf2surf, mri_pretess, mri_tessellate, mris_smooth, mris_convert
  (the last one is reached through `freesurfer::mris_convert()`, so grep
  this repo for `mris_` and for `freesurfer::` calls when auditing the list)
- `subjects/fsaverage5` (the package's default subject everywhere)
- `average/mni152.register.dat` (the `registration = "mni152"` path)
- `FreeSurferColorLUT.txt`, `build-stamp.txt`, and the two env scripts the
  freesurfer R package reads
- the shared objects under `lib/` that `ldd` resolves for those binaries

`include.txt` is the whitelist. Extraction streams the tarball through `tar -T`,
so only whitelisted members ever touch disk. `lib/` is extracted whole in the
first stage purely so `ldd` can pick the needed objects; the rest is dropped
before the final stage.

The image also carries ImageMagick 7 from the official portable build, since
`has_magick()` probes the `magick` binary and Ubuntu's apt package is
version 6. With it, every test in the suite runs in the container.

## Adding a binary or subject

Append the tarball member path to `include.txt` (directories extract
recursively). The final stage fails the build if any retained binary has an
unresolved library, so a missing system package shows up at build time.

`subjects/fsaverage` is deliberately absent. Add it if a test needs
`--srcsubject fsaverage` or a surface-to-surface resample onto it.

## License

FreeSurfer's license permits redistribution with attribution. The per-user
`license.txt` is not in the image; `freesurfer-tests.yaml` writes it from the
`FREESURFER_LICENSE` secret at run time and fails if the secret is missing.
