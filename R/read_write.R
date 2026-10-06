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
#' A file written by [write_lut()] can carry declared columns after the
#' colours. With a single extra field it is read as `type`. With more, a
#' comment line naming the fields -- `# idx label R G B A type hemi` -- says
#' which is which, and a field holding `NA` is read as missing.
#'
#' @param path Path to the LUT file.
#' @return A data.frame with columns: idx, label, R, G, B, A, and
#'   optionally type and hemi when the file carries them.
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
  declared <- lut_header_columns(lines)
  extras <- declared %||% "type"
  lut_pattern <- paste0(
    "^\\s*(\\d+)\\s+(\\S+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)",
    strrep("(?:\\s+(\\w+))?", length(extras)),
    "\\s*$"
  )
  parsed <- regmatches(lines, regexec(lut_pattern, lines))
  matched <- lengths(parsed) > 0

  dropped <- lines[!matched & !startsWith(lines, "#")]
  if (length(dropped) > 0) {
    cli::cli_warn(c(
      "Skipped {length(dropped)} unparseable line{?s} in {.path {path}}",
      "i" = "First skipped: {.val {dropped[1]}}"
    ))
  }

  rows <- lapply(parsed[matched], function(m) {
    row <- data.frame(
      idx = as.integer(m[2]),
      label = trimws(m[3]),
      R = as.integer(m[4]),
      G = as.integer(m[5]),
      B = as.integer(m[6]),
      A = as.integer(m[7]),
      stringsAsFactors = FALSE
    )
    row[extras] <- as.list(lut_extra_values(m[7 + seq_along(extras)]))
    row
  })
  if (length(rows) == 0) {
    cli::cli_abort("No valid LUT entries found in {.path {path}}")
  }

  result <- do.call(rbind, rows)
  if (is.null(declared) && all(is.na(result$type))) {
    result$type <- NULL
  }
  result
}

#' Write FreeSurfer LUT
#'
#' Write a LUT to file in FreeSurfer format.
#'
#' The declared columns `type` and `hemi` are written after the colours, so
#' that [read_lut()] reads them back. FreeSurfer reads only the first six
#' fields of a line and skips comments, so the file stays a valid colour
#' table for it.
#'
#' A table with `type` alone gets it as a 7th field, left off rows that have
#' none. A table with `hemi` gets a comment line naming the fields, and every
#' row then carries each one, written as `NA` where it declares nothing.
#' Other columns are not written.
#'
#' @param x A data.frame with columns: idx, label, R, G, B, A, and
#'   optionally type and hemi. Their values must be single words.
#' @param path Path to write to.
#' @return Invisibly returns the lines written.
#' @seealso [read_lut()], [is_lut()], [lut_classify_anatomy()] to fill in
#'   the type column
#' @export
#' @examples
#' ct <- data.frame(
#'   idx = 0:1, label = c("Unknown", "Region1"),
#'   R = c(0L, 205L), G = c(0L, 130L), B = c(0L, 176L), A = c(0L, 0L)
#' )
#' out <- tempfile()
#' write_lut(ct, out)
write_lut <- function(x, path) {
  if (!is_lut(x)) {
    cli::cli_abort(c(
      "{.arg x} must be a valid LUT",
      "i" = "Expected columns: {.field idx}, {.field label}, {.field R}, \\
             {.field G}, {.field B}, {.field A}"
    ))
  }
  extras <- lut_extra_fields(x)
  check_writable_label(x)
  check_writable_channels(x)
  lls <- c(
    extras$header,
    paste0(lut_line(x$idx, x$label, x$R, x$G, x$B, x$A), extras$fields),
    ""
  )
  writeLines(lls, path)
  invisible(lls)
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
#' Subcortical parcels in grayordinate files are stored as voxels, which the
#' cortical pipeline cannot use; a warning names how many were skipped. Use
#' [read_cifti_subcortical()] to extract them.
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
  cii <- read_cifti_file(cifti_file, reason = "to read CIFTI files")
  warn_dropped_cifti_subcortex(cii, cifti_file)

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
#' vertices are medial wall and values are discretized into bins: quantile
#' bins via `n_bins`, or bins of your own via `breaks`. Either way both
#' hemispheres share one set of bin edges.
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
#'   to 5--20). The quantiles are taken over both hemispheres together, so a
#'   bin covers the same range of values on the left and on the right.
#'   Ignored for integer parcellation data.
#' @param breaks How to cut a continuous map into bins yourself, instead of
#'   by quantiles. Either the bin edges, as increasing numbers, or a function
#'   that takes the map's finite values from both hemispheres and returns the
#'   edges -- for example `function(x) pretty(x, 6)` for round, equal-width
#'   bins. Values outside the edges are left `unknown`, with a warning. Use
#'   `n_bins` or `breaks`, not both. Ignored for parcellation data.
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
  n_bins = NULL,
  breaks = NULL
) {
  rlang::check_installed("gifti", reason = "to read GIFTI metric files")

  validate_neuromaps_inputs(gifti_files, label_table)
  check_bin_args(n_bins, breaks)

  hemi_values <- list()

  for (gifti_file in gifti_files) {
    filename <- basename(gifti_file)
    hemi_short <- detect_hemi_from_neuromaps_filename(filename)

    if (is.na(hemi_short)) {
      cli::cli_warn(
        "Cannot detect hemisphere from filename: {.file {filename}}"
      )
      next
    }
    hemi_values[[hemi_short]] <- read_neuromaps_values(
      gifti_file,
      hemi_to_long(hemi_short)
    )
  }

  holds_labels <- all(vapply(hemi_values, is_integer_valued, logical(1)))
  bind_rows(neuromaps_hemi_regions(
    hemi_values,
    holds_labels,
    label_table,
    n_bins,
    breaks
  ))
}

