# Create brain surface meshes for ggseg3d

Creates brain surface mesh data for all combinations of hemispheres and
surface types. This data should be stored in ggseg3d for shared use
across all atlases.

## Usage

``` r
make_brain_meshes(
  subject = "fsaverage5",
  surfaces = c("inflated", "white", "pial"),
  subjects_dir = fs_subj_dir()
)
```

## Arguments

- subject:

  FreeSurfer subject (default "fsaverage5")

- surfaces:

  Surface types to extract

- subjects_dir:

  FreeSurfer subjects directory

## Value

Named list of meshes, with names like "lh_inflated", "rh_white", etc.
