# Whole-brain atlas creation ----

#' Create atlas from whole-brain volumetric parcellation
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Build a brain atlas from a single volumetric parcellation (NIfTI/MGZ) that
#' contains both cortical and subcortical regions. Cortical regions are
#' projected onto the fsaverage5 surface via FreeSurfer's `mri_vol2surf`
#' and rendered as surface views, while subcortical regions go through
#' the mesh-based subcortical pipeline.
#'
#' Requires FreeSurfer.
#'
#' @section Label classification:
#' The pipeline must know which labels are cortical (rendered on the surface)
#' and which are subcortical (rendered as 3D meshes / 2D slices). Three
#' mechanisms are available, applied in priority order:
#'
#' 1. **Function arguments** (highest priority): `cortical_labels` and
#'    `subcortical_labels` override everything for the specified labels.
#' 2. **LUT `type` column**: If the colour lookup table has a `type` column
#'    with values `"cortical"` or `"subcortical"`, that classification is
#'    used for any labels not covered by the function arguments. This is the
#'    recommended approach for reproducible atlas creation.
#' 3. **Vertex-count heuristic** (fallback): Labels with at least
#'    `min_vertices` vertices on the surface projection are classified as
#'    cortical; the rest as subcortical.
#'
#' @section Volume pre-processing:
#' Before surface projection, the volume is filtered so that only voxel IDs
#' listed in the LUT are kept; all other non-zero voxels are zeroed out.
#' This prevents unlisted structures (e.g. white matter, ventricle masks)
#' from bleeding onto the cortical surface during label dilation.
#'
#' Cortical voxels are also used to generate the brain-outline reference
#' geometry for the subcortical pipeline. The volume's orientation matrix
#' (`xform`) is used to split cortical voxels by hemisphere: left-hemisphere
#' voxels map to FreeSurfer label 3 (left cortex) and right-hemisphere to
#' label 42 (right cortex).
#'
#' @section Human oversight:
#' This is the most complex pipeline in ggsegExtra and the one most likely
#' to need manual correction. Recommended workflow:
#'
#' 1. Run `steps = 1:2` first to project the volume and classify labels.
#' 2. Inspect `result$cortical_labels` and `result$subcortical_labels`.
#'    If the automatic split is wrong, either add a `type` column to the
#'    LUT or use `cortical_labels` / `subcortical_labels` to override.
#' 3. Run the full pipeline once you are satisfied with the split.
#' 4. Visually inspect the resulting atlas with `ggseg()` / `ggseg3d()`.
#'
#' The cortical surface projection uses FreeSurfer's cortex label
#' (`{hemi}.cortex.label`) to prevent label dilation into the medial wall.
#' This file ships with fsaverage5 and is always required.
#'
#' @param input_volume Path to volumetric parcellation in MNI152 space
#'   (.mgz, .nii, .nii.gz).
#' @param input_lut Path to FreeSurfer-style colour lookup table, or a
#'   data.frame with columns `idx`, `label`, `R`, `G`, `B`, `A`.
#'   An optional `type` column with values `"cortical"` or `"subcortical"`
#'   controls label classification (see **Label classification**). Voxel IDs
#'   not listed in the LUT are automatically zeroed out before surface
#'   projection (see **Volume pre-processing**).
#'   If NULL, generic names and no palette.
#' @template atlas_name
#' @template output_dir
#' @param projfrac Cortical depth fraction for projection (0 = white surface,
#'   1 = pial surface). Only used when `projfrac_range` is NULL. Default 0.5.
#' @param projfrac_range Numeric vector `c(min, max, delta)` for multi-depth
#'   projection via `mri_vol2surf --projfrac-max`. Samples at multiple cortical
#'   depths and takes the maximum label value at each vertex, giving much better
#'   surface coverage than single-depth projection. Default `c(0, 1, 0.1)`.
#'   Set to NULL to use single-depth `projfrac` instead.
#' @param subject Target surface subject. Default "fsaverage5".
#' @param regheader If TRUE (default), assumes volume RAS coordinates match
#'   the subject space and uses `--regheader`. Works well for standard
#'   MNI152-space volumes. If FALSE, uses FreeSurfer's `--mni152reg`
#'   registration (may produce noisy results due to surf2surf resampling).
#' @param min_vertices Minimum total vertex count across hemispheres for a
#'   label to be classified as cortical by the vertex-count heuristic (see
#'   **Label classification**). Ignored when `type` column or explicit label
#'   vectors are provided. Default 50.
#' @param cortical_labels Character vector of label names to force as cortical.
#'   Highest priority; overrides LUT `type` and the vertex-count heuristic.
#' @param subcortical_labels Character vector of label names to force as
#'   subcortical. Highest priority; overrides LUT `type` and the vertex-count
#'   heuristic.
#' @param cortical_views Views for cortical sub-pipeline.
#'   Default `c("lateral", "medial", "superior", "inferior")`.
#' @param subcortical_views Views for subcortical sub-pipeline. Default NULL
#'   (auto-detected).
#' @param decimate Mesh decimation ratio for subcortical meshes (0-1).
#'   Default 0.5.
#' @template tolerance
#' @template smoothness
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run. Default NULL runs all steps.
#'   Steps are:
#'   \itemize{
#'     \item 1: Project volume onto surface
#'     \item 2: Split labels into cortical/subcortical
#'     \item 3: Run cortical pipeline
#'     \item 4: Run subcortical pipeline
#'   }
#'   Use `steps = 1:2` to run projection and split only.
#'
#' @return A named list with elements `cortical` and `subcortical`, each a
#'   `ggseg_atlas` object (or NULL if no regions of that type exist).
#' @export
#' @importFrom dplyr tibble bind_rows filter
#' @importFrom freesurfer have_fs fs_subj_dir
#' @importFrom grDevices rgb
#' @importFrom tools file_path_sans_ext
#'
#' @examples
#' \dontrun{
#' # --- Recommended: LUT with type column ---
#' lut <- data.frame(
#'   idx   = c(10, 11, 49, 50, 101:148),
#'   label = c("Left-Thalamus", "Left-Caudate",
#'             "Right-Thalamus", "Right-Caudate",
#'             paste0("cortical_region_", 1:48)),
#'   type  = c(rep("subcortical", 4), rep("cortical", 48)),
#'   R = sample(50:220, 52, TRUE),
#'   G = sample(50:220, 52, TRUE),
#'   B = sample(50:220, 52, TRUE),
#'   A = 255L
#' )
#'
#' result <- create_wholebrain_from_volume(
#'   input_volume = "my_atlas.nii.gz",
#'   input_lut = lut,
#'   atlas_name = "my_atlas"
#' )
#' result$cortical   # surface-based cortical atlas
#' result$subcortical # mesh-based subcortical atlas
#'
#' # --- Without type column: automatic classification ---
#' result <- create_wholebrain_from_volume(
#'   input_volume = "atlas.nii.gz",
#'   input_lut = "atlas_LUT.txt",
#'   atlas_name = "auto_atlas"
#' )
#'
#' # --- Inspect classification before full run ---
#' result <- create_wholebrain_from_volume(
#'   input_volume = "atlas.nii.gz",
#'   input_lut = "atlas_LUT.txt",
#'   steps = 1:2
#' )
#' result$cortical_labels
#' result$subcortical_labels
#' }
create_wholebrain_from_volume <- function(
  input_volume,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  projfrac = 0.5,
  projfrac_range = c(0, 1, 0.1),
  subject = "fsaverage5",
  regheader = TRUE,
  min_vertices = 50L,
  cortical_labels = NULL,
  subcortical_labels = NULL,
  cortical_views = c("lateral", "medial", "superior", "inferior"),
  subcortical_views = NULL,
  decimate = 0.5,
  tolerance = NULL,
  smoothness = NULL,
  cleanup = NULL,
  verbose = get_verbose(), # nolint: object_usage_linter
  skip_existing = NULL,
  steps = NULL
) {
  start_time <- Sys.time()

  config <- validate_wholebrain_config(
    input_volume = input_volume,
    input_lut = input_lut,
    atlas_name = atlas_name,
    output_dir = output_dir,
    projfrac = projfrac,
    projfrac_range = projfrac_range,
    subject = subject,
    regheader = regheader,
    min_vertices = min_vertices,
    verbose = verbose,
    cleanup = cleanup,
    skip_existing = skip_existing,
    tolerance = tolerance,
    smoothness = smoothness,
    steps = steps
  )

  dirs <- setup_atlas_dirs(
    config$output_dir, config$atlas_name, type = "cortical"
  )

  if (config$verbose) {
    cli::cli_h1("Creating whole-brain atlas {.val {config$atlas_name}}")
    cli::cli_alert_warning(paste(
      "This pipeline combines volume-to-surface projection with automatic",
      "cortical/subcortical classification. Both steps are heuristic and",
      "require manual validation. Run with {.code steps = 1:2} first to",
      "inspect the label split before committing to the full pipeline."
    ))
    cli::cli_alert_info("Volume: {.path {config$input_volume}}")
    if (!is.null(config$input_lut) && is.character(config$input_lut)) {
      cli::cli_alert_info("Color LUT: {.path {config$input_lut}}")
    }
    cli::cli_alert_info(
      "Setting output directory to {.path {config$output_dir}}"
    )
  }

  projection <- wholebrain_resolve_projection(config, dirs)

  split <- wholebrain_resolve_split(
    config, dirs, projection,
    cortical_labels = cortical_labels,
    subcortical_labels = subcortical_labels
  )

  if (max(config$steps) <= 2L) {
    if (config$verbose) {
      cli::cli_alert_info(paste(
        "Inspect {.code split$cortical_labels} and",
        "{.code split$subcortical_labels}.",
        "Override with {.arg cortical_labels}/{.arg subcortical_labels}",
        "if needed, then re-run with all steps."
      ))
      log_elapsed(start_time)
    }
    return(invisible(split))
  }

  cortical_atlas <- NULL
  subcortical_atlas <- NULL

  if (3L %in% config$steps && length(split$cortical_labels) > 0) {
    refined <- wholebrain_refine_cortical_projection(
      config, dirs, projection, split
    )
    cortical_atlas <- wholebrain_run_cortical(
      config, dirs, refined, split,
      views = cortical_views
    )
  }

  if (4L %in% config$steps && length(split$subcortical_labels) > 0) {
    subcortical_atlas <- wholebrain_run_subcortical(
      config, dirs, split,
      colortable = projection$colortable,
      views = subcortical_views,
      decimate = decimate
    )
  }

  result <- list(
    cortical = cortical_atlas,
    subcortical = subcortical_atlas
  )

  if (config$cleanup) {
    unlink(dirs$base, recursive = TRUE)
    if (config$verbose) cli::cli_alert_success("Temporary files removed")
  }

  if (config$verbose) {
    n_cort <- if (!is.null(cortical_atlas)) { # nolint: object_usage_linter.
      nrow(cortical_atlas$core)
    } else {
      0L
    }
    n_sub <- if (!is.null(subcortical_atlas)) { # nolint: object_usage_linter.
      nrow(subcortical_atlas$core)
    } else {
      0L
    }
    cli::cli_alert_success(
      "Whole-brain atlas created: {n_cort} cortical, {n_sub} subcortical"
    )
    log_elapsed(start_time)
  }

  result
}


