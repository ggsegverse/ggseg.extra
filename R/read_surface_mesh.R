#' Read a brain surface mesh
#'
#' Reads a surface file into a mesh that describes itself: vertices, faces,
#' and a [ggseg.formats::mesh_space()] recording the vertex space, hemisphere
#' and relationship to a standard space.
#'
#' @details
#' Meshes are independent of atlases. An atlas defines regions -- labels and
#' the vertex indices they cover -- while a mesh is a surface to draw them on.
#' The two meet only at `vertex_space`: an atlas's indices mean something on a
#' mesh in the space the atlas was built against, and nothing on any other.
#' This function therefore produces a mesh, never an atlas, and nothing here
#' feeds the `create_*_from_*()` pipelines.
#'
#' `face_index_base` chooses what the returned faces count from. FreeSurfer
#' surfaces are read as 1-based and GIFTI as 0-based, so a base is always
#' converted to rather than assumed, and
#' [ggseg.formats::brain_mesh()] checks the result. The ecosystem genuinely
#' holds both conventions -- `ggseg.formats` inflated surfaces are 0-based,
#' `ggseg.meshes` cortical surfaces are 1-based -- because four build scripts
#' each chose independently. Choosing here, once, is the point.
#'
#' FreeSurfer surfaces are read through `mris_convert` where it is available,
#' which handles the QUAD surfaces `mri_tessellate` writes, falling back to
#' `freesurferformats`.
#'
#' @param path Path to a FreeSurfer binary surface or a GIFTI surface file.
#' @param space A [ggseg.formats::mesh_space()] describing what the mesh's
#'   coordinates mean.
#' @param face_index_base `0L` or `1L` -- what the returned face indices
#'   should count from.
#' @param format Source format. `"auto"` reads the extension, which is why it
#'   can be overridden: a FreeSurfer surface is often named `lh.inflated`,
#'   with no extension to go on.
#'
#' @return A mesh from [ggseg.formats::brain_mesh()], carrying `mesh_space`
#'   and `face_index_base` attributes.
#' @family surface meshes
#' @export
#' @examplesIf FALSE
#' space <- ggseg.formats::mesh_space(
#'   vertex_space = "fsaverage5",
#'   hemi = "left",
#'   anatomical = FALSE,
#'   surface = "inflated"
#' )
#' read_surface_mesh(
#'   file.path(Sys.getenv("FREESURFER_HOME"), "subjects", "fsaverage5",
#'             "surf", "lh.inflated"),
#'   space = space
#' )
read_surface_mesh <- function(
  path,
  space,
  face_index_base = 0L,
  format = c("auto", "freesurfer", "gifti")
) {
  format <- rlang::arg_match(format)

  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  if (!file.exists(path)) {
    cli::cli_abort("No surface file at {.path {path}}.")
  }

  format <- if (identical(format, "auto")) {
    detect_surface_format(path)
  } else {
    format
  }

  mesh <- switch(
    format,
    freesurfer = read_freesurfer_surface_mesh(path),
    gifti = read_gifti_surface_mesh(path)
  )

  faces <- shift_face_base(mesh$faces, from = mesh$base, to = face_index_base)

  ggseg.formats::brain_mesh(
    vertices = mesh$vertices,
    faces = faces,
    space = space,
    face_index_base = face_index_base
  )
}


#' Which reader a surface file needs
#'
#' GIFTI announces itself in the extension; a FreeSurfer surface usually has
#' none worth reading, so it is the fallback rather than something detected.
#' @noRd
detect_surface_format <- function(path) {
  if (grepl("\\.(surf\\.)?gii$", path, ignore.case = TRUE)) {
    "gifti"
  } else {
    "freesurfer"
  }
}


#' Read a FreeSurfer surface, exactly where that is possible
#'
#' freesurferformats reads the binary directly and so returns the
#' coordinates the file holds. `read_fs_surface()` prefers FreeSurfer's
#' `mris_convert`, which round-trips through ASCII and loses about 5e-7 mm --
#' irrelevant to a rendering, but enough that a mesh rebuilt through it is no
#' longer byte-identical to the one it replaces, which is exactly what the
#' build scripts assert.
#'
#' So the binary reader goes first and `mris_convert` remains the fallback it
#' is genuinely needed for: freesurferformats cannot reliably read the QUAD
#' surfaces `mri_tessellate` writes.
#' @noRd
read_freesurfer_surface_mesh <- function(path) {
  mesh <- tryCatch(
    {
      rlang::check_installed("freesurferformats")
      surf <- freesurferformats::read.fs.surface(path)
      faces <- surf$faces
      if (!all(faces %in% seq_len(nrow(surf$vertices)))) {
        cli::cli_abort("Faces reference vertices the surface does not have.")
      }
      list(
        vertices = data.frame(
          x = surf$vertices[, 1],
          y = surf$vertices[, 2],
          z = surf$vertices[, 3]
        ),
        faces = data.frame(
          i = faces[, 1],
          j = faces[, 2],
          k = faces[, 3]
        )
      )
    },
    error = function(cnd) cnd
  )

  if (inherits(mesh, "condition")) {
    mesh <- read_fs_surface(path)
  }

  list(vertices = mesh$vertices, faces = mesh$faces, base = 1L)
}


#' @noRd
read_gifti_surface_mesh <- function(path) {
  rlang::check_installed("gifti")
  gii <- gifti::readgii(path)

  pointset <- gii$data$pointset
  triangle <- gii$data$triangle
  if (is.null(pointset) || is.null(triangle)) {
    cli::cli_abort(
      c(
        "{.path {path}} is not a surface GIFTI.",
        "i" = "A surface needs both a {.field pointset} and a
               {.field triangle} array."
      )
    )
  }

  vertices <- as.data.frame(pointset)
  names(vertices) <- c("x", "y", "z")
  faces <- as.data.frame(triangle)
  names(faces) <- c("i", "j", "k")

  list(vertices = vertices, faces = faces, base = 0L)
}


#' Move face indices between bases
#'
#' Separated so the arithmetic is in one place rather than repeated at each
#' reader, which is how the ecosystem's bases came to disagree.
#'
#' Indices are returned as integers. The readers hand back doubles -- both
#' `mris_convert` and `freesurferformats` do -- and a double index is a vertex
#' number stored as a measurement: it doubles the memory, and it compares
#' equal to its own rounding error rather than exactly.
#' @noRd
shift_face_base <- function(faces, from, to) {
  offset <- to - from
  faces$i <- as.integer(faces$i + offset)
  faces$j <- as.integer(faces$j + offset)
  faces$k <- as.integer(faces$k + offset)
  faces
}