#' Read neuromaps volume annotation via surface projection
#'
#' Projects an MNI152-space NIfTI volume onto the fsaverage5 surface via
#' FreeSurfer's `mri_vol2surf`, then discretizes the projected per-vertex
#' values using the same binning logic as [read_neuromaps_annotation()].
#'
#' A volume whose voxels are all whole numbers, or one given a `label_table`,
#' is treated as a parcellation and sampled with nearest-neighbour
#' interpolation, so every vertex takes the id of a parcel in the volume.
#' Any other volume is treated as a continuous map and sampled with
#' trilinear interpolation.
#'
#' @param nifti_file Path to a `.nii` or `.nii.gz` file in MNI152 space.
#' @param n_bins Number of quantile bins for continuous data. When `NULL`
#'   (default), auto-detected via Sturges' rule. The quantiles are taken over
#'   both hemispheres together. Ignored for integer data.
#' @inheritParams read_neuromaps_annotation
#' @param label_table Optional data.frame mapping parcel ids to region names
#'   and colours, as for [read_neuromaps_annotation()]. Supplying one declares
#'   the volume a parcellation. Continuous volumes are binned and the bins
#'   named `bin_1`, `bin_2`, and so on.
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
  label_table = NULL,
  output_dir = tempdir(),
  breaks = NULL
) {
  check_fs(abort = TRUE)
  rlang::check_installed("RNifti", reason = "to read NIfTI volume files")
  check_bin_args(n_bins, breaks)
  if (!file.exists(nifti_file)) {
    cli::cli_abort("Volume not found: {.path {nifti_file}}")
  }
  holds_labels <- neuromaps_volume_holds_labels(nifti_file, label_table)
  interpolation <- if (holds_labels) "nearest" else "trilinear"

  surf_dir <- as.character(fs::path(output_dir, "surface_overlays"))
  mkdir(surf_dir)

  hemi_values <- list()
  subject <- "fsaverage5"
  validate_registration("mni152", subject, nifti_file)
  reg <- resolve_vol2surf_registration("mni152", subject)

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
      reg = reg$reg,
      srcsubject = reg$srcsubject,
      regheader = reg$regheader,
      opts = paste(
        "--interp",
        interpolation,
        "--trgsubject",
        shQuote(subject)
      )
    )

    if (!file.exists(output_nii)) {
      cli::cli_abort(c(
        "mri_vol2surf failed to produce output for {hemi_short}",
        "i" = "Expected: {.path {output_nii}}"
      ))
    }

    hemi_values[[hemi_short]] <- read_surface_overlay(output_nii, hemi)
  }

  result <- bind_rows(neuromaps_hemi_regions(
    hemi_values,
    holds_labels,
    label_table,
    n_bins,
    breaks
  ))
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

