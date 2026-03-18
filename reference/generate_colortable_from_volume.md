# Generate colour table from volume labels

Creates a colour lookup table from unique labels in a volume file.
Region names are generic and colours are NA (no palette).

## Usage

``` r
generate_colortable_from_volume(volume_file)
```

## Arguments

- volume_file:

  Path to volume file

## Value

data.frame with columns: idx, label, R, G, B, A, roi, color
