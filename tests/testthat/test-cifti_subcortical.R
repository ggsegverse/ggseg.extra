testthat::describe("cifti_subcortical_volume", {
  it("fills mask voxels in array order and zeroes the rest", {
    volume <- cifti_subcortical_volume(mock_subcortical_cii())

    expect_identical(dim(volume), c(2L, 2L, 2L))
    expect_identical(volume[c(1, 3, 6, 8)], c(0L, 101L, 102L, 101L))
    expect_identical(sum(volume != 0L), 3L)
  })

  it("errors when the data and mask sizes differ", {
    expect_error(
      cifti_subcortical_volume(mock_subcortical_cii(subcort = c(101L, 102L))),
      "2 voxels but its mask has 4"
    )
  })
})


testthat::describe("cifti_subcortical_lut", {
  it("keeps the labels present and scales colours to 0-255", {
    lut <- cifti_subcortical_lut(mock_subcortical_cii())

    expect_true(is_lut(lut))
    expect_identical(lut$idx, c(101L, 102L))
    expect_identical(lut$label, c("Thalamus-L", "Caudate-R"))
    expect_identical(lut$R, c(255L, 0L))
    expect_identical(lut$G, c(0L, 255L))
  })
})


testthat::describe("read_cifti_subcortical", {
  it("errors when the file does not exist", {
    skip_if_not_installed("ciftiTools")
    skip_if_not_installed("RNifti")

    expect_error(
      read_cifti_subcortical("nonexistent.dlabel.nii"),
      "not found"
    )
  })

  it("errors when the CIFTI has no subcortical voxels", {
    skip_if_not_installed("ciftiTools")
    skip_if_not_installed("RNifti")
    local_mocked_bindings(
      read_cifti = function(...) mock_subcortical_cii(subcort = NULL),
      .package = "ciftiTools"
    )
    cifti_file <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", cifti_file)

    expect_error(
      read_cifti_subcortical(cifti_file),
      "no subcortical voxels"
    )
  })

  it("writes the label volume with the CIFTI transform and its LUT", {
    skip_if_not_installed("ciftiTools")
    skip_if_not_installed("RNifti")
    local_mocked_bindings(
      read_cifti = function(...) mock_subcortical_cii(),
      .package = "ciftiTools"
    )
    cifti_file <- withr::local_tempfile(fileext = ".dlabel.nii")
    writeLines("mock", cifti_file)
    output_file <- withr::local_tempfile(fileext = ".nii.gz")

    result <- read_cifti_subcortical(cifti_file, output_file)
    image <- RNifti::readNifti(result$volume)
    header <- RNifti::niftiHeader(image)

    expect_identical(result$volume, output_file)
    expect_identical(as.integer(image[c(1, 3, 6, 8)]), c(0L, 101L, 102L, 101L))
    expect_equal(
      RNifti::xform(image),
      mock_cifti_trans_mat(),
      ignore_attr = TRUE
    )
    expect_identical(header$pixdim[2:4], c(2, 2, 2))
    expect_identical(as.integer(header$qform_code), 4L)
    expect_identical(as.integer(header$sform_code), 4L)
    expect_identical(RNifti::pixunits(image)[[1]], "mm")
    expect_identical(result$lut$idx, c(101L, 102L))
    expect_identical(result$lut$label, c("Thalamus-L", "Caudate-R"))
  })
})


testthat::describe("warn_dropped_cifti_subcortex", {
  it("warns with the number of labelled voxels", {
    expect_warning(
      warn_dropped_cifti_subcortex(mock_subcortical_cii(), "atlas.dlabel.nii"),
      "3 labelled subcortical voxels"
    )
  })

  it("is silent when no subcortical voxel is labelled", {
    expect_no_warning(
      warn_dropped_cifti_subcortex(
        mock_subcortical_cii(subcort = c(0L, 0L, 0L, 0L)),
        "atlas.dlabel.nii"
      )
    )
  })

  it("is silent when the CIFTI has no subcortex", {
    expect_no_warning(
      warn_dropped_cifti_subcortex(
        mock_subcortical_cii(subcort = NULL),
        "atlas.dlabel.nii"
      )
    )
  })
})


testthat::describe("ciftitools_min_version", {
  it("matches the Suggests constraint in DESCRIPTION", {
    suggests <- gsub(
      "\\s+",
      " ",
      utils::packageDescription("ggseg.extra", fields = "Suggests")
    )

    expect_match(
      suggests,
      paste0("ciftiTools (>= ", ciftitools_min_version(), ")"),
      fixed = TRUE
    )
  })
})
