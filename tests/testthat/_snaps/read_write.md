# check_bin_args / rejects conflicting or unusable bin specifications

    Code
      check_bin_args(5, c(0, 1, 2))
    Condition
      Error:
      ! Supply `n_bins` or `breaks`, not both.
      i `breaks` already fixes how many bins there are.
    Code
      check_bin_args(2.5, NULL)
    Condition
      Error:
      ! `n_bins` must be a single whole number, not 2.5.
    Code
      check_bin_args(0, NULL)
    Condition
      Error:
      ! `n_bins` must be at least 1, not 0.
    Code
      check_bin_args(NULL, c(2, 1))
    Condition
      Error:
      ! `breaks` must give at least two increasing numbers, the edges of the bins.
      x Got a double vector: 2, 1.
      i A function passed as `breaks` must return such a vector.
    Code
      check_bin_args(NULL, 4)
    Condition
      Error:
      ! `breaks` must give at least two increasing numbers, the edges of the bins.
      x Got a number: 4.
      i A function passed as `breaks` must return such a vector.

