# File I/O functions ----

#' Check if file is a supported volume format
#'
#' @param file Path to file
#' @return Logical
#' @keywords internal
is_volume_file <- function(file) {
  grepl("\\.(mgz|nii|nii\\.gz)$", file, ignore.case = TRUE)
}

#' Read neuroimaging volume file
#'
#' Reads volume data from common neuroimaging formats including
#' FreeSurfer MGZ and NIfTI. By default, reorients to RAS+ so that
#' dim1 = Left-to-Right, dim2 = Posterior-to-Anterior,
#' dim3 = Inferior-to-Superior.
#'
#' When `reorient = FALSE`, returns an RNifti niftiImage preserving the
#' file's native orientation and header metadata.
#'
#' @param file Path to volume file (.mgz, .nii, .nii.gz)
#' @param reorient If TRUE (default), reorient the volume to RAS+ and
#'   return a plain array. If FALSE, return an RNifti niftiImage in the
#'   file's native orientation (preserves header for downstream use).
#' @return 3D array (reorient=TRUE) or niftiImage (reorient=FALSE)
#' @keywords internal
read_volume <- function(file, reorient = TRUE) {
  if (!file.exists(file)) {
    cli::cli_abort("Volume file not found: {.path {file}}")
  }

  ext <- tolower(tools::file_ext(file))
  if (ext == "gz") {
    ext <- tools::file_ext(sub("\\.gz$", "", file))
  }

  vol <- switch(
    ext,
    "mgz" = freesurferformats::read.fs.mgh(file),
    "nii" = RNifti::readNifti(file),
    cli::cli_abort(c(
      "Unsupported volume format: {.file {basename(file)}}",
      "i" = "Supported formats: .mgz, .nii, .nii.gz"
    ))
  )

  if (reorient && inherits(vol, "niftiImage")) {
    if (RNifti::orientation(vol) != "RAS") {
      RNifti::orientation(vol) <- "RAS"
    }
  }

  vol <- as.array(vol)
  vol <- drop(vol)
  if (length(dim(vol)) != 3L) {
    cli::cli_abort(c(
      "Expected a 3D volume, got {length(dim(vol))}D.",
      "i" = "File: {.path {file}}"
    ))
  }
  vol
}

#' Read mesh data from PLY file
#'
#' Reads an ASCII PLY file and extracts vertices and faces into
#' a list format suitable for ggseg3d.
#'
#' @param ply path to ply-file
#' @param ... ignored, kept for backward compatibility
#'
#' @return list with vertices (data.frame with x, y, z) and
#'   faces (data.frame with i, j, k)
#' @keywords internal
read_ply_mesh <- function(ply, ...) {
  if (!is.character(ply)) {
    cli::cli_abort("{.arg ply} must be a file path")
  }

  lines <- readLines(ply)

  if (lines[1] != "ply") {
    cli::cli_abort("Not a valid PLY file: {.path {ply}}")
  }

  n_vertices <- 0L
  n_faces <- 0L
  header_end <- 0L

  for (i in seq_along(lines)) {
    line <- trimws(lines[i])
    if (grepl("^element vertex", line)) {
      n_vertices <- as.integer(sub("element vertex ", "", line))
    } else if (grepl("^element face", line)) {
      n_faces <- as.integer(sub("element face ", "", line))
    } else if (line == "end_header") {
      header_end <- i
      break
    }
  }

  vert_lines <- lines[(header_end + 1):(header_end + n_vertices)]
  vert_data <- do.call(
    rbind,
    lapply(
      strsplit(vert_lines, "\\s+"),
      function(x) as.numeric(x[1:3])
    )
  )

  vertices <- data.frame(
    x = vert_data[, 1],
    y = vert_data[, 2],
    z = vert_data[, 3]
  )

  face_lines <- lines[
    (header_end + n_vertices + 1):(header_end + n_vertices + n_faces)
  ]
  face_data <- do.call(
    rbind,
    lapply(
      strsplit(face_lines, "\\s+"),
      function(x) as.integer(x[2:4])
    )
  )

  faces <- data.frame(
    i = face_data[, 1],
    j = face_data[, 2],
    k = face_data[, 3]
  )

  list(vertices = vertices, faces = faces)
}

