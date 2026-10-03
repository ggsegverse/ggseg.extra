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

