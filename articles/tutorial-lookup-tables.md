# Tutorial: Lookup tables and colours

A volumetric parcellation is a NIfTI file full of integers. Voxel 4 is
`4`, and nothing in the file says that `4` means the left thalamus or
that it should be drawn in teal. That mapping lives in a separate text
file — a colour lookup table, or LUT — and every volumetric pipeline in
this package asks you for one.

If you got your parcellation from FreeSurfer, the LUT came with it. If
you got it from a paper’s supplementary material, it probably didn’t,
and you have a spreadsheet of region names instead. This tutorial covers
both cases: reading a LUT, building one from nothing, and colouring it.

``` r

library(ggseg.extra)
```

## What counts as a lookup table

A LUT is a plain data frame with six columns. `idx` is the integer in
the volume, `label` is the name, and `R`, `G`, `B` and `A` are the
colour, each 0–255.

``` r

lut <- data.frame(
  idx = 0L,
  label = "Unknown",
  R = 0L, G = 0L, B = 0L, A = 0L
)

is_lut(lut)
#> [1] TRUE
```

[`is_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/is_lut.md)
is the check every pipeline runs before it trusts your table, so it is
worth calling yourself while you build one. It is strict about names — a
table with `index` and `name` columns is a perfectly good data frame and
a useless LUT.

``` r

is_lut(data.frame(index = 1, name = "Thalamus"))
#> [1] FALSE
```

Row `idx = 0` is the background. Every pipeline expects it, and several
functions treat it specially, so leave it in place even when it looks
like clutter.

## Adding regions

[`lut_add()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_add.md)
appends a row and keeps the column types honest, which matters more than
it sounds — a LUT with a double `idx` will not match the integers in
your volume.

``` r

lut <- lut |>
  lut_add(idx = 1L, label = "Left-Thalamus", R = 0L, G = 118L, B = 14L) |>
  lut_add(idx = 2L, label = "Right-Thalamus", R = 0L, G = 118L, B = 14L) |>
  lut_add(idx = 3L, label = "Left-Putamen", R = 236L, G = 13L, B = 176L) |>
  lut_add(idx = 4L, label = "Right-Putamen", R = 236L, G = 13L, B = 176L)

lut
#>   idx          label   R   G   B A
#> 1   0        Unknown   0   0   0 0
#> 2   1  Left-Thalamus   0 118  14 0
#> 3   2 Right-Thalamus   0 118  14 0
#> 4   3   Left-Putamen 236  13 176 0
#> 5   4  Right-Putamen 236  13 176 0
```

`A` defaults to `0`, which is what FreeSurfer writes and what the
pipelines expect. It is an opacity column that nothing in this ecosystem
reads; it exists so the file format round-trips.

## Reading and writing

Real tables come from disk.
[`read_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/read_lut.md)
parses FreeSurfer’s whitespace-separated format, and
[`write_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/write_lut.md)
writes it back:

``` r

path <- file.path(tempdir(), "demo_LUT.txt")
write_lut(lut, path)

cat(readLines(path), sep = "\n")
#>   0  Unknown                           0   0   0   0
#>   1  Left-Thalamus                     0 118  14   0
#>   2  Right-Thalamus                    0 118  14   0
#>   3  Left-Putamen                    236  13 176   0
#>   4  Right-Putamen                   236  13 176   0
```

Reading it back gives you the same table, which is the property you want
when a LUT is under version control alongside the atlas it describes:

``` r

read_lut(path)
#>   idx          label   R   G   B A
#> 1   0        Unknown   0   0   0 0
#> 2   1  Left-Thalamus   0 118  14 0
#> 3   2 Right-Thalamus   0 118  14 0
#> 4   3   Left-Putamen 236  13 176 0
#> 5   4  Right-Putamen 236  13 176 0
```

## Colours you didn’t have to pick

