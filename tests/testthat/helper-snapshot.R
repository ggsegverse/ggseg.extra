# Gap and vertex counts that come out of sf/GEOS geometry work can shift
# between GEOS versions, so snapshots keep the message but not the number.
scrub_geometry_counts <- function(lines) {
  lines <- gsub("Filling [0-9]+ small", "Filling <n> small", lines)
  gsub("has [0-9]+ vertices", "has <n> vertices", lines)
}
