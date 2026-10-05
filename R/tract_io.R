# Tractography file reading ----

#' Read tractography file
#'
#' Load streamlines from a tractography file. Supports TrackVis (`.trk`) and
#' MRtrix (`.tck`) formats. The file format is detected from the extension.
#'
#' @param file Path to a `.trk` or `.tck` file.
#' @return A list of matrices, one per streamline. Each matrix has N rows
#'   (points along the streamline) and 3 columns (x, y, z coordinates), in
#'   RAS world millimetres.
#' @details Format-specific readers are used internally depending on the
#'   file extension: `.trk` (TrackVis) and `.tck` (MRtrix).
#' @export
#' @examples
#' \dontrun{
#' streamlines <- read_tractography("bundle.trk")
#' }
read_tractography <- function(file) {
  ext <- tolower(tools::file_ext(file))

  if (ext == "trk") {
    return(read_trk(file))
  }

  if (ext == "tck") {
    return(read_tck(file))
  }

  cli::cli_abort(c(
    "Unsupported tractography format: {.file {basename(file)}}",
    "i" = "Supported formats: .trk (TrackVis), .tck (MRtrix)"
  ))
}


#' Read TrackVis TRK file
#'
#' Parse a TrackVis `.trk` file and return its streamlines in RAS world
#' millimetres. The file stores points in TrackVis "voxmm" space -- voxel
#' coordinates scaled by the voxel size, with the origin at the corner of the
#' first voxel and the axes ordered as the header's `voxel_order` says -- so
#' the header is needed to place them.
#'
#' @param file Path to a `.trk` file.
#' @return A list of matrices, one per streamline. Each matrix has columns
#'   x, y, z.
#' @seealso [read_tractography()] for format auto-detection
#' @keywords internal
#' @noRd
read_trk <- function(file) {
  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)

  header <- parse_trk_header(readBin(con, "raw", 1000), file)
  to_ras <- trk_voxmm_to_ras(header)

  seek(con, 1000)

  # The header's stored track count is unreliable: the TrackVis spec allows 0
  # to mean "count not recorded, read to EOF", and some writers leave it so.
  # Read streamlines until EOF, using a positive n_count only as an upper bound.
  max_tracks <- if (isTRUE(header$n_count > 0L)) header$n_count else Inf

  streamlines <- list()
  while (length(streamlines) < max_tracks) {
    points <- read_trk_streamline(
      con,
      header$n_scalars,
      header$n_properties,
      header$endian
    )
    if (is.null(points)) {
      break
    }
    streamlines[[length(streamlines) + 1L]] <- points
  }
  warn_short_trk(header$n_count, length(streamlines))

  lapply(streamlines, apply_trk_affine, to_ras)
}


#' Parse the fields of a 1000-byte TrackVis header that place the streamlines
#' @noRd
parse_trk_header <- function(header, file) {
  is_trk <- length(header) == 1000L &&
    identical(header[1:5], charToRaw("TRACK"))
  if (!is_trk) {
    cli::cli_abort("Invalid TRK file: {.path {file}}")
  }

  endian <- trk_header_endian(header, file)
  read_int <- function(bytes, size) {
    readBin(
      header[bytes],
      "integer",
      length(bytes) / size,
      size,
      endian = endian
    )
  }
  read_float <- function(bytes) {
    readBin(header[bytes], "double", length(bytes) / 4L, 4L, endian = endian)
  }

  voxel_size <- read_float(13:24)
  if (anyNA(voxel_size) || any(voxel_size <= 0)) {
    cli::cli_abort(c(
      "TRK file has no usable voxel size: {.path {file}}",
      "x" = "The header records {.val {voxel_size}}.",
      "i" = "Streamline points are stored scaled by the voxel size, so they
      cannot be placed without it."
    ))
  }

  list(
    dims = read_int(7:12, 2L),
    voxel_size = voxel_size,
    n_scalars = read_int(37:38, 2L),
    n_properties = read_int(239:240, 2L),
    vox_to_ras = matrix(read_float(441:504), nrow = 4, byrow = TRUE),
    voxel_order = rawToChar(header[949:951][header[949:951] != as.raw(0)]),
    n_count = read_int(989:992, 4L),
    endian = endian
  )
}


#' Tell a TrackVis header's byte order from its header-size field
#'
#' The last field of the header is its own size, always 1000, so the byte
#' order that reads it as 1000 is the one the file was written in.
#' @noRd
trk_header_endian <- function(header, file) {
  for (endian in c("little", "big")) {
    hdr_size <- readBin(header[997:1000], "integer", 1, 4, endian = endian)
    if (identical(hdr_size, 1000L)) {
      return(endian)
    }
  }
  cli::cli_abort(c(
    "Invalid TRK file: {.path {file}}",
    "x" = "The header does not record its size as 1000 bytes in either byte
    order."
  ))
}


