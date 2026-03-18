# Read FreeSurfer surface file

Reads FreeSurfer surface files including QUAD format from
mri_tessellate. Uses FreeSurfer's mris_convert for robust handling of
all surface formats.

## Usage

``` r
read_fs_surface(file, verbose = get_verbose())
```

## Arguments

- file:

  Path to FreeSurfer surface file

- verbose:

  Verbosity level (0/1/2)

## Value

list with vertices and faces data.frames (faces are 1-indexed)
