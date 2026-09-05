# post-creation tweaks passed to a pipeline / still errors on a typo, as an unused argument always did

    Code
      check_post_creation_dots("create_subcortical_from_volume", toolerance = 1)
    Condition
      Error in `check_post_creation_dots()`:
      ! unused argument passed to `create_subcortical_from_volume()`.
      x Unknown: `toolerance`.

# post-creation tweaks passed to a pipeline / errors on an unnamed extra argument

    Code
      check_post_creation_dots("create_subcortical_from_volume", 42)
    Condition
      Error in `check_post_creation_dots()`:
      ! unused argument passed to `create_subcortical_from_volume()`.
      x 1 unnamed argument.

# post-creation tweaks passed to a pipeline / names the function the caller actually used

    Code
      check_post_creation_dots("create_tract_from_tractography", tolerance = 1)
    Condition
      Warning:
      The `tolerance` argument of `create_tract_from_tractography()` is deprecated as of ggseg.extra 1.9.9.9005.
      i Atlas creation no longer smooths or simplifies sf geometry. Call `atlas_smooth(atlas, keep = ...)` on the returned atlas instead. Use `exclude = "cortex_"` to keep the brain outline crisp.

