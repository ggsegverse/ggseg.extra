# Atlas name derivation ----

#' @noRd
#' @importFrom tools file_ext file_path_sans_ext
derive_atlas_name <- function(filepath) {
  if (length(filepath) == 0 || is.na(filepath)) {
    cli::cli_abort("No input file provided to derive atlas name from")
  }
  name <- basename(filepath)
  ext <- tools::file_ext(name)
  name <- tools::file_path_sans_ext(name)
  if (ext %in% c("gii", "nii")) {
    name <- tools::file_path_sans_ext(name)
  }
  name <- gsub("^[lr]h\\.|\\.[LR]\\.", "", name)
  gsub("\\.", "_", name)
}


# Hemisphere utilities ----

#' Detect hemisphere from label name
#'
#' Detects whether a label belongs to left or right hemisphere based on
#' common naming conventions. Handles multiple patterns:
#' - Prefix: "Left-", "left_", "lh.", "lh_", "L_"
#' - Suffix: "_left", "_lh", "_L", "_l"
#' - Contains: "left", "right" (case insensitive)
#'
#' @param label_name Character string containing label/region name
#' @param strict If TRUE, only match prefix patterns. If FALSE (default),
#'   also check if label contains "left"/"right" anywhere.
#' @param default Value to return when no hemisphere detected. Default is
#'   NA_character_. Use "midline" for tract atlases.
#' @return "left", "right", or the default value
#' @noRd
detect_hemi <- function(label_name, strict = FALSE, default = NA_character_) {
  if (is.na(label_name) || label_name == "") {
    return(default)
  }

  left_prefix <- grepl("^(Left|left|lh|L)[- _.]+", label_name)
  left_suffix <- grepl("[- _.]+(left|lh|L|l)$", label_name)
  right_prefix <- grepl("^(Right|right|rh|R)[- _.]+", label_name)
  right_suffix <- grepl("[- _.]+(right|rh|R|r)$", label_name)

  if (left_prefix || left_suffix) {
    return("left")
  }
  if (right_prefix || right_suffix) {
    return("right")
  }

  if (!strict) {
    if (grepl("left|lh", label_name, ignore.case = TRUE)) {
      return("left")
    }
    if (grepl("right|rh", label_name, ignore.case = TRUE)) {
      return("right")
    }
  }

  default
}

#' Vectorized hemisphere detection
#' @noRd
detect_hemi_vec <- function(
  label_names,
  strict = FALSE,
  default = NA_character_
) {
  vapply(
    label_names,
    detect_hemi,
    character(1),
    strict = strict,
    default = default,
    USE.NAMES = FALSE
  )
}

#' Map short hemisphere code to long form
#' @noRd
hemi_to_long <- function(hemi_short) {
  if (hemi_short == "lh") {
    "left"
  } else if (hemi_short == "rh") {
    "right"
  } else {
    hemi_short
  }
}

#' Map long hemisphere to short code
#' @noRd
hemi_to_short <- function(hemi_long) {
  if (hemi_long == "left") {
    "lh"
  } else if (hemi_long == "right") {
    "rh"
  } else {
    hemi_long
  }
}


# Region name utilities ----

#' Clean region name from label
#'
#' Removes hemisphere prefix and normalizes the region name by converting
#' dashes and underscores to spaces and lowercasing.
#'
#' @param label_name Label name to clean
#' @param remove_hemi Remove hemisphere prefix (default TRUE)
#' @param normalize Convert to lowercase with spaces (default TRUE)
#' @return Cleaned region name
#' @noRd
clean_region_name <- function(
  label_name,
  remove_hemi = TRUE,
  normalize = TRUE
) {
  region <- label_name

  if (remove_hemi) {
    region <- gsub("^(Left|Right|left|right|lh|rh)[- _.]?", "", region)
  }

  if (normalize) {
    region <- gsub("[()]", " ", region)
    region <- gsub("[-_/]", " ", region)
    region <- tolower(region)
    region <- gsub("\\s+", " ", trimws(region))
  }

  region
}

#' Vectorized region name cleaning
#' @noRd
clean_region_names <- function(
  label_names,
  remove_hemi = TRUE,
  normalize = TRUE
) {
  vapply(
    label_names,
    clean_region_name,
    character(1),
    remove_hemi = remove_hemi,
    normalize = normalize,
    USE.NAMES = FALSE
  )
}


# Directory setup ----

#' Setup standard atlas directory structure
#' @param output_dir Base output directory
#' @param atlas_name Name of the atlas
#' @param type Type of atlas: "cortical", "subcortical", or "tract"
#' @return Named list of directory paths
#' @noRd
setup_atlas_dirs <- function(output_dir, atlas_name = NULL, type = "cortical") {
  base <- if (is.null(atlas_name)) {
    output_dir
  } else {
    file.path(output_dir, atlas_name)
  }

  dirs <- list(
    base = base,
    snapshots = file.path(base, "snapshots"),
    processed = file.path(base, "processed"),
    masks = file.path(base, "masks")
  )

  if (type == "subcortical") {
    dirs$meshes <- file.path(base, "meshes")
  }

  if (type == "tract") {
    dirs$volumes <- file.path(base, "volumes")
  }

  invisible(
    lapply(dirs, mkdir)
  )

  dirs
}


# Label sanitization ----