# Annotation reading ----

#' Extract vertex-to-region mapping into atlas tibble rows
#'
#' Shared helper for annotation, GIFTI, and CIFTI readers. Iterates
#' over regions, finds matching vertices, and collects tibble rows.
#' Unlabeled vertices are assigned to an "unknown" region.
#'
#' @param vertex_codes Integer vector of per-vertex label codes (one per vertex)
#' @param regions Data.frame with columns: code (integer key), name (character),
#'   colour (hex string)
#' @param hemi Long hemisphere name ("left" or "right")
#' @param hemi_short Short hemisphere code ("lh" or "rh")
#' @return List of tibble rows
#' @noRd
extract_vertex_regions <- function(
  vertex_codes, regions, hemi, hemi_short
) {
  all_data <- vector("list", nrow(regions))
  labeled <- vector("list", nrow(regions))
  n_regions <- 0L

  for (i in seq_len(nrow(regions))) {
    region_vertices <- which(vertex_codes == regions$code[i]) - 1L
    if (length(region_vertices) == 0) next

    n_regions <- n_regions + 1L
    labeled[[n_regions]] <- region_vertices
    all_data[[n_regions]] <- tibble(
      hemi = hemi,
      region = regions$name[i],
      label = paste(hemi_short, regions$name[i], sep = "_"),
      colour = regions$colour[i],
      vertices = list(region_vertices)
    )
  }

  all_data <- all_data[seq_len(n_regions)]
  labeled_vertices <- unlist(labeled[seq_len(n_regions)])

  all_vertex_indices <- seq_along(vertex_codes) - 1L
  unlabeled_vertices <- setdiff(all_vertex_indices, labeled_vertices)

  if (length(unlabeled_vertices) > 0) {
    all_data[[n_regions + 1L]] <- tibble(
      hemi = hemi,
      region = "unknown",
      label = paste(hemi_short, "unknown", sep = "_"),
      colour = "#BEBEBE",
      vertices = list(unlabeled_vertices)
    )
  }

  all_data
}


#' @noRd
annot_to_atlas_data <- function(annot, hemi, hemi_short) {
  ct <- annot$colortable_df
  ct <- ct[!is.na(ct$r), ]

  regions <- data.frame(
    code = ct$code,
    name = ct$struct_name,
    colour = ct$hex_color_string_rgb,
    stringsAsFactors = FALSE
  )

  extract_vertex_regions(annot$label_codes, regions, hemi, hemi_short)
}


#' Read annotation data from files
#'
#' Reads FreeSurfer annotation files and extracts region information
#' including vertices, colours, and labels for both hemispheres.
#'
#' @param annot_files Character vector of paths to annotation files.
#'   Files should follow FreeSurfer naming convention with `lh.` or `rh.`
#'   prefix (e.g., `c("lh.aparc.annot", "rh.aparc.annot")`).
#'
#' @return A tibble with columns: hemi, region, label, colour, vertices
#' @export
#' @importFrom dplyr tibble bind_rows
#'
#' @examples
#' \dontrun{
#' atlas_data <- read_annotation_data(c(
#'   "path/to/lh.aparc.annot",
#'   "path/to/rh.aparc.annot"
#' ))
#' }
read_annotation_data <- function(annot_files) {
  rlang::check_installed(
    "freesurferformats",
    reason = "to read annotation files"
  )

  if (!all(file.exists(annot_files))) {
    missing <- annot_files[!file.exists(annot_files)] # nolint: object_usage_linter
    cli::cli_abort("Annotation file{?s} not found: {.path {missing}}")
  }

  all_data <- list()

  for (annot_file in annot_files) {
    filename <- basename(annot_file)
    hemi_short <- detect_hemi_from_gifti_filename(filename)

    if (is.na(hemi_short)) {
      cli::cli_warn(
        "Cannot detect hemisphere from filename: {.file {filename}}"
      )
      next
    }
    hemi <- hemi_to_long(hemi_short)

    annot <- freesurferformats::read.fs.annot(annot_file)
    all_data <- c(all_data, annot_to_atlas_data(annot, hemi, hemi_short))
  }

  bind_rows(all_data)
}