#' Build the affine taking TrackVis voxmm points to RAS world millimetres
#'
#' Four steps, composed: divide by the voxel size (voxmm to voxel), shift by
#' half a voxel (corner origin to voxel centre), reorder and flip axes from
#' the header's `voxel_order` to the order `vox_to_ras` expects, then apply
#' `vox_to_ras`. The axis step follows nibabel's TRK reader, the reference
#' implementation other tools round-trip against.
#' @noRd
trk_voxmm_to_ras <- function(header) {
  vox_to_ras <- header$vox_to_ras
  if (vox_to_ras[4, 4] == 0) {
    cli::cli_warn(
      c(
        "TRK header does not record a voxel-to-world transform.",
        "i" = "Reading the streamlines as voxel coordinates in RAS
        orientation. Their placement in world space cannot be trusted."
      ),
      wrap = TRUE
    )
    vox_to_ras <- diag(4)
  }

  to_voxel <- diag(c(1 / header$voxel_size, 1))
  to_centre <- diag(4)
  to_centre[1:3, 4] <- -0.5

  vox_to_ras %*%
    trk_reorient_affine(header$voxel_order, vox_to_ras, header$dims) %*%
    to_centre %*%
    to_voxel
}


#' Affine reordering voxel axes from the header's order to the transform's
#' @noRd
trk_reorient_affine <- function(voxel_order, vox_to_ras, dims) {
  stored <- trk_axes_from_codes(voxel_order)
  expected <- trk_axes_from_affine(vox_to_ras)

  reorient <- matrix(0, 4, 4)
  reorient[4, 4] <- 1
  for (i in 1:3) {
    source_axis <- match(stored$world[i], expected$world)
    flip <- stored$sign[i] * expected$sign[source_axis]
    reorient[i, source_axis] <- flip
    if (flip < 0) {
      reorient[i, 4] <- dims[i] - 1
    }
  }
  reorient
}


#' World axis and direction of each voxel axis, from codes such as `"LPS"`
#'
#' An empty code means the writer did not record one; TrackVis's own default
#' is `"LPS"`.
#' @noRd
trk_axes_from_codes <- function(voxel_order) {
  if (!nzchar(voxel_order)) {
    voxel_order <- "LPS"
  }
  codes <- strsplit(toupper(voxel_order), "", fixed = TRUE)[[1]]
  positive <- match(codes, c("R", "A", "S"))
  negative <- match(codes, c("L", "P", "I"))
  world <- ifelse(is.na(positive), negative, positive)

  if (length(codes) != 3L || !setequal(world, 1:3)) {
    cli::cli_abort(c(
      "TRK header has an unusable voxel order: {.val {voxel_order}}",
      "i" = "Expected one letter per axis from L/R, P/A and I/S, such as
      {.val LPS}."
    ))
  }
  list(world = world, sign = ifelse(is.na(positive), -1, 1))
}


#' World axis and direction of each voxel axis, from a voxel-to-world affine
#' @noRd
trk_axes_from_affine <- function(vox_to_ras) {
  rotation <- vox_to_ras[1:3, 1:3]
  world <- apply(abs(rotation), 2, which.max)

  if (!setequal(world, 1:3)) {
    cli::cli_abort(c(
      "TRK header's voxel-to-world transform does not map each voxel axis
      to its own world axis.",
      "i" = "The file cannot be placed in world space."
    ))
  }
  list(world = world, sign = sign(rotation[cbind(world, 1:3)]))
}


#' Apply a 4x4 affine to an x/y/z point matrix
#' @noRd
apply_trk_affine <- function(points, affine) {
  moved <- points %*% t(affine[1:3, 1:3])
  moved <- sweep(moved, 2, affine[1:3, 4], "+")
  colnames(moved) <- c("x", "y", "z")
  moved
}


#' Say when a TRK file holds fewer streamlines than its header promises
#'
#' A count of 0 means "not recorded, read to end of file", so it is not a
#' promise and nothing is reported. A positive count is one the writer chose
#' to record, and a file that ends before it is reached is either truncated or
#' mis-written -- either way the tract is built from less than it should be,
#' and reading short used to be silent.
#' @noRd
warn_short_trk <- function(n_count, n_read) {
  if (!isTRUE(n_count > 0L) || n_read >= n_count) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "Read {n_read} streamline{?s} from a TRK file whose header declares
      {n_count}.",
      "i" = "The file ends before the count its header records. The tract is
      built from the streamlines that are there."
    ),
    wrap = TRUE
  )
  invisible(NULL)
}

