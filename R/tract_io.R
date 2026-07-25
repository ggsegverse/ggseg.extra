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

  streamlines
}

#' Read one TRK streamline's x/y/z coordinates, or `NULL` at end of file
#' @noRd
read_trk_streamline <- function(con, n_scalars, n_properties) {
  n_pts <- readBin(con, "integer", 1, size = 4)
  if (length(n_pts) == 0L || is.na(n_pts) || n_pts <= 0) {
    return(NULL)
  }

  points <- matrix(
    readBin(con, "double", n_pts * (3 + n_scalars), size = 4),
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

  streamlines <- list()
  points <- list()

  while (TRUE) {
    coords <- readBin(con, "double", 3, size = byte_size, endian = endian)
    if (length(coords) < 3) {
      break
    }

    if (all(is.infinite(coords))) {
      break
    }

    if (all(is.nan(coords))) {
      if (length(points) > 0) {
        streamlines[[length(streamlines) + 1L]] <- tck_points_to_matrix(points)
        points <- list()
      }
      next
    }

    points[[length(points) + 1L]] <- coords
  }

  if (length(points) > 0) {
    streamlines[[length(streamlines) + 1L]] <- tck_points_to_matrix(points)
  }

  streamlines
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


#' Bind collected TCK points into an x/y/z coordinate matrix
#' @noRd
tck_points_to_matrix <- function(points) {
  sl <- do.call(rbind, points)
  colnames(sl) <- c("x", "y", "z")
  sl
}