# Validation ----

#' @noRd
validate_wholebrain_config <- function(
  input_volume, input_lut, atlas_name, output_dir,
  projfrac, projfrac_range, subject, regheader, min_vertices,
  verbose, cleanup, skip_existing,
  tolerance, smoothness, steps
) {
  config <- resolve_common_config(
    output_dir, verbose, cleanup, skip_existing,
    tolerance, smoothness, steps, max_step = 4L
  )

  check_fs(abort = TRUE)

  if (!file.exists(input_volume)) {
    cli::cli_abort("Volume file not found: {.path {input_volume}}")
  }
  if (!is.null(input_lut) && is.character(input_lut) &&
        !file.exists(input_lut)) {
    cli::cli_abort("Color lookup table not found: {.path {input_lut}}")
  }

  config$output_dir <- normalizePath(config$output_dir, mustWork = FALSE)

  if (is.null(atlas_name)) {
    atlas_name <- basename(input_volume)
    atlas_name <- sub(
      "\\.(nii\\.gz|nii|mgz)$", "", atlas_name,
      ignore.case = TRUE
    )
  }

  config$input_volume <- input_volume
  config$input_lut <- input_lut
  config$atlas_name <- atlas_name
  config$projfrac <- projfrac
  config$projfrac_range <- projfrac_range
  config$subject <- subject
  config$regheader <- regheader
  config$min_vertices <- as.integer(min_vertices)
  config
}