#' Read vertex indices from a FreeSurfer label file
#'
#' @param label_file Path to .label file
#' @return Integer vector of vertex indices (0-indexed)
#' @keywords internal
read_label_vertices <- function(label_file) {
  rlang::check_installed(
    "freesurferformats",
    reason = "to read label files"
  )
  tryCatch(
    freesurferformats::read.fs.label.native(
      label_file,
      return_one_based_indices = FALSE
    ),
    error = function(e) {
      cli::cli_warn("Could not parse label file: {.path {label_file}}")
      integer(0)
    }
  )
}


# DPV file format ----

#' Write DPV file
#'
#' @param path path to file
#' @param vertices object with vertices
#' @param faces object with faces
#' @noRd
write_dpv <- function(path, vertices, faces) {
  if (min(faces) == 1) {
    faces <- faces - 1
  }

  vert_lines <- sprintf("%f %f %f %g", vertices$x, vertices$y, vertices$z, 0)
  face_lines <- sprintf("%g %g %g %g", faces$i, faces$j, faces$k, 0)

  file_content <- c(
    "#!ascii",
    sprintf("%g %g", nrow(vertices), nrow(faces)),
    vert_lines,
    face_lines
  )

  con <- file(path)
  on.exit(close(con))
  writeLines(file_content, con)
}


#' Read DPV file
#'
#' @param path path to dpv file
#' @noRd
#' @return list of vertices and faces
#' @importFrom utils read.table
read_dpv <- function(path) {
  header <- readLines(path, n = 2)
  counts <- as.integer(strsplit(trimws(header[2]), "\\s+")[[1]])
  n_vertices <- counts[1]
  n_faces <- counts[2]

  data <- read.table(path, skip = 2)

  vertices <- data[seq_len(n_vertices), 1:3, drop = FALSE]
  names(vertices) <- c("x", "y", "z")
  row.names(vertices) <- NULL

  faces <- data[(n_vertices + 1):(n_vertices + n_faces), 1:3, drop = FALSE]
  names(faces) <- c("i", "j", "k")
  row.names(faces) <- NULL

  list(vertices = vertices, faces = faces)
}


# FreeSurfer color table functions ----

