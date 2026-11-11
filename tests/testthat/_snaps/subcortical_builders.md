# the views/slabs rename / subcortical_slabs() warns and returns what subcortical_views() does

    Code
      old <- subcortical_slabs(vol, labels = 17, coronal = 3, axial = 2)
    Condition
      Warning:
      `subcortical_slabs()` was deprecated in ggseg.extra 1.9.9.9142.
      i Please use `subcortical_views()` instead.

# the views/slabs rename / accepts the old `slabs` spelling, with a warning, and forwards it

    Code
      got <- resolve_renamed_views(NULL, "S", "f")
    Condition
      Warning:
      The `slabs` argument of `f()` is deprecated as of ggseg.extra 1.9.9.9142.
      i Please use the `views` argument instead.

# the views/slabs rename / refuses both spellings at once

    Code
      resolve_renamed_views("V", "S", "f")
    Condition
      Warning:
      The `slabs` argument of `f()` is deprecated as of ggseg.extra 1.9.9.9142.
      i Please use the `views` argument instead.
      Error in `resolve_renamed_views()`:
      ! Pass either `views` or the deprecated `slabs`, not both.
      i `slabs` was renamed to `views`.

