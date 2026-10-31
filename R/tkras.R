# tkRAS and the volume's own world ----
#
# FreeSurfer's tessellation tools emit surfaces in tkRAS, a frame derived from
# a volume's dimensions and voxel sizes alone. It ignores the orientation the
# header declares, so tkRAS only coincides with the volume's world coordinates
# when the volume is in FreeSurfer's conformed order. For anything else the
# axes are permuted and, where the handedness differs, left and right are
# swapped. Every mesh built by tessellation has to be brought back.
#
# This is why the omission was invisible for so long: for a conformed volume
# the transform is the identity, so every atlas built from FreeSurfer's own
# data was right by coincidence.

# nocov start
#' Compute tkRAS-to-world transform for a NIfTI volume
#'
#' FreeSurfer tessellation outputs surfaces in tkRAS coordinates.
#' This computes the transform to convert them to the volume's world
#' (scanner RAS / MNI) coordinates: world = vox2ras * inv(vox2ras_tkr) * tkRAS
#' @noRd
get_tkras_to_world <- function(volume_path) {
  check_fs(abort = TRUE)

  vox2ras_tkr <- mri_info_matrix("--vox2ras-tkr", volume_path)
  vox2ras <- mri_info_matrix("--vox2ras", volume_path)

  vox2ras %*% solve(vox2ras_tkr)
}
# nocov end

#' Run `mri_info` and parse its printed matrix
#'
#' `mri_info` can print informational/warning lines (e.g. about a missing
#' qform) ahead of the requested matrix, so only the matrix's own 4 lines
#' -- always the last non-empty lines of output -- are parsed; naively
#' parsing every line would silently fold stray numbers from those messages
#' into the matrix. Aborts loudly if the subprocess fails or the tail lines
#' don't parse into a complete 4x4 matrix, rather than returning garbage.
#' @noRd
mri_info_matrix <- function(flag, volume_path) {
  # Resolved under `freesurfer::fs_dir()` rather than off PATH, like every
  # other FreeSurfer call in the package. The two can name different
  # installations -- a shell whose PATH leads one way and an R session whose
  # `FREESURFER_HOME` leads another -- and reading a volume's geometry from a
  # different FreeSurfer than the one tessellating it is a very quiet way to
  # be wrong.
  lines <- system2(
    as.character(fs::path(freesurfer::fs_dir(), "bin", "mri_info")),
    c(flag, shQuote(volume_path)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(lines, "status")
  if (!is.null(status) && status != 0L) {
    cli::cli_abort(c(
      "{.code mri_info {flag}} failed for {.path {volume_path}} \\
       (exit {status}).",
      "x" = paste(lines, collapse = "\n")
    ))
  }

  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  vals <- suppressWarnings(as.numeric(unlist(
    strsplit(utils::tail(lines, 4L), "\\s+")
  )))

  if (length(vals) != 16L || anyNA(vals)) {
    cli::cli_abort(
      "{.code mri_info {flag}} did not return a valid 4x4 matrix for \\
       {.path {volume_path}}."
    )
  }
  matrix(vals, nrow = 4, ncol = 4, byrow = TRUE)
}


#' Move a mesh's vertices from tkRAS into the volume's world coordinates
#'
#' Shared by every pipeline that tessellates, because a mesh left in tkRAS is
#' wrong in a way nothing downstream can detect: `center_meshes()` subtracts a
#' centroid, and a translation cannot undo a reflection.
#' @noRd
mesh_tkras_to_world <- function(mesh, tkr_to_world) {
  if (is.null(mesh) || is.null(tkr_to_world)) {
    return(mesh)
  }
  world <- cbind(as.matrix(mesh$vertices), 1) %*% t(tkr_to_world)
  mesh$vertices <- data.frame(x = world[, 1], y = world[, 2], z = world[, 3])
  mesh
}


#' Do the meshes sit on the side their labels claim?
#'
#' The ecosystem's axis convention, which `ggseg3d::resolve_brain_mesh()`
#' documents and its own surfaces honour, puts the left hemisphere at
#' `x <= 0` and the right at `x >= 0`. An atlas that disagrees still plots:
#' the renderer filters by the `hemi` label and points a fixed camera, so a
#' mirrored atlas draws the structures of one hemisphere under the name of
#' the other, and the picture looks entirely plausible.
#'
#' Checked here, where the atlas is built, because that is the last point at
#' which it can be stopped rather than published. Structures with no
#' hemisphere -- brain stem, vermis -- are ignored, and an atlas with only
#' one hemisphere has nothing to compare.
#' @noRd
check_mesh_hemispheres <- function(meshes, call = rlang::caller_env()) {
  # Takes the meshes frame rather than the atlas: a subcortical atlas can
  # legitimately carry none, and asking an accessor that aborts in that case
  # would mean catching the abort, which turns the check into one that
  # silently passes.
  if (is.null(meshes) || !nrow(meshes)) {
    return(invisible(meshes))
  }
  if (!all(c("hemi", "mesh") %in% names(meshes))) {
    return(invisible(meshes))
  }

  hemi <- as.character(meshes$hemi)
  centre <- vapply(
    meshes$mesh,
    function(m) mean(as.matrix(m$vertices)[, 1]),
    numeric(1)
  )
  left <- mean(centre[hemi %in% "left"], na.rm = TRUE)
  right <- mean(centre[hemi %in% "right"], na.rm = TRUE)
  if (is.na(left) || is.na(right)) {
    return(invisible(meshes))
  }
  if (left <= 0 && right >= 0) {
    return(invisible(meshes))
  }

  cli::cli_abort(
    c(
      "The meshes are on the wrong side of the midline.",
      "x" = "Left-hemisphere structures average x = {round(left, 1)} and
      right-hemisphere x = {round(right, 1)}; the convention is left at
      {.code x <= 0} and right at {.code x >= 0}.",
      "i" = "A mirrored atlas still plots, so this is caught here rather
      than left to whoever reads the figure.",
      "i" = "This usually means the tessellated meshes never reached the
      volume's own world coordinates. Check the volume's orientation."
    ),
    call = call
  )
}