# Step 1: Project volume onto surface ----

#' @noRd
wholebrain_resolve_projection <- function(config, dirs) {
  files <- c(
    file.path(dirs$base, "atlas_data.rds"),
    file.path(dirs$base, "colortable.rds")
  )
  cached <- load_or_run_step(
    1L, config$steps, files, config$skip_existing,
    "Step 1 (Project to surface)"
  )

  if (!cached$run) {
    if (config$verbose) {
      cli::cli_h2("Surface projection")
      cli::cli_alert_success("Loaded existing surface projection")
    }
    return(list(
      atlas_data = cached$data[["atlas_data.rds"]],
      colortable = cached$data[["colortable.rds"]]
    ))
  }

  if (config$verbose) {
    cli::cli_h2("Surface projection")
    cli::cli_progress_step("Projecting volume onto surface")
  }

  colortable <- if (is.null(config$input_lut)) {
    cli::cli_warn(c(
      "No color lookup table provided",
      "i" = "Region names will be generic (e.g., 'region_0010')",
      "i" = "Atlas will have no palette"
    ))
    generate_colortable_from_volume(config$input_volume)
  } else {
    get_ctab(config$input_lut)
  }

  atlas_data <- wholebrain_project_to_surface(
    input_volume = config$input_volume,
    colortable = colortable,
    subject = config$subject,
    projfrac = config$projfrac,
    projfrac_range = config$projfrac_range,
    regheader = config$regheader,
    output_dir = dirs$base,
    verbose = config$verbose
  )

  saveRDS(atlas_data, file.path(dirs$base, "atlas_data.rds"))
  saveRDS(colortable, file.path(dirs$base, "colortable.rds"))
  if (config$verbose) cli::cli_progress_done()

  list(atlas_data = atlas_data, colortable = colortable)
}


