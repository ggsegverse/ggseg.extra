# Read mesh data from PLY file

Reads an ASCII PLY file and extracts vertices and faces into a list
format suitable for ggseg3d.

## Usage

``` r
read_ply_mesh(ply, ...)
```

## Arguments

- ply:

  path to ply-file

- ...:

  ignored, kept for backward compatibility

## Value

list with vertices (data.frame with x, y, z) and faces (data.frame with
i, j, k)
