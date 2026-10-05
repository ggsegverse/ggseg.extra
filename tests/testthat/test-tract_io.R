describe("read_tractography", {
  it("errors on unsupported format", {
    tmp <- withr::local_tempfile(fileext = ".xyz")
    writeLines("dummy", tmp)

    expect_error(read_tractography(tmp), "Unsupported tractography format")
  })

  it("dispatches to read_trk for .trk files", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 1L,
      n_scalars = 0L,
      n_properties = 0L
    )
    writeBin(header, con)
    writeBin(3L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6, 7, 8, 9)), con, size = 4)
    close(con)

    result <- read_tractography(tmp)

    expect_type(result, "list")
    expect_length(result, 1)
  })

  it("dispatches to read_tck for .tck files", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(c("mrtrix tracks", "datatype: Float32LE", "END"), con)
    writeBin(as.numeric(c(1, 2, 3)), con, size = 4)
    writeBin(as.numeric(c(Inf, Inf, Inf)), con, size = 4)
    close(con)

    result <- read_tractography(tmp)

    expect_type(result, "list")
  })
})


describe("read_trk", {
  it("errors on invalid TRK file", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    writeBin(charToRaw("INVALID HEADER DATA"), tmp)

    expect_error(read_trk(tmp), "Invalid TRK")
  })

  it("reads valid TRK file with one streamline", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 1L,
      n_scalars = 0L,
      n_properties = 0L
    )
    writeBin(header, con)
    writeBin(3L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6, 7, 8, 9)), con, size = 4)
    close(con)

    result <- read_trk(tmp)

    expect_type(result, "list")
    expect_length(result, 1)
    expect_identical(nrow(result[[1]]), 3L)
    expect_identical(colnames(result[[1]]), c("x", "y", "z"))
  })

  it("reads TRK file with multiple streamlines", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 2L,
      n_scalars = 0L,
      n_properties = 0L
    )
    writeBin(header, con)
    writeBin(2L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6)), con, size = 4)
    writeBin(2L, con, size = 4)
    writeBin(as.numeric(c(7, 8, 9, 10, 11, 12)), con, size = 4)
    close(con)

    result <- read_trk(tmp)

    expect_length(result, 2)
    expect_identical(nrow(result[[1]]), 2L)
    expect_identical(nrow(result[[2]]), 2L)
  })

  it("reads to EOF when the header track count is 0 (spec-valid)", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 0L,
      n_scalars = 0L,
      n_properties = 0L
    )
    writeBin(header, con)
    writeBin(2L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6)), con, size = 4)
    writeBin(2L, con, size = 4)
    writeBin(as.numeric(c(7, 8, 9, 10, 11, 12)), con, size = 4)
    close(con)

    result <- read_trk(tmp)

    expect_length(result, 2)
    expect_identical(nrow(result[[1]]), 2L)
    expect_identical(nrow(result[[2]]), 2L)
  })

  it("handles TRK with scalars", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 1L,
      n_scalars = 1L,
      n_properties = 0L
    )
    writeBin(header, con)
    writeBin(2L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 0.5, 4, 5, 6, 0.8)), con, size = 4)
    close(con)

    result <- read_trk(tmp)

    expect_length(result, 1)
    expect_identical(ncol(result[[1]]), 3L)
  })

  it("handles TRK with properties", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 1L,
      n_scalars = 0L,
      n_properties = 1L
    )
    writeBin(header, con)
    writeBin(2L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6)), con, size = 4)
    writeBin(42.0, con, size = 4)
    close(con)

    result <- read_trk(tmp)

    expect_length(result, 1)
    expect_identical(nrow(result[[1]]), 2L)
  })
})