Hand-picking 80 distinguishable colours is not a good use of an
afternoon.
[`lut_generate_colors()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_generate_colors.md)
spreads the palette around the colour circle for you, and — this is the
part that makes it worth using — it gives both hemispheres of a
structure the same colour, because `Left-Thalamus` and `Right-Thalamus`
are one structure seen twice.

``` r

blank <- data.frame(
  idx = 0:4,
  label = c(
    "Unknown",
    "Left-Thalamus", "Right-Thalamus",
    "Left-Putamen", "Right-Putamen"
  ),
  R = 0L, G = 0L, B = 0L, A = 0L
)

lut_generate_colors(blank)
#>   idx          label   R   G   B A
#> 1   0        Unknown   0   0   0 0
#> 2   1  Left-Thalamus 179  68  97 0
#> 3   2 Right-Thalamus 179  68  97 0
#> 4   3   Left-Putamen   0 185 166 0
#> 5   4  Right-Putamen   0 185 166 0
```

Two structures, two colours, and `idx = 0` untouched. Every other row is
overwritten, so run this on a table whose palette you are willing to
lose.

`chroma` and `luminance` control intensity and lightness. If you ask for
a chroma the display cannot render across that many hues, the function
errors rather than quietly handing you two regions the same colour —
lowering `chroma` is the usual fix.

``` r

lut_generate_colors(blank, chroma = 45)
#>   idx          label   R   G   B A
#> 1   0        Unknown   0   0   0 0
#> 2   1  Left-Thalamus 155  86 101 0
#> 3   2 Right-Thalamus 155  86 101 0
#> 4   3   Left-Putamen  59 175 163 0
#> 5   4  Right-Putamen  59 175 163 0
```

### A trap with `by`

`by` names a column whose groups each get the *whole* colour circle
instead of a slice of a shared one. It is built for a whole-brain table
split into `"cortical"` and `"subcortical"`, which become two atlases
that never appear in the same plot — so a colour only has to be unique
within each half.

The trap is that nothing stops you passing a column with one group per
region. Every group then starts at the same point on the circle, and you
get one colour for the entire table:

``` r

grouped <- blank
grouped$region <- label_to_region(grouped$label)

lut_generate_colors(grouped, by = "region")
#>   idx          label   R  G  B A   region
#> 1   0        Unknown   0  0  0 0  unknown
#> 2   1  Left-Thalamus 179 68 97 0 thalamus
#> 3   2 Right-Thalamus 179 68 97 0 thalamus
#> 4   3   Left-Putamen 179 68 97 0  putamen
#> 5   4  Right-Putamen 179 68 97 0  putamen
```

That is the documented behaviour working as designed, and it is still
almost certainly not what you wanted. Keep `by` for coarse splits — two
or three groups, not forty.

## Hex colours for plotting

[`get_lut()`](https://ggsegverse.github.io/ggseg.extra/reference/get_lut.md)
adds the two columns plotting code actually wants: `color`, the hex
string, and `roi`, the zero-padded index that ggseg3d matches on.

``` r

get_lut(lut_generate_colors(blank))
#>   idx          label   R   G   B A  roi   color
#> 1   0        Unknown   0   0   0 0 0000 #000000
#> 2   1  Left-Thalamus 179  68  97 0 0001 #B34461
#> 3   2 Right-Thalamus 179  68  97 0 0002 #B34461
#> 4   3   Left-Putamen   0 185 166 0 0003 #00B9A6
#> 5   4  Right-Putamen   0 185 166 0 0004 #00B9A6
```

It takes a path as well as a data frame, so `get_lut("aseg_LUT.txt")` is
a one-liner for inspecting a table on disk.

## Merging two tables

[`lut_combine()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_combine.md)
stacks tables, which comes up when you are bolting a custom subcortical
parcellation onto a standard cortical one.

It warns about duplicate indices rather than resolving them, and the
warning fires on the common case: both of your tables have a background
row at `idx = 0`.

``` r

extra <- data.frame(
  idx = 0L, label = "Unknown",
  R = 0L, G = 0L, B = 0L, A = 0L
) |>
  lut_add(idx = 10L, label = "Left-Amygdala", R = 103L, G = 255L, B = 255L)

lut_combine(lut, extra)
#> Warning: Duplicate label indices in combined table: 0.
#>   idx          label   R   G   B A
#> 1   0        Unknown   0   0   0 0
#> 2   1  Left-Thalamus   0 118  14 0
#> 3   2 Right-Thalamus   0 118  14 0
#> 4   3   Left-Putamen 236  13 176 0
#> 5   4  Right-Putamen 236  13 176 0
#> 6   0        Unknown   0   0   0 0
#> 7  10  Left-Amygdala 103 255 255 0
```

