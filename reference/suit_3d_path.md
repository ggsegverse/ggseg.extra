# Path to bundled SUIT 3D cerebellar surface

Returns the path to the SUIT 3D pial surface file
(`tpl-SUIT_3d.surf.gii`) shipped with ggseg.extra. Used for
volume-to-surface sampling of cerebellar parcellation volumes.

## Usage

``` r
suit_3d_path()
```

## Value

File path to the SUIT 3D `.surf.gii` file.

## Examples

``` r
suit_3d_path()
#> [1] "/home/runner/work/_temp/Library/ggseg.extra/extdata/suit/tpl-SUIT_3d.surf.gii"
```