describe("read_trk world coordinates", {
  it("converts voxmm points to RAS millimetres with the header transform", {
    vox_to_ras <- diag(c(2, 2, 2, 1))
    vox_to_ras[1:3, 4] <- c(-10, -20, -30)
    path <- local_trk_file(
      trk_header(voxel_size = c(2, 2, 2), vox_to_ras = vox_to_ras),
      matrix(c(3, 5, 7), ncol = 3)
    )

    expect_identical(unname(read_trk(path)[[1]][1, ]), c(-8, -16, -24))
  })

  it("flips axes whose stored order differs from the transform's", {
    path <- local_trk_file(
      trk_header(dims = c(10L, 12L, 14L), voxel_order = "LPS"),
      matrix(c(1.5, 2.5, 3.5), ncol = 3)
    )

    expect_identical(unname(read_trk(path)[[1]][1, ]), c(8, 9, 3))
  })

  it("places a big-endian file where its little-endian twin lands", {
    points <- matrix(c(3, 5, 7, 4, 6, 8), ncol = 3, byrow = TRUE)
    little <- local_trk_file(trk_header(voxel_size = c(2, 1, 4)), points)
    big <- local_trk_file(
      trk_header(voxel_size = c(2, 1, 4), endian = "big"),
      points
    )

    expect_identical(read_trk(big), read_trk(little))
  })

  it("warns that placement is untrusted without a recorded transform", {
    path <- local_trk_file(
      trk_header(vox_to_ras = matrix(0, 4, 4)),
      matrix(c(1.5, 2.5, 3.5), ncol = 3)
    )

    expect_warning(
      result <- read_trk(path),
      "does not record a voxel-to-world transform"
    )
    expect_identical(unname(result[[1]][1, ]), c(1, 2, 3))
  })

  it("aborts on a header that cannot place the points", {
    no_size <- local_trk_file(
      trk_header(voxel_size = c(0, 0, 0)),
      matrix(c(1, 2, 3), ncol = 3)
    )
    bad_order <- local_trk_file(
      trk_header(voxel_order = "RRS"),
      matrix(c(1, 2, 3), ncol = 3)
    )
    wrong_size <- trk_header()
    wrong_size[997:1000] <- writeBin(999L, raw(), size = 4)
    not_trk <- local_trk_file(wrong_size, matrix(c(1, 2, 3), ncol = 3))

    expect_error(read_trk(no_size), "no usable voxel size")
    expect_error(read_trk(bad_order), "unusable voxel order")
    expect_error(read_trk(not_trk), "Invalid TRK")
  })
})


describe("read_tck", {
  it("reads valid TCK format with header", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(
      c(
        "mrtrix tracks",
        "datatype: Float32LE",
        "END"
      ),
      con
    )
    writeBin(as.numeric(c(1, 2, 3)), con, size = 4)
    writeBin(as.numeric(c(NaN, NaN, NaN)), con, size = 4)
    writeBin(as.numeric(c(Inf, Inf, Inf)), con, size = 4)
    close(con)

    result <- read_tck(tmp)

    expect_type(result, "list")
  })

  it("reads multiple streamlines separated by NaN", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(c("mrtrix tracks", "datatype: Float32LE", "END"), con)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6)), con, size = 4)
    writeBin(as.numeric(c(NaN, NaN, NaN)), con, size = 4)
    writeBin(as.numeric(c(7, 8, 9)), con, size = 4)
    writeBin(as.numeric(c(Inf, Inf, Inf)), con, size = 4)
    close(con)

    result <- read_tck(tmp)

    expect_length(result, 2)
    expect_identical(nrow(result[[1]]), 2L)
    expect_identical(nrow(result[[2]]), 1L)
  })

  it("handles trailing streamline without NaN separator", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(c("mrtrix tracks", "datatype: Float32LE", "END"), con)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6)), con, size = 4)
    writeBin(as.numeric(c(Inf, Inf, Inf)), con, size = 4)
    close(con)

    result <- read_tck(tmp)

    expect_length(result, 1)
    expect_identical(nrow(result[[1]]), 2L)
  })

  it("handles Float64LE datatype", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(c("mrtrix tracks", "datatype: Float64LE", "END"), con)
    writeBin(as.numeric(c(1, 2, 3)), con, size = 8)
    writeBin(as.numeric(c(Inf, Inf, Inf)), con, size = 8)
    close(con)

    result <- read_tck(tmp)

    expect_length(result, 1)
    expect_identical(nrow(result[[1]]), 1L)
  })

  it("breaks when file is truncated (coords length < 3)", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(c("mrtrix tracks", "datatype: Float32LE", "END"), con)
    writeBin(as.numeric(c(1, 2, 3)), con, size = 4)
    writeBin(as.numeric(c(NaN, NaN, NaN)), con, size = 4)
    writeBin(7, con, size = 4)
    close(con)

    result <- read_tck(tmp)

    expect_length(result, 1)
    expect_identical(nrow(result[[1]]), 1L)
  })
})


