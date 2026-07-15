# Brain surface mesh functions ----

#' Read FreeSurfer surface mesh file
#'
#' Reads a FreeSurfer surface file and returns vertex/face data. This is a
#' low-level I/O function for extracting meshes from FreeSurfer subjects.
#' For retrieving pre-built brain meshes, use [ggseg.formats::get_brain_mesh()]
#' instead.
#'
#' @param subject FreeSurfer subject (default "fsaverage5")
#' @param hemisphere "lh" or "rh"
#' @param surface Surface type: "inflated", "white", "pial"
#' @param subjects_dir FreeSurfer subjects directory
#'
#' @return list with vertices (data.frame with x, y, z) and
#'   faces (data.frame with i, j, k)
#' @keywords internal
#' @noRd
read_fs_mesh <- function(
  subject = "fsaverage5",
  hemisphere = c("lh", "rh"),
  surface = c("inflated", "white", "pial"),
  subjects_dir = freesurfer::fs_subj_dir()
) {
  check_fs(abort = TRUE)

  hemisphere <- match.arg(hemisphere)
  surface <- match.arg(surface)

  surf_file <- fs_surface_path(subjects_dir, subject, hemisphere, surface)

  # Use temporary file for conversion
  tmp_dir <- tempdir()
  tmp_asc <- file.path(tmp_dir, paste0(hemisphere, ".", surface, ".asc"))

  old_fs_verbose <- options(freesurfer.verbose = (get_verbose() >= 2))
  on.exit(options(old_fs_verbose), add = TRUE)

  freesurfer::mris_convert(
    infile = surf_file,
    outfile = tmp_asc,
    verbose = (get_verbose() >= 2)
  )

  # Read ascii file
  asc_lines <- readLines(tmp_asc)
  mesh <- parse_fs_asc_mesh(asc_lines)

  # Clean up

  unlink(tmp_asc)

  list(
    vertices = mesh$vertices,
    faces = mesh$faces,
    hemisphere = hemisphere,
    surface = surface,
    subject = subject
  )
}


#' Build the path to a FreeSurfer surface file and check it exists
#' @noRd
fs_surface_path <- function(subjects_dir, subject, hemisphere, surface) {
  surf_file <- file.path(
    subjects_dir,
    subject,
    "surf",
    paste(hemisphere, surface, sep = ".")
  )

  if (!file.exists(surf_file)) {
    cli::cli_abort(c(
      "Surface file not found:",
      surf_file
    ))
  }

  surf_file
}


#' Parse vertices and faces from the lines of a FreeSurfer ascii surface
#' @noRd
parse_fs_asc_mesh <- function(asc_lines) {
  # First line is comment, second has vertex/face counts
  counts <- as.integer(strsplit(trimws(asc_lines[2]), "\\s+")[[1]])
  n_vertices <- counts[1]
  n_faces <- counts[2]

  # Parse vertices (lines 3 to 2+n_vertices)
  vert_lines <- asc_lines[3:(2 + n_vertices)]
  vertices <- do.call(
    rbind,
    lapply(vert_lines, function(line) {
      as.numeric(strsplit(trimws(line), "\\s+")[[1]][1:3])
    })
  )
  vertices <- as.data.frame(vertices)
  names(vertices) <- c("x", "y", "z")

  # Parse faces (lines after vertices)
  face_lines <- asc_lines[(3 + n_vertices):(2 + n_vertices + n_faces)]
  faces <- do.call(
    rbind,
    lapply(face_lines, function(line) {
      as.integer(strsplit(trimws(line), "\\s+")[[1]][1:3])
    })
  )
  faces <- as.data.frame(faces)
  names(faces) <- c("i", "j", "k")

  list(vertices = vertices, faces = faces)
}
