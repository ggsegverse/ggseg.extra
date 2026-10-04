# check_lut_hemi / names the values that are not a hemisphere

    Code
      check_lut_hemi(lut)
    Condition
      Error in `check_lut_hemi()`:
      ! `input_lut` has 2 labels with an unrecognised hemi
      x Not a hemisphere: "rigth" and "both"
      i Allowed: "left", "right", "midline", and "vermis", or `NA` to read it from the label's name.

# drop_labels_without_geometry / aborts rather than build an atlas with no drawable region

    Code
      drop_labels_without_geometry(make_components(), NULL)
    Condition
      Warning:
      Dropping 2 labels with no geometry.
      x Dropped: "region_a" and "region_b"
      i A label kept in core without a shape counts towards the region total and cannot be drawn.
      Error in `drop_labels_without_geometry()`:
      ! No labels with geometry remain. Cannot build atlas.