#' Convert a filled overlay vector to atlas_data rows for one hemisphere
#'
#' @param include_unknown If TRUE, unlabeled vertices (value 0) are included
#'   as an "unknown" region. This provides the brain outline context geometry
#'   needed for medial wall rendering.
#' @noRd
overlay_to_atlas_data <- function(
  overlay, hemi_short, colortable, include_unknown = FALSE
) {
  hemi <- hemi_to_long(hemi_short)
  unique_labels <- sort(unique(overlay[overlay != 0L]))

  rows <- lapply(unique_labels, function(label_val) {
    ct_row <- colortable[colortable$idx == label_val, ]
    if (nrow(ct_row) == 0) return(NULL)

    label_name <- ct_row$label[1]
    safe_name <- sanitize_label(label_name)
    colour <- if ("color" %in% names(ct_row)) {
      ct_row$color[1]
    } else if (all(c("R", "G", "B") %in% names(ct_row))) {
      rgb(ct_row$R[1], ct_row$G[1], ct_row$B[1], maxColorValue = 255)
    } else {
      NA_character_
    }

    tibble(
      hemi = hemi,
      region = clean_region_name(label_name),
      label = paste(hemi_short, safe_name, sep = "_"),
      colour = colour,
      vertices = list(which(overlay == label_val) - 1L),
      source_label = label_name,
      source_idx = label_val
    )
  })

  result <- bind_rows(Filter(Negate(is.null), rows))

  if (include_unknown) {
    unknown_verts <- which(overlay == 0L) - 1L
    if (length(unknown_verts) > 0) {
      result <- bind_rows(result, tibble(
        hemi = hemi,
        region = "unknown",
        label = paste0(hemi_short, "_unknown"),
        colour = "#BEBEBE",
        vertices = list(unknown_verts),
        source_label = "unknown",
        source_idx = 0L
      ))
    }
  }

  result
}


