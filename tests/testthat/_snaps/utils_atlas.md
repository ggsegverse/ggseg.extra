# check_lut_hemi / names the values that are not a hemisphere

    Code
      check_lut_hemi(lut)
    Condition
      Error in `check_lut_hemi()`:
      ! `input_lut` has 2 labels with an unrecognised hemi
      x Not a hemisphere: "rigth" and "both"
      i Allowed: "left", "right", and "midline", or `NA` to read it from the label's name. "vermis" is accepted and recorded as "midline".

# setup_atlas_dirs working directory safety / rejects an atlas name that is not one directory name

    Code
      setup_atlas_dirs(output_dir, atlas_name = "")
    Condition
      Error in `check_atlas_name()`:
      ! `atlas_name` must be a single name, not "".
      i It names the working directory inside `output_dir`, so it cannot be empty, "." or "..", or contain a path separator.

# lut_context_values / aborts on a value that is neither

    Code
      lut_context_values(c("TRUE", "backdrop"))
    Condition
      Error in `lut_context_values()`:
      ! The lookup table's context column must be "TRUE" or "FALSE".
      x Not recognised: "backdrop"
      i Leave a row blank or "NA" to make it a region.

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

