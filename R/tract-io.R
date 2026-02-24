# Tractography file reading ----

#' Read tractography file
#'
#' Load streamlines from a tractography file. Supports TrackVis (`.trk`) and
#' MRtrix (`.tck`) formats. The file format is detected from the extension.
#'
#' @param file Path to a `.trk` or `.tck` file.
#' @return A list of matrices, one per streamline. Each matrix has N rows
#'   (points along the streamline) and 3 columns (x, y, z coordinates).
#' @seealso [read_trk()], [read_tck()] for format-specific readers
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
read_trk <- function(file) {
  con <- file(file, "rb")
  on.exit(close(con))

  header <- readBin(con, "raw", 1000)
  id_string <- rawToChar(header[1:6])

  if (!grepl("TRACK", id_string)) {
    cli::cli_abort("Invalid TRK file: {file}")
  }

  n_scalars <- readBin(header[37:38], "integer", 1, size = 2)
  n_properties <- readBin(header[239:240], "integer", 1, size = 2)
  n_count <- readBin(header[989:992], "integer", 1, size = 4)

  seek(con, 1000)

  streamlines <- list()

  for (i in seq_len(n_count)) {
    n_pts <- readBin(con, "integer", 1, size = 4)
    if (is.na(n_pts) || n_pts <= 0) {
      break
    }

    points <- matrix(
      readBin(con, "double", n_pts * (3 + n_scalars), size = 4),
      ncol = 3 + n_scalars,
      byrow = TRUE
    )

    streamlines[[i]] <- points[, 1:3, drop = FALSE]
    colnames(streamlines[[i]]) <- c("x", "y", "z")

    if (n_properties > 0) {
      readBin(con, "double", n_properties, size = 4)
    }
  }

  streamlines
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
read_tck <- function(file) {
  con <- file(file, "rb")
  on.exit(close(con))

  header_lines <- character()
  while (TRUE) {
    line <- readLines(con, 1)
    if (length(line) == 0 || line == "END") {
      break
    }
    header_lines <- c(header_lines, line)
  }

  datatype <- "float32"
  for (line in header_lines) {
    if (grepl("^datatype:", line)) {
      datatype <- trimws(sub("datatype:", "", line))
    }
  }

  byte_size <- switch(
    datatype,
    "Float32LE" = 4,
    "Float32BE" = 4,
    "Float64LE" = 8,
    "Float64BE" = 8,
    4
  )

  endian <- if (grepl("BE$", datatype)) "big" else "little"

  streamlines <- list()
  current_streamline <- matrix(ncol = 3, nrow = 0)
  colnames(current_streamline) <- c("x", "y", "z")

  while (TRUE) {
    coords <- readBin(con, "double", 3, size = byte_size, endian = endian)
    if (length(coords) < 3) {
      break
    }

    if (all(is.infinite(coords))) {
      break
    }

    if (all(is.nan(coords))) {
      if (nrow(current_streamline) > 0) {
        streamlines[[length(streamlines) + 1]] <- current_streamline
        current_streamline <- matrix(ncol = 3, nrow = 0)
        colnames(current_streamline) <- c("x", "y", "z")
      }
      next
    }

    current_streamline <- rbind(current_streamline, coords)
  }

  if (nrow(current_streamline) > 0) {
    streamlines[[length(streamlines) + 1]] <- current_streamline
  }

  streamlines
}
