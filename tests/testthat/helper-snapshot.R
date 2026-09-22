# Pipeline output names session temp files, FreeSurfer install paths and cli
# step timings, none of which are stable between runs or machines. Temp paths
# are found by the session directory's random name rather than by its parent,
# which on Linux is /tmp and would also catch literal paths in messages.
scrub_volatile <- function(lines) {
  path_chars <- "[^'\"[:space:]]*"
  temp_path <- paste0(path_chars, "\\Q", basename(tempdir()), "\\E", path_chars)
  lines <- gsub(temp_path, "<tempfile>", lines, perl = TRUE)
  fs_home <- Sys.getenv("FREESURFER_HOME")
  if (nzchar(fs_home)) {
    lines <- gsub(fs_home, "<FREESURFER_HOME>", lines, fixed = TRUE)
  }
  # cli cuts a step line at the console width, which can land partway through
  # its timing once the step takes a few milliseconds longer.
  lines <- sub("\\[[0-9.]*(m?s\\]|\\.\\.\\.)$", "[<time>]", lines)
  lines <- gsub("\\[[0-9.]+m?s\\]", "[<time>]", lines)
  gsub("completed in [0-9.]+ minutes?", "completed in <n> minutes", lines)
}

# Gap and vertex counts that come out of sf/GEOS geometry work can shift
# between GEOS versions, so snapshots keep the message but not the number.
scrub_geometry_counts <- function(lines) {
  lines <- gsub("Filling [0-9]+ small", "Filling <n> small", lines)
  lines <- gsub("has [0-9]+ vertices", "has <n> vertices", lines)
  scrub_volatile(lines)
}
