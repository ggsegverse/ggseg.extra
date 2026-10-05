trk_header <- function(
  n_count = 0L,
  n_scalars = 0L,
  n_properties = 0L,
  voxel_size = c(1, 1, 1),
  dims = c(10L, 10L, 10L),
  vox_to_ras = diag(4),
  voxel_order = "RAS",
  endian = "little"
) {
  header <- raw(1000)
  header[1:5] <- charToRaw("TRACK")
  header[7:12] <- writeBin(as.integer(dims), raw(), size = 2, endian = endian)
  header[13:24] <- writeBin(voxel_size, raw(), size = 4, endian = endian)
  header[37:38] <- writeBin(n_scalars, raw(), size = 2, endian = endian)
  header[239:240] <- writeBin(n_properties, raw(), size = 2, endian = endian)
  header[441:504] <- writeBin(
    as.numeric(t(vox_to_ras)),
    raw(),
    size = 4,
    endian = endian
  )
  order_bytes <- charToRaw(voxel_order)
  header[948 + seq_along(order_bytes)] <- order_bytes
  header[989:992] <- writeBin(n_count, raw(), size = 4, endian = endian)
  header[997:1000] <- writeBin(1000L, raw(), size = 4, endian = endian)
  header
}

local_trk_file <- function(header, points, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".trk", .local_envir = env)
  endian <- if (identical(header[997:1000], writeBin(1000L, raw(), size = 4))) {
    "little"
  } else {
    "big"
  }
  con <- file(path, "wb")
  writeBin(header, con)
  writeBin(nrow(points), con, size = 4, endian = endian)
  writeBin(as.numeric(t(points)), con, size = 4, endian = endian)
  close(con)
  path
}
