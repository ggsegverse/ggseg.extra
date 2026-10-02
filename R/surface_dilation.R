# Surface label dilation ----
#
# Reading a cortex mask, masking an overlay to it, and growing labels
# across a surface's vertex adjacency. None of this is whole-brain
# specific - any surface pipeline that has to fill unlabelled vertices
# uses it.

#' Load cortex mask from FreeSurfer cortex.label file
#'
#' Reads `{subject}/label/{hemi}.cortex.label` and converts the vertex
#' indices to a logical mask. Vertices inside the cortex are TRUE; medial
#' wall vertices are FALSE. Errors if the label file is missing since
#' fsaverage5 (the default subject) always ships with cortex labels.
#'
#' @param hemi Hemisphere code ("lh" or "rh").
#' @param subject FreeSurfer subject name. Default "fsaverage5".
#' @param n_vertices Total vertex count for the surface.
#' @return Logical vector of length `n_vertices`.
#' @noRd
load_cortex_mask <- function(hemi, n_vertices, subject = "fsaverage5") {
  label_file <- as.character(fs::path(
    freesurfer::fs_subj_dir(),
    subject,
    "label",
    paste0(hemi, ".cortex.label")
  ))
  if (!file.exists(label_file)) {
    # nolint start
    cli::cli_abort(c(
      "Cortex label not found: {.path {label_file}}",
      "i" = "This file is required to prevent label dilation into
      the medial wall.",
      "i" = "It should exist for {.val {subject}}. Check your
      FreeSurfer installation."
    ))
    # nolint end
  }

  cortex_vertices <- read_label_vertices(label_file)
  mask <- logical(n_vertices)
  mask[cortex_vertices + 1L] <- TRUE
  mask
}


#' Clear overlay values outside the cortex label
#' @noRd
mask_to_cortex <- function(overlay, hemi, subject = "fsaverage5") {
  overlay[!load_cortex_mask(hemi, length(overlay), subject)] <- 0L
  overlay
}


#' Fill unlabeled surface vertices via mesh-neighbor dilation
#'
#' After vol2surf projection, many surface vertices remain unlabeled (value 0)
#' due to the sparse sampling. This function iteratively assigns each unlabeled
#' vertex the most common label among its mesh neighbors, using the surface
#' topology (face adjacency) to propagate labels outward until all reachable
#' vertices are filled.
#'
#' Dilation is restricted to cortex vertices (from `{hemi}.cortex.label`)
#' so labels do not bleed into the medial wall.
#'
#' @param overlay Integer vector of label values
#'   (0 = unlabeled), one per vertex.
#' @param hemi Hemisphere code ("lh" or "rh").
#' @param subject FreeSurfer subject for surface mesh. Default "fsaverage5".
#' @return Integer vector of same length with gaps filled.
#' @noRd
fill_surface_labels <- function(overlay, hemi, subject = "fsaverage5") {
  surf_file <- as.character(fs::path(
    freesurfer::fs_subj_dir(),
    subject,
    "surf",
    paste0(hemi, ".white")
  ))
  if (!file.exists(surf_file)) {
    cli::cli_warn(
      "Surface file not found: {.path {surf_file}}, skipping dilation"
    )
    return(overlay)
  }

  rlang::check_installed(
    "freesurferformats",
    reason = "to read FreeSurfer surfaces"
  )
  surf <- freesurferformats::read.fs.surface(surf_file)
  adj <- build_adjacency(surf$faces, nrow(surf$vertices))

  cortex_mask <- load_cortex_mask(hemi, length(overlay), subject)

  result <- overlay
  unlabeled <- intersect(which(result == 0L), which(cortex_mask))

  while (length(unlabeled) > 0L) {
    newly_labeled <- integer(length(unlabeled))
    n_new <- 0L

    for (idx in unlabeled) {
      neighbor_labels <- result[adj[[idx]]]
      neighbor_labels <- neighbor_labels[neighbor_labels != 0L]
      if (length(neighbor_labels) > 0L) {
        tbl <- tabulate(neighbor_labels, nbins = max(neighbor_labels))
        result[idx] <- which.max(tbl)
        n_new <- n_new + 1L
        newly_labeled[n_new] <- idx
      }
    }

    if (n_new == 0L) {
      break
    }
    unlabeled <- setdiff(unlabeled, newly_labeled[seq_len(n_new)])
  }

  result
}


#' Build vertex adjacency list from face matrix
#' @param faces n x 3 integer matrix (1-indexed vertex indices)
#' @param n_vertices total number of vertices
#' @return list of integer vectors, one per vertex
#' @noRd
build_adjacency <- function(faces, n_vertices) {
  f1 <- faces[, 1]
  f2 <- faces[, 2]
  f3 <- faces[, 3]

  from <- c(f1, f1, f2, f2, f3, f3)
  to <- c(f2, f3, f1, f3, f1, f2)

  edges <- split(to, from)

  adj <- vector("list", n_vertices)
  idx <- as.integer(names(edges))
  adj[idx] <- lapply(edges, unique.default)
  adj
}