describe("read_tck data offset", {
  it("starts reading at the offset the header declares, not after END", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    header <- c("mrtrix tracks", "datatype: Float32LE", "file: . 64", "END")
    header_bytes <- charToRaw(paste0(paste(header, collapse = "\n"), "\n"))
    padding <- raw(64L - length(header_bytes))
    con <- file(tmp, "wb")
    writeBin(c(header_bytes, padding), con)
    writeBin(c(1, 2, 3, 4, 5, 6, NaN, NaN, NaN, Inf, Inf, Inf), con, size = 4)
    close(con)

    result <- read_tck(tmp)

    expect_length(result, 1)
    expect_identical(
      result[[1]],
      matrix(
        c(1, 2, 3, 4, 5, 6),
        ncol = 3,
        byrow = TRUE,
        dimnames = list(NULL, c("x", "y", "z"))
      )
    )
  })

  it("ignores everything after the end-of-file triplet", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(c("mrtrix tracks", "datatype: Float32LE", "END"), con)
    writeBin(c(1, 2, 3, Inf, Inf, Inf, 7, 8, 9), con, size = 4)
    close(con)

    result <- read_tck(tmp)

    expect_length(result, 1)
    expect_identical(unname(result[[1]][1, ]), c(1, 2, 3))
  })

  it("returns no streamlines for a file with no points", {
    tmp <- withr::local_tempfile(fileext = ".tck")
    con <- file(tmp, "wb")
    writeLines(c("mrtrix tracks", "datatype: Float32LE", "END"), con)
    writeBin(c(Inf, Inf, Inf), con, size = 4)
    close(con)

    expect_identical(read_tck(tmp), list())
  })
})


describe("parse_tck_data_offset", {
  it("reads the byte offset from the file field", {
    expect_identical(parse_tck_data_offset(c("count: 1", "file: . 337")), 337)
  })

  it("is NA when the header declares no usable offset", {
    expect_identical(parse_tck_data_offset("datatype: Float32LE"), NA_real_)
    expect_identical(parse_tck_data_offset("file: . soon"), NA_real_)
  })
})


describe("read_trk early break", {
  it("breaks when n_pts is zero", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 2L,
      n_scalars = 0L,
      n_properties = 0L
    )
    writeBin(header, con)
    writeBin(3L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6, 7, 8, 9)), con, size = 4)
    writeBin(0L, con, size = 4)
    close(con)

    # The header declares 2 and the file holds 1, which is now reported.
    expect_warning(
      result <- read_trk(tmp),
      "header declares 2"
    )

    expect_length(result, 1)
    expect_identical(nrow(result[[1]]), 3L)
  })

  it("breaks when n_pts is negative", {
    tmp <- withr::local_tempfile(fileext = ".trk")
    con <- file(tmp, "wb")
    header <- trk_header(
      n_count = 2L,
      n_scalars = 0L,
      n_properties = 0L
    )
    writeBin(header, con)
    writeBin(3L, con, size = 4)
    writeBin(as.numeric(c(1, 2, 3, 4, 5, 6, 7, 8, 9)), con, size = 4)
    writeBin(-1L, con, size = 4)
    close(con)

    # The header declares 2 and the file holds 1, which is now reported.
    expect_warning(
      result <- read_trk(tmp),
      "header declares 2"
    )

    expect_length(result, 1)
    expect_identical(nrow(result[[1]]), 3L)
  })
})


describe("tck_datatype_byte_size", {
  it("returns 4 bytes for Float32 datatypes", {
    expect_identical(tck_datatype_byte_size("Float32LE"), 4)
    expect_identical(tck_datatype_byte_size("Float32BE"), 4)
  })

  it("returns 8 bytes for Float64 datatypes", {
    expect_identical(tck_datatype_byte_size("Float64LE"), 8)
    expect_identical(tck_datatype_byte_size("Float64BE"), 8)
  })

  it("falls back to 4 bytes for unknown datatypes", {
    expect_identical(tck_datatype_byte_size("Int16LE"), 4)
    expect_identical(tck_datatype_byte_size("bogus"), 4)
  })
})


describe("read_trk_streamline", {
  it("aborts on a streamline truncated mid-record", {
    path <- withr::local_tempfile(fileext = ".trk")
    con <- file(path, "wb")
    writeBin(5L, con, size = 4)
    writeBin(c(1, 2, 3, 4, 5), con, size = 4)
    close(con)

    con <- file(path, "rb")
    withr::defer(close(con))

    expect_error(
      read_trk_streamline(con, n_scalars = 0L, n_properties = 0L),
      "Truncated streamline"
    )
  })
})


describe("warn_short_trk", {
  it("reports a file that ends before its header's count", {
    expect_warning(warn_short_trk(10L, 3L), "declares 10")
  })

  it("says nothing when the header records no count", {
    # 0 means "not recorded, read to end of file" in the TrackVis spec, so it
    # is not a promise the file can break.
    expect_no_warning(warn_short_trk(0L, 3L))
  })

  it("says nothing when every declared streamline was read", {
    expect_no_warning(warn_short_trk(3L, 3L))
    expect_no_warning(warn_short_trk(3L, 4L))
  })
})
