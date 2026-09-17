# Generate a palette for a colourless lookup table

Several atlas releases ship a lookup table of names only, with every RGB
channel set to zero. Handed to a creation pipeline as-is, the atlas
arrives with no palette and the plotting packages assign one, which
renders as large blocks of repeated hue. `lut_generate_colors()` fills
the `R`, `G` and `B` columns with a palette built from the label names,
and sets `A` to `0`.

## Usage

``` r
lut_generate_colors(lut, by = NULL, chroma = 75, luminance = c(45, 65, 82))
```

## Arguments

- lut:

  A lookup table with `idx`, `label`, `R`, `G`, `B` and `A` columns, as
  returned by
  [`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md).

- by:

  Optional name of a column whose groups are each coloured from the full
  colour circle, rather than from a slice of one shared circle. Pass
  `by = "type"` for a whole-brain table, where the cortical and
  subcortical rows become two atlases that are never plotted together: a
  colour then has to be unique within an atlas rather than within the
  table, and each atlas gets the whole circle to spend. The default,
  `NULL`, colours the table as one atlas.

- chroma:

  Colour intensity, zero or more, passed to
  [`grDevices::hcl()`](https://rdrr.io/r/grDevices/hcl.html) and held
  constant across the palette. Asking for more than the display can show
  is what makes colours collide, so lowering this is the usual answer to
  the error that reports one.

- luminance:

  Lightness values, 0 to 100, passed to
  [`grDevices::hcl()`](https://rdrr.io/r/grDevices/hcl.html) and cycled
  through in order as the hue advances.

## Value

`lut`, with `R`, `G` and `B` filled in and `A` set to `0` on every row
that is not the background.

## Details

Colours are assigned per *structure*, not per region, so a structure's
two hemispheres share one the way FreeSurfer's own tables do. The
hemisphere marker is read off the label in the spellings the rest of the
package recognises - a `Left-` / `rh_` / `L_` prefix or a `_right` /
`-lh` suffix - plus the `ctx-lh-` and `wm-rh-` prefixes FreeSurfer's
cortical and white-matter tables use. A label carrying none of them is a
structure of its own.

Hues are spread evenly around the colour circle in order of first
appearance, and stepped through `luminance` in turn so that neighbouring
hues still separate. Reordering the table's rows therefore reshuffles
the palette; generate it once and commit the result.

No two structures are given the same colour:
[`grDevices::hcl()`](https://rdrr.io/r/grDevices/hcl.html) clips
out-of-gamut colours without saying so, and where that would hand back a
colour twice this errors rather than let it through. Colours growing
merely *close* is not an error. One chroma and three luminances hold
only so many, and past roughly sixty structures neighbouring hues stop
being easy to tell apart - a limit of the ramp rather than a fault, and
a parcellation that fine is read by hovering a region rather than by
matching it to a legend.

Rows with `idx = 0` are the background rather than a structure, and are
left exactly as they are. Every other row has its `R`, `G`, `B` and `A`
replaced, so run this on a table that has no palette worth keeping.

## See also

[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
to read a table in,
[`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
to write the coloured table back out, and
[`lut_classify_anatomy()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_classify_anatomy.md)
to fill in the `type` column that `by` can group on.

## Examples

``` r
lut <- data.frame(
  idx = 1:4,
  label = c(
    "Left-Hippocampus", "Right-Hippocampus",
    "Amygdala_left", "Amygdala_right"
  ),
  R = 0L, G = 0L, B = 0L, A = 0L
)
lut_generate_colors(lut)
#>   idx             label   R   G   B A
#> 1   1  Left-Hippocampus 179  68  97 0
#> 2   2 Right-Hippocampus 179  68  97 0
#> 3   3     Amygdala_left   0 185 166 0
#> 4   4    Amygdala_right   0 185 166 0

# A whole-brain table, where each half becomes an atlas of its own.
lut$type <- c("subcortical", "subcortical", "cortical", "cortical")
lut_generate_colors(lut, by = "type")
#>   idx             label   R  G  B A        type
#> 1   1  Left-Hippocampus 179 68 97 0 subcortical
#> 2   2 Right-Hippocampus 179 68 97 0 subcortical
#> 3   3     Amygdala_left 179 68 97 0    cortical
#> 4   4    Amygdala_right 179 68 97 0    cortical
```