# ciftiTools keeps label names as the row names of each label table, not in a
# column of their own.
#' @noRd
cifti_label_regions <- function(cii) {
  label_maps <- cii$meta$cifti$labels
  if (length(label_maps) > 1) {
    cli::cli_warn(
      "CIFTI file has {length(label_maps)} label maps; using only the first."
    )
  }
  label_table <- label_maps[[1]]

  data.frame(
    code = as.integer(label_table$Key),
    name = rownames(label_table),
    colour = rgb(
      label_table$Red,
      label_table$Green,
      label_table$Blue,
      maxColorValue = 1
    ),
    stringsAsFactors = FALSE
  )
}

#' @noRd
read_cifti_file <- function(cifti_file, reason) {
  rlang::check_installed(
    "ciftiTools",
    version = ciftitools_min_version(),
    reason = reason
  )

  if (!file.exists(cifti_file)) {
    cli::cli_abort("CIFTI file not found: {.path {cifti_file}}")
  }

  ciftiTools::read_cifti(cifti_file)
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


#' Reorient an MGZ array to RAS+, saying so when the affine cannot be read
#'
#' The NIfTI path gets its orientation from `RNifti::orientation<-`, which has
#' the header to work from. An MGZ arrives as a bare array, so the affine is
#' the only thing that can place it -- and a conformed volume is typically LIA,
#' not RAS. Returning it unreoriented and unannounced would hand the projection
#' code a volume whose axes are transposed, which renders as a plausible brain
#' rather than failing. `load_tract_grid()` reports the same condition the
#' same way.
#' @noRd
reorient_mgz_to_ras <- function(data, vox2ras, file) {
  if (is.null(vox2ras)) {
    cli::cli_warn(c(
      "Could not read a voxel-to-world affine from {.path {file}}.",
      "!" = "Returning the volume in its native voxel order; downstream steps \\
             assume RAS+, so regions may be placed along the wrong axes.",
      "i" = "Convert the volume with {.code mri_convert}, or pass one whose \\
             header carries a valid affine."
    ))
    return(data)
  }
  reorient_volume_to_ras(data, vox2ras)
}


#' Extension of a volume file, seeing through a `.gz` wrapper
#' @noRd
volume_ext <- function(file) {
  ext <- tolower(tools::file_ext(file))
  if (ext == "gz") {
    ext <- tolower(tools::file_ext(sub("\\.gz$", "", file)))
  }
  ext
}


#' Read neuroimaging volume file
#'
#' Reads volume data from common neuroimaging formats including
#' FreeSurfer MGZ and NIfTI. By default, reorients to RAS+ so that
#' dim1 = Left-to-Right, dim2 = Posterior-to-Anterior,
#' dim3 = Inferior-to-Superior.
#'
#' Always returns a bare 3D array: the header is consumed here and does not
#' travel with the result. Callers that need the affine read it separately,
#' via `read_vox2ras()`.
#'
#' @param file Path to volume file (.mgz, .nii, .nii.gz)
#' @param reorient If TRUE (default), reorient the volume to RAS+. If FALSE,
#'   return the array in the file's native voxel order.
#' @return 3D array, in RAS+ when `reorient = TRUE`
#' @keywords internal
#' @noRd
read_volume <- function(file, reorient = TRUE) {
  if (!file.exists(file)) {
    cli::cli_abort("Volume file not found: {.path {file}}")
  }

  ext <- volume_ext(file)

  vol <- switch(
    ext,
    "mgz" = {
      rlang::check_installed(
        "freesurferformats",
        reason = "to read FreeSurfer MGZ files"
      )
      mgh <- freesurferformats::read.fs.mgh(file, with_header = TRUE)
      data <- drop(mgh$data)
      vox2ras <- tryCatch(
        freesurferformats::mghheader.vox2ras(mgh$header),
        error = function(e) NULL
      )
      if (reorient && length(dim(data)) == 3L) {
        reorient_mgz_to_ras(data, vox2ras, file)
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
    existing_unknown <- Position(
      function(d) identical(d$region, "unknown"),
      all_data,
      nomatch = 0L
    )
    if (existing_unknown > 0L) {
      merged <- sort(unique(c(
        all_data[[existing_unknown]]$vertices[[1]],
        unlabeled_vertices
      )))
      all_data[[existing_unknown]]$vertices <- list(merged)
    } else {
      all_data[[n_regions + 1L]] <- tibble(
        hemi = hemi,
        region = "unknown",
        label = paste(hemi_short, "unknown", sep = "_"),
        colour = "#BEBEBE",
        vertices = list(unlabeled_vertices)
      )
    }
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
  counts <- suppressWarnings(as.integer(strsplit(trimws(header[2]), "\\s+")[[
    1
  ]]))
  if (length(counts) < 2 || anyNA(counts[1:2])) {
    cli::cli_abort(c(
      "Could not read vertex/face counts from {.path {path}}",
      "i" = "Expected two integers on the second line."
    ))
  }
  n_vertices <- counts[1]
  n_faces <- counts[2]

  data <- read.table(path, skip = 2)

  vertices <- data[seq_len(n_vertices), 1:3, drop = FALSE]
  names(vertices) <- c("x", "y", "z")
  row.names(vertices) <- NULL

  faces <- data[seq_len(n_faces) + n_vertices, 1:3, drop = FALSE]
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

#' Decide whether a volume holds parcel labels rather than a continuous map
#'
#' Asked of the volume itself, before projection, because the answer picks
#' the interpolation: averaging neighbouring voxels is right for a continuous
#' map and turns label ids into ids of parcels that are not there. A lookup
#' table is a declaration that the values are labels.
#' @noRd
neuromaps_volume_holds_labels <- function(nifti_file, label_table) {
  if (!is.null(label_table)) {
    return(TRUE)
  }
  is_integer_valued(c(RNifti::readNifti(nifti_file)))
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


#' Check the binning arguments of the neuromaps readers
#'
#' Run before any file is fetched or projected, so a bad bin specification
#' does not cost a download or a FreeSurfer call to discover.
#' @noRd
check_bin_args <- function(n_bins, breaks, call = rlang::caller_env()) {
  if (!is.null(n_bins) && !is.null(breaks)) {
    cli::cli_abort(
      c(
        "Supply {.arg n_bins} or {.arg breaks}, not both.",
        "i" = "{.arg breaks} already fixes how many bins there are."
      ),
      call = call
    )
  }
  if (!is.null(n_bins) && !rlang::is_scalar_integerish(n_bins, finite = TRUE)) {
    cli::cli_abort(
      "{.arg n_bins} must be a single whole number, not {.val {n_bins}}.",
      call = call
    )
  }
  if (!is.null(n_bins) && n_bins < 1) {
    cli::cli_abort(
      "{.arg n_bins} must be at least 1, not {.val {n_bins}}.",
      call = call
    )
  }
  if (!is.null(breaks) && !is.function(breaks)) {
    check_break_points(breaks, call = call)
  }
  invisible(NULL)
}


#' Check a vector of bin edges can be handed to `cut()`
#' @noRd
check_break_points <- function(breaks, call = rlang::caller_env()) {
  usable <- is.numeric(breaks) &&
    length(breaks) >= 2L &&
    !anyNA(breaks) &&
    all(diff(breaks) > 0)
  if (usable) {
    return(invisible(breaks))
  }
  cli::cli_abort(
    c(
      "{.arg breaks} must give at least two increasing numbers, the edges of
      the bins.",
      "x" = "Got {.obj_type_friendly {breaks}}{if (is.numeric(breaks))
      paste0(': ', toString(utils::head(breaks, 6)))}.",
      "i" = "A function passed as {.arg breaks} must return such a vector."
    ),
    call = call
  )
}


#' Settle the bin edges for a continuous map, once for both hemispheres
#'
#' The edges are worked out on the finite values of every hemisphere pooled.
#' Working them out per hemisphere gave the left and right `bin_3` different
#' value ranges under one name and one colour.
#'
#' @param hemi_values Named list of per-vertex value vectors, one per
#'   hemisphere, named by long hemisphere name.
#' @param n_bins Number of quantile bins, or `NULL` for Sturges' rule clamped
#'   to 5--20.
#' @param breaks `NULL`, bin edges, or a function of the pooled finite values
#'   returning bin edges.
#' @return Increasing numeric vector of bin edges.
#' @noRd
neuromaps_bin_breaks <- function(
  hemi_values,
  n_bins = NULL,
  breaks = NULL,
  call = rlang::caller_env()
) {
  finite <- lapply(hemi_values, function(values) values[is.finite(values)])
  empty <- names(finite)[lengths(finite) == 0L] # nolint: object_usage_linter.
  if (length(empty) > 0) {
    cli::cli_abort(
      c(
        "No finite values to bin for the {empty} hemisphere{?s}",
        "i" = "Every projected vertex was medial wall or non-finite"
      ),
      call = call
    )
  }
  pooled <- unlist(finite, use.names = FALSE)

  if (is.function(breaks)) {
    return(check_break_points(breaks(pooled), call = call))
  }
  if (!is.null(breaks)) {
    return(breaks)
  }
  quantile_bin_breaks(pooled, n_bins)
}


#' Quantile bin edges, with tied quantiles collapsed
#' @noRd
quantile_bin_breaks <- function(values, n_bins = NULL) {
  if (is.null(n_bins)) {
    n_bins <- as.integer(grDevices::nclass.Sturges(values))
    n_bins <- max(5L, min(n_bins, 20L))
  }

  # Tied values (thresholded maps, many zeros, or n_bins larger than the number
  # of distinct values) collapse adjacent quantiles; cut() aborts on duplicate
  # breaks, so drop them and shrink the bin count to match.
  breaks <- unique(unname(
    stats::quantile(values, probs = seq(0, 1, length.out = n_bins + 1))
  ))
  if (length(breaks) - 1L < n_bins) {
    cli::cli_warn(
      "Using {max(length(breaks) - 1L, 1L)} bin{?s} instead of {n_bins}: the \\
       data has fewer distinct values than requested bins."
    )
  }
  if (length(breaks) == 1L) {
    breaks <- c(breaks, breaks)
  }
  breaks
}


#' Bin one hemisphere's continuous values on shared bin edges
#'
#' Non-finite vertices are the medial wall. A finite vertex outside the edges,
#' which only caller-supplied `breaks` can produce, joins it as `unknown`
#' and is reported.
#' @noRd
bin_continuous_values <- function(values, hemi, hemi_short, breaks) {
  n_bins <- length(breaks) - 1L
  bin_ids <- if (breaks[1] == breaks[length(breaks)]) {
    ifelse(is.finite(values), 1L, NA_integer_)
  } else {
    cut(values, breaks = breaks, labels = FALSE, include.lowest = TRUE)
  }
  unbinned <- is.na(bin_ids)

  outside <- sum(unbinned & is.finite(values))
  if (outside > 0) {
    cli::cli_warn(
      c(
        "In the {hemi} hemisphere, {outside} vert{?ex/ices} fall{?s/} outside
        {.arg breaks} and {?is/are} left in {.val unknown}.",
        "i" = "The edges run from {.val {breaks[1]}} to
        {.val {breaks[length(breaks)]}}."
      ),
      wrap = TRUE
    )
  }

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

  wall_vertices <- which(unbinned) - 1L
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


#' Turn per-hemisphere vertex values into region rows
#'
#' @param hemi_values Named list of value vectors, named by short hemisphere
#'   name (`lh`, `rh`).
#' @param holds_labels Whether the values are parcel ids rather than a
#'   continuous map.
#' @return A list of one-row tibbles.
#' @noRd
neuromaps_hemi_regions <- function(
  hemi_values,
  holds_labels,
  label_table,
  n_bins,
  breaks
) {
  long_names <- vapply(names(hemi_values), hemi_to_long, character(1))
  if (!holds_labels) {
    cut_points <- neuromaps_bin_breaks(
      stats::setNames(hemi_values, long_names),
      n_bins,
      breaks
    )
  }

  regions <- list()
  for (i in seq_along(hemi_values)) {
    hemi_short <- names(hemi_values)[i]
    hemi_regions <- if (holds_labels) {
      parse_parcellation_values(
        hemi_values[[i]],
        long_names[[i]],
        hemi_short,
        label_table
      )
    } else {
      bin_continuous_values(
        hemi_values[[i]],
        long_names[[i]],
        hemi_short,
        cut_points
      )
    }
    regions <- c(regions, hemi_regions)
  }
  regions
}


#' @noRd
lut_line <- function(idx, name, red, green, blue, alpha) {
  # Names are padded to 30 characters for readability but never truncated.
  # FreeSurfer parses the LUT on whitespace, and its own
  # FreeSurferColorLUT.txt carries names up to 47 characters, so a cap here
  # only corrupted long labels -- and silently merged any two that shared a
  # prefix once cut.
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


#' The columns a LUT file carries after its six colour-table fields
#'
#' In the order they are written. These are the columns a pipeline reads a
#' declaration from; anything else in the table stays out of the file.
#' @noRd
lut_declared_columns <- c("type", "hemi")


#' The comment line naming a LUT file's fields
#'
#' A comment, so FreeSurfer and every other reader of the format skips it.
#' @noRd
lut_header <- function(extras) {
  paste(
    "#",
    paste(c("idx", "label", "R", "G", "B", "A", extras), collapse = " ")
  )
}


#' The declared columns a LUT file's header names, or `NULL` without a header
#' @noRd
lut_header_columns <- function(lines) {
  pattern <- "^#\\s*idx\\s+label\\s+R\\s+G\\s+B\\s+A((?:\\s+\\w+)*)$"
  header <- grep(pattern, lines, value = TRUE)
  if (length(header) == 0) {
    return(NULL)
  }
  declared <- strsplit(trimws(sub(pattern, "\\1", header[1])), "\\s+")[[1]]
  declared[nzchar(declared)]
}


#' Declared fields as read from a LUT line: absent or `NA` is missing
#' @noRd
lut_extra_values <- function(fields) {
  fields[!nzchar(fields) | fields == "NA"] <- NA_character_
  fields
}


#' The header and per-row text for a LUT's declared columns
#'
#' A table whose only declared column is `type` is written the way it always
#' was -- no header, the field left off rows that have none -- so the file is
#' unchanged for a reader that predates the header. Any other declared column
#' needs the header to say which field is which, and then every row carries
#' every field, `NA` where it declares nothing.
#' @noRd
lut_extra_fields <- function(x) {
  extras <- intersect(lut_declared_columns, names(x))
  values <- lapply(extras, function(column) check_writable_field(x, column))
  names(values) <- extras

  if (length(extras) == 0) {
    return(list(header = NULL, fields = rep("", nrow(x))))
  }
  if (identical(extras, "type")) {
    type <- values$type
    return(list(
      header = NULL,
      fields = ifelse(is.na(type), "", paste0("  ", type))
    ))
  }

  filled <- lapply(values, function(value) ifelse(is.na(value), "NA", value))
  list(
    header = lut_header(extras),
    fields = paste0("  ", do.call(paste, c(unname(filled), sep = "  ")))
  )
}


#' A declared column as a writable character vector
#'
#' `read_lut()` matches each declared field with `\\w+`, and its pattern is
#' anchored, so a value carrying anything else does not make that field
#' unreadable - it makes the whole line unreadable, silently losing the
#' label and its colours too. Refuse to write one.
#' @noRd
check_writable_field <- function(x, column) {
  value <- as.character(x[[column]])
  bad <- !is.na(value) & !grepl("^\\w+$", value)
  if (any(bad)) {
    cli::cli_abort(c(
      "{.field {column}} must be a single word, or {.fn read_lut} cannot read
      the line back",
      "x" = "Not a single word: {.val {unique(value[bad])}}",
      "i" = "Allowed: letters, digits and underscores."
    ))
  }
  value
}


#' Check `label` survives a `read_lut()` round trip
#'
#' Same reasoning as `check_writable_field()`: `read_lut()` splits on
#' whitespace, so a label carrying a space does not lose the label alone. The
#' pattern backtracks into a different, valid-looking parse and every colour
#' channel shifts one field along, with no warning. Refuse to write one.
#' @noRd
check_writable_label <- function(x) {
  label <- as.character(x$label)
  bad <- is.na(label) | !grepl("^\\S+$", label)
  if (any(bad)) {
    cli::cli_abort(c(
      "{.field label} must be a single word with no whitespace, or
      {.fn read_lut} reads the line back with its colours shifted",
      "x" = "Not a single word: {.val {unique(label[bad])}}",
      "i" = "Separate words with {.val -} or {.val _}, as FreeSurfer does."
    ))
  }
  invisible(label)
}


#' Check the colour channels survive a `read_lut()` round trip
#'
#' `read_lut()` matches each channel with `\\d+`. An `NA`, a negative or a
#' fractional value writes a field that does not match, and because the
#' pattern is anchored the whole row is dropped on read - label and colours
#' with it.
#' @noRd
check_writable_channels <- function(x) {
  channels <- c("idx", "R", "G", "B", "A")
  bad <- vapply(
    channels,
    function(nm) {
      value <- x[[nm]]
      if (!is.numeric(value)) {
        return(TRUE)
      }
      any(is.na(value) | value != trunc(value) | value < 0)
    },
    logical(1)
  )
  if (any(bad)) {
    cli::cli_abort(c(
      "{.field {channels[bad]}} must be {?a/} whole number{?s} of zero or
      more, or {.fn read_lut} drops the whole row",
      "i" = "Colour channels run from {.val {0L}} to {.val {255L}}."
    ))
  }
  invisible(x)
}


#' Non-zero label ids present in a volume
#' @noRd
volume_label_ids <- function(input_volume) {
  ids <- unique(c(read_volume(input_volume)))
  sort(ids[!is.na(ids) & ids != 0])
}


#' Restrict a colour table to the labels a volume actually contains
#'
#' A full FreeSurferColorLUT carries over a thousand entries; downstream
#' classification would otherwise treat every one of them as a region the
#' atlas holds, whether or not a single voxel carries it.
#' @noRd
keep_labels_in_volume <- function(colortable, vol_labels, verbose = FALSE) {
  kept <- colortable[colortable$idx %in% vol_labels, , drop = FALSE]
  if (nrow(kept) == 0) {
    cli::cli_abort("No matching labels found in volume and color table")
  }

  dropped <- nrow(colortable) - nrow(kept)
  if (verbose && dropped > 0) {
    cli::cli_alert_info(
      "Dropped {dropped} colour table entr{?y/ies} absent from the volume"
    )
  }
  kept
}


#' Colour table for a volume, generated when none was supplied
#'
#' @return List with the `colortable` restricted to labels in the volume and
#'   the `vol_labels` themselves.
#' @noRd
load_volume_colortable <- function(input_lut, input_volume, verbose = FALSE) {
  if (is.null(input_lut)) {
    cli::cli_warn(c(
      "No color lookup table provided",
      "i" = "Region names will be generic (e.g., 'region_0010')",
      "i" = "The atlas will have no palette; plotting picks its own colours"
    ))
    colortable <- generate_colortable_from_volume(input_volume)
    return(list(colortable = colortable, vol_labels = colortable$idx))
  }

  vol_labels <- volume_label_ids(input_volume)
  list(
    colortable = keep_labels_in_volume(get_lut(input_lut), vol_labels, verbose),
    vol_labels = vol_labels
  )
}
