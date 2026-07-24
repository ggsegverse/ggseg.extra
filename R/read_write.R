# File I/O functions ----

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

#' Read FreeSurfer LUT
#'
#' Read a FreeSurfer color lookup table file (e.g., `FreeSurferColorLUT.txt`
#' or `ASegStatsLUT.txt`). These files map label indices to region names
#' and RGBA colours.
#'
#' @param path Path to the LUT file.
#' @return A data.frame with columns: idx, label, R, G, B, A, and
#'   optionally type when a 7th field is present.
#' @seealso [get_lut()] to read and add hex colours, [write_lut()] to write,
#'   [lut_add()] and [lut_combine()] to build one up
#' @export
#' @importFrom utils read.table
#' @examples
#' lut_file <- tempfile()
#' writeLines(c(
#'   "  0  Unknown                         0   0   0   0",
#'   "  1  Left-Cerebral-Cortex          205 130 176   0"
#' ), lut_file)
#' read_lut(lut_file)
read_lut <- function(path) {
  lines <- trimws(readLines(path))
  lines <- lines[nzchar(lines)]
  lut_pattern <- paste0(
    "^\\s*(\\d+)\\s+(.+?)\\s+(\\d+)\\s+(\\d+)",
    "\\s+(\\d+)\\s+(\\d+)(?:\\s+(\\w+))?\\s*$"
  )
  parsed <- regmatches(lines, regexec(lut_pattern, lines))
  rows <- lapply(parsed, function(m) {
    if (length(m) == 0) {
      return(NULL)
    }
    data.frame(
      idx = as.integer(m[2]),
      label = trimws(m[3]),
      R = as.integer(m[4]),
      G = as.integer(m[5]),
      B = as.integer(m[6]),
      A = as.integer(m[7]),
      type = if (nzchar(m[8])) m[8] else NA_character_,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, Filter(Negate(is.null), rows))
  if (all(is.na(result$type))) {
    result$type <- NULL
  }
  result
}

#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `read_ctab()` was renamed to [read_lut()] for consistency with
#' [get_lut()], [write_lut()], [is_lut()], [lut_add()], and [lut_combine()].
#' @rdname read_lut
#' @export
read_ctab <- function(path) {
  lifecycle::deprecate_warn("1.9.9.9005", "read_ctab()", "read_lut()")
  read_lut(path)
}

#' Write FreeSurfer LUT
#'
#' Write a LUT to file in FreeSurfer format.
#'
#' @param x A data.frame with columns: idx, label, R, G, B, A.
#' @param path Path to write to.
#' @return Invisibly returns the lines written.
#' @seealso [read_lut()], [is_lut()]
#' @export
#' @examples
#' ct <- data.frame(
#'   idx = 0:1, label = c("Unknown", "Region1"),
#'   R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
#' )
#' out <- tempfile()
#' write_lut(ct, out)
write_lut <- function(x, path) {
  lls <- apply(x, 1, function(row) {
    lut_line(row[1], row[2], row[3], row[4], row[5], row[6])
  })
  lls[length(lls) + 1] <- ""
  writeLines(lls, path)
  invisible(lls)
}

#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `write_ctab()` was renamed to [write_lut()] for consistency with
#' [read_lut()], [get_lut()], [is_lut()], [lut_add()], and [lut_combine()].
#' @rdname write_lut
#' @export
write_ctab <- function(x, path) {
  lifecycle::deprecate_warn("1.9.9.9005", "write_ctab()", "write_lut()")
  write_lut(x, path)
}

#' Check if object is a LUT
#'
#' @param x Object to check.
#' @return TRUE if x is a data.frame with the required LUT columns.
#' @export
#' @examples
#' ct <- data.frame(
#'   idx = 0L, label = "Unknown",
#'   R = 0L, G = 0L, B = 0L, A = 0L
#' )
#' is_lut(ct)
#' is_lut(data.frame(x = 1))
is_lut <- function(x) {
  if (!is.data.frame(x)) {
    return(FALSE)
  }
  required <- c("idx", "label", "R", "G", "B", "A") #nolint
  all(required %in% names(x))
}

#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `is_ctab()` was renamed to [is_lut()] for consistency with [read_lut()],
#' [write_lut()], [get_lut()], [lut_add()], and [lut_combine()].
#' @rdname is_lut
#' @export
is_ctab <- function(x) {
  lifecycle::deprecate_warn("1.9.9.9005", "is_ctab()", "is_lut()")
  is_lut(x)
}

#' Read LUT and add hex colours
#'
#' Reads a FreeSurfer color lookup table and adds hex colour codes for
#' use in plotting.
#'
#' @param lut Path to a LUT file, or a data.frame that passes [is_lut()].
#' @return A data.frame with the original columns plus `roi` (zero-padded
#'   index) and `color` (hex colour code).
#' @seealso [read_lut()], [is_lut()]
#' @export
#' @importFrom grDevices rgb
#' @examples
#' ct <- data.frame(
#'   idx = 0:1, label = c("Unknown", "Region1"),
#'   R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
#' )
#' get_lut(ct)
get_lut <- function(lut) {
  colourtable <- if (is.character(lut)) {
    read_lut(lut)
  } else {
    lut
  }

  if (!is_lut(colourtable)) {
    cli::cli_abort(c(
      "lut does not have the correct format.",
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

#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `get_ctab()` was renamed to [get_lut()] for consistency with
#' [read_lut()], [write_lut()], [is_lut()], [lut_add()], and [lut_combine()].
#' @param color_lut Path to a LUT file, or a data.frame that passes
#'   [is_lut()].
#' @rdname get_lut
#' @export
get_ctab <- function(color_lut) {
  lifecycle::deprecate_warn("1.9.9.9005", "get_ctab()", "get_lut()")
  get_lut(color_lut)
}

#' Add rows to a FreeSurfer LUT
#'
#' Append custom label entries to a LUT (as read by [read_lut()]).
#' Scalar inputs are recycled to the length of `idx`. Useful for adding
#' custom subregion labels (e.g. hemisphere-prefixed or split structures)
#' before passing the table to [create_subcortical_from_volume()].
#'
#' @param lut A LUT data.frame (passes [is_lut()]).
#' @param idx Integer label indices to add.
#' @param label Character region labels.
#' @param R,G,B,A Integer colour channels (0-255); `A` defaults to `0`.
#' @return `lut` with the new rows appended (a `type` column, if present, is
#'   filled with `NA` for the new rows).
#' @seealso [read_lut()], [lut_combine()]
#' @export
#' @examples
#' ct <- data.frame(
#'   idx = 0L, label = "Unknown", R = 0L, G = 0L, B = 0L, A = 0L
#' )
#' lut_add(ct, idx = 20001:20002,
#'         label = c("Left-Hippocampus-ant", "Left-Hippocampus-post"),
#'         R = c(220, 60), G = c(190, 140), B = c(30, 200))
# nolint start: object_name_linter.
lut_add <- function(lut, idx, label, R, G, B, A = 0L) {
  # nolint end
  if (!is_lut(lut)) {
    cli::cli_abort("{.arg lut} must be a LUT; see {.fn is_lut}.")
  }
  n <- length(idx)
  validate_lut_add_length(label, n, "label")
  validate_lut_add_length(R, n, "R")
  validate_lut_add_length(G, n, "G")
  validate_lut_add_length(B, n, "B")
  validate_lut_add_length(A, n, "A")
  new <- data.frame(
    idx = as.integer(idx),
    label = rep_len(as.character(label), n),
    R = as.integer(rep_len(R, n)),
    G = as.integer(rep_len(G, n)),
    B = as.integer(rep_len(B, n)),
    A = as.integer(rep_len(A, n)),
    stringsAsFactors = FALSE
  )
  lut_combine(lut, new)
}

#' Combine FreeSurfer LUTs
#'
#' Row-binds several LUTs (as read by [read_lut()] or built with
#' [lut_add()]) into one, aligning columns (a `type` column present in only
#' some tables is filled with `NA`) and warning on duplicate label indices.
#'
#' @param ... LUT data.frames, each passing [is_lut()]. `NULL`
#'   inputs are dropped.
#' @return A single combined LUT.
#' @seealso [read_lut()], [lut_add()]
#' @export
#' @examples
#' a <- data.frame(idx = 0L, label = "Unknown", R = 0L, G = 0L, B = 0L, A = 0L)
#' b <- data.frame(idx = 1L, label = "Region1", R = 5L, G = 5L, B = 5L, A = 0L)
#' lut_combine(a, b)
lut_combine <- function(...) {
  luts <- Filter(Negate(is.null), list(...))
  if (length(luts) == 0) {
    cli::cli_abort("Provide at least one LUT.")
  }
  if (!all(vapply(luts, is_lut, logical(1)))) {
    cli::cli_abort("All inputs must be LUTs; see {.fn is_lut}.")
  }
  cols <- Reduce(union, lapply(luts, names))
  luts <- lapply(luts, function(d) {
    for (cc in setdiff(cols, names(d))) {
      d[[cc]] <- NA
    }
    d[cols]
  })
  out <- do.call(rbind, luts)
  dup <- unique(out$idx[duplicated(out$idx)])
  if (length(dup) > 0) {
    cli::cli_warn("Duplicate label indices in combined table: {.val {dup}}.")
  }
  rownames(out) <- NULL
  out
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
    # nolint start: object_usage_linter.
    missing <- gifti_files[!file.exists(gifti_files)]
    # nolint end
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

  hemi_info <- cifti_hemi_info(cii)
  regions <- cifti_label_regions(cii)

  for (hi in hemi_info) {
    if (is.null(hi$data)) {
      next
    }

    all_data <- c(all_data, cifti_hemi_regions(hi, regions))
  }

  bind_rows(all_data)
}

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

  validate_neuromaps_inputs(gifti_files, label_table)

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

    values <- read_neuromaps_values(gifti_file, hemi)
    is_parcellation <- is_integer_valued(values)

    hemi_data <- if (is_parcellation) {
      parse_parcellation_values(values, hemi, hemi_short, label_table)
    } else {
      parse_continuous_values(values, hemi, hemi_short, n_bins)
    }

    all_data <- c(all_data, hemi_data)
  }

  result <- bind_rows(all_data)

  if (nrow(result) == 0) {
    return(result)
  }

  result
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

  surf_dir <- as.character(fs::path(output_dir, "surface_overlays"))
  mkdir(surf_dir)

  all_data <- list()

  for (hemi_short in c("lh", "rh")) {
    hemi <- hemi_to_long(hemi_short)
    output_nii <- as.character(fs::path(
      surf_dir,
      paste0(hemi_short, "_overlay.nii.gz")
    ))

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

    values <- read_surface_overlay(output_nii, hemi)

    hemi_data <- if (is_integer_valued(values)) {
      parse_parcellation_values(values, hemi, hemi_short, label_table = NULL)
    } else {
      parse_continuous_values(values, hemi, hemi_short, n_bins)
    }
    all_data <- c(all_data, hemi_data)
  }

  result <- bind_rows(all_data)
  fill_missing_colours(result)
}

#' @noRd
validate_lut_add_length <- function(x, n, arg_name) {
  if (!length(x) %in% c(1L, n)) {
    cli::cli_abort(
      "{.arg {arg_name}} must have length 1 or {n} (the length of \\
       {.arg idx}); got {length(x)}."
    )
  }
  invisible(TRUE)
}

#' Build the per-hemisphere CIFTI data descriptors
#' @noRd
cifti_hemi_info <- function(cii) {
  list(
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
}

#' Build the region lookup table from CIFTI label metadata
#' @noRd
cifti_label_regions <- function(cii) {
  label_table <- cii$meta$cifti$labels[[1]]

  data.frame(
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
}

#' Validate CIFTI hemisphere vertex count and extract region rows
#' @noRd
cifti_hemi_regions <- function(hi, regions) {
  vertex_labels <- as.integer(hi$data[, 1])
  n_verts <- length(vertex_labels)

  if (n_verts != hi$expected_n) {
    cli::cli_abort(c(
      "CIFTI {hi$hemi} hemisphere has {n_verts} vertices,
      expected {hi$expected_n} (fsaverage5)",
      "i" = "Resample to fsaverage5 first using
      {.code wb_command -cifti-resample}"
    ))
  }

  extract_vertex_regions(vertex_labels, regions, hi$hemi, hi$hemi_short)
}

#' Validate neuromaps GIFTI file paths and optional label table
#' @noRd
validate_neuromaps_inputs <- function(gifti_files, label_table) {
  if (!all(file.exists(gifti_files))) {
    # nolint start: object_usage_linter.
    missing <- gifti_files[!file.exists(gifti_files)]
    # nolint end
    cli::cli_abort(
      "GIFTI file{?s} not found: {.path {missing}}"
    )
  }

  volume_files <- grepl("\\.(nii|nii\\.gz)$", gifti_files, ignore.case = TRUE)
  if (any(volume_files)) {
    cli::cli_abort(c(
      "Volume files are not supported for cortical atlas creation.",
      "i" = "Found volume file{?s}: {.path {gifti_files[volume_files]}}",
      "i" = "Use only surface (.func.gii) files." # nolint
    ))
  }

  if (!is.null(label_table)) {
    if (!all(c("id", "region") %in% names(label_table))) {
      cli::cli_abort(c(
        "{.arg label_table} must have columns {.field id} and {.field region}",
        "i" = "Optionally include a {.field colour} column with hex colour
        codes."
      ))
    }
  }

  invisible(NULL)
}

#' Read per-vertex values from a neuromaps GIFTI metric file
#' @noRd
read_neuromaps_values <- function(gifti_file, hemi) {
  gii <- gifti::read_gifti(gifti_file)
  values <- as.numeric(gii$data[[1]])
  n_verts <- length(values)

  if (n_verts != fsaverage5_nverts) {
    cli::cli_abort(c(
      "{hemi} hemisphere has {n_verts} vertices,
      expected {fsaverage5_nverts} (fsaverage5)",
      "i" = "Use space='fsaverage' with density='10k'
      for fsaverage5 compatibility."
    ))
  }

  values
}

#' Read a projected surface overlay and validate its vertex count
#' @noRd
read_surface_overlay <- function(output_nii, hemi) {
  values <- as.numeric(c(RNifti::readNifti(output_nii)))
  values[values == 0] <- NaN

  if (length(values) != fsaverage5_nverts) {
    cli::cli_abort(
      "{hemi} hemisphere has {length(values)} vertices,
      expected {fsaverage5_nverts} (fsaverage5)"
    )
  }

  values
}

#' Assign fallback colours to regions that have none
#' @noRd
fill_missing_colours <- function(result) {
  needs_colour <- is.na(result$colour) & result$region != "unknown"
  if (any(needs_colour)) {
    result$colour[needs_colour] <- grDevices::hcl.colors(
      sum(needs_colour),
      "Set2"
    )
  }

  result
}


#' Reorient a voxel array to RAS+ using its vox2ras affine
#'
#' Derives the axis permutation and per-axis flips that map a volume's voxel
#' axes to Right-Anterior-Superior from the direction part of its vox2ras
#' matrix, then applies them. This is the array-level equivalent of
#' `RNifti::orientation<-`, used for FreeSurfer MGZ volumes (read as plain
#' arrays, e.g. the LIA-oriented conformed volumes), which would otherwise
#' reach the RAS+-assuming projection code unreoriented.
#'
#' @param vol 3D array in the file's native voxel order.
#' @param vox2ras 4x4 voxel-to-scanner-RAS affine (only the 3x3 direction
#'   block is used).
#' @return `vol` reordered and flipped so dim1 increases toward Right,
#'   dim2 toward Anterior, dim3 toward Superior.
#' @keywords internal
#' @noRd
reorient_volume_to_ras <- function(vol, vox2ras) {
  direction <- vox2ras[1:3, 1:3, drop = FALSE]
  voxel_axis <- apply(abs(direction), 1L, which.max)
  if (!setequal(voxel_axis, 1:3)) {
    cli::cli_abort(
      "Cannot derive a RAS axis mapping from the volume's vox2ras affine."
    )
  }

  vol <- aperm(vol, voxel_axis)
  for (world_axis in 1:3) {
    if (direction[world_axis, voxel_axis[world_axis]] < 0) {
      index <- lapply(dim(vol), seq_len)
      index[[world_axis]] <- rev(index[[world_axis]])
      vol <- do.call(`[`, c(list(vol), index, list(drop = FALSE)))
    }
  }
  vol
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
#' @noRd
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
    "mgz" = {
      mgh <- freesurferformats::read.fs.mgh(file, with_header = TRUE)
      data <- drop(mgh$data)
      vox2ras <- tryCatch(
        freesurferformats::mghheader.vox2ras(mgh$header),
        error = function(e) NULL
      )
      if (reorient && length(dim(data)) == 3L && !is.null(vox2ras)) {
        reorient_volume_to_ras(data, vox2ras)
      } else {
        data
      }
    },
    "nii" = {
      rlang::check_installed("RNifti", reason = "to read NIfTI files")
      RNifti::readNifti(file)
    },
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

  vol <- drop(as.array(vol))
  if (length(dim(vol)) != 3L) {
    cli::cli_abort(c(
      "Expected a 3D volume, got {length(dim(vol))}D.",
      "i" = "File: {.path {file}}"
    ))
  }
  vol
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
  vertex_codes,
  regions,
  hemi,
  hemi_short
) {
  all_data <- vector("list", nrow(regions))
  labeled <- vector("list", nrow(regions))
  n_regions <- 0L

  for (i in seq_len(nrow(regions))) {
    region_vertices <- which(vertex_codes == regions$code[i]) - 1L
    if (length(region_vertices) == 0) {
      next
    }

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


#' Read vertex indices from a FreeSurfer label file
#'
#' @param label_file Path to .label file
#' @return Integer vector of vertex indices (0-indexed)
#' @keywords internal
#' @noRd
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

# GIFTI annotation reading ----

#' Detect hemisphere from GIFTI filename
#'
#' @param filename Basename of the GIFTI file
#' @return "lh" or "rh", or NA if undetectable
#' @keywords internal
#' @noRd
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


# CIFTI annotation reading ----

# Neuromaps annotation reading ----

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
      # nocov start
      # pid comes from unique(parcel_ids), so a match always exists here
      next
      # nocov end
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


#' @noRd
lut_line <- function(idx, name, red, green, blue, alpha) {
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