#' Make labels filesystem-safe
#'
#' Replaces spaces, parentheses, slashes, and other problematic characters
#' so labels can be safely used in filenames and as machine identifiers.
#' Human-readable names belong in the `region` column, not `label`.
#'
#' @param x Character vector of labels
#' @return Sanitized character vector
#' @noRd
sanitize_label <- function(x) {
  x <- trimws(x)
  x <- gsub("\\s+", "_", x)
  x <- gsub("\\(", "_", x)
  x <- gsub("\\)", "", x)
  x <- gsub("/", "-", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  x
}


# Atlas data construction ----

#' Build core, palette, and vertices/meshes from atlas data
#'
#' Consolidates the repeated pattern of building atlas components from a
#' data frame containing hemi, region, label, colour, and vertices/mesh columns.
#'
#' Labels are sanitized to be filesystem-safe (spaces, parentheses, and
#' slashes are replaced). Human-readable names are kept in the `region` column.
#'
#' Labels with empty vertices are filtered out (these are context-only regions
#' like the medial wall that will only appear in sf geometry).
#'
#' @param atlas_data Data frame with hemi, region, label, colour columns
#'   and either vertices (list column) or mesh (list column)
#' @return Named list with core, palette, and either vertices_df or meshes_df
#' @noRd
#' @importFrom dplyr distinct bind_rows
build_atlas_components <- function(atlas_data) {
  atlas_data$label <- sanitize_label(atlas_data$label)

  if ("vertices" %in% names(atlas_data)) {
    vertex_lengths <- vapply(atlas_data$vertices, length, integer(1))
    atlas_data <- atlas_data[vertex_lengths > 0, , drop = FALSE]
  }

  core <- distinct(atlas_data, hemi, region, label)

  raw_colours <- stats::setNames(atlas_data$colour, atlas_data$label)
  raw_colours <- raw_colours[!duplicated(names(raw_colours))]
  palette <- if (all(is.na(raw_colours))) NULL else raw_colours

  result <- list(core = core, palette = palette)

  if ("vertices" %in% names(atlas_data)) {
    vertices_df <- data.frame(
      label = atlas_data$label,
      stringsAsFactors = FALSE
    )
    vertices_df$vertices <- atlas_data$vertices
    result$vertices_df <- vertices_df
  }

  if ("mesh" %in% names(atlas_data)) {
    meshes_df <- data.frame(
      label = atlas_data$label,
      stringsAsFactors = FALSE
    )
    meshes_df$mesh <- atlas_data$mesh
    result$meshes_df <- meshes_df
  }

  result
}


# Shared pipeline helpers ----

#' @noRd
resolve_common_config <- function(
  output_dir, verbose, cleanup, skip_existing,
  tolerance, smoothness, steps, max_step
) {
  list(
    output_dir = get_output_dir(output_dir),
    verbose = is_verbose(verbose),
    cleanup = get_cleanup(cleanup),
    skip_existing = get_skip_existing(skip_existing),
    tolerance = get_tolerance(tolerance),
    smoothness = get_smoothness(smoothness),
    steps = if (is.null(steps)) seq_len(max_step) else as.integer(steps)
  )
}


#' @noRd
finalize_atlas <- function(
  atlas, config, dirs, start_time,
  type_label = "Brain", unit = "regions", early_step = 1L
) {
  if (config$cleanup) {
    unlink(dirs$base, recursive = TRUE)
    if (config$verbose) cli::cli_alert_success("Temporary files removed")
  }

  if (config$verbose) {
    if (!is.null(atlas)) {
      # fmt: skip
      type <- if (max(config$steps) == early_step) { # nolint
        "3D"
      } else {
        type_label
      }
      cli::cli_alert_success(
        "{type} atlas created with {nrow(atlas$core)} {unit}"
      )
    } else {
      cli::cli_alert_success("Completed steps {.val {config$steps}}")
    }
    log_elapsed(start_time) # nolint: object_usage_linter.
  }

  if (is.null(atlas)) invisible(NULL) else atlas
}


#' @noRd
run_image_steps <- function(
  config, dirs, step_map, total_steps,
  dilate = NULL, vertex_size_limits = NULL
) {
  fmt <- function(step) paste0(step, "/", total_steps)

  if (step_map$process %in% config$steps) {
    if (config$verbose) {
      cli::cli_progress_step("{fmt(step_map$process)} Processing images")
    }
    process_and_mask_images(
      # nolint: object_usage_linter.
      dirs$snapshots,
      dirs$processed,
      dirs$masks,
      dilate = dilate,
      skip_existing = config$skip_existing
    )
    if (config$verbose) cli::cli_progress_done()
  }

  if (step_map$extract %in% config$steps) {
    extract_contours(
      dirs$masks, dirs$base,
      step = fmt(step_map$extract),
      verbose = config$verbose,
      vertex_size_limits = vertex_size_limits
    )
  }

  if (step_map$smooth %in% config$steps) {
    smooth_contours(
      dirs$base, config$smoothness,
      step = fmt(step_map$smooth),
      verbose = config$verbose
    )
  }

  if (step_map$reduce %in% config$steps) {
    reduce_vertex(
      dirs$base, config$tolerance,
      step = fmt(step_map$reduce),
      verbose = config$verbose
    )
  }
}


#' @noRd
parse_lut_colours <- function(input_lut) {
  if (is.null(input_lut)) {
    return(list(region_names = NULL, colours = NULL))
  }

  lut <- if (is.character(input_lut)) read_ctab(input_lut) else input_lut
  region_names <- lut$region
  colours <- if ("hex" %in% names(lut)) {
    lut$hex
  } else if (all(c("R", "G", "B") %in% names(lut))) {
    grDevices::rgb(lut$R, lut$G, lut$B, maxColorValue = 255)
  } else {
    NULL
  }

  list(region_names = region_names, colours = colours)
}