#' Read FreeSurfer color table
#'
#' Read a FreeSurfer color lookup table file (e.g., `FreeSurferColorLUT.txt`
#' or `ASegStatsLUT.txt`). These files map label indices to region names
#' and RGBA colours.
#'
#' @param path Path to the color table file.
#' @return A data.frame with columns: idx, label, R, G, B, A.
#' @seealso [get_ctab()] to read and add hex colours, [write_ctab()] to write
#' @export
#' @importFrom utils read.table
#' @examples
#' ctab_file <- tempfile()
#' writeLines(c(
#'   "  0  Unknown                         0   0   0   0",
#'   "  1  Left-Cerebral-Cortex          205 130 176   0"
#' ), ctab_file)
#' read_ctab(ctab_file)
read_ctab <- function(path) {
  lines <- trimws(readLines(path))
  lines <- lines[nzchar(lines)]
  parsed <- regmatches(
    lines,
    regexec(
      "^\\s*(\\d+)\\s+(.+?)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s*$",
      lines
    )
  )
  rows <- lapply(parsed, function(m) {
    if (length(m) == 0) return(NULL)
    data.frame(
      idx = as.integer(m[2]),
      label = trimws(m[3]),
      R = as.integer(m[4]),
      G = as.integer(m[5]),
      B = as.integer(m[6]),
      A = as.integer(m[7]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, Filter(Negate(is.null), rows))
}


#' Write FreeSurfer color table
#'
#' Write a color table to file in FreeSurfer format.
#'
#' @param x A data.frame with columns: idx, label, R, G, B, A.
#' @param path Path to write to.
#' @return Invisibly returns the lines written.
#' @seealso [read_ctab()], [is_ctab()]
#' @export
#' @examples
#' ct <- data.frame(
#'   idx = 0:1, label = c("Unknown", "Region1"),
#'   R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
#' )
#' out <- tempfile()
#' write_ctab(ct, out)
write_ctab <- function(x, path) {
  lls <- apply(x, 1, function(row) {
    ctab_line(row[1], row[2], row[3], row[4], row[5], row[6])
  })
  lls[length(lls) + 1] <- ""
  writeLines(lls, path)
  invisible(lls)
}


#' Check if object is a color table
#'
#' @param x Object to check.
#' @return TRUE if x is a data.frame with the required color table columns.
#' @export
#' @examples
#' ct <- data.frame(
#'   idx = 0L, label = "Unknown",
#'   R = 0L, G = 0L, B = 0L, A = 0L
#' )
#' is_ctab(ct)
#' is_ctab(data.frame(x = 1))
is_ctab <- function(x) {
  if (!is.data.frame(x)) {
    return(FALSE)
  }
  required <- c("idx", "label", "R", "G", "B", "A") #nolint
  all(required %in% names(x))
}


#' Read color table and add hex colours
#'
#' Reads a FreeSurfer color lookup table and adds hex colour codes for
#' use in plotting.
#'
#' @param color_lut Path to a color table file, or a data.frame that
#'   passes [is_ctab()].
#' @return A data.frame with the original columns plus `roi` (zero-padded
#'   index) and `color` (hex colour code).
#' @seealso [read_ctab()], [is_ctab()]
#' @export
#' @importFrom grDevices rgb
#' @examples
#' ct <- data.frame(
#'   idx = 0:1, label = c("Unknown", "Region1"),
#'   R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
#' )
#' get_ctab(ct)
get_ctab <- function(color_lut) {
  colourtable <- if (is.character(color_lut)) {
    read_ctab(color_lut)
  } else {
    color_lut
  }

  if (!is_ctab(colourtable)) {
    cli::cli_abort(c(
      "color_lut does not have the correct format.",
      "i" = "Required columns: idx, label, R, G, B, A"
    ))
  }

  colourtable$roi <- sprintf("%04d", colourtable$idx)
  colourtable$color <- rgb(
    colourtable$R,
    colourtable$G,
    colourtable$B,
    maxColorValue = 255
  )

  colourtable
}

# GIFTI annotation reading ----

#' Detect hemisphere from GIFTI filename
#'
#' @param filename Basename of the GIFTI file
#' @return "lh" or "rh", or NA if undetectable
#' @keywords internal
# nolint next: object_length_linter.
detect_hemi_from_gifti_filename <- function(filename) {
  if (grepl("^lh\\.|[._]lh[._]|\\.L\\.", filename)) {
    return("lh")
  }
  if (grepl("^rh\\.|[._]rh[._]|\\.R\\.", filename)) {
    return("rh")
  }
  NA_character_
}


#' @noRd
# nolint next: object_length_linter.
detect_hemi_from_neuromaps_filename <- function(filename) {
  if (grepl("hemi-L", filename, fixed = TRUE)) {
    return("lh")
  }
  if (grepl("hemi-R", filename, fixed = TRUE)) {
    return("rh")
  }
  detect_hemi_from_gifti_filename(filename)
}


#' Read GIFTI annotation files
#'
#' Reads GIFTI annotation (`.label.gii`) files and extracts region
#' information including vertices, colours, and labels. Returns data in
#' the same format as [read_annotation_data()] for use with the cortical
#' atlas pipeline.
#'
#' Hemisphere is detected from filename patterns: `lh.`, `rh.`, `.L.`, `.R.`
#'
#' @param gifti_files Character vector of paths to `.label.gii` files.
#'
#' @return A tibble with columns: hemi, region, label, colour, vertices
#' @export
#' @importFrom dplyr tibble bind_rows
#' @importFrom grDevices rgb
#'
#' @examples
#' \dontrun{
#' atlas_data <- read_gifti_annotation(c(
#'   "lh.aparc.label.gii",
#'   "rh.aparc.label.gii"
#' ))
#' }
read_gifti_annotation <- function(gifti_files) {
  rlang::check_installed(
    "freesurferformats",
    reason = "to read GIFTI annotation files"
  )

  if (!all(file.exists(gifti_files))) {
    missing <- gifti_files[ # nolint: object_usage_linter.
      !file.exists(gifti_files)
    ]
    cli::cli_abort(
      "GIFTI file{?s} not found: {.path {missing}}"
    )
  }

  all_data <- list()

  for (gifti_file in gifti_files) {
    filename <- basename(gifti_file)
    hemi_short <- detect_hemi_from_gifti_filename(filename)

    if (is.na(hemi_short)) {
      cli::cli_warn(
        "Cannot detect hemisphere from filename: {.file {filename}}"
      )
      next
    }
    hemi <- hemi_to_long(hemi_short)

    annot <- freesurferformats::read.fs.annot.gii(gifti_file)
    all_data <- c(all_data, annot_to_atlas_data(annot, hemi, hemi_short))
  }

  bind_rows(all_data)
}


# CIFTI annotation reading ----

#' Read CIFTI annotation file
#'
#' Reads a CIFTI dense label file (`.dlabel.nii`) and extracts region
#' information for both hemispheres. Returns data in the same format as
#' [read_annotation_data()] for use with the cortical atlas pipeline.
#'
#' The CIFTI file must be in fsaverage5 space (10,242 vertices per
#' hemisphere). If your file uses a different resolution, resample it first
#' with Connectome Workbench:
#' ```
#' wb_command -cifti-resample input.dlabel.nii ...
#' ```
#'
#' @param cifti_file Path to a `.dlabel.nii` CIFTI file.
#'
#' @return A tibble with columns: hemi, region, label, colour, vertices
#' @export
#' @importFrom dplyr tibble bind_rows
#' @importFrom grDevices rgb
#'
#' @examples
#' \dontrun{
#' atlas_data <- read_cifti_annotation("parcellation.dlabel.nii")
#' }
read_cifti_annotation <- function(cifti_file) {
  rlang::check_installed("ciftiTools", reason = "to read CIFTI files")

  if (!file.exists(cifti_file)) {
    cli::cli_abort("CIFTI file not found: {.path {cifti_file}}")
  }

  cii <- ciftiTools::read_cifti(cifti_file)

  all_data <- list()

  hemi_info <- list(
    list(
      data = cii$data$cortex_left,
      hemi = "left",
      hemi_short = "lh",
      expected_n = fsaverage5_nverts
    ),
    list(
      data = cii$data$cortex_right,
      hemi = "right",
      hemi_short = "rh",
      expected_n = fsaverage5_nverts
    )
  )

  label_table <- cii$meta$cifti$labels[[1]]

  regions <- data.frame(
    code = label_table$Key,
    name = label_table$Label,
    colour = rgb(
      label_table$Red,
      label_table$Green,
      label_table$Blue,
      maxColorValue = 1
    ),
    stringsAsFactors = FALSE
  )

  for (hi in hemi_info) {
    if (is.null(hi$data)) next

    vertex_labels <- as.integer(hi$data[, 1])
    n_verts <- length(vertex_labels)

    if (n_verts != hi$expected_n) {
      cli::cli_abort(c(
        paste(
          "CIFTI {hi$hemi} hemisphere has {n_verts} vertices,",
          "expected {hi$expected_n} (fsaverage5)"
        ),
        "i" = paste(
          "Resample to fsaverage5 first using",
          "{.code wb_command -cifti-resample}"
        )
      ))
    }

    all_data <- c(
      all_data,
      extract_vertex_regions(vertex_labels, regions, hi$hemi, hi$hemi_short)
    )
  }

  bind_rows(all_data)
}


# Neuromaps annotation reading ----

#' Read neuromaps annotation files
#'
#' Reads neuromaps GIFTI metric files (`.func.gii`) and converts them to
#' the standard annotation format used by the cortical atlas pipeline.
#'
#' Automatically detects whether data contains integer parcel IDs
#' (parcellation) or continuous values (brain map). For parcellations,
#' vertex value 0 is treated as medial wall. For continuous data, NaN
#' vertices are medial wall and values are discretized into quantile
#' bins via `n_bins`.
#'
#' Files must be in fsaverage5 space (10,242 vertices per hemisphere).
#' Use `space = "fsaverage"` with `density = "10k"` when fetching from
#' neuromaps.
#'
#' @param gifti_files Character vector of paths to `.func.gii` files.
#'   Hemisphere is detected from BIDS filename patterns (`hemi-L`, `hemi-R`).
#' @param label_table Optional data.frame mapping integer parcel IDs to
#'   region names. Must have columns `id` (integer) and `region` (character).
#'   Optionally include `colour` (hex string). When `NULL`, regions are
#'   named `parcel_1`, `parcel_2`, etc. (parcellation) or
#'   `bin_1`, `bin_2`, etc. (continuous).
#' @param n_bins Number of quantile bins for continuous data. When `NULL`
#'   (default), auto-detected via Sturges' rule (`1 + log2(n)`, clamped
#'   to 5--20). Ignored for integer parcellation data.
#'
#' @return A tibble with columns: hemi, region, label, colour, vertices
#' @export
#' @importFrom dplyr tibble bind_rows
#' @importFrom grDevices hcl.colors
#'
#' @examples
#' \dontrun{
#' files <- neuromapr::fetch_neuromaps_annotation(
#'   "abagen", "genepc1", "fsaverage", density = "10k"
#' )
#' atlas_data <- read_neuromaps_annotation(files, n_bins = 7)
#' }
read_neuromaps_annotation <- function(
  gifti_files,
  label_table = NULL,
  n_bins = NULL
) {
  rlang::check_installed("gifti", reason = "to read GIFTI metric files")

  if (!all(file.exists(gifti_files))) {
    missing <- gifti_files[ # nolint: object_usage_linter.
      !file.exists(gifti_files)
    ]
    cli::cli_abort(
      "GIFTI file{?s} not found: {.path {missing}}"
    )
  }

  volume_files <- grepl("\\.(nii|nii\\.gz)$", gifti_files, ignore.case = TRUE)
  if (any(volume_files)) {
    cli::cli_abort(c(
      "Volume files are not supported for cortical atlas creation.",
      "i" = "Found volume file{?s}: {.path {gifti_files[volume_files]}}",
      "i" = "Use only surface (.func.gii) files."
    ))
  }

  if (!is.null(label_table)) {
    if (!all(c("id", "region") %in% names(label_table))) {
      cli::cli_abort(c(
        "{.arg label_table} must have columns {.field id} and {.field region}",
        "i" = paste(
          "Optionally include a {.field colour}",
          "column with hex colour codes."
        )
      ))
    }
  }

  all_data <- list()

  for (gifti_file in gifti_files) {
    filename <- basename(gifti_file)
    hemi_short <- detect_hemi_from_neuromaps_filename(filename)

    if (is.na(hemi_short)) {
      cli::cli_warn(
        "Cannot detect hemisphere from filename: {.file {filename}}"
      )
      next
    }
    hemi <- hemi_to_long(hemi_short)

    gii <- gifti::read_gifti(gifti_file)
    values <- as.numeric(gii$data[[1]])
    n_verts <- length(values)

    if (n_verts != fsaverage5_nverts) {
      cli::cli_abort(c(
        paste(
          "{hemi} hemisphere has {n_verts} vertices,",
          "expected {fsaverage5_nverts} (fsaverage5)"
        ),
        "i" = paste(
          "Use space='fsaverage' with density='10k'",
          "for fsaverage5 compatibility."
        )
      ))
    }

    is_parcellation <- is_integer_valued(values)

    if (is_parcellation) {
      hemi_data <- parse_parcellation_values(
        values,
        hemi,
        hemi_short,
        label_table
      )
    } else {
      hemi_data <- parse_continuous_values(
        values,
        hemi,
        hemi_short,
        n_bins
      )
    }

    all_data <- c(all_data, hemi_data)
  }

  result <- bind_rows(all_data)

  if (nrow(result) == 0) {
    return(result)
  }

  needs_colour <- is.na(result$colour) & result$region != "unknown"
  if (any(needs_colour)) {
    n_missing <- sum(needs_colour)
    generated <- hcl.colors(n_missing, palette = "Set2")
    result$colour[needs_colour] <- generated
  }

  result
}


#' @noRd
is_integer_valued <- function(values) {
  finite <- values[is.finite(values)]
  if (length(finite) == 0) {
    return(TRUE)
  }
  all(finite == round(finite))
}


#' @noRd
parse_parcellation_values <- function(values, hemi, hemi_short, label_table) {
  parcel_ids <- round(values)
  parcel_ids[!is.finite(parcel_ids)] <- 0L
  unique_ids <- sort(unique(parcel_ids))
  data <- list()

  for (pid in unique_ids) {
    if (pid == 0) {
      next
    }

    region_vertices <- which(parcel_ids == pid) - 1L
    if (length(region_vertices) == 0) {
      next
    }

    if (!is.null(label_table) && pid %in% label_table$id) {
      row <- label_table[label_table$id == pid, ]
      region_name <- row$region[1]
      colour <- if ("colour" %in% names(row)) row$colour[1] else NA_character_
    } else {
      region_name <- paste0("parcel_", pid)
      colour <- NA_character_
    }

    data[[length(data) + 1]] <- tibble(
      hemi = hemi,
      region = region_name,
      label = paste(hemi_short, region_name, sep = "_"),
      colour = colour,
      vertices = list(region_vertices)
    )
  }

  medial_wall <- which(parcel_ids == 0) - 1L
  if (length(medial_wall) > 0) {
    data[[length(data) + 1]] <- tibble(
      hemi = hemi,
      region = "unknown",
      label = paste(hemi_short, "unknown", sep = "_"),
      colour = "#BEBEBE",
      vertices = list(medial_wall)
    )
  }

  data
}


#' @noRd
parse_continuous_values <- function(values, hemi, hemi_short, n_bins) {
  medial_wall <- !is.finite(values)
  valid <- values[!medial_wall]

  if (is.null(n_bins)) {
    n_bins <- as.integer(grDevices::nclass.Sturges(valid))
    n_bins <- max(5L, min(n_bins, 20L))
  }

  breaks <- stats::quantile(valid, probs = seq(0, 1, length.out = n_bins + 1))
  breaks[1] <- breaks[1] - 1
  bin_ids <- cut(values, breaks = breaks, labels = FALSE)
  bin_ids[medial_wall] <- NA_integer_

  palette <- hcl.colors(n_bins, palette = "Spectral")
  data <- list()

  for (bid in seq_len(n_bins)) {
    region_vertices <- which(bin_ids == bid) - 1L
    if (length(region_vertices) == 0) {
      next
    }

    region_name <- paste0("bin_", bid)
    data[[length(data) + 1]] <- tibble(
      hemi = hemi,
      region = region_name,
      label = paste(hemi_short, region_name, sep = "_"),
      colour = palette[bid],
      vertices = list(region_vertices)
    )
  }

  wall_vertices <- which(medial_wall) - 1L
  if (length(wall_vertices) > 0) {
    data[[length(data) + 1]] <- tibble(
      hemi = hemi,
      region = "unknown",
      label = paste(hemi_short, "unknown", sep = "_"),
      colour = "#BEBEBE",
      vertices = list(wall_vertices)
    )
  }

  data
}


#' Read neuromaps volume annotation via surface projection
#'
#' Projects an MNI152-space NIfTI volume onto the fsaverage5 surface via
#' FreeSurfer's `mri_vol2surf`, then discretizes the projected per-vertex
#' values using the same binning logic as [read_neuromaps_annotation()].
#'
#' @param nifti_file Path to a `.nii` or `.nii.gz` file in MNI152 space.
#' @param n_bins Number of quantile bins for continuous data. When `NULL`
#'   (default), auto-detected via Sturges' rule. Ignored for integer data.
#' @param output_dir Directory for intermediate surface overlay files.
#'
#' @return A tibble with columns: hemi, region, label, colour, vertices
#' @export
#' @importFrom dplyr tibble bind_rows
#' @importFrom grDevices hcl.colors
#' @examples
#' \dontrun{
#' atlas_data <- read_neuromaps_volume("map.nii.gz", n_bins = 7)
#' }
read_neuromaps_volume <- function(
  nifti_file,
  n_bins = NULL,
  output_dir = tempdir()
) {
  check_fs(abort = TRUE)
  rlang::check_installed("RNifti", reason = "to read NIfTI volume files")

  surf_dir <- file.path(output_dir, "surface_overlays")
  mkdir(surf_dir)

  all_data <- list()

  for (hemi_short in c("lh", "rh")) {
    hemi <- hemi_to_long(hemi_short)
    output_nii <- file.path(surf_dir, paste0(hemi_short, "_overlay.nii.gz"))

    mri_vol2surf(
      input_file = nifti_file,
      output_file = output_nii,
      hemisphere = hemi_short,
      projfrac_range = c(0, 1, 0.1),
      mni152reg = TRUE,
      opts = paste("--interp trilinear --trgsubject fsaverage5")
    )

    if (!file.exists(output_nii)) {
      cli::cli_abort(c(
        "mri_vol2surf failed to produce output for {hemi_short}",
        "i" = "Expected: {.path {output_nii}}"
      ))
    }

    values <- as.numeric(c(RNifti::readNifti(output_nii)))
    values[values == 0] <- NaN

    if (length(values) != fsaverage5_nverts) {
      cli::cli_abort(c(
        paste(
          "{hemi} hemisphere has {length(values)} vertices,",
          "expected {fsaverage5_nverts} (fsaverage5)"
        )
      ))
    }

    hemi_data <- if (is_integer_valued(values)) {
      parse_parcellation_values(values, hemi, hemi_short, label_table = NULL)
    } else {
      parse_continuous_values(values, hemi, hemi_short, n_bins)
    }
    all_data <- c(all_data, hemi_data)
  }

  result <- bind_rows(all_data)

  needs_colour <- is.na(result$colour) & result$region != "unknown"
  if (any(needs_colour)) {
    result$colour[needs_colour] <- hcl.colors(sum(needs_colour), "Set2")
  }

  result
}


#' @noRd
ctab_line <- function(idx, name, red, green, blue, alpha) {
  if (nchar(name) > 29) {
    name <- substr(name, 1, 29)
  }
  sprintf(
    "% 3s  % -30s  % 3s % 3s % 3s % 3s",
    idx,
    name,
    red,
    green,
    blue,
    alpha
  )
}