#' Read one TRK streamline's x/y/z coordinates, or `NULL` at end of file
#' @noRd
read_trk_streamline <- function(
  con,
  n_scalars,
  n_properties,
  endian = "little"
) {
  n_pts <- readBin(con, "integer", 1, size = 4, endian = endian)
  if (length(n_pts) == 0L || is.na(n_pts) || n_pts <= 0) {
    return(NULL)
  }

  n_values <- n_pts * (3L + n_scalars)
  values <- readBin(con, "double", n_values, size = 4, endian = endian)
  if (length(values) < n_values) {
    cli::cli_abort(c(
      "Truncated streamline in TRK file",
      "x" = "Expected {n_values} value{?s}, read {length(values)}.",
      "i" = "The file ends part-way through a streamline record."
    ))
  }

  points <- matrix(
    values,
    ncol = 3 + n_scalars,
    byrow = TRUE
  )[, 1:3, drop = FALSE]
  colnames(points) <- c("x", "y", "z")

  if (n_properties > 0) {
    readBin(con, "double", n_properties, size = 4, endian = endian)
  }

  points
}


#' Read MRtrix TCK file
#'
#' Parse an MRtrix `.tck` file and extract all streamlines.
#'
#' @param file Path to a `.tck` file.
#' @return A list of matrices, one per streamline. Each matrix has columns
#'   x, y, z.
#' @seealso [read_tractography()] for format auto-detection
#' @keywords internal
#' @noRd
read_tck <- function(file) {
  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)

  header_lines <- read_tck_header(con)
  datatype <- parse_tck_datatype(header_lines)
  byte_size <- tck_datatype_byte_size(datatype)
  endian <- if (grepl("BE$", datatype)) "big" else "little"

  data_offset <- parse_tck_data_offset(header_lines)
  if (!is.na(data_offset)) {
    seek(con, data_offset)
  }

  n_values <- (file.size(file) - seek(con)) %/% byte_size
  values <- readBin(con, "double", n_values, size = byte_size, endian = endian)

  split_tck_streamlines(values)
}


#' Split a TCK coordinate stream into streamlines
#'
#' An all-NaN triplet ends a streamline and the first all-Inf triplet ends the
#' file. Values after a trailing incomplete triplet are dropped.
#'
#' @param values Numeric vector of consecutive x, y, z values.
#' @return A list of matrices with columns x, y, z.
#' @noRd
split_tck_streamlines <- function(values) {
  n_points <- length(values) %/% 3L
  points <- matrix(
    values[seq_len(n_points * 3L)],
    ncol = 3,
    byrow = TRUE,
    dimnames = list(NULL, c("x", "y", "z"))
  )

  end_of_file <- which(rowSums(is.infinite(points)) == 3L)
  if (length(end_of_file) > 0) {
    points <- points[seq_len(end_of_file[1] - 1L), , drop = FALSE]
  }

  is_separator <- rowSums(is.nan(points)) == 3L
  streamline_id <- cumsum(is_separator)[!is_separator]
  points <- points[!is_separator, , drop = FALSE]

  unname(lapply(
    split(seq_len(nrow(points)), streamline_id),
    function(rows) points[rows, , drop = FALSE]
  ))
}


#' Extract the byte offset of the track data from TCK header lines
#'
#' The `file: . <offset>` field says where the data starts, which can be past
#' the `END` line when the writer pads the header.
#'
#' @return The offset in bytes, or `NA` when the header does not declare one.
#' @noRd
parse_tck_data_offset <- function(header_lines) {
  field <- grep("^file:", header_lines, value = TRUE)
  if (length(field) == 0) {
    return(NA_real_)
  }
  offset <- sub("^file:\\s*\\S+\\s+", "", field[length(field)])
  if (!grepl("^[0-9]+$", offset)) {
    return(NA_real_)
  }
  as.numeric(offset)
}


#' Read TCK header lines up to the END marker
#' @noRd
read_tck_header <- function(con) {
  header_lines <- character()
  while (TRUE) {
    line <- readLines(con, 1)
    if (length(line) == 0 || line == "END") {
      break
    }
    header_lines <- c(header_lines, line)
  }
  header_lines
}


#' Extract the datatype field from TCK header lines
#' @noRd
parse_tck_datatype <- function(header_lines) {
  datatype <- "float32"
  for (line in header_lines) {
    if (grepl("^datatype:", line)) {
      datatype <- trimws(sub("datatype:", "", line, fixed = TRUE))
    }
  }
  datatype
}


#' Map a TCK datatype string to its element byte size
#' @noRd
tck_datatype_byte_size <- function(datatype) {
  switch(
    datatype,
    "Float32LE" = 4,
    "Float32BE" = 4,
    "Float64LE" = 8,
    "Float64BE" = 8,
    4
  )
}
