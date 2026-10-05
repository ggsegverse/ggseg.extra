# Tractography file reading ----

#' Read tractography file
#'
#' Load streamlines from a tractography file. Supports TrackVis (`.trk`) and
#' MRtrix (`.tck`) formats. The file format is detected from the extension.
#'
#' @param file Path to a `.trk` or `.tck` file.
#' @return A list of matrices, one per streamline. Each matrix has N rows
#'   (points along the streamline) and 3 columns (x, y, z coordinates).
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
#' Parse a TrackVis `.trk` file and extract all streamlines.
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

  header <- readBin(con, "raw", 1000)
  id_string <- rawToChar(header[1:6])

  if (!grepl("TRACK", id_string, fixed = TRUE)) {
    cli::cli_abort("Invalid TRK file: {file}")
  }

  n_scalars <- readBin(header[37:38], "integer", 1, size = 2)
  n_properties <- readBin(header[239:240], "integer", 1, size = 2)
  n_count <- readBin(header[989:992], "integer", 1, size = 4)

  seek(con, 1000)

  # The header's stored track count is unreliable: the TrackVis spec allows 0
  # to mean "count not recorded, read to EOF", and some writers leave it so.
  # Read streamlines until EOF, using a positive n_count only as an upper bound.
  max_tracks <- if (isTRUE(n_count > 0L)) n_count else Inf

  streamlines <- list()
  while (length(streamlines) < max_tracks) {
    points <- read_trk_streamline(con, n_scalars, n_properties)
    if (is.null(points)) {
      break
    }
    streamlines[[length(streamlines) + 1L]] <- points
  }
  warn_short_trk(n_count, length(streamlines))

  streamlines
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
read_trk_streamline <- function(con, n_scalars, n_properties) {
  n_pts <- readBin(con, "integer", 1, size = 4)
  if (length(n_pts) == 0L || is.na(n_pts) || n_pts <= 0) {
    return(NULL)
  }

  n_values <- n_pts * (3L + n_scalars)
  values <- readBin(con, "double", n_values, size = 4)
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
    readBin(con, "double", n_properties, size = 4)
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