Drop the duplicate background before combining and the warning goes
away:

``` r

lut_combine(lut, extra[extra$idx != 0L, ])
#>   idx          label   R   G   B A
#> 1   0        Unknown   0   0   0 0
#> 2   1  Left-Thalamus   0 118  14 0
#> 3   2 Right-Thalamus   0 118  14 0
#> 4   3   Left-Putamen 236  13 176 0
#> 5   4  Right-Putamen 236  13 176 0
#> 6  10  Left-Amygdala 103 255 255 0
```

Take the warning seriously when it names an index other than `0`. Two
rows claiming `idx = 12` means one of your regions is about to silently
become the other.

## From label to region name

Atlases carry two names per parcel. `label` is the identifier from the
source parcellation, stable and unambiguous; `region` is what a reader
sees in a legend.

[`label_to_region()`](https://ggsegverse.github.io/ggseg.extra/reference/label_to_region.md)
is the exact rule the pipelines use to derive one from the other — strip
the hemisphere affix, turn separators into spaces, lower-case the
result:

``` r

label_to_region(c("Left-Thalamus", "Pu_Left", "Central_Lateral-Lateral_Posterior_Left"))
#> [1] "thalamus"                          "pu"                               
#> [3] "central lateral lateral posterior"
```

It is exported so that build scripts can reproduce the rule exactly. If
you are writing a metadata table keyed on `region`, key it on
`label_to_region(label)` rather than on a
[`gsub()`](https://rdrr.io/r/base/grep.html) you wrote by hand; that is
how one region quietly joins to `NA`.

Check the output before trusting it. The affixes it strips are a fixed
set, and FreeSurfer’s `ctx-lh-` convention is not among them:

``` r

label_to_region(c("ctx-lh-superiorfrontal", "ctx-rh-superiorfrontal"))
#> [1] "ctx lh superiorfrontal" "ctx rh superiorfrontal"
```

Both hemispheres kept their prefix, so one structure now looks like two
different regions — and `region` is the column that pairs hemispheres.
When your labels use a convention it doesn’t recognise, strip the affix
yourself first.

## Handing the table to a pipeline

Every volumetric builder takes `input_lut`, and every one of them
accepts either a path or a data frame:

``` r

atlas <- create_subcortical_from_volume(
  input_volume = "my_parcellation.nii.gz",
  input_lut = lut,
  atlas_name = "myatlas",
  output_dir = "data-raw"
)
```

Passing the data frame is the better habit. It means the table you
inspected is the table the pipeline used, with no chance of editing one
file and reading another.

For whole-brain volumes there is one more column to fill in.
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
needs to know which labels are cortical, subcortical and cerebellar, and
it will guess from surface coverage if you don’t tell it — noisily, but
it will guess.
[`lut_classify_anatomy()`](https://ggsegverse.github.io/ggseg.extra/reference/lut_classify_anatomy.md)
works the column out properly by overlaying the volume on FreeSurfer’s
`aparc+aseg`:

``` r

lut <- lut_classify_anatomy("my_parcellation.nii.gz", "my_LUT.txt")
write_lut(lut, "my_LUT.txt")
```

Run it once and commit the result. It needs FreeSurfer installed, and
there is no reason to pay for it on every build.

## Where to go next

The LUT is the least glamorous file in an atlas build and the one that
most often explains a broken result. When a region comes out the wrong
colour, missing, or merged with its neighbour, read the table first.

From here, [Post-processing
atlases](https://ggsegverse.github.io/ggseg.extra/articles/post-processing.md)
covers renaming and curating regions once the atlas exists, and the
volumetric tutorials —
[subcortical](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-subcortical-atlas.md),
[whole-brain](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-wholebrain-atlas.md)
and
[cerebellar](https://ggsegverse.github.io/ggseg.extra/articles/tutorial-cerebellar-atlas.md)
— put the table to work.
