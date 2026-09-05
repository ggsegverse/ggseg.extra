# post-creation tweaks passed to a pipeline / names the function the caller actually used

    Code
      warn_post_creation_args("create_tract_from_tractography", tolerance = 1)
    Condition
      Warning:
      The `tolerance` argument of `create_tract_from_tractography()` is deprecated as of ggseg.extra 1.9.9.9016.
      i Please use `atlas_simplify()` instead.
      i Apply it to the finished atlas instead, so retuning it does not mean rebuilding.

