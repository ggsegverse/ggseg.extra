# check_breaks / rejects what is neither a bin count nor bin edges

    Code
      check_breaks(2.5)
    Condition
      Error:
      ! `breaks` must be a number of bins, or at least two increasing numbers giving their edges.
      x Got a number: 2.5.
      i A function passed as `breaks` must return the edges.
    Code
      check_breaks(0)
    Condition
      Error:
      ! `breaks` must be a number of bins, or at least two increasing numbers giving their edges.
      x Got a number: 0.
      i A function passed as `breaks` must return the edges.
    Code
      check_breaks(c(2, 1))
    Condition
      Error:
      ! `breaks` must be a number of bins, or at least two increasing numbers giving their edges.
      x Got a double vector: 2, 1.
      i A function passed as `breaks` must return the edges.
    Code
      check_breaks("quartiles")
    Condition
      Error:
      ! `breaks` must be a number of bins, or at least two increasing numbers giving their edges.
      x Got a string.
      i A function passed as `breaks` must return the edges.