#' @noRd
wholebrain_project_to_surface <- function(
  input_volume, colortable, subject, projfrac,
  projfrac_range, regheader, output_dir, verbose
) {
  surf_dir <- file.path(output_dir, "surface_overlays")
  mkdir(surf_dir)

  all_data <- list()

  for (hemi_short in c("lh", "rh")) {
    hemi <- hemi_to_long(hemi_short) # nolint: object_usage_linter
    output_mgz <- file.path(surf_dir, paste0(hemi_short, "_overlay.nii.gz"))

    reg_opts <- paste0(
      "--interp nearest --trgsubject ", subject
    )
    if (regheader) {
      reg_opts <- paste(reg_opts, "--regheader", subject)
    }

    mri_vol2surf(
      input_file = input_volume,
      output_file = output_mgz,
      hemisphere = hemi_short,
      projfrac = projfrac,
      projfrac_range = projfrac_range,
      mni152reg = !regheader,
      opts = reg_opts,
      verbose = verbose
    )

    if (!file.exists(output_mgz)) {
      cli::cli_abort(c(
        "mri_vol2surf failed to produce output for {hemi_short}",
        "i" = "Expected: {.path {output_mgz}}",
        "i" = "Check that the volume is in the correct space (MNI152 or native)"
      ))
    }

    overlay <- as.integer(c(RNifti::readNifti(output_mgz)))

    n_before <- sum(overlay != 0L) # nolint: object_usage_linter.
    overlay <- fill_surface_labels(overlay, hemi_short, subject)
    if (verbose) {
      n_after <- sum(overlay != 0L) # nolint: object_usage_linter.
      n_total <- length(overlay)
      n_medial <- n_total - n_after # nolint: object_usage_linter.
      pct <- sprintf( # nolint: object_usage_linter.
        "%.0f%%", 100 * n_after / n_total
      )
      cli::cli_alert(
        paste(
          "{hemi_short}: {n_before} -> {n_after}",
          "labeled vertices ({pct} cortex,",
          "{n_medial} medial wall)"
        )
      )
    }

    all_data[[hemi_short]] <- overlay_to_atlas_data(
      overlay, hemi_short, colortable, include_unknown = TRUE
    )
  }

  bind_rows(all_data)
}


# Step 2: Split labels ----

#' @noRd
wholebrain_resolve_split <- function(
  config, dirs, projection,
  cortical_labels = NULL,
  subcortical_labels = NULL
) {
  files <- file.path(dirs$base, "label_split.rds")
  cached <- load_or_run_step(
    2L, config$steps, files, config$skip_existing,
    "Step 2 (Split labels)"
  )

  if (!cached$run) {
    if (config$verbose) {
      cli::cli_h2("Label classification")
      cli::cli_alert_success("Loaded existing label classification")
    }
    return(cached$data[["label_split.rds"]])
  }

  if (config$verbose) {
    cli::cli_h2("Label classification")
    cli::cli_progress_step("Classifying cortical vs subcortical labels")
  }

  split <- wholebrain_classify_labels(
    atlas_data = projection$atlas_data,
    colortable = projection$colortable,
    min_vertices = config$min_vertices,
    cortical_labels = cortical_labels,
    subcortical_labels = subcortical_labels,
    verbose = config$verbose
  )

  saveRDS(split, file.path(dirs$base, "label_split.rds"))
  if (config$verbose) cli::cli_progress_done()

  split
}


