# Region name utilities ----

#' Derive an atlas `region` from a label
#'
#' The rule every atlas pipeline here uses to fill the `region` column: strip
#' the hemisphere affix, turn brackets, hyphens, underscores and slashes into
#' spaces, lower-case the result and squeeze runs of whitespace.
#'
#' Exported because atlas build scripts need to reproduce it exactly. A script
#' that adds a `name` column keyed on `region`, for instance, has to key on
#' what the pipeline will actually derive; re-implementing the rule by hand is
#' how a key silently stops matching (an underscore handled but a hyphen not,
#' and one region joins to `NA`).
#'
#' The affixes recognised are `Left`/`Right`, `left`/`right`, `lh`/`rh` and
#' `L`/`R`, as a prefix or a suffix, separated by `-`, `_`, `.` or a space.
#' A label is never stripped to nothing, so a structure genuinely named
#' "left" keeps its name.
#'
#' @param label_name Character vector of labels.
#' @param remove_hemi Strip hemisphere affixes (default `TRUE`).
#' @param normalize Lower-case and convert separators to spaces
#'   (default `TRUE`).
#' @return A character vector of region names.
#' @export
#' @examples
#' label_to_region("Left-Thalamus")
#' label_to_region("Central_Lateral-Lateral_Posterior_Left")
#' label_to_region(c("Pu_Left", "SNc_PBP_VTA_Right"))
label_to_region <- function(
  label_name,
  remove_hemi = TRUE,
  normalize = TRUE
) {
  region <- label_name

  if (remove_hemi) {
    # vermis and midline are hemisphere values this package itself assigns --
    # detect_cerebellar_hemi() returns them, and detect_hemi() takes
    # "midline" as its default for tracts -- so a label carrying one is
    # carrying a hemisphere, exactly as left/right is, and the region name
    # should not keep it. Leaving them out is why every cerebellar region in
    # the ggsegverse was named "midline_<something>".
    stripped <- gsub(
      "^(Left|Right|left|right|lh|rh|L|R|Vermis|vermis|Midline|midline)[- _.]+",
      "",
      region
    )
    stripped <- gsub(
      "[- _.]+(left|right|lh|rh|l|r|vermis|midline)$",
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


# Context silhouette ----

#' The label pattern that matches an atlas's backdrop
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The grey drawn behind an atlas's structures is not a structure, and almost
#' every polish step treats it differently -- a backdrop wants rounding that
#' keeps its sulci, the structures want their staircase taken off. That means
#' writing the same pattern twice per build, in every build, and the pattern
#' has to agree with what the pipelines actually label it.
#'
#' This is that pattern, in one place. Use it rather than retyping the
#' spellings below, so a change of convention is one release rather than one
#' edit per atlas repository.
#'
#' @details
#' A backdrop reaches an atlas two ways, and this matches both, because from a
#' plotting point of view they are the same thing.
#'
#' The pipelines generate one for the surface a parcellation does not cover:
#' `lh_cortex` / `rh_cortex` on a cortical surface, `cerebellum` on the SUIT
#' flatmap, and `cortex`, `cortex_left` or `cortex_right` from the volumetric
#' slice tracing.
#'
#' A parcellation can also carry its own -- an annotation's `unknown`, `???` or
#' medial-wall region. Those arrive as regions and are demoted to backdrop
#' during the build, so an atlas's medial wall is as much the grey behind the
#' structures as a generated silhouette is.
#'
#' Anchored on purpose. A loose `"cortex"` also matches `Cerebellar_Cortex_*`
#' and `Left-Cerebral-Cortex`, which are structures; anchoring at the start is
#' what excludes them, so the pattern is safe to use case-insensitively, as
#' [atlas_simplify()] and [atlas_smooth()] do.
#'
#' @return A regular expression, as a length-one character vector.
#' @seealso [atlas_polish()], [atlas_simplify()] and [atlas_smooth()], which
#'   take it as `labels` or `exclude`.
#' @export
#'
#' @examples
#' context_pattern()
#'
#' # What it does and does not match: the backdrop, not a cortex structure.
#' labels <- c("lh_cortex", "cerebellum", "lh_unknown", "Left-Cerebral-Cortex")
#' grepl(context_pattern(), labels, ignore.case = TRUE)
#'
#' # The usual shape of a build: backdrop and structures, each its own way.
#' \dontrun{
#' atlas <- my_atlas |>
#'   atlas_polish(
#'     keep = 0.4,
#'     smoothness = 0.4,
#'     method = "chaikin",
#'     labels = context_pattern()
#'   ) |>
#'   atlas_polish(keep = 0.1, smoothness = 0.4, exclude = context_pattern())
#' }
context_pattern <- function() {
  paste(
    # Generated by a pipeline for the surface nothing covered.
    "^([lr]h_)?cortex",
    "^cerebellum$",
    # Carried by the parcellation and demoted during the build.
    "(^|_)unknown$",
    "(^|_)[?]{3}$",
    "medial[ _.-]?wall$",
    sep = "|"
  )
}


# Atlas name derivation ----

#' @noRd
#' @importFrom tools file_ext file_path_sans_ext
derive_atlas_name <- function(filepath) {
  if (length(filepath) != 1L || is.na(filepath)) {
    cli::cli_abort("A single input file is required to derive an atlas name")
  }
  name <- sub("\\.gz$", "", basename(filepath))
  ext <- tools::file_ext(name)
  name <- tools::file_path_sans_ext(name)
  if (ext %in% c("gii", "nii")) {
    name <- tools::file_path_sans_ext(name)
  }
  name <- gsub("^[lr]h\\.|\\.[LR]\\.", "", name)
  gsub(".", "_", name, fixed = TRUE)
}


#' Drop labels the geometry stage produced no geometry for
#'
#' `core` names an atlas's regions; the geometry holds their shapes. A label in
#' one and not the other is an atlas that claims a region it cannot draw.
#' Nothing complains at build time -- `print()` still counts the region -- so
#' the user meets it much later, as `geom_brain()` warning that some data was
#' not merged properly.
#'
#' A region can lose its geometry for honest reasons: too few vertices to close
#' a polygon, a contour below threshold, a structure lying off the surface being
#' drawn. So the row is dropped and named rather than the build refused. What is
#' not acceptable is keeping it.
#'
#' Every pipeline needs this, because every pipeline builds `core` and its
#' geometry in separate passes over the same labels. This lived in the
#' subcortical pipeline alone, which is why the cerebellar and cortical ones
#' could ship a region with no shape.
#'
#' @param components Components list from [build_atlas_components()].
#' @param sf_data The geometry, carrying a `label` column. Anything that is not
#'   a data.frame counts as no geometry at all.
#' @return `components`, with every label-keyed field pruned in step.
#' @noRd
drop_labels_without_geometry <- function(components, sf_data) {
  drawn <- if (is.data.frame(sf_data)) {
    unique(sf_data$label[!is.na(sf_data$label)])
  } else {
    character(0)
  }
  named <- components$core$label[!is.na(components$core$label)]
  missing <- setdiff(named, drawn)

  if (length(missing) > 0) {
    cli::cli_warn(
      c(
        "Dropping {length(missing)} label{?s} with no geometry.",
        "x" = "Dropped: {.val {missing}}",
        "i" = "A label kept in {.field core} without a shape counts towards
        the region total and cannot be drawn."
      ),
      wrap = TRUE
    )
    components <- prune_component_labels(components, missing)
  }

  if (nrow(components$core) == 0) {
    cli::cli_abort("No labels with geometry remain. Cannot build atlas.")
  }
  components
}


#' Remove labels from every label-keyed field of a components list
#'
#' The fields are pruned together or the atlas is inconsistent in a new way:
#' a palette entry for a region that is gone, or a mesh with no `core` row.
#' @noRd
prune_component_labels <- function(components, drop) {
  components$core <- components$core[
    !components$core$label %in% drop,
    ,
    drop = FALSE
  ]

  for (field in c("vertices_df", "meshes_df")) {
    rows <- components[[field]]
    if (!is.null(rows)) {
      components[[field]] <- rows[!rows$label %in% drop, , drop = FALSE]
    }
  }

  for (field in c("palette", "vol_idx")) {
    keyed <- components[[field]]
    if (!is.null(keyed)) {
      components[[field]] <- keyed[!names(keyed) %in% drop]
    }
  }

  components
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
  embedded <- embedded_hemi_token(label_name)
  if (!is.na(embedded)) {
    return(embedded)
  }
  if (grepl("left", label_name, ignore.case = TRUE)) {
    return("left")
  }
  if (grepl("right", label_name, ignore.case = TRUE)) {
    return("right")
  }
  NULL
}


#' Abort on a `hemi` value no pipeline recognises
#'
#' `NA` and an empty string are allowed: they declare nothing and leave the
#' hemisphere to be read from the label's name. A lookup table without a
#' `hemi` column passes untouched.
#'
#' @param lut A lookup table, or the path to a lookup table file.
#' @noRd
check_lut_hemi <- function(lut) {
  if (rlang::is_string(lut) && file.exists(lut)) {
    lut <- read_lut(lut)
  }
  if (!is.data.frame(lut) || !"hemi" %in% names(lut)) {
    return(invisible(lut))
  }
  declared <- trimws(as.character(lut$hemi))
  declares_something <- !is.na(declared) & nzchar(declared)
  recognised <- !is.na(vapply(declared, normalise_hemi, character(1)))
  unrecognised <- declares_something & !recognised
  if (any(unrecognised)) {
    cli::cli_abort(c(
      "{.arg input_lut} has {sum(unrecognised)} label{?s} with an
      unrecognised {.field hemi}",
      "x" = "Not a hemisphere: {.val {unique(declared[unrecognised])}}",
      "i" = "Allowed: {.val {c('left', 'right', 'midline', 'vermis')}}, or
      {.code NA} to read it from the label's name."
    ))
  }
  invisible(lut)
}


#' The hemisphere of a lookup table row
#'
#' A `hemi` column wins over the name: it is the more explicit of the two, and
#' an author who adds it is overriding what the name happens to say. A row
#' whose column declares nothing falls back to its name, so a partly filled
#' column behaves like a table without one for the rows it leaves empty.
#'
#' @param lut_row The label's lookup table row.
#' @param label_name The label's source name.
#' @param from_name Function reading a hemisphere out of a label name.
#' @return The declared hemisphere, or whatever `from_name` makes of the name.
#' @noRd
lut_hemi <- function(lut_row, label_name, from_name = detect_hemi) {
  if ("hemi" %in% names(lut_row)) {
    check_lut_hemi(lut_row)
    declared <- normalise_hemi(lut_row$hemi[1])
    if (!is.na(declared)) {
      return(declared)
    }
  }
  from_name(label_name)
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


# Directory setup ----

working_dir_marker <- ".ggseg.extra-workdir"

#' Check an atlas name can only name a directory inside `output_dir`
#'
#' The name becomes a path component of the working directory, and that
#' directory is removed recursively when the build finishes. An empty name
#' resolves to `output_dir` itself and `..` to its parent.
#' @noRd
check_atlas_name <- function(atlas_name) {
  usable <- rlang::is_string(atlas_name) &&
    !is.na(atlas_name) &&
    nzchar(trimws(atlas_name)) &&
    !grepl("[/\\\\]", atlas_name) &&
    !atlas_name %in% c(".", "..")
  if (usable) {
    return(invisible(atlas_name))
  }
  cli::cli_abort(c(
    "{.arg atlas_name} must be a single name, not {.val {atlas_name}}.",
    "i" = "It names the working directory inside {.arg output_dir}, so it
    cannot be empty, {.val .} or {.val ..}, or contain a path separator."
  ))
}


#' Mark a directory as a ggseg.extra working directory
#' @noRd
mark_working_dir <- function(dir) {
  mkdir(dir)
  file.create(as.character(fs::path(dir, working_dir_marker)))
  invisible(dir)
}


#' Could removing this directory delete files no build wrote?
#'
#' True for a directory that has content but neither the working-directory
#' marker nor a cache manifest, which working directories from before the
#' marker existed still carry. The one definition serves the check before the
#' build and the one before removal.
#' @noRd
holds_foreign_files <- function(dir) {
  if (!dir.exists(dir)) {
    return(FALSE)
  }
  contents <- list.files(dir, all.files = TRUE, no.. = TRUE)
  length(contents) > 0 &&
    !working_dir_marker %in% contents &&
    !cache_manifest_name %in% contents
}


#' @noRd
abort_foreign_working_dir <- function(dir) {
  cli::cli_abort(
    c(
      "The working directory already holds files this build did not write:
      {.path {dir}}",
      "x" = "{.code cleanup = TRUE} removes that directory when the build
      finishes, and would take those files with it.",
      "i" = "Use another {.arg output_dir} or {.arg atlas_name}, or pass
      {.code cleanup = FALSE} to build there and keep everything."
    )
  )
}


#' Remove a working directory, unless it holds files no build wrote
#' @return `TRUE` if the directory was removed.
#' @noRd
remove_working_dir <- function(dir) {
  if (holds_foreign_files(dir)) {
    cli::cli_warn(
      c(
        "Not removing {.path {dir}}: it holds files this build did not
        write.",
        "i" = "Remove the build's files yourself if you no longer need them."
      ),
      wrap = TRUE
    )
    return(FALSE)
  }
  unlink(dir, recursive = TRUE)
  TRUE
}


#' Setup standard atlas directory structure
#'
#' Also claims the cache manifests for this process. Every pipeline calls this
#' from the main thread before doing any work, which is what makes a later
#' stamp from inside a worker fail rather than silently drop manifest rows.
#'
#' The working directory is the one `cleanup` removes when the build is done,
#' so it is refused here, before any work, if removing it could take files
#' the build did not write. A directory this function creates is marked, which
#' is how a later run recognises it as safe to reuse and remove.
#' @param output_dir Base output directory
#' @param atlas_name Name of the atlas
#' @param type Type of atlas: "cortical", "subcortical", or "tract"
#' @param cleanup Whether the build will remove the working directory.
#' @return Named list of directory paths
#' @noRd
setup_atlas_dirs <- function(
  output_dir,
  type = "cortical",
  atlas_name = NULL,
  cleanup = FALSE
) {
  claim_cache_manifests()
  base <- if (is.null(atlas_name)) {
    output_dir
  } else {
    check_atlas_name(atlas_name)
    as.character(fs::path(output_dir, atlas_name))
  }
  if (cleanup && holds_foreign_files(base)) {
    abort_foreign_working_dir(base)
  }
  mark_working_dir(base)

  dirs <- list(
    base = base,
    snapshots = as.character(fs::path(base, "snapshots"))
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


# Context regions ----

#' Names a source parcellation uses for "not a structure"
#'
#' Matched against a *source* `region` or `source_label`, not against a
#' finished atlas's labels, and that is the whole difference from
#' [context_pattern()]. This one answers "did the parcellation mean this as a
#' real structure?", and the answer decides whether a region is demoted to
#' backdrop during the build. [context_pattern()] answers "is this geometry the
#' backdrop?" of an atlas that is already built, whatever produced it -- so it
#' matches these spellings too, plus the backdrops the pipelines generate.
#'
#' Keep them separate. Folding this into [context_pattern()] would mean a
#' generated `lh_cortex` could be read back as something the parcellation
#' declared, which it is not.
#' @noRd
context_region_pattern <- "^(unknown|\\?\\?\\?)$|medial[ _.-]?wall$"

#' Whether a source parcellation name denotes unlabelled cortex or the medial
#' wall rather than a structure
#' @noRd
is_context_region <- function(x) {
  grepl(context_region_pattern, x, ignore.case = TRUE)
}


# Atlas data construction ----

#' The display name a lookup table gives a label, or the region if it gives none
#'
#' `names` is the long-form name an atlas shows in a legend. The lookup table
#' may carry it in a `names` column; a table without the column, or a row left
#' `NA` or blank, falls back to the region derived from the label.
#' @param lut_row One row of a lookup table.
#' @param region The region derived for that label.
#' @return A single string.
#' @noRd
lut_names <- function(lut_row, region) {
  if (!"names" %in% names(lut_row) || nrow(lut_row) == 0) {
    return(region)
  }
  given <- trimws(as.character(lut_row$names[1]))
  if (is.na(given) || !nzchar(given)) {
    return(region)
  }
  given
}


#' Give a core table its `names` column
#'
#' Every atlas a pipeline builds carries `names`, the display name of each
#' region. Rows without one take their region, so the column is always
#' complete and always a character vector.
#' @param core Core data frame with at least `region`.
#' @return `core` with a `names` column after `label`.
#' @noRd
core_with_names <- function(core) {
  given <- if ("names" %in% names(core)) {
    as.character(core$names)
  } else {
    rep(NA_character_, nrow(core))
  }
  missing <- is.na(given) | !nzchar(trimws(given))
  given[missing] <- as.character(core$region)[missing]
  core$names <- given
  core
}


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

  core_columns <- intersect(
    c("hemi", "region", "label", "names"),
    names(atlas_data)
  )
  core <- core_with_names(distinct(atlas_data[core_columns]))

  raw_colours <- stats::setNames(atlas_data$colour, atlas_data$label)
  raw_colours <- raw_colours[!duplicated(names(raw_colours))]

  # Colours are never invented. An atlas built without a lookup table has no
  # palette, and says so by returning NULL, rather than carrying made-up
  # colours that read as though they came from the source. Plotting generates
  # its own colours for an atlas with no palette, and does it knowing which
  # labels are regions and which are anatomical backdrop -- which is more than
  # this function knows.
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
  skip_existing
) {
  resolve_common_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    steps = NULL,
    max_step = 2L
  )
}


#' @noRd
resolve_common_config <- function(
  output_dir,
  verbose,
  cleanup,
  skip_existing,
  steps,
  max_step
) {
  list(
    output_dir = get_output_dir(output_dir),
    verbose = get_verbose(verbose),
    cleanup = get_cleanup(cleanup),
    skip_existing = get_skip_existing(skip_existing),
    steps = validate_steps(steps, max_step),
    max_step = max_step
  )
}


#' Did the caller stop short of the pipeline's last step?
#'
#' A run that stops early is a run whose cache is the input to the next one.
#' @noRd
run_stopped_early <- function(config) {
  !is.null(config$max_step) && max(config$steps) < config$max_step
}


#' Remove the working directory, unless a later run still needs it
#'
#' `cleanup` and the documented two-phase workflow used to contradict each
#' other. `create_wholebrain_from_volume()` tells callers to run the first
#' steps and inspect the label split before continuing, and following that
#' with `cleanup = TRUE` wrote the cache and then deleted the directory
#' holding it, so the continuation run aborted with "Step 1 was not run but
#' required files are missing". Every subcortical atlas repository already
#' passes `cleanup = FALSE` to work around it.
#'
#' `cleanup` means the build is finished with its scratch space. A run that
#' stopped short of the last step is not finished, so it keeps it.
#'
#' A config with no `max_step` -- hand-built, as in tests -- says nothing
#' about the ceiling, and the previous behaviour stands.
#' @noRd
cleanup_working_dir <- function(config, dirs) {
  if (!config$cleanup) {
    return(invisible(NULL))
  }
  if (run_stopped_early(config)) {
    if (config$verbose) {
      # nolint next: object_usage_linter.
      remaining <- seq.int(max(config$steps) + 1L, config$max_step)
      cli::cli_alert_info(
        "Keeping the working directory so {cli::qty(length(remaining))}step{?s}
        {.val {remaining}} can reuse it. The run that finishes the atlas
        removes it.",
        wrap = TRUE
      )
    }
    return(invisible(NULL))
  }
  if (remove_working_dir(dirs$base) && config$verbose) {
    cli::cli_alert_success("Temporary files removed")
  }
  invisible(NULL)
}


#' Resolve and bounds-check the `steps` argument
#'
#' `steps` was only ever used to pick a default, so a value above the last
#' step ran nothing and reported success. Checking it here costs nothing and
#' turns a silent no-op into an error that names the steps there are.
#' @noRd
validate_steps <- function(steps, max_step) {
  if (is.null(steps)) {
    return(seq_len(max_step))
  }
  if (!all_whole_in_range(steps, 1L, max_step)) {
    cli::cli_abort(c(
      "{.arg steps} must be whole numbers between 1 and {max_step}.",
      "x" = "Got {.val {steps}}."
    ))
  }
  as.integer(steps)
}


#' Whether every element is a whole number within `[lo, hi]`
#'
#' Checked before any coercion: `as.integer()` makes a fractional step
#' whole, so validating afterwards accepts the typo it was meant to catch.
#' @noRd
all_whole_in_range <- function(x, lo, hi) {
  if (!is.numeric(x) || length(x) == 0L || anyNA(x)) {
    return(FALSE)
  }
  all(x == trunc(x) & x >= lo & x <= hi)
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
  cleanup_working_dir(config, dirs)

  steps <- config$steps

  if (config$verbose) {
    if (!is.null(atlas)) {
      # fmt: skip
      type <- if (max(steps) == early_step) { # nolint
        "3D"
      } else {
        type_label
      }
      cli::cli_alert_success(
        "{type} atlas created with {nrow(atlas$core)} {unit}"
      )
    } else {
      cli::cli_alert_success(
        "Completed {cli::qty(length(steps))}step{?s} {.val {steps}}"
      )
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


#' Validate a grouped-argument list and fill it out with its defaults
#' @noRd
resolve_opts <- function(opts, arg_name, defaults) {
  opts <- validate_pipeline_opts(opts, arg_name, names(defaults))
  utils::modifyList(defaults, opts)
}
