# warn_deprecated_sf_smoothing / warns once per supplied argument when several are passed together

    Code
      warn_deprecated_sf_smoothing(tolerance = 0.1, smoothness = 2)
    Condition
      Warning:
      `tolerance()` was deprecated in ggseg.extra 1.9.9.9005.
      i Atlas creation no longer smooths or simplifies sf geometry. Call `atlas_simplify(atlas, keep = ...)` on the returned atlas instead. Use `exclude = "cortex_"` to keep the brain outline crisp.
      Warning:
      `smoothness()` was deprecated in ggseg.extra 1.9.9.9005.
      i Atlas creation no longer smooths or simplifies sf geometry. Call `atlas_simplify(atlas, keep = ...)` on the returned atlas instead. Use `exclude = "cortex_"` to keep the brain outline crisp.