#' Classify volume labels as cortical or subcortical
#'
#' Classification priority:
#' 1. `cortical_labels`/`subcortical_labels` function arguments (highest)
#' 2. `type` column on the colortable (`"cortical"` or `"subcortical"`)
#' 3. Vertex-count heuristic: labels with >= `min_vertices` on the surface
#'    projection are cortical, the rest subcortical (lowest)
#'
#' @param atlas_data Tibble from `wholebrain_project_to_surface()` with
#'   `source_label` and `vertices` columns.
#' @param colortable Colortable data.frame. If it has a `type` column with
#'   values `"cortical"` / `"subcortical"`, that is used for classification.
#' @param min_vertices Minimum total vertex count for cortical classification.
#' @param cortical_labels Manual override: force these labels as cortical.
#' @param subcortical_labels Manual override: force these labels as subcortical.
#' @param verbose Print classification summary.
#'
#' @return Named list with `cortical_labels` and `subcortical_labels`
#'   (character vectors of source label names).
#' @noRd
wholebrain_classify_labels <- function(
  atlas_data,
  colortable = NULL,
  min_vertices = 50L,
  cortical_labels = NULL,
  subcortical_labels = NULL,
  verbose = FALSE
) {
  vertex_counts <- tapply(
    vapply(atlas_data$vertices, length, integer(1)),
    atlas_data$source_label,
    sum
  )

  all_labels <- names(vertex_counts)
  classified_cortical <- character(0)
  classified_subcortical <- character(0)

  if (!is.null(cortical_labels)) {
    classified_cortical <- intersect(cortical_labels, all_labels)
  }
  if (!is.null(subcortical_labels)) {
    unmatched <- setdiff(subcortical_labels, all_labels)
    if (length(unmatched) > 0) {
      cli::cli_warn(
        "Subcortical labels not found in data: {.val {unmatched}}"
      )
    }
    classified_subcortical <- intersect(subcortical_labels, all_labels)
  }

  remaining <- setdiff(
    all_labels,
    c(classified_cortical, classified_subcortical)
  )

  has_type <- !is.null(colortable) && "type" %in% names(colortable)
  if (has_type && length(remaining) > 0) {
    lut_cortical <- colortable$label[colortable$type == "cortical"]
    lut_subcortical <- colortable$label[colortable$type == "subcortical"]
    classified_cortical <- c(
      classified_cortical, intersect(remaining, lut_cortical)
    )
    classified_subcortical <- c(
      classified_subcortical, intersect(remaining, lut_subcortical)
    )
    remaining <- setdiff(
      remaining, c(classified_cortical, classified_subcortical)
    )
  }

  if (length(remaining) > 0) {
    if (verbose && !has_type) {
      cli::cli_alert_info(
        paste(
          "No {.field type} column in LUT;",
          "classifying {length(remaining)} labels by vertex count"
        )
      )
    }
    auto_cortical <- remaining[vertex_counts[remaining] >= min_vertices]
    auto_subcortical <- remaining[vertex_counts[remaining] < min_vertices]
    classified_cortical <- c(classified_cortical, auto_cortical)
    classified_subcortical <- c(classified_subcortical, auto_subcortical)
  }

  if (verbose) {
    cli::cli_alert_info(
      paste(
        "{length(classified_cortical)} cortical,",
        "{length(classified_subcortical)} subcortical labels"
      )
    )
    if (length(classified_subcortical) > 0) {
      sub_info <- paste( # nolint: object_usage_linter.
        classified_subcortical,
        paste0("(", vertex_counts[classified_subcortical], "v)"),
        collapse = ", "
      )
      cli::cli_alert("Subcortical: {sub_info}")
    }
  }

  list(
    cortical_labels = classified_cortical,
    subcortical_labels = classified_subcortical,
    vertex_counts = vertex_counts
  )
}


# Step 2.5: Refine cortical projection ----

