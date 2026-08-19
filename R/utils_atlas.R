# Atlas name derivation ----

#' @noRd
#' @importFrom tools file_ext file_path_sans_ext
derive_atlas_name <- function(filepath) {
  if (length(filepath) != 1L || is.na(filepath)) {
    cli::cli_abort("A single input file is required to derive an atlas name")
  }
  name <- basename(filepath)
  ext <- tools::file_ext(name)
  name <- tools::file_path_sans_ext(name)
  if (ext %in% c("gii", "nii")) {
    name <- tools::file_path_sans_ext(name)
  }
  name <- gsub("^[lr]h\\.|\\.[LR]\\.", "", name)
  gsub(".", "_", name, fixed = TRUE)
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
  if (length(label_name) != 1L || is.na(label_name) || !nzchar(label_name)) {
    return(default)
  }

  affix <- detect_hemi_affix(label_name)
  if (!is.null(affix)) {
    return(affix)
  }

  if (!strict) {
    contains <- detect_hemi_contains(label_name)
    if (!is.null(contains)) {
      return(contains)
    }
  }

  default
}

#' Detect hemisphere from prefix/suffix affix patterns
#' @noRd
detect_hemi_affix <- function(label_name) {
  left_prefix <- grepl("^(Left|left|lh|L)[- _.]+", label_name)
  left_suffix <- grepl("[- _.]+(left|lh|L|l)$", label_name)
  if (left_prefix || left_suffix) {
    return("left")
  }

  right_prefix <- grepl("^(Right|right|rh|R)[- _.]+", label_name)
  right_suffix <- grepl("[- _.]+(right|rh|R|r)$", label_name)
  if (right_prefix || right_suffix) {
    return("right")
  }

  NULL
}

#' Detect hemisphere from substring anywhere in the label
#' @noRd
detect_hemi_contains <- function(label_name) {
  if (grepl("left|lh", label_name, ignore.case = TRUE)) {
    return("left")
  }
  if (grepl("right|rh", label_name, ignore.case = TRUE)) {
    return("right")
  }
  NULL
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
#' Removes hemisphere affixes and normalizes the region name by converting
#' dashes and underscores to spaces and lowercasing.
#'
#' The affixes stripped here must match the ones [detect_hemi()] recognises.
#' Where they disagree the hemisphere ends up in `region` as well as `hemi`:
#' `detect_hemi()` reads the `L_`/`R_` convention, so `R_Fx` correctly gave
#' hemi "right", while this function left the prefix in place and produced
#' region "r fx". Two hemispheres of one structure then look like two
#' different structures, since `region` is what pairs them.
#'
#' @param label_name Label name to clean
#' @param remove_hemi Remove hemisphere affixes (default TRUE)
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
    stripped <- gsub(
      "^(Left|Right|left|right|lh|rh|L|R)[- _.]+",
      "",
      region
    )
    stripped <- gsub(
      "[- _.]+(left|right|lh|rh)$",
      "",
      stripped,
      ignore.case = TRUE
    )
    # Never strip a label down to nothing: a structure genuinely named "left"
    # would otherwise lose its whole name.
    region <- ifelse(nzchar(stripped), stripped, region)
  }

  if (normalize) {
    region <- gsub("[()]", " ", region)
    region <- gsub("[-_/]", " ", region)
    region <- tolower(region)
    region <- gsub("\\s+", " ", trimws(region))
  }

  region
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
    as.character(fs::path(output_dir, atlas_name))
  }

  dirs <- list(
    base = base,
    snapshots = as.character(fs::path(base, "snapshots")),
    processed = as.character(fs::path(base, "processed")),
    masks = as.character(fs::path(base, "masks"))
  )

  if (type %in% c("subcortical", "cerebellar")) {
    dirs$meshes <- as.character(fs::path(base, "meshes"))
  }

  if (type == "tract") {
    dirs$volumes <- as.character(fs::path(base, "volumes"))
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
  x <- gsub("(", "_", x, fixed = TRUE)
  x <- gsub(")", "", x, fixed = TRUE)
  x <- gsub("/", "-", x, fixed = TRUE)
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

  needs_colour <- is.na(raw_colours) & names(raw_colours) != "unknown"
  if (any(needs_colour)) {
    raw_colours[needs_colour] <- generate_region_colours(sum(needs_colour))
  }
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

  if ("vol_idx" %in% names(atlas_data)) {
    result$vol_idx <- stats::setNames(
      atlas_data$vol_idx,
      atlas_data$label
    )
  }

  result
}


# Shared pipeline helpers ----

#' Resolve config for the surface-based pipelines
#'
#' Shared by the cortical and cerebellar builders, which both run two steps and
#' support refinement smoothing.
#' @noRd
validate_surface_config <- function(
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  tolerance,
  smooth_refinements = NULL
) {
  config <- resolve_common_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance,
    smoothness = NULL,
    steps = NULL,
    max_step = 2L
  )
  config$smooth_refinements <- get_smooth_refinements(smooth_refinements)

  config
}


#' @noRd
resolve_common_config <- function(
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  tolerance,
  smoothness,
  steps,
  max_step
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
  atlas,
  config,
  dirs,
  start_time,
  type_label = "Brain",
  unit = "regions",
  early_step = 1L
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

  if (is.null(atlas)) {
    return(invisible(NULL))
  }

  if (ggseg.formats::is_atlas_sf(atlas)) {
    atlas <- ggseg.formats::as_polygon_atlas(atlas)
  }
  atlas
}


#' @noRd
run_image_steps <- function(
  config,
  dirs,
  step_map,
  total_steps,
  dilate = NULL,
  vertex_size_limits = NULL
) {
  fmt <- function(step) sprintf("%s/%s", step, total_steps)

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
      dirs$masks,
      dirs$base,
      step = fmt(step_map$extract),
      verbose = config$verbose,
      vertex_size_limits = vertex_size_limits
    )
  }

  if (step_map$smooth %in% config$steps) {
    smooth_contours(
      dirs$base,
      config$smoothness,
      step = fmt(step_map$smooth),
      verbose = config$verbose
    )
  }

  if (step_map$reduce %in% config$steps) {
    reduce_vertex(
      dirs$base,
      config$tolerance,
      smoothness = config$smoothness,
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

  lut <- if (is.character(input_lut)) read_lut(input_lut) else input_lut
  region_names <- if ("region" %in% names(lut)) {
    lut$region
  } else if ("label" %in% names(lut)) {
    lut$label
  } else {
    NULL
  }
  colours <- if ("hex" %in% names(lut)) {
    lut$hex
  } else if (all(c("R", "G", "B") %in% names(lut))) {
    grDevices::rgb(lut$R, lut$G, lut$B, maxColorValue = 255)
  } else {
    NULL
  }

  list(region_names = region_names, colours = colours)
}


#' @noRd
generate_region_colours <- function(n) {
  if (n <= 8) {
    grDevices::hcl.colors(n, palette = "Set2")
  } else if (n <= 36) {
    grDevices::palette.colors(n, palette = "Polychrome 36")
  } else {
    grDevices::hcl.colors(n, palette = "Dynamic")
  }
}
