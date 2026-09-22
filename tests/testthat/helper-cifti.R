mock_cifti_label_table <- function(names, keys, red, green, blue) {
  data.frame(
    Key = keys,
    Red = red,
    Green = green,
    Blue = blue,
    Alpha = 1,
    row.names = names
  )
}

mock_cifti_trans_mat <- function() {
  matrix(c(-2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 90, -126, -72, 1), nrow = 4)
}

mock_subcortical_cii <- function(subcort = c(0L, 101L, 102L, 101L)) {
  mask <- array(FALSE, dim = c(2, 2, 2))
  mask[c(1, 3, 6, 8)] <- TRUE

  list(
    data = list(
      cortex_left = NULL,
      cortex_right = NULL,
      subcort = if (!is.null(subcort)) matrix(subcort, ncol = 1)
    ),
    meta = list(
      subcort = list(mask = mask, trans_mat = mock_cifti_trans_mat()),
      cifti = list(
        labels = list(
          mock_cifti_label_table(
            names = c("???", "Thalamus-L", "Caudate-R", "Putamen-L"),
            keys = c(0, 101, 102, 103),
            red = c(0.667, 1, 0, 0.5),
            green = c(0.667, 0, 1, 0.5),
            blue = c(0.667, 0, 0, 0.5)
          )
        )
      )
    )
  )
}