#' Remove subcortical labels from surface projection and re-fill
#'
#' When projecting a combined volume, subcortical voxels near the cortical
#' surface can "steal" vertices that should be cortical. This function reloads
#' the raw vol2surf overlays, zeros out subcortical label values, and re-runs
#' fill_surface_labels so dilation only spreads cortical labels.
#'
#' @param config Pipeline config.
#' @param dirs Pipeline directory structure.
#' @param projection Original projection from step 1 (needs `colortable`).
#' @param split Classification result from step 2 (needs `subcortical_labels`).
#' @return A list with `atlas_data` (refined) and `colortable` (unchanged).
#' @noRd
# nolint next: object_length_linter.
wholebrain_refine_cortical_projection <- function(
  config, dirs, projection, split
) {
  if (length(split$subcortical_labels) == 0) return(projection)

  subcort_idx <- projection$colortable$idx[
    projection$colortable$label %in% split$subcortical_labels
  ]
  if (length(subcort_idx) == 0) return(projection)

  surf_dir <- file.path(dirs$base, "surface_overlays")
  colortable <- projection$colortable[
    projection$colortable$label %in% split$cortical_labels,
  ]

  if (config$verbose) {
    cli::cli_progress_step(
      paste(
        "Refining cortical projection",
        "(removing {length(subcort_idx)} subcortical labels from surface)"
      )
    )
  }

  all_data <- lapply(c("lh", "rh"), function(hemi_short) {
    overlay_file <- file.path(surf_dir, paste0(hemi_short, "_overlay.nii.gz"))
    if (!file.exists(overlay_file)) {
      cli::cli_abort(
        "Overlay file missing: {.path {overlay_file}}. Re-run step 1."
      )
    }
    overlay <- as.integer(c(RNifti::readNifti(overlay_file)))
    overlay[overlay %in% subcort_idx] <- 0L
    overlay <- fill_surface_labels(overlay, hemi_short, config$subject)
    overlay_to_atlas_data(
      overlay, hemi_short, colortable, include_unknown = TRUE
    )
  })

  if (config$verbose) cli::cli_progress_done()

  list(
    atlas_data = bind_rows(all_data),
    colortable = colortable
  )
}


# Step 3: Run cortical pipeline ----

#' @noRd
wholebrain_run_cortical <- function(
  config, dirs, projection, split, views
) {
  if (config$verbose) {
    cli::cli_h2(
      "Cortical pipeline ({length(split$cortical_labels)} regions)"
    )
  }

  cortical_data <- projection$atlas_data[
    projection$atlas_data$source_label %in% split$cortical_labels,
  ]
  cortical_data <- cortical_data[
    , c("hemi", "region", "label", "colour", "vertices")
  ]

  cortical_name <- paste0(config$atlas_name, "_cortical")
  cortical_dirs <- setup_atlas_dirs(
    dirs$base, "cortical", type = "cortical"
  )

  cortical_config <- validate_cortical_config(
    output_dir = dirs$base,
    verbose = config$verbose,
    cleanup = FALSE,
    skip_existing = config$skip_existing,
    tolerance = config$tolerance,
    smoothness = config$smoothness,
    snapshot_dim = NULL,
    steps = NULL
  )

  step1 <- cortical_resolve_step1(
    cortical_config, cortical_dirs, cortical_name,
    read_fn = function() cortical_data,
    step_label = "Reading projected cortical data",
    cache_label = "Cortical step 1"
  )

  hemisphere <- unique(cortical_data$hemi)
  hemi_short <- vapply(
    hemisphere, hemi_to_short, character(1),
    USE.NAMES = FALSE
  )

  atlas <- cortical_pipeline(
    atlas_3d = step1$atlas_3d,
    components = step1$components,
    atlas_name = cortical_name,
    hemisphere = hemi_short,
    views = views,
    region_snapshot_fn = cortical_region_snapshots,
    config = cortical_config,
    dirs = cortical_dirs,
    start_time = Sys.time()
  )

  atlas
}


# Step 4: Run subcortical pipeline ----

#' @noRd
wholebrain_run_subcortical <- function(
  config, dirs, split, colortable, views, decimate
) {
  if (config$verbose) {
    cli::cli_h2(
      "Subcortical pipeline ({length(split$subcortical_labels)} regions)"
    )
  }

  subcort_ct <- colortable[
    colortable$label %in% split$subcortical_labels,
  ]

  subcort_lut <- file.path(dirs$base, "subcort_lut.txt")
  required_cols <- c("idx", "label", "R", "G", "B", "A")
  missing_cols <- setdiff(required_cols, names(subcort_ct))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      "Colortable missing required columns: {.val {missing_cols}}"
    )
  }
  write_ctab(subcort_ct[, required_cols], subcort_lut)

  cortical_idx <- colortable$idx[
    colortable$label %in% split$cortical_labels
  ]

  filtered_vol <- file.path(dirs$base, "subcort_volume.nii.gz")
  wholebrain_prepare_subcortical_volume(
    input_volume = config$input_volume,
    subcortical_idx = subcort_ct$idx,
    cortical_idx = cortical_idx,
    output_file = filtered_vol
  )

  subcort_name <- paste0(config$atlas_name, "_subcortical")

  atlas <- create_subcortical_from_volume(
    input_volume = filtered_vol,
    input_lut = subcort_lut,
    atlas_name = "subcortical",
    views = views,
    output_dir = dirs$base,
    decimate = decimate,
    tolerance = config$tolerance,
    smoothness = config$smoothness,
    verbose = config$verbose,
    cleanup = FALSE,
    skip_existing = config$skip_existing
  )

  atlas$atlas <- subcort_name
  atlas
}


