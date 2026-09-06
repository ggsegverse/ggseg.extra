# atlas_dilate / rejects both selectors at once

    Code
      atlas_dilate(mk_atlas(), 0.5, labels = "a", exclude = "b")
    Condition
      Error in `check_dilate_args()`:
      ! Specify only one of `labels` or `exclude`, not both.

# atlas_dilate / rejects a non-numeric amount

    Code
      atlas_dilate(mk_atlas(), "lots")
    Condition
      Error in `check_dilate_args()`:
      ! `amount` must be a single number.

