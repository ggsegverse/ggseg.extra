# Read FreeSurfer surface mesh file

Reads a FreeSurfer surface file and returns vertex/face data. This is a
low-level I/O function for extracting meshes from FreeSurfer subjects.
For retrieving pre-built brain meshes, use
[`ggseg.formats::get_brain_mesh()`](https://ggsegverse.github.io/ggseg.formats/reference/get_brain_mesh.html)
instead.

## Usage

``` r
read_fs_mesh(
  subject = "fsaverage5",
  hemisphere = c("lh", "rh"),
  surface = c("inflated", "white", "pial"),
  subjects_dir = freesurfer::fs_subj_dir()
)
```

## Arguments

- subject:

  FreeSurfer subject (default "fsaverage5")

- hemisphere:

  "lh" or "rh"

- surface:

  Surface type: "inflated", "white", "pial"

- subjects_dir:

  FreeSurfer subjects directory

## Value

list with vertices (data.frame with x, y, z) and faces (data.frame with
i, j, k)