#' Prepare volume for subcortical pipeline with cortex reference
#'
#' Keeps subcortical labels unchanged and remaps cortical labels to FS cortex
#' reference, so the subcortical pipeline can generate brain outline context
#' geometry via `detect_cortex_labels()`. Cortical labels are split by
#' hemisphere using the volume midpoint: left hemisphere voxels map to label 3
#' (FS left cortex), right hemisphere to label 42 (FS right cortex).
#' All other labels are zeroed.
#' @noRd
# nolint next: object_length_linter.
wholebrain_prepare_subcortical_volume <- function(
  input_volume, subcortical_idx, cortical_idx, output_file
) {
  vol <- read_volume(input_volume, reorient = FALSE)
  arr <- as.array(vol)
  result <- array(0L, dim = dim(arr))
  for (idx in subcortical_idx) {
    result[arr == idx] <- idx
  }
  cortical_mask <- arr %in% cortical_idx
  xform <- RNifti::xform(vol)
  x0_voxel <- round(solve(xform, c(0, 0, 0, 1))[1])
  x_idx <- slice.index(arr, 1)
  left_is_high <- xform[1, 1] < 0
  if (left_is_high) {
    result[cortical_mask & x_idx > x0_voxel] <- 3L
    result[cortical_mask & x_idx <= x0_voxel] <- 42L
  } else {
    result[cortical_mask & x_idx <= x0_voxel] <- 3L
    result[cortical_mask & x_idx > x0_voxel] <- 42L
  }
  out <- RNifti::asNifti(result, reference = vol)
  if (RNifti::orientation(out) != "RAS") {
    RNifti::orientation(out) <- "RAS"
  }
  RNifti::writeNifti(out, output_file)
  invisible(output_file)
}


# Surface label dilation ----

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
load_cortex_mask <- function(hemi, subject = "fsaverage5", n_vertices) {
  label_file <- file.path(
    freesurfer::fs_subj_dir(), subject, "label",
    paste0(hemi, ".cortex.label")
  )
  if (!file.exists(label_file)) {
    cli::cli_abort(c(
      "Cortex label not found: {.path {label_file}}",
      "i" = paste(
        "This file is required to prevent",
        "label dilation into the medial wall."
      ),
      "i" = paste(
        "It should exist for {.val {subject}}.",
        "Check your FreeSurfer installation."
      )
    ))
  }

  cortex_vertices <- read_label_vertices(label_file)
  mask <- logical(n_vertices)
  mask[cortex_vertices + 1L] <- TRUE
  mask
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
  surf_file <- file.path(
    freesurfer::fs_subj_dir(), subject, "surf",
    paste0(hemi, ".white")
  )
  if (!file.exists(surf_file)) {
    cli::cli_warn(
      "Surface file not found: {.path {surf_file}}, skipping dilation"
    )
    return(overlay)
  }

  surf <- freesurferformats::read.fs.surface(surf_file)
  adj <- build_adjacency(surf$faces, nrow(surf$vertices))

  cortex_mask <- load_cortex_mask(hemi, subject, length(overlay))

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

    if (n_new == 0L) break
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
  to   <- c(f2, f3, f1, f3, f1, f2)

  edges <- split(to, from)

  adj <- vector("list", n_vertices)
  idx <- as.integer(names(edges))
  adj[idx] <- lapply(edges, unique.default)
  adj
}
