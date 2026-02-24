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
#' @importFrom freesurfer fs_subj_dir
read_fs_mesh <- function(
  subject = "fsaverage5",
  hemisphere = c("lh", "rh"),
  surface = c("inflated", "white", "pial"),
  subjects_dir = fs_subj_dir()
) {
  check_fs(abort = TRUE)

  hemisphere <- match.arg(hemisphere)
  surface <- match.arg(surface)

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

  # Clean up

  unlink(tmp_asc)

  list(
    vertices = vertices,
    faces = faces,
    hemisphere = hemisphere,
    surface = surface,
    subject = subject
  )
}


#' Create brain surface meshes for ggseg3d
#'
#' Creates brain surface mesh data for all combinations of hemispheres
#' and surface types. This data should be stored in ggseg3d for shared
#' use across all atlases.
#'
#' @param subject FreeSurfer subject (default "fsaverage5")
#' @param surfaces Surface types to extract
#' @param subjects_dir FreeSurfer subjects directory
#'
#' @return Named list of meshes, with names like "lh_inflated", "rh_white", etc.
#' @keywords internal
make_brain_meshes <- function(
  subject = "fsaverage5",
  surfaces = c("inflated", "white", "pial"),
  subjects_dir = fs_subj_dir()
) {
  check_fs(abort = TRUE)

  hemispheres <- c("lh", "rh")

  meshes <- list()

  for (hemi in hemispheres) {
    for (surf in surfaces) {
      name <- paste(hemi, surf, sep = "_")
      cli::cli_alert_info("Extracting {name}")

      meshes[[name]] <- read_fs_mesh(
        subject = subject,
        hemisphere = hemi,
        surface = surf,
        subjects_dir = subjects_dir
      )
    }
  }

  structure(
    meshes,
    class = c("brain_meshes", "list"),
    subject = subject
  )
}
