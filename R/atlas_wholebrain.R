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
#'    cortical; the rest as subcortical. It measures how much surface a
#'    label covers rather than where the label sits, so a small cortical
#'    parcel and a deep structure look the same to it. It warns whenever it
#'    runs; treat that warning as a request to declare the labels instead.
#'
#' [lut_classify_anatomy()] writes the `type` column for a lookup table that
#' has none, by reading each label's position in FreeSurfer's `aparc+aseg`.
#' Run it once while authoring the atlas and commit the column it returns:
#' a declared classification is reviewable in a diff, where an inferred one
#' is not.
#'
#' @section Volume pre-processing:
#' Before surface projection, the volume is filtered so that only voxel IDs
#' listed in the LUT are kept; all other non-zero voxels are zeroed out.
#' This prevents unlisted structures (e.g. white matter, ventricle masks)
#' from bleeding onto the cortical surface during label dilation.
#'
#' The subcortical pipeline also gets a brain-outline reference to draw as
#' grey context behind its structures, under FreeSurfer's cortex labels 3
#' (left) and 42 (right). By default that is the atlas's own cortical voxels,
#' split by hemisphere at the volume's midline: left-hemisphere voxels map to
#' label 3, right-hemisphere to label 42.
#'
#' A parcellation that covers both banks of every sulcus makes a solid mantle
#' that way, and no amount of polishing can put sulci into a silhouette that
#' never had any. When the cortical labels hold more than 1.5 times the voxels
#' of a cortical ribbon, the context is taken from FreeSurfer's `aseg`
#' instead, where sulcal CSF is unlabelled: its ribbon is resampled onto this
#' volume's own grid through the two headers
#' (`mri_vol2vol --regheader --nearest`) and written wherever no structure
#' claims the voxel. An atlas whose cortical labels are already a ribbon, such
#' as one derived from a surface, keeps its own.
#'
#' A ribbon is 2.5-3 mm thick, so a volume sampled more coarsely than that
#' cannot hold one: the resampled ribbon breaks into islands and the
#' silhouette with it. The substitution is declined when the resampled
#' ribbon is not at least a voxel thick through most of itself, and the
#' atlas's own cortical labels are used, as they were before.
#'
#' Either way, the `aseg` cerebellar cortex and brain stem are added to the
#' context, so the posterior fossa is not drawn as empty space behind an
#' atlas that reaches below the tentorium or one whose cerebellum lives in a
#' separate atlas. Cerebellar white matter is left out: without it the
#' cerebellum stays a foliated shell rather than a solid lump that merges
#' with the occipital lobe.
#'
#' When no usable `aseg` is available - no FreeSurfer, no `aseg.mgz` for the
#' subject, a failed resampling, or a ribbon that does not land inside this
#' volume, which is what a volume in some other space looks like - the
#' midline split is used and the pipeline warns.
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
#' This file ships with fsaverage5 and is always required. Cortex vertices
#' left without a listed label take the most common label of their
#' neighbours. Everything outside the cortex label becomes the `unknown`
#' medial wall, which the cortical atlas keeps as grey context geometry
#' rather than as a region.
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
#' @param regheader `r lifecycle::badge("deprecated")` Use
#'   `projection_opts = list(registration = )` instead. `TRUE` maps to
#'   `"header"`, `FALSE` to `"mni152"`. Supplying both is an error.
#' @param ... `r lifecycle::badge("deprecated")` The flat arguments that
#'   `labels`, `projection_opts` and `cerebellar_opts` replaced. Each is
#'   folded into the list that now holds it and raises a deprecation warning;
#'   supplying both the old argument and the list entry it maps to is an
#'   error rather than a precedence rule.
#' @param labels Named list routing labels to a sub-pipeline, overriding the
#'   lookup table's `type` column and the vertex-count heuristic. Entries:
#'   \itemize{
#'     \item `cortical`: label names to force as cortical.
#'     \item `subcortical`: label names to force as subcortical.
#'     \item `cerebellar`: label names to send through the cerebellar SUIT
#'       flatmap pipeline, using the bundled surfaces from
#'       [suit_flatmap_path()] and [suit_3d_path()].
#'   }
#'   Unnamed or unknown entries error. Replaces the `cortical_labels`,
#'   `subcortical_labels` and `cerebellar_labels` arguments.
#' @param projection_opts Named list of volume-to-surface projection
#'   settings, with these entries and defaults:
#'   \itemize{
#'     \item `subject` (`"fsaverage5"`) and `registration` (`"header"`): the
#'       target surface subject and how the volume is aligned to it. Read
#'       **Registration** below before relying on the default.
#'     \item `projfrac` (`0.5`) and `projfrac_range` (`c(0, 1, 0.1)`): how
#'       deep through the cortical ribbon to sample, passed on to
#'       `mri_vol2surf`. Set `projfrac_range` to `NULL` to sample the single
#'       depth `projfrac` instead.
#'     \item `min_vertices` (`50`): how much surface a label needs before
#'       the vertex-count heuristic calls it cortical. Only reached for
#'       labels that `labels` and a `type` column leave unclassified; see
#'       **Label classification**.
#'   }
#'   Unknown entries error. Replaces the flat `subject`, `registration`,
#'   `projfrac`, `projfrac_range` and `min_vertices` arguments.
#' @param cortical_opts Named list of extra arguments forwarded to the
#'   cortical sub-pipeline. Allowed entry: `views`. Unknown entries error.
#'   Leave empty to use defaults.
#' @param subcortical_opts Named list of extra arguments forwarded to
#'   [create_subcortical_from_volume()]. Any argument of that function may
#'   be set here except those managed by the wholebrain pipeline
#'   (`input_volume`, `input_lut`, `atlas_name`, `output_dir`, `verbose`,
#'   `cleanup`, `skip_existing`). Use this to tune `vertex_size_limits`,
#'   `decimate`, `slabs`. The deprecated `dilate`/`tolerance`/`smoothness`
#'   entries trigger a lifecycle warning and are no longer applied.
#' @param cerebellar_opts Named list of extra arguments forwarded to
#'   [create_cerebellar_from_volume()]. Any argument of that function may be
#'   set here except those managed by the wholebrain pipeline
#'   (`input_volume`, `input_lut`, `atlas_name`, `output_dir`, `verbose`,
#'   `cleanup`, `skip_existing`).
#'
#'   One entry is not forwarded: `cerebellar_space` is consumed here, and
#'   names the space `input_volume`'s cerebellar labels are in. The flatmap
#'   they are drawn on is in SUIT space, so anything else is transformed with
#'   the matching [suit_deformation_field()] first. Nothing in a NIfTI header
#'   records a volume's space, so `"suit"` is an assumption rather than a
#'   detection: set it if your volume is in an MNI space. See
#'   [suit_deformation_field()] for the spaces available.
#' @template cleanup
#' @template verbose
#' @template skip_existing
#' @param steps Which pipeline steps to run. Default NULL runs all steps.
#'   Steps are:
#'   \itemize{
#'     \item 1: Project volume onto surface
#'     \item 2: Split labels into cortical/subcortical/cerebellar
#'     \item 3: Run cortical pipeline
#'     \item 4: Run subcortical pipeline
#'     \item 5: Run cerebellar pipeline
#'   }
#'   Use `steps = 1:2` to run projection and split only.
#'
#' @section Registration:
#' `fsaverage` lives in MNI305, so an MNI152 volume projected with
#' `"header"` samples roughly 2 mm off, uniformly, anteriorly and
#' inferiorly. Every atlas in the ggsegverse was built that way. For
#' reference maps meant for visualisation that error is usually acceptable,
#' which is why it remains the default.
#'
#' `"mni152"` removes it, but only for volumes on the grid
#' `mni152.register.dat` was built for: 1 mm, left-handed (LAS). tkregister
#' coordinates are derived from the volume's own voxel order, size and field
#' of view, so the same matrix applied to a right-handed volume mirrors left
#' and right, and applied to an LAS volume of another resolution mislocates
#' regions (7.7% of vertices at 1.5 mm, about 28% at 4 mm, measured against
#' the same volume resampled to 1 mm first). Both mistakes produce an atlas
#' that still looks anatomically plausible, so an unsuitable grid is refused
#' rather than warned about. To use `"mni152"` with such a volume, resample
#' it onto the 1 mm LAS MNI152 grid first.
#'
#' No header identifies the space an arbitrary volume is in, so the
#' registration you name is applied to whatever you pass. A volume sitting
#' on the target subject's exact voxel grid warns, that being a claim a
#' header does support, but a volume in some other non-MNI152 space cannot
#' be detected.
#'
#' `mni152.register.dat` targets the FSL/SPM MNI152 (NLin6) 1 mm template.
#' Volumes in other MNI152 variants, such as the NLin2009cAsym template
#' `ggsegJulich` uses, keep a sub-millimetre residual rather than the
#' roughly 2 mm the transform corrects. It is registered against
#' `fsaverage`, so `subject` must share fsaverage's conformed geometry,
#' which the `fsaverageN` subjects do; for any other subject, supply your
#' own register.dat or LTA file.
#'
#' FreeSurfer's own `INFO` and `WARNING` lines about the registration are
#' only visible with `verbose = TRUE`.
#'
#' @return A named list with elements `cortical`, `subcortical`, and
#'   `cerebellar`, each a `ggseg_atlas` object (or NULL if no regions of
#'   that type exist).
#' @export
#' @importFrom dplyr tibble bind_rows filter
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
#'   atlas_name = "my_atlas",
#'   subcortical_opts = list(vertex_size_limits = c(3e6, 3e7))
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
#'
#' # --- Overriding classification and projection ---
#' # `labels` forces a label down a particular pipeline; `projection_opts`
#' # holds everything about getting the volume onto the surface.
#' result <- create_wholebrain_from_volume(
#'   input_volume = "atlas.nii.gz",
#'   input_lut = "atlas_LUT.txt",
#'   labels = list(
#'     cerebellar = c("Left-Cerebellum-Cortex", "Right-Cerebellum-Cortex")
#'   ),
#'   projection_opts = list(registration = "mni152", subject = "fsaverage6"),
#'   cerebellar_opts = list(cerebellar_space = "MNI152NLin6AsymC")
#' )
#' }
create_wholebrain_from_volume <- function(
  input_volume,
  verbose = get_verbose(), # nolint: object_usage_linter
  regheader = lifecycle::deprecated(),
  ...,
  input_lut = NULL,
  atlas_name = NULL,
  output_dir = NULL,
  labels = list(),
  projection_opts = list(),
  cortical_opts = list(),
  subcortical_opts = list(),
  cerebellar_opts = list(),
  steps = NULL,
  cleanup = NULL,
  skip_existing = NULL
) {
  grouped <- wholebrain_group_dots(
    labels = labels,
    projection_opts = projection_opts,
    cerebellar_opts = cerebellar_opts,
    dots = list(...)
  )
  labels <- resolve_labels(grouped$labels)
  projection <- resolve_projection_opts(grouped$projection_opts)
  cerebellar <- take_cerebellar_space(grouped$cerebellar_opts)

  if (lifecycle::is_present(regheader)) {
    # match.call() rather than missing(): goodpractice's tidyverse_no_missing
    # check rejects missing(), and registration has a real default to fall
    # back on, so lifecycle::is_present() cannot answer this for it.
    projection$registration <- registration_from_regheader(
      regheader,
      !"registration" %in% names(grouped$projection_opts)
    )
  }

  start_time <- Sys.time()
  do.call(
    check_post_creation_dots,
    c(list("create_wholebrain_from_volume"), grouped$dots)
  )
  opts <- validate_wholebrain_opts(
    cortical_opts,
    subcortical_opts,
    cerebellar$opts
  )
  setup <- wholebrain_setup(
    input_volume = input_volume,
    input_lut = input_lut,
    atlas_name = atlas_name,
    output_dir = output_dir,
    projfrac = projection$projfrac,
    projfrac_range = projection$projfrac_range,
    subject = projection$subject,
    registration = projection$registration,
    min_vertices = projection$min_vertices,
    verbose = verbose,
    cleanup = cleanup,
    skip_existing = skip_existing,
    steps = steps,
    cerebellar_space = cerebellar$space
  )
  wholebrain_run_pipeline(setup, opts, labels, start_time)
}


#' Map the deprecated regheader argument onto a registration specification
#' @noRd
registration_from_regheader <- function(regheader, registration_missing) {
  if (!registration_missing) {
    cli::cli_abort(c(
      "Cannot use both {.arg registration} and {.arg regheader}.",
      "i" = "{.arg regheader} is deprecated; keep {.arg registration} alone."
    ))
  }

  if (!is.logical(regheader) || length(regheader) != 1L || is.na(regheader)) {
    cli::cli_abort("{.arg regheader} must be {.code TRUE} or {.code FALSE}.")
  }

  lifecycle::deprecate_warn(
    "1.9.9.9025",
    "create_wholebrain_from_volume(regheader = )",
    "create_wholebrain_from_volume(registration = )"
  )

  if (regheader) "header" else "mni152"
}


# Argument grouping ----

# nolint start: object_name_linter.
#' Defaults for the grouped `projection_opts` argument
#' @noRd
WHOLEBRAIN_PROJECTION_DEFAULTS <- list(
  projfrac = 0.5,
  projfrac_range = c(0, 1, 0.1),
  subject = "fsaverage5",
  registration = "header",
  min_vertices = 50L
)

#' Flat arguments retired into `labels`, and the entry each becomes
#' @noRd
WHOLEBRAIN_RETIRED_LABELS <- c(
  cortical_labels = "cortical",
  subcortical_labels = "subcortical",
  cerebellar_labels = "cerebellar"
)

#' Every retired flat argument, and the `<list argument>.<entry>` it becomes
#' @noRd
WHOLEBRAIN_RETIRED_ARGS <- c(
  stats::setNames(
    paste0("labels.", WHOLEBRAIN_RETIRED_LABELS),
    names(WHOLEBRAIN_RETIRED_LABELS)
  ),
  stats::setNames(
    paste0("projection_opts.", names(WHOLEBRAIN_PROJECTION_DEFAULTS)),
    names(WHOLEBRAIN_PROJECTION_DEFAULTS)
  ),
  c(cerebellar_space = "cerebellar_opts.cerebellar_space")
)
# nolint end

#' Move the retired flat arguments into `labels`, `projection_opts` and
#' `cerebellar_opts`, leaving the post-creation dots alone
#'
#' Every call site found in the ggsegverse atlas repositories names its
#' arguments, so nothing here has to cope with positional matching.
#' @noRd
wholebrain_group_dots <- function(
  labels,
  projection_opts,
  cerebellar_opts,
  dots
) {
  grouped <- group_retired_dots(
    opts = list(
      labels = labels,
      projection_opts = projection_opts,
      cerebellar_opts = cerebellar_opts
    ),
    mapping = WHOLEBRAIN_RETIRED_ARGS,
    dots = dots,
    fn = "create_wholebrain_from_volume",
    when = "1.9.9.9052"
  )
  redirect_sub_pipeline_args(names(grouped$dots))
  c(grouped$opts, list(dots = grouped$dots))
}


#' Point a sub-pipeline option passed at the top level at the list it belongs in
#'
#' `decimate` and friends were never arguments of this function, so R used to
#' answer them with `unused argument`, which does not say where they should
#' have gone. They are real options of the builders the wholebrain pipeline
#' drives, so name the list that forwards them.
#' @noRd
redirect_sub_pipeline_args <- function(nms) {
  if (is.null(nms) || !length(nms)) {
    return(invisible(NULL))
  }
  managed <- c(
    "input_volume",
    "volume",
    "input_lut",
    "atlas_name",
    "output_dir",
    "verbose",
    "cleanup",
    "skip_existing"
  )
  owners <- list(
    subcortical_opts = setdiff(
      names(formals(create_subcortical_from_volume)),
      c(managed, "...")
    ),
    cerebellar_opts = setdiff(
      names(formals(create_cerebellar_from_volume)),
      c(managed, "...")
    )
  )
  for (nm in nms) {
    for (list_name in names(owners)) {
      if (nm %in% owners[[list_name]]) {
        cli::cli_abort(c(
          "{.arg {nm}} is not an argument of
           {.fn create_wholebrain_from_volume}.",
          "i" = "It is an option of the sub-pipeline: pass
                 {.code {list_name} = list({nm} = ...)}."
        ))
      }
    }
  }
  invisible(NULL)
}

#' Fill `projection_opts` out with its defaults after validating the names
#' @noRd
resolve_projection_opts <- function(projection_opts) {
  projection_opts <- validate_pipeline_opts(
    projection_opts,
    "projection_opts",
    names(WHOLEBRAIN_PROJECTION_DEFAULTS)
  )
  utils::modifyList(WHOLEBRAIN_PROJECTION_DEFAULTS, projection_opts)
}

#' Validate `labels` and fill the three entries out with NULL
#' @noRd
resolve_labels <- function(labels) {
  labels <- validate_pipeline_opts(
    labels,
    "labels",
    unname(WHOLEBRAIN_RETIRED_LABELS)
  )
  utils::modifyList(
    list(cortical = NULL, subcortical = NULL, cerebellar = NULL),
    labels
  )
}

#' Split `cerebellar_space` back out of `cerebellar_opts`
#'
#' It is not a formal of `create_cerebellar_from_volume()`, so it cannot be
#' forwarded with the rest of the list; it tells the wholebrain pipeline
#' whether to transform the volume before the cerebellar builder ever runs.
#' @noRd
take_cerebellar_space <- function(cerebellar_opts) {
  space <- cerebellar_opts$cerebellar_space
  cerebellar_opts$cerebellar_space <- NULL
  if (is.null(space)) {
    space <- c("suit", "MNI152NLin6AsymC", "MNI152NLin2009cSymC")
  }
  list(space = space, opts = cerebellar_opts)
}


#' Validate the wholebrain config, create the output dirs and log the header
#' @noRd
wholebrain_setup <- function(
  input_volume,
  input_lut,
  atlas_name,
  output_dir,
  projfrac,
  projfrac_range,
  subject,
  registration,
  min_vertices,
  verbose,
  cleanup,
  skip_existing,
  steps,
  cerebellar_space
) {
  config <- validate_wholebrain_config(
    input_volume = input_volume,
    input_lut = input_lut,
    atlas_name = atlas_name,
    output_dir = output_dir,
    projfrac = projfrac,
    projfrac_range = projfrac_range,
    subject = subject,
    registration = registration,
    min_vertices = min_vertices,
    verbose = verbose,
    cleanup = cleanup,
    skip_existing = skip_existing,
    steps = steps,
    cerebellar_space = cerebellar_space
  )

  dirs <- setup_atlas_dirs(
    config$output_dir,
    atlas_name = config$atlas_name,
    type = "cortical"
  )

  if (config$verbose) {
    wholebrain_log_header(config)
  }

  list(config = config, dirs = dirs)
}


#' Run the wholebrain pipeline steps and return the atlases (or the split)
#' @noRd
wholebrain_run_pipeline <- function(setup, opts, labels, start_time) {
  config <- setup$config
  dirs <- setup$dirs

  projection <- wholebrain_resolve_projection(config, dirs)

  split <- wholebrain_resolve_split(
    config,
    dirs,
    projection,
    cortical_labels = labels$cortical,
    subcortical_labels = labels$subcortical,
    cerebellar_labels = labels$cerebellar
  )

  if (max(config$steps) <= 2L) {
    if (config$verbose) {
      wholebrain_log_split_inspect(start_time)
    }
    return(invisible(split))
  }

  result <- wholebrain_build_atlases(
    config,
    dirs,
    projection,
    split,
    cortical_opts = opts$cortical,
    subcortical_opts = opts$subcortical,
    cerebellar_opts = opts$cerebellar
  )

  wholebrain_finalize(config, dirs, result, start_time)

  result
}


#' Remove temporary files and log the final wholebrain summary
#' @noRd
wholebrain_finalize <- function(config, dirs, result, start_time) {
  if (config$cleanup) {
    unlink(dirs$base, recursive = TRUE)
    if (config$verbose) cli::cli_alert_success("Temporary files removed")
  }

  if (config$verbose) {
    wholebrain_log_summary(
      result$cortical,
      result$subcortical,
      result$cerebellar,
      start_time
    )
  }

  invisible(NULL)
}


#' Run pipeline steps 3-5 and assemble the result list
#' @noRd
wholebrain_build_atlases <- function(
  config,
  dirs,
  projection,
  split,
  cortical_opts,
  subcortical_opts,
  cerebellar_opts
) {
  cortical_atlas <- NULL
  subcortical_atlas <- NULL

  if (3L %in% config$steps && length(split$cortical_labels) > 0) {
    refined <- wholebrain_refine_cortical_projection(
      config,
      dirs,
      projection,
      split
    )
    cortical_atlas <- wholebrain_run_cortical(
      config,
      dirs,
      refined,
      split,
      cortical_opts
    )
  }

  if (4L %in% config$steps && length(split$subcortical_labels) > 0) {
    subcortical_atlas <- wholebrain_run_subcortical(
      config,
      dirs,
      split,
      colortable = projection$colortable,
      opts = subcortical_opts
    )
  }

  cerebellar_atlas <- NULL
  if (5L %in% config$steps && length(split$cerebellar_labels) > 0) {
    cerebellar_atlas <- wholebrain_run_cerebellar(
      config,
      dirs,
      split,
      colortable = projection$colortable,
      opts = cerebellar_opts
    )
  }

  list(
    cortical = cortical_atlas,
    subcortical = subcortical_atlas,
    cerebellar = cerebellar_atlas
  )
}


#' Print the inspect-the-split guidance for a steps = 1:2 run
#' @noRd
wholebrain_log_split_inspect <- function(start_time) {
  cli::cli_alert_info(
    "Inspect {.code split$cortical_labels}, {.code split$subcortical_labels},
    and {.code split$cerebellar_labels}. Override with
    {.arg cortical_labels}/{.arg subcortical_labels}/
    {.arg cerebellar_labels} if needed, then re-run with all steps.",
    wrap = TRUE
  )
  log_elapsed(start_time)
  invisible(NULL)
}


#' Validate all three sub-pipeline opts lists for the wholebrain pipeline
#' @noRd
validate_wholebrain_opts <- function(
  cortical_opts,
  subcortical_opts,
  cerebellar_opts
) {
  # The creators take the retired post-creation tweaks through `...` now, so
  # the formals no longer name them. Keep accepting them here, and let the
  # creator issue the deprecation notice.
  allowed <- function(fn, managed) {
    c(
      setdiff(names(formals(fn)), c(managed, "...")),
      DEPRECATED_POST_CREATION_ARGS
    )
  }

  list(
    cortical = validate_pipeline_opts(
      cortical_opts,
      "cortical_opts",
      allowed(create_cortical_from_annotation, CORTICAL_MANAGED_ARGS)
    ),
    subcortical = validate_pipeline_opts(
      subcortical_opts,
      "subcortical_opts",
      allowed(create_subcortical_from_volume, SUBCORT_MANAGED_ARGS)
    ),
    cerebellar = validate_pipeline_opts(
      cerebellar_opts,
      "cerebellar_opts",
      allowed(create_cerebellar_from_volume, CEREBELLAR_MANAGED_ARGS)
    )
  )
}


#' Print the wholebrain pipeline header and input summary
#' @noRd
wholebrain_log_header <- function(config) {
  cli::cli_h1("Creating whole-brain atlas {.val {config$atlas_name}}")
  cli::cli_alert_warning(
    "This pipeline combines volume-to-surface projection with automatic
    cortical/subcortical classification. Both steps are heuristic and
    require manual validation. Run with {.code steps = 1:2} first to
    inspect the label split before committing to the full pipeline.",
    wrap = TRUE
  )
  cli::cli_alert_info("Volume: {.path {config$input_volume}}")
  if (!is.null(config$input_lut) && is.character(config$input_lut)) {
    cli::cli_alert_info("Color LUT: {.path {config$input_lut}}")
  }
  cli::cli_alert_info(
    "Setting output directory to {.path {config$output_dir}}"
  )
  invisible(NULL)
}


#' Print the final region-count summary for the wholebrain pipeline
#' @noRd
wholebrain_log_summary <- function(
  cortical_atlas,
  subcortical_atlas,
  cerebellar_atlas,
  start_time
) {
  # nolint start: object_usage_linter.
  n_cort <- if (!is.null(cortical_atlas)) {
    nrow(cortical_atlas$core)
  } else {
    0L
  }
  n_sub <- if (!is.null(subcortical_atlas)) {
    nrow(subcortical_atlas$core)
  } else {
    0L
  }
  n_cer <- if (!is.null(cerebellar_atlas)) {
    nrow(cerebellar_atlas$core)
  } else {
    0L
  }
  # nolint end
  cli::cli_alert_success(
    "Whole-brain atlas created: {n_cort} cortical, {n_sub} subcortical,
    {n_cer} cerebellar",
    wrap = TRUE
  )
  log_elapsed(start_time)
  invisible(NULL)
}


# Validation ----

# Arg names managed by the wholebrain pipeline for each sub-pipeline.
# Users cannot set these via *_opts; the wholebrain call owns them.
# nolint start: object_name_linter.
DEPRECATED_POST_CREATION_ARGS <- c(
  "dilate",
  "smoothness",
  "tolerance",
  "smooth_refinements"
)


# Index values the subcortical pipeline writes into its own volume to build
# the grey brain outline: 3/42 are the FreeSurfer cortex labels the cortical
# hemispheres are remapped to, and 7/8/46/47/16 are the cerebellum and
# brainstem labels the outline is extended with. A subcortical structure
# carrying one of these indices would be fused with a whole hemisphere of
# cortex, which lands the silhouette in `core` instead of leaving it as
# context.
SUBCORT_RESERVED_IDX <- c(3L, 7L, 8L, 16L, 42L, 46L, 47L)


SUBCORT_MANAGED_ARGS <- c(
  "input_volume",
  "input_lut",
  "atlas_name",
  "output_dir",
  "verbose",
  "cleanup",
  "skip_existing"
)
CEREBELLAR_MANAGED_ARGS <- c(
  "input_volume",
  "volume", # deprecated alias for input_volume; also managed, not user-settable
  "input_lut",
  "atlas_name",
  "output_dir",
  "verbose",
  "cleanup",
  "skip_existing"
)
# create_cortical_from_annotation() stands in for the cortical family here
# (unlike subcortical/cerebellar, wholebrain doesn't call a single public
# cortical builder directly) purely so the allowed cortical_opts names track
# that family's shared tail parameters instead of drifting from a hand-kept
# list.
CORTICAL_MANAGED_ARGS <- c(
  "input_annot",
  "atlas_name",
  "output_dir",
  "hemisphere",
  "cleanup",
  "verbose",
  "skip_existing"
)
# nolint end

#' Validate a named-list of extra arguments for a sub-pipeline
#'
#' @param opts User-supplied list.
#' @param pipeline One of "cortical", "subcortical", "cerebellar"; used in
#'   error messages.
#' @param allowed Character vector of permitted entry names.
#' @return Validated list (empty list if `opts` was NULL or empty).
#' @noRd
validate_pipeline_opts <- function(opts, arg_name, allowed) {
  if (is.null(opts)) {
    return(list())
  }
  if (!is.list(opts)) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a named list, not {.cls {class(opts)}}"
    )
  }
  if (length(opts) == 0L) {
    return(list())
  }
  if (is.null(names(opts)) || !all(nzchar(names(opts)))) {
    cli::cli_abort("All entries in {.arg {arg_name}} must be named")
  }
  dupes <- names(opts)[duplicated(names(opts))]
  if (length(dupes)) {
    cli::cli_abort(
      "Duplicate {.arg {arg_name}} name{?s}: {.val {dupes}}"
    )
  }
  invalid <- setdiff(names(opts), allowed)
  if (length(invalid)) {
    cli::cli_abort(c(
      "Unknown {.arg {arg_name}} entr{?y/ies}: {.val {invalid}}",
      "i" = "Allowed: {.val {allowed}}"
    ))
  }
  opts
}


#' @noRd
validate_wholebrain_config <- function(
  input_volume,
  input_lut,
  atlas_name,
  output_dir,
  projfrac,
  projfrac_range,
  subject,
  registration,
  min_vertices,
  verbose,
  cleanup,
  skip_existing,
  steps,
  cerebellar_space = "suit"
) {
  config <- resolve_common_config(
    output_dir,
    verbose,
    cleanup,
    skip_existing,
    tolerance = NULL,
    smoothness = NULL,
    steps,
    max_step = 5L
  )

  check_fs(abort = TRUE)

  if (!file.exists(input_volume)) {
    cli::cli_abort("Volume file not found: {.path {input_volume}}")
  }
  if (
    !is.null(input_lut) && is.character(input_lut) && !file.exists(input_lut)
  ) {
    cli::cli_abort("Color lookup table not found: {.path {input_lut}}")
  }

  validate_registration(registration, subject, input_volume)

  config$output_dir <- normalizePath(config$output_dir, mustWork = FALSE)

  if (is.null(atlas_name)) {
    atlas_name <- basename(input_volume)
    atlas_name <- sub(
      "\\.(nii\\.gz|nii|mgz)$",
      "",
      atlas_name,
      ignore.case = TRUE
    )
  }

  config$input_volume <- input_volume
  config$input_lut <- input_lut
  config$atlas_name <- atlas_name
  config$projfrac <- projfrac
  config$projfrac_range <- projfrac_range
  config$subject <- subject
  config$registration <- registration
  config$min_vertices <- as.integer(min_vertices)
  config$cerebellar_space <- match.arg(
    cerebellar_space,
    c("suit", "MNI152NLin6AsymC", "MNI152NLin2009cSymC")
  )
  config
}


# Step 1: Project volume onto surface ----

#' @noRd
wholebrain_resolve_projection <- function(config, dirs) {
  files <- c(
    as.character(fs::path(dirs$base, "atlas_data.rds")),
    as.character(fs::path(dirs$base, "colortable.rds"))
  )
  cached <- load_or_run_step(
    1L,
    config$steps,
    files,
    config$skip_existing,
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

  wholebrain_compute_projection(config, dirs)
}


#' Project the volume onto the surface and cache the result
#' @noRd
wholebrain_compute_projection <- function(config, dirs) {
  if (config$verbose) {
    cli::cli_h2("Surface projection")
    cli::cli_progress_step("Projecting volume onto surface")
  }

  colortable <- load_volume_colortable(
    config$input_lut,
    config$input_volume,
    config$verbose
  )$colortable

  atlas_data <- wholebrain_project_to_surface(
    input_volume = config$input_volume,
    colortable = colortable,
    subject = config$subject,
    projfrac = config$projfrac,
    projfrac_range = config$projfrac_range,
    registration = config$registration,
    output_dir = dirs$base,
    verbose = config$verbose
  )

  save_cache_rds(
    dirs$base,
    atlas_data.rds = atlas_data,
    colortable.rds = colortable
  )
  if (config$verbose) {
    cli::cli_progress_done()
  }

  list(atlas_data = atlas_data, colortable = colortable)
}


#' Convert a filled overlay vector to atlas_data rows for one hemisphere
#'
#' @param include_unknown If TRUE, unlabeled vertices (value 0) are included
#'   as an "unknown" region. This provides the brain outline context geometry
#'   needed for medial wall rendering.
#' @noRd
overlay_to_atlas_data <- function(
  overlay,
  hemi_short,
  colortable,
  include_unknown = FALSE
) {
  hemi <- hemi_to_long(hemi_short)
  unique_labels <- sort(unique(overlay[overlay != 0L]))

  rows <- lapply(
    unique_labels,
    overlay_label_row,
    overlay = overlay,
    hemi = hemi,
    hemi_short = hemi_short,
    colortable = colortable
  )

  result <- bind_rows(Filter(Negate(is.null), rows))

  if (include_unknown) {
    unknown_verts <- which(overlay == 0L) - 1L
    if (length(unknown_verts) > 0) {
      result <- bind_rows(
        result,
        tibble(
          hemi = hemi,
          region = "unknown",
          label = paste0(hemi_short, "_unknown"),
          colour = "#BEBEBE",
          vertices = list(unknown_verts),
          source_label = "unknown",
          source_idx = 0L
        )
      )
    }
  }

  result
}


#' Build the atlas_data row for a single label value of an overlay
#' @noRd
overlay_label_row <- function(
  label_val,
  overlay,
  hemi,
  hemi_short,
  colortable
) {
  ct_row <- colortable[colortable$idx == label_val, ]
  if (nrow(ct_row) == 0) {
    return(NULL)
  }

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
    region = label_to_region(label_name),
    label = paste(hemi_short, safe_name, sep = "_"),
    colour = colour,
    vertices = list(which(overlay == label_val) - 1L),
    source_label = label_name,
    source_idx = label_val
  )
}


#' @noRd
wholebrain_project_to_surface <- function(
  input_volume,
  colortable,
  subject,
  projfrac,
  projfrac_range,
  registration,
  output_dir,
  verbose
) {
  surf_dir <- as.character(fs::path(output_dir, "surface_overlays"))
  mkdir(surf_dir)

  registration_args <- resolve_vol2surf_registration(registration, subject)
  write_registration_record(
    output_dir,
    registration,
    subject,
    registration_args
  )

  projection_volume <- write_projection_volume(
    input_volume,
    colortable$idx,
    surf_dir
  )

  all_data <- list()

  for (hemi_short in c("lh", "rh")) {
    hemi <- hemi_to_long(hemi_short) # nolint: object_usage_linter
    overlay <- wholebrain_vol2surf_overlay(
      input_volume = projection_volume,
      hemi_short = hemi_short,
      subject = subject,
      projfrac = projfrac,
      projfrac_range = projfrac_range,
      registration_args = registration_args,
      surf_dir = surf_dir,
      verbose = verbose
    )
    overlay <- zero_unlisted_labels(overlay, colortable$idx)
    overlay <- mask_to_cortex(overlay, hemi_short, subject)

    n_before <- sum(overlay != 0L)
    overlay <- fill_surface_labels(overlay, hemi_short, subject)
    if (verbose) {
      wholebrain_log_hemi_coverage(hemi_short, n_before, overlay)
    }

    all_data[[hemi_short]] <- overlay_to_atlas_data(
      overlay,
      hemi_short,
      colortable,
      include_unknown = TRUE
    )
  }

  bind_rows(all_data)
}


#' Record which registration produced the surface overlays
#'
#' The projection is the step whose output cannot be judged by looking at
#' it: a volume registered the wrong way yields a displaced atlas that still
#' looks plausible. A plain-text sidecar beside the overlays keeps that
#' decision answerable later. It is deliberately not a cache entry, so it is
#' never stamped, reused as pipeline state, or read back by the pipeline.
#' @noRd
write_registration_record <- function(dir, registration, subject, args) {
  writeLines(
    c(
      paste("registration:", registration),
      paste("subject:", subject),
      if (!is.null(args$reg)) paste("reg:", args$reg),
      if (!is.null(args$srcsubject)) paste("srcsubject:", args$srcsubject),
      if (!is.null(args$regheader)) paste("regheader:", args$regheader),
      paste("ggseg.extra:", as.character(utils::packageVersion("ggseg.extra")))
    ),
    as.character(fs::path(dir, "registration.txt"))
  )
}


#' Set label ids that are missing from the lookup table to zero
#' @noRd
zero_unlisted_labels <- function(labels, keep_idx) {
  labels[!labels %in% keep_idx] <- 0L
  labels
}


#' Write the lookup-table-only copy of the volume, or return the input as is
#'
#' An MGZ without valid RAS information is written without it, so FreeSurfer
#' applies the same default geometry to the copy.
#' @noRd
write_projection_volume <- function(input_volume, keep_idx, output_dir) {
  if (grepl("\\.mgz$", input_volume, ignore.case = TRUE)) {
    rlang::check_installed(
      "freesurferformats",
      reason = "to rewrite FreeSurfer MGZ volumes"
    )
    mgh <- freesurferformats::read.fs.mgh(input_volume, with_header = TRUE)
    if (all(mgh$data %in% c(0L, keep_idx))) {
      return(input_volume)
    }
    vox2ras <- if (freesurferformats::mghheader.is.ras.valid(mgh$header)) {
      freesurferformats::mghheader.vox2ras(mgh$header)
    }
    output_file <- file.path(output_dir, "projection_volume.mgh")
    freesurferformats::write.fs.mgh(
      output_file,
      zero_unlisted_labels(mgh$data, keep_idx),
      vox2ras_matrix = vox2ras
    )
    return(output_file)
  }

  vol <- read_volume(input_volume, reorient = FALSE)
  label_array <- as.array(vol)
  if (all(label_array %in% c(0L, keep_idx))) {
    return(input_volume)
  }
  output_file <- file.path(output_dir, "projection_volume.nii")
  label_array <- zero_unlisted_labels(label_array, keep_idx)
  RNifti::writeNifti(RNifti::asNifti(label_array, reference = vol), output_file)
  output_file
}


#' Run mri_vol2surf for one hemisphere and read the resulting overlay
#' @noRd
wholebrain_vol2surf_overlay <- function(
  input_volume,
  hemi_short,
  subject,
  projfrac,
  projfrac_range,
  registration_args,
  surf_dir,
  verbose
) {
  output_mgz <- as.character(fs::path(
    surf_dir,
    paste0(hemi_short, "_overlay.nii.gz")
  ))

  mri_vol2surf(
    input_file = input_volume,
    output_file = output_mgz,
    hemisphere = hemi_short,
    projfrac = projfrac,
    projfrac_range = projfrac_range,
    reg = registration_args$reg,
    srcsubject = registration_args$srcsubject,
    regheader = registration_args$regheader,
    opts = paste("--interp nearest --trgsubject", shQuote(subject)),
    verbose = verbose
  )

  if (!file.exists(output_mgz)) {
    cli::cli_abort(c(
      "mri_vol2surf failed to produce output for {hemi_short}",
      "i" = "Expected: {.path {output_mgz}}",
      "i" = "Check that the volume is in the correct space (MNI152 or native)" # nolint
    ))
  }

  as.integer(c(RNifti::readNifti(output_mgz)))
}


#' Report labeled-vertex coverage for one hemisphere after label dilation
#' @noRd
wholebrain_log_hemi_coverage <- function(hemi_short, n_before, overlay) {
  # nolint start: object_usage_linter.
  n_after <- sum(overlay != 0L)
  n_total <- length(overlay)
  n_medial <- n_total - n_after
  pct <- sprintf(
    "%.0f%%",
    100 * n_after / n_total
  )
  # nolint end
  cli::cli_alert(
    "{hemi_short}: {n_before} -> {n_after} labeled vertices ({pct} cortex,
    {n_medial} medial wall)",
    wrap = TRUE
  )
  invisible(NULL)
}


# Step 2: Split labels ----

#' @noRd
wholebrain_resolve_split <- function(
  config,
  dirs,
  projection,
  cortical_labels = NULL,
  subcortical_labels = NULL,
  cerebellar_labels = NULL
) {
  files <- as.character(fs::path(dirs$base, "label_split.rds"))
  cached <- load_or_run_step(
    2L,
    config$steps,
    files,
    config$skip_existing,
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
    cli::cli_progress_step(
      "Classifying cortical/subcortical/cerebellar labels"
    )
  }

  split <- wholebrain_classify_labels(
    atlas_data = projection$atlas_data,
    colortable = projection$colortable,
    min_vertices = config$min_vertices,
    cortical_labels = cortical_labels,
    subcortical_labels = subcortical_labels,
    cerebellar_labels = cerebellar_labels,
    verbose = config$verbose
  )

  save_cache_rds(dirs$base, label_split.rds = split)
  if (config$verbose) {
    cli::cli_progress_done()
  }

  split
}


#' Classify volume labels as cortical, subcortical, or cerebellar
#'
#' Classification priority:
#' 1. `cortical_labels`/`subcortical_labels`/`cerebellar_labels` function
#'    arguments (highest)
#' 2. `type` column on the colortable (`"cortical"`, `"subcortical"`, or
#'    `"cerebellar"`)
#' 3. Vertex-count heuristic: labels with >= `min_vertices` on the surface
#'    projection are cortical, the rest subcortical (lowest). It warns
#'    whenever it runs, because it measures a label's surface area rather
#'    than its depth.
#'
#' @param atlas_data Tibble from `wholebrain_project_to_surface()` with
#'   `source_label` and `vertices` columns.
#' @param colortable Colortable data.frame. If it has a `type` column with
#'   values `"cortical"` / `"subcortical"` / `"cerebellar"`, that is used.
#' @param min_vertices Minimum vertex count on the surface projection for
#'   cortical classification, summed over every region sharing a label name.
#' @param cortical_labels Manual override: force these labels as cortical.
#' @param subcortical_labels Manual override: force these labels as subcortical.
#' @param cerebellar_labels Manual override: force these labels as cerebellar.
#' @param verbose Print classification summary.
#'
#' @return Named list with `cortical_labels`, `subcortical_labels`, and
#'   `cerebellar_labels` (character vectors of source label names).
#' @noRd
wholebrain_classify_labels <- function(
  atlas_data,
  min_vertices = 50L,
  verbose = FALSE,
  colortable = NULL,
  cortical_labels = NULL,
  subcortical_labels = NULL,
  cerebellar_labels = NULL
) {
  prep <- classify_labels_inputs(atlas_data, colortable)
  vertex_counts <- prep$vertex_counts

  assigned <- classify_labels_assign(
    prep,
    colortable,
    cortical_labels,
    subcortical_labels,
    cerebellar_labels
  )
  classified_cortical <- assigned$cortical
  classified_subcortical <- assigned$subcortical
  classified_cerebellar <- assigned$cerebellar

  if (length(assigned$remaining) > 0) {
    auto <- classify_labels_auto(assigned, prep, min_vertices)
    classified_cortical <- c(classified_cortical, auto$cortical)
    classified_subcortical <- c(classified_subcortical, auto$subcortical)
  }

  if (verbose) {
    classify_labels_log_summary(
      classified_cortical,
      classified_subcortical,
      classified_cerebellar,
      vertex_counts
    )
  }

  list(
    cortical_labels = classified_cortical,
    subcortical_labels = classified_subcortical,
    cerebellar_labels = classified_cerebellar,
    vertex_counts = vertex_counts
  )
}


#' Vertex counts and the full label universe used for classification
#' @noRd
classify_labels_inputs <- function(atlas_data, colortable) {
  parcels <- atlas_data[!is_context_region(atlas_data$source_label), ]
  vertex_counts <- tapply(
    vapply(parcels$vertices, length, integer(1)),
    parcels$source_label,
    sum
  )

  projected_labels <- names(vertex_counts)

  # Include all volume labels (from colortable) so cerebellar/subcortical
  # labels that didn't project onto the cortical surface are still classified.
  volume_labels <- if (!is.null(colortable)) colortable$label else character(0)
  all_labels <- union(projected_labels, volume_labels)

  list(
    vertex_counts = vertex_counts,
    projected_labels = projected_labels,
    all_labels = all_labels
  )
}


#' Assign labels from the manual overrides and the LUT `type` column
#'
#' @return List with the labels classified so far plus the still-unassigned
#'   `remaining` labels.
#' @noRd
classify_labels_assign <- function(
  prep,
  colortable,
  cortical_labels,
  subcortical_labels,
  cerebellar_labels
) {
  manual <- classify_labels_manual(
    prep$all_labels,
    cortical_labels,
    subcortical_labels,
    cerebellar_labels
  )
  classified_cortical <- manual$cortical
  classified_subcortical <- manual$subcortical
  classified_cerebellar <- manual$cerebellar

  remaining <- setdiff(
    prep$all_labels,
    c(classified_cortical, classified_subcortical, classified_cerebellar)
  )

  has_type <- !is.null(colortable) && "type" %in% names(colortable)
  if (has_type && length(remaining) > 0) {
    by_type <- classify_labels_by_type(colortable, remaining)
    classified_cortical <- c(classified_cortical, by_type$cortical)
    classified_subcortical <- c(classified_subcortical, by_type$subcortical)
    classified_cerebellar <- c(classified_cerebellar, by_type$cerebellar)
    remaining <- setdiff(
      remaining,
      c(classified_cortical, classified_subcortical, classified_cerebellar)
    )
  }

  list(
    cortical = classified_cortical,
    subcortical = classified_subcortical,
    cerebellar = classified_cerebellar,
    remaining = remaining
  )
}


#' Classify the still-unassigned labels with the vertex-count heuristic
#'
#' The last resort: it measures how much surface a label covers, not where
#' the label sits, so a small cortical parcel is indistinguishable from a
#' deep structure. Warns unconditionally, because silently guessing this is
#' how atlases have shipped with half their parcels in the wrong table.
#' @noRd
classify_labels_auto <- function(assigned, prep, min_vertices) {
  # Only apply vertex-count heuristic to labels that actually projected
  # onto the cortical surface. Labels only in the volume (not projected)
  # are left unclassified here — they stay subcortical by default.
  vertex_counts <- prep$vertex_counts
  projected_remaining <- intersect(assigned$remaining, prep$projected_labels)
  volume_only <- setdiff(assigned$remaining, prep$projected_labels)

  warn_vertex_count_fallback(length(projected_remaining))

  auto_cortical <- projected_remaining[
    vertex_counts[projected_remaining] >= min_vertices
  ]
  auto_subcortical <- c(
    projected_remaining[vertex_counts[projected_remaining] < min_vertices],
    volume_only
  )

  list(cortical = auto_cortical, subcortical = auto_subcortical)
}


#' Warn that labels were classified by size rather than by anatomy
#' @noRd
warn_vertex_count_fallback <- function(n) {
  if (n == 0L) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "Classified {n} label{?s} by surface vertex count, not by anatomy.",
      "!" = "The vertex count measures how much surface a label covers, so a
      small cortical parcel and a deep structure look the same to it.",
      "i" = "Declare the labels instead: {.fn lut_classify_anatomy} fills in
      a {.field type} column from FreeSurfer's {.field aparc+aseg}, or pass
      {.arg cortical_labels}/{.arg subcortical_labels}/
      {.arg cerebellar_labels}."
    ),
    wrap = TRUE
  )
  invisible(NULL)
}


#' Apply explicit cortical/subcortical/cerebellar label overrides
#'
#' Returns the labels matched by the manual override vectors. Warns about
#' subcortical labels that are not present in the data.
#' @noRd
classify_labels_manual <- function(
  all_labels,
  cortical_labels,
  subcortical_labels,
  cerebellar_labels
) {
  cortical <- character(0)
  subcortical <- character(0)
  cerebellar <- character(0)

  if (!is.null(cortical_labels)) {
    cortical <- intersect(cortical_labels, all_labels)
  }
  if (!is.null(cerebellar_labels)) {
    cerebellar <- intersect(cerebellar_labels, all_labels)
  }
  if (!is.null(subcortical_labels)) {
    unmatched <- setdiff(subcortical_labels, all_labels)
    if (length(unmatched) > 0) {
      cli::cli_warn(
        "Subcortical labels not found in data: {.val {unmatched}}"
      )
    }
    subcortical <- intersect(subcortical_labels, all_labels)
  }

  list(cortical = cortical, subcortical = subcortical, cerebellar = cerebellar)
}


#' Classify the still-unassigned labels using the LUT `type` column
#' @noRd
classify_labels_by_type <- function(colortable, remaining) {
  lut_cortical <- colortable$label[colortable$type == "cortical"]
  lut_subcortical <- colortable$label[colortable$type == "subcortical"]
  lut_cerebellar <- colortable$label[colortable$type == "cerebellar"]
  list(
    cortical = intersect(remaining, lut_cortical),
    subcortical = intersect(remaining, lut_subcortical),
    cerebellar = intersect(remaining, lut_cerebellar)
  )
}


#' Print the cortical/subcortical/cerebellar classification summary
#' @noRd
classify_labels_log_summary <- function(
  classified_cortical,
  classified_subcortical,
  classified_cerebellar,
  vertex_counts
) {
  cli::cli_alert_info(
    "{length(classified_cortical)} cortical,
    {length(classified_subcortical)} subcortical,
    {length(classified_cerebellar)} cerebellar labels",
    wrap = TRUE
  )
  if (length(classified_subcortical) > 0) {
    # nolint start: object_usage_linter.
    sub_info <- paste(
      classified_subcortical,
      paste0("(", vertex_counts[classified_subcortical], "v)"),
      collapse = ", "
    )
    # nolint end
    cli::cli_alert("Subcortical: {sub_info}")
  }
  if (length(classified_cerebellar) > 0) {
    # nolint start: object_usage_linter.
    cer_info <- paste(
      classified_cerebellar,
      paste0("(", vertex_counts[classified_cerebellar], "v)"),
      collapse = ", "
    )
    # nolint end
    cli::cli_alert("Cerebellar: {cer_info}")
  }
  invisible(NULL)
}


# Step 2.5: Refine cortical projection ----

#' Keep only cortical labels in the surface projection and re-fill
#'
#' When projecting a combined volume, subcortical voxels near the cortical
#' surface can "steal" vertices that should be cortical. This function reloads
#' the raw vol2surf overlays, zeros every label that is not in the cortical
#' lookup table (subcortical, cerebellar, and unlisted ids), and re-runs
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
  config,
  dirs,
  projection,
  split
) {
  colortable <- projection$colortable[
    projection$colortable$label %in% split$cortical_labels,
  ]
  if (nrow(colortable) == nrow(projection$colortable)) {
    return(projection)
  }

  surf_dir <- as.character(fs::path(dirs$base, "surface_overlays"))
  atlas_data <- refine_cortical_overlays(config, surf_dir, colortable)

  list(
    atlas_data = atlas_data,
    colortable = colortable
  )
}


#' Re-fill both hemisphere overlays keeping only the cortical labels
#' @noRd
refine_cortical_overlays <- function(config, surf_dir, colortable) {
  if (config$verbose) {
    cli::cli_progress_step(
      "Refining cortical projection (keeping {nrow(colortable)} cortical
      labels on the surface)"
    )
  }

  all_data <- lapply(c("lh", "rh"), function(hemi_short) {
    overlay_file <- as.character(fs::path(
      surf_dir,
      paste0(hemi_short, "_overlay.nii.gz")
    ))
    if (!file.exists(overlay_file)) {
      cli::cli_abort(
        "Overlay file missing: {.path {overlay_file}}. Re-run step 1."
      )
    }
    overlay <- zero_unlisted_labels(
      as.integer(c(RNifti::readNifti(overlay_file))),
      colortable$idx
    )
    overlay <- mask_to_cortex(overlay, hemi_short, config$subject)
    overlay <- fill_surface_labels(overlay, hemi_short, config$subject)
    overlay_to_atlas_data(
      overlay,
      hemi_short,
      colortable,
      include_unknown = TRUE
    )
  })

  if (config$verbose) {
    cli::cli_progress_done()
  }

  bind_rows(all_data)
}


# Step 3: Run cortical pipeline ----

#' @noRd
wholebrain_run_cortical <- function(
  config,
  dirs,
  projection,
  split,
  opts = list()
) {
  if (config$verbose) {
    cli::cli_h2(
      "Cortical pipeline ({length(split$cortical_labels)} regions)"
    )
  }

  prep <- wholebrain_cortical_inputs(config, dirs, projection, split, opts)

  step1 <- cortical_read_data(
    prep$config,
    prep$dirs,
    prep$name,
    read_fn = function() prep$data,
    step_label = "Reading projected cortical data",
    cache_label = "Cortical step 1"
  )

  hemisphere <- unique(prep$data$hemi)
  hemi_short <- vapply(
    hemisphere,
    hemi_to_short,
    character(1),
    USE.NAMES = FALSE
  )

  atlas <- cortical_project_and_build(
    components = step1$components,
    atlas_name = prep$name,
    hemisphere = hemi_short,
    views = prep$views,
    config = prep$config,
    dirs = prep$dirs,
    start_time = Sys.time()
  )

  atlas
}


#' Assemble the cortical sub-pipeline inputs (data, dirs, config, views)
#' @noRd
wholebrain_cortical_inputs <- function(config, dirs, projection, split, opts) {
  views <- opts$views
  if (is.null(views)) {
    views <- c("lateral", "medial", "superior", "inferior")
  }

  source_label <- projection$atlas_data$source_label
  cortical_data <- projection$atlas_data[
    source_label %in% split$cortical_labels | is_context_region(source_label),
  ]
  cortical_data <- cortical_data[,
    c("hemi", "region", "label", "colour", "vertices")
  ]

  cortical_name <- paste0(config$atlas_name, "_cortical")
  cortical_dirs <- setup_atlas_dirs(
    dirs$base,
    atlas_name = "cortical",
    type = "cortical"
  )

  cortical_config <- validate_surface_config(
    output_dir = dirs$base,
    verbose = config$verbose,
    cleanup = FALSE,
    skip_existing = config$skip_existing,
    tolerance = opts$tolerance,
    smooth_refinements = opts$smooth_refinements
  )

  list(
    data = cortical_data,
    name = cortical_name,
    dirs = cortical_dirs,
    config = cortical_config,
    views = views
  )
}


# Step 4: Run subcortical pipeline ----

#' @noRd
wholebrain_run_subcortical <- function(
  config,
  dirs,
  split,
  colortable,
  opts = list()
) {
  if (config$verbose) {
    cli::cli_h2(
      "Subcortical pipeline ({length(split$subcortical_labels)} regions)"
    )
  }

  subcort_ct <- colortable[
    colortable$label %in% split$subcortical_labels,
  ]

  subcort_lut <- as.character(fs::path(dirs$base, "subcort_lut.txt"))
  required_cols <- c("idx", "label", "R", "G", "B", "A")
  subcort_ct <- fill_missing_rgb(subcort_ct, "subcort")
  subcort_ct <- reindex_reserved_subcort_idx(subcort_ct, config$verbose)
  write_lut(subcort_ct[, required_cols], subcort_lut)

  cortical_idx <- colortable$idx[
    colortable$label %in% split$cortical_labels
  ]

  filtered_vol <- as.character(fs::path(dirs$base, "subcort_volume.nii.gz"))
  wholebrain_prepare_subcortical_volume(
    input_volume = config$input_volume,
    subcortical_idx = subcort_ct$source_idx,
    cortical_idx = cortical_idx,
    output_file = filtered_vol,
    target_idx = subcort_ct$idx,
    verbose = config$verbose
  )

  subcort_name <- paste0(config$atlas_name, "_subcortical")

  managed <- list(
    input_volume = filtered_vol,
    input_lut = subcort_lut,
    atlas_name = "subcortical",
    output_dir = dirs$base,
    verbose = config$verbose,
    cleanup = FALSE,
    skip_existing = config$skip_existing
  )
  atlas <- do.call(
    create_subcortical_from_volume,
    c(managed, opts)
  )

  atlas$atlas <- subcort_name
  atlas
}


# Step 5: Run cerebellar pipeline ----

#' @noRd
wholebrain_run_cerebellar <- function(
  config,
  dirs,
  split,
  colortable,
  opts = list()
) {
  if (config$verbose) {
    cli::cli_h2(
      "Cerebellar pipeline ({length(split$cerebellar_labels)} regions)"
    )
  }

  cer_ct <- colortable[
    colortable$label %in% split$cerebellar_labels,
  ]
  cer_ct <- fill_missing_rgb(cer_ct, "cerebellar")

  cer_lut <- data.frame(
    idx = cer_ct$idx,
    label = cer_ct$label,
    R = cer_ct$R,
    G = cer_ct$G,
    B = cer_ct$B,
    A = cer_ct$A,
    stringsAsFactors = FALSE
  )

  filtered_vol <- as.character(fs::path(dirs$base, "cerebellar_volume.nii.gz"))
  wholebrain_prepare_cerebellar_volume(
    input_volume = config$input_volume,
    cerebellar_idx = cer_ct$idx,
    output_file = filtered_vol
  )
  filtered_vol <- wholebrain_cerebellar_to_suit(filtered_vol, config, dirs)

  cer_name <- paste0(config$atlas_name, "_cerebellar")

  managed <- list(
    input_volume = filtered_vol,
    input_lut = cer_lut,
    atlas_name = cer_name,
    output_dir = dirs$base,
    verbose = config$verbose,
    cleanup = FALSE,
    skip_existing = config$skip_existing
  )
  args <- c(managed, opts)
  do.call(create_cerebellar_from_volume, args)
}


#' Put the cerebellar volume in the space its flatmap is drawn in
#'
#' Step 5 samples onto the bundled SUIT surfaces, so a volume in any other
#' space renders onto a flatmap it does not correspond to -- a picture that
#' looks like an atlas and is not one. Nothing in a NIfTI header says which
#' space it is, and the two MNI templates need different deformation fields,
#' so `cerebellar_space` is the only thing that knows.
#'
#' Nearest-neighbour is not a quality choice here: this is a label volume, and
#' interpolating between two label ids gives an id that means nothing.
#' @noRd
wholebrain_cerebellar_to_suit <- function(filtered_vol, config, dirs) {
  # Transform only on an explicit request. Anything else leaves the volume
  # alone, so a config that never set the field cannot silently resample.
  if (identical(config$cerebellar_space %||% "suit", "suit")) {
    if (config$verbose) {
      cli::cli_alert_info(
        "Treating the cerebellar volume as already in SUIT space
        ({.code cerebellar_space = \"suit\"}).",
        wrap = TRUE
      )
    }
    return(filtered_vol)
  }

  if (config$verbose) {
    cli::cli_alert_info(
      "Transforming the cerebellar volume from
      {.val {config$cerebellar_space}} into SUIT space."
    )
  }

  suit_vol <- as.character(
    fs::path(dirs$base, "cerebellar_volume_suit.nii.gz")
  )
  transform_mni_to_suit(
    input_volume = filtered_vol,
    deformation_field = suit_deformation_field(
      template = config$cerebellar_space
    ),
    output_file = suit_vol,
    interpolation = "nearest"
  )
  suit_vol
}


#' Fill NA or missing R/G/B/A columns with an auto-generated palette
#'
#' Keeps any real colours already present. Only rows where R, G, and B are
#' all NA (or entirely missing) are replaced with values from an evenly
#' spaced HCL palette so generic LUTs render as something other than black.
#' @noRd
fill_missing_rgb <- function(ct, label = "structures") {
  for (col in c("R", "G", "B", "A")) {
    if (!col %in% names(ct)) ct[[col]] <- NA_integer_
  }
  missing_rows <- is.na(ct$R) & is.na(ct$G) & is.na(ct$B)
  n_missing <- sum(missing_rows)
  if (n_missing > 0L) {
    cli::cli_alert_info(c(
      "Auto-generating colours for {n_missing} {label} ",
      "{cli::qty(n_missing)}region{?s}"
    ))
    hex <- generate_region_palette(n_missing)
    rgb_mat <- grDevices::col2rgb(hex)
    ct$R[missing_rows] <- as.integer(rgb_mat["red", ])
    ct$G[missing_rows] <- as.integer(rgb_mat["green", ])
    ct$B[missing_rows] <- as.integer(rgb_mat["blue", ])
  }
  ct$A[is.na(ct$A)] <- 0L
  ct
}


#' Prepare volume for cerebellar pipeline
#'
#' Keeps only cerebellar labels in the volume and zeros everything else.
#' @noRd
# nolint next: object_length_linter.
wholebrain_prepare_cerebellar_volume <- function(
  input_volume,
  cerebellar_idx,
  output_file
) {
  vol <- read_volume(input_volume, reorient = FALSE)
  arr <- as.array(vol)
  result <- array(0L, dim = dim(arr))
  for (idx in cerebellar_idx) {
    result[arr == idx] <- idx
  }
  out <- RNifti::asNifti(result, reference = vol)
  if (RNifti::orientation(out) != "RAS") {
    RNifti::orientation(out) <- "RAS"
  }
  RNifti::writeNifti(out, output_file)
  invisible(output_file)
}


#' Move subcortical indices off the values reserved for the brain outline
#'
#' The subcortical volume carries the cortical hemispheres alongside the
#' subcortical structures, under the indices in `SUBCORT_RESERVED_IDX`. An
#' atlas LUT that uses one of those values for a real structure would have
#' that structure fused with a whole hemisphere of cortex, so the silhouette
#' ends up as a legended `core` region instead of grey context. Reindexing is
#' invisible in the finished atlas: regions are identified by label, and the
#' LUT written for the pipeline carries the new indices.
#'
#' @param ct Subcortical colortable with `idx` and `label` columns
#' @param verbose Report the reindexed labels
#'
#' @return `ct` with a `source_idx` column holding the original indices and
#'   `idx` moved off the reserved values
#' @noRd
reindex_reserved_subcort_idx <- function(ct, verbose = TRUE) {
  ct$source_idx <- ct$idx
  clashing <- ct$idx %in% SUBCORT_RESERVED_IDX
  if (!any(clashing)) {
    return(ct)
  }

  taken <- union(ct$idx, SUBCORT_RESERVED_IDX)
  available <- setdiff(seq_len(max(taken) + sum(clashing)), taken)
  ct$idx[clashing] <- available[seq_len(sum(clashing))]

  if (verbose) {
    # nolint next: object_usage_linter.
    moved <- paste0(
      ct$label[clashing],
      " (",
      ct$source_idx[clashing],
      " -> ",
      ct$idx[clashing],
      ")"
    )
    cli::cli_alert_info(
      "Reindexed {sum(clashing)} subcortical label{?s} clashing with the
      brain outline: {moved}",
      wrap = TRUE
    )
  }

  ct
}


#' Prepare volume for subcortical pipeline with cortex reference
#'
#' Keeps subcortical labels (optionally reindexed through `target_idx`) and
#' adds the FreeSurfer cortex indices 3 (left) and 42 (right) as context, so
#' the subcortical pipeline can generate brain outline geometry via
#' `detect_cortex_labels()`. All other labels are zeroed.
#'
#' Which voxels become context decides whether that outline reads as a brain
#' or as a potato. A parcellation covers both banks of every sulcus, so the
#' union of its cortical labels is a solid mantle. The shape comes from
#' FreeSurfer's `aseg` instead, where sulcal CSF is unlabelled: it is
#' resampled onto this volume's own grid and its cortical ribbon is written
#' wherever no structure claims the voxel. Without a usable `aseg`, or on a
#' grid too coarse to carry a ribbon, the atlas's own cortical mask is used,
#' which is the old solid silhouette.
#' @noRd
# nolint next: object_length_linter.
wholebrain_prepare_subcortical_volume <- function(
  input_volume,
  subcortical_idx,
  cortical_idx,
  output_file,
  target_idx = subcortical_idx,
  cortex_subject = "cvs_avg35_inMNI152",
  verbose = get_verbose()
) {
  vol <- read_volume(input_volume, reorient = FALSE)
  arr <- as.array(vol)
  result <- array(0L, dim = dim(arr))
  for (i in seq_along(subcortical_idx)) {
    result[arr == subcortical_idx[i]] <- target_idx[i]
  }
  result <- wholebrain_write_cortex_context(
    result = result,
    arr = arr,
    vol = vol,
    cortical_idx = cortical_idx,
    input_volume = input_volume,
    cortex_subject = cortex_subject,
    verbose = verbose
  )
  out <- RNifti::asNifti(result, reference = vol)
  if (RNifti::orientation(out) != "RAS") {
    RNifti::orientation(out) <- "RAS"
  }
  RNifti::writeNifti(out, output_file)
  invisible(output_file)
}


#' Write the cortex context indices into the volume
#'
#' An atlas whose own cortical mask is already a ribbon keeps it, split at the
#' midline, which is what this always did. Only a solid mantle is replaced,
#' with the resampled `aseg` ribbon written into voxels no structure claims,
#' and only where the grid is fine enough to carry a ribbon. The same midline
#' split is the fallback when no ribbon can be had. An atlas with no cortical
#' labels at all gets no context either way: the whole-brain
#' split decided this parcellation has no cortex to draw.
#' @noRd
# nolint next: object_length_linter.
wholebrain_write_cortex_context <- function(
  result,
  arr,
  vol,
  cortical_idx,
  input_volume,
  cortex_subject,
  verbose
) {
  cortical_mask <- arr %in% cortical_idx
  if (!any(cortical_mask)) {
    return(result)
  }

  aseg <- aseg_context_volume(
    input_volume = input_volume,
    subject = cortex_subject,
    dims = dim(arr),
    brain_mask = arr != 0,
    verbose = verbose
  )
  if (is.null(aseg)) {
    return(wholebrain_cortex_by_midline(result, cortical_mask, vol))
  }

  result <- wholebrain_write_cerebrum(result, cortical_mask, vol, aseg, verbose)
  write_aseg_context(result, aseg, aseg_fossa_idx())
}


#' Cerebral cortex context: the `aseg` ribbon, or the atlas's own mask
#'
#' Two things have to hold before the ribbon is worth substituting: the
#' atlas's own mask has to be a solid mantle, and the grid has to be fine
#' enough to carry a ribbon at all.
#' @noRd
wholebrain_write_cerebrum <- function(
  result,
  cortical_mask,
  vol,
  aseg,
  verbose
) {
  solid <- cortex_mask_is_solid(cortical_mask, aseg, verbose)
  if (!solid || !ribbon_is_resolved(aseg, verbose)) {
    return(wholebrain_cortex_by_midline(result, cortical_mask, vol))
  }
  write_aseg_context(result, aseg, aseg_cortex_idx())
}


#' Copy `aseg` labels into the voxels no structure claims
#' @noRd
write_aseg_context <- function(result, aseg, idx) {
  free <- result == 0L
  for (i in idx) {
    result[free & aseg == i] <- i
  }
  result
}


#' Split a cortical mask into hemispheres at the volume midline
#'
#' The fallback when no `aseg` ribbon is available. Left-hemisphere voxels
#' map to label 3 (FS left cortex), right-hemisphere to label 42.
#' @noRd
wholebrain_cortex_by_midline <- function(result, cortical_mask, vol) {
  xform <- RNifti::xform(vol)
  # xform maps 0-based voxel indices to world; slice.index() is 1-based, so
  # shift the midline voxel to 1-based before comparing.
  x0_voxel <- round(solve(xform, c(0, 0, 0, 1))[1]) + 1L
  x_idx <- slice.index(result, 1)
  left_is_high <- xform[1, 1] < 0
  cortex <- aseg_cortex_idx()
  low <- if (left_is_high) cortex[["right"]] else cortex[["left"]]
  high <- if (left_is_high) cortex[["left"]] else cortex[["right"]]
  result[cortical_mask & x_idx <= x0_voxel] <- low
  result[cortical_mask & x_idx > x0_voxel] <- high
  result
}


# aseg cortical ribbon ----

#' FreeSurfer `aseg` indices for the left and right cortical ribbon
#' @noRd
aseg_cortex_idx <- function() {
  c(left = 3L, right = 42L)
}


#' `aseg` indices that fill the posterior fossa behind the structures
#'
#' Cortex alone stops at the tentorium, so a subcortical atlas that reaches
#' below it - or one whose cerebellum has been split off into an atlas of its
#' own, as `ggsegMcalt`'s has - is drawn against empty space where the
#' cerebellum and brain stem should be.
#'
#' Cerebellar white matter (7, 46) is deliberately left out. Filling it makes
#' the cerebellum a solid lump that merges with the occipital lobe in
#' sagittal views and reads as more subcortex; the cortex alone comes through
#' as the foliated shell it is, which is what makes it recognisable as
#' cerebellum. [detect_context_labels()] excludes it for the same reason.
#' @noRd
aseg_fossa_idx <- function() {
  c(cerebellum_left = 8L, cerebellum_right = 47L, brainstem = 16L)
}


#' Every `aseg` index the context silhouette is drawn from
#' @noRd
aseg_context_idx <- function() {
  c(aseg_cortex_idx(), aseg_fossa_idx())
}


#' Is the atlas's own cortical mask a solid mantle rather than a ribbon?
#'
#' Not every parcellation needs this fix. One derived from a surface, such as
#' `MarsAtlas`, is already a cortical ribbon in the volume and draws a
#' silhouette with sulci of its own, which the `aseg`'s would only replace
#' with another brain's. One that covers both banks of every sulcus does not.
#'
#' The two are told apart by how many voxels the mask holds against the
#' resampled ribbon in the same grid, which is the same anatomy measured the
#' thin way. Measured: `MarsAtlas` 0.78, Julich 1.96, Hammersmith 2.23. The
#' threshold sits between them with room on both sides, and both ways of
#' being wrong leave the atlas exactly as it was.
#'
#' @param cortical_mask Logical array of the atlas's cortical voxels.
#' @param aseg The resampled `aseg` context volume. Only its cortical ribbon
#'   counts here; the posterior fossa labels are not cortex.
#' @param verbose Report the decision, either way.
#' @param factor How many ribbons' worth of voxels counts as solid.
#' @noRd
cortex_mask_is_solid <- function(
  cortical_mask,
  aseg,
  verbose = get_verbose(),
  factor = 1.5
) {
  ratio <- sum(cortical_mask) / max(1L, sum(aseg %in% aseg_cortex_idx()))
  solid <- ratio >= factor
  if (verbose) {
    log_cortex_mask_decision(solid, round(ratio, 2))
  }
  solid
}


#' Say which silhouette the cortical mask's own thickness argues for
#' @noRd
log_cortex_mask_decision <- function(solid, ratio) {
  if (solid) {
    cli::cli_alert_info(
      "Cortical labels are a solid mantle ({ratio} times the {.field aseg}
      ribbon); looking to the {.field aseg} ribbon for the silhouette.",
      wrap = TRUE
    )
    return(invisible(NULL))
  }
  cli::cli_alert_info(
    "Cortical labels are already a ribbon ({ratio} times the {.field aseg}
    ribbon); keeping them as the context silhouette.",
    wrap = TRUE
  )
  invisible(NULL)
}


#' Is the grid fine enough for the resampled ribbon to hold together?
#'
#' A cortical ribbon is 2.5-3 mm thick. Sampled on a grid whose step is
#' coarser than that, it cannot keep a voxel across itself everywhere, and
#' the silhouette traced from it breaks into disconnected islands - which is
#' worse than the solid mantle it replaces: anatomically right and illegible.
#' The ratio in `cortex_mask_is_solid()` does not see this; Craddock 200
#' (1.58) and ADHD-200 400 (2.82) sit at opposite ends of it and fragment
#' alike, because what they share is a 4 mm grid.
#'
#' What is measured is the ribbon itself rather than the voxel size, so an
#' anisotropic grid, an oblique volume, or anything else the resampling does
#' to the ribbon is caught by the same number: the share of ribbon voxels
#' whose six face neighbours are all ribbon too. That share is what having
#' more than one voxel across the ribbon means.
#'
#' Calibrated by resampling the `cvs_avg35_inMNI152` ribbon to a range of
#' isotropic grids: 1.0 mm 0.49, 1.5 mm 0.29, 2.0 mm 0.18, 2.5 mm 0.11,
#' 3.0 mm 0.06, 4.0 mm 0.03. The threshold is the value at a 2.5 mm step,
#' the thin end of the ribbon and the coarsest grid that can still hold one.
#' The atlases either side of it are not close to it: the 1.5 mm `Mcalt`
#' measures 0.29, the 4 mm parcellations 0.028 to 0.031.
#'
#' @param aseg The resampled `aseg` context volume.
#' @param verbose Report the decision, either way.
#' @param min_interior Share of ribbon voxels that must have a full ribbon
#'   neighbourhood.
#' @noRd
ribbon_is_resolved <- function(
  aseg,
  verbose = get_verbose(),
  min_interior = 0.1
) {
  ribbon <- array(aseg %in% aseg_cortex_idx(), dim = dim(aseg))
  interior <- ribbon_interior_fraction(ribbon)
  resolved <- interior >= min_interior
  if (verbose) {
    log_ribbon_resolution(resolved, round(interior, 3), min_interior)
  }
  resolved
}


#' Say whether the resampled ribbon survived the grid it landed on
#' @noRd
log_ribbon_resolution <- function(resolved, interior, min_interior) {
  if (resolved) {
    cli::cli_alert_info(
      "Taking the silhouette from the resampled {.field aseg} ribbon
      ({interior} of its voxels are a full ribbon thick).",
      wrap = TRUE
    )
    return(invisible(NULL))
  }
  cli::cli_alert_info(
    "The grid is too coarse to carry a ribbon ({interior} of the resampled
    {.field aseg} ribbon's voxels are a full ribbon thick, against
    {min_interior}); keeping the atlas's own cortical labels as the context
    silhouette.",
    wrap = TRUE
  )
  invisible(NULL)
}


#' Share of a mask's voxels whose six face neighbours are all mask too
#'
#' The three-dimensional mask eroded by one voxel, over the mask. Voxels on
#' the volume's own face are never interior, since what lies beyond them is
#' not mask.
#' @noRd
ribbon_interior_fraction <- function(mask) {
  total <- sum(mask)
  if (total == 0L) {
    return(0)
  }
  interior <- mask
  for (axis in seq_len(3L)) {
    for (step in c(-1L, 1L)) {
      interior <- interior & shift_mask(mask, axis, step)
    }
  }
  sum(interior) / total
}


#' A logical array shifted one voxel along an axis, filling with `FALSE`
#' @noRd
shift_mask <- function(mask, axis, step) {
  dims <- dim(mask)
  shifted <- array(FALSE, dim = dims)
  if (dims[axis] < 2L) {
    return(shifted)
  }
  from <- lapply(dims, seq_len)
  to <- from
  keep_low <- seq_len(dims[axis] - 1L)
  keep_high <- seq.int(2L, dims[axis])
  from[[axis]] <- if (step > 0L) keep_low else keep_high
  to[[axis]] <- if (step > 0L) keep_high else keep_low
  shifted[to[[1]], to[[2]], to[[3]]] <- mask[from[[1]], from[[2]], from[[3]]]
  shifted
}

#' Resample the FreeSurfer `aseg` context labels onto a volume's own grid
#'
#' `mri_vol2vol --regheader` resamples through the two headers, so no new
#' transform is invented: the atlas volume is taken to be in the space its
#' header claims, exactly as the rest of the pipeline takes it. Nearest
#' neighbour keeps the label values intact.
#'
#' Returns `NULL`, with a warning, whenever the result cannot be trusted:
#' FreeSurfer missing, the subject's `aseg` missing, the resampling failing,
#' a grid mismatch, or labels that do not land inside the volume's own brain
#' - the last being what a volume in some other space looks like.
#'
#' @param input_volume Path to the atlas volume, used as the target grid.
#' @param subject FreeSurfer subject to take the `aseg` from.
#' @param dims Dimensions of the atlas volume's own grid, which the
#'   resampled `aseg` has to match for the two to be talking about the same
#'   voxels.
#' @param brain_mask Logical array, `TRUE` wherever the atlas volume is
#'   non-zero.
#' @template verbose
#' @return Integer array of the [aseg_context_idx()] values and 0, or `NULL`.
#' @noRd
aseg_context_volume <- function(
  input_volume,
  subject,
  dims,
  brain_mask,
  verbose = get_verbose()
) {
  aseg <- aseg_volume_path(subject)
  if (is.null(aseg)) {
    return(NULL)
  }

  resampled <- resample_volume_to_grid(aseg, input_volume, verbose)
  if (is.null(resampled)) {
    warn_solid_cortex_context("{.code mri_vol2vol} failed")
    return(NULL)
  }
  on.exit(unlink(resampled), add = TRUE)

  context <- as.array(read_volume(resampled, reorient = FALSE))
  if (!identical(dim(context), dims)) {
    warn_solid_cortex_context(
      "the resampled {.field aseg} does not share the volume's grid"
    )
    return(NULL)
  }

  context[!context %in% aseg_context_idx()] <- 0L

  # The gate asks whether the two volumes are in the same space, and only the
  # cortical ribbon can answer: the posterior fossa labels are wanted precisely
  # where the atlas has nothing, so counting them makes an atlas that labels
  # grey matter only look mis-spaced.
  ribbon <- context
  ribbon[!ribbon %in% aseg_cortex_idx()] <- 0L
  if (!ribbon_lands_on_volume(ribbon, brain_mask)) {
    return(NULL)
  }
  storage.mode(context) <- "integer"
  context
}


#' Locate a subject's `aseg.mgz`, or `NULL` when it cannot be used
#' @noRd
aseg_volume_path <- function(subject) {
  if (
    !rlang::is_installed("freesurfer") ||
      !isTRUE(have_fs_quietly())
  ) {
    warn_solid_cortex_context("FreeSurfer is not available")
    return(NULL)
  }

  aseg <- as.character(fs::path(
    freesurfer::fs_subj_dir(),
    subject,
    "mri",
    "aseg.mgz"
  ))
  if (!file.exists(aseg)) {
    warn_solid_cortex_context(
      "{.path {aseg}} does not exist"
    )
    return(NULL)
  }
  aseg
}


#' Is the resampled ribbon actually sitting on this volume's brain?
#'
#' A volume in a space its header does not describe still resamples without
#' error; the ribbon simply lands somewhere else. Requiring most of it to
#' fall on non-zero voxels catches that, and catches an empty ribbon.
#' @noRd
ribbon_lands_on_volume <- function(ribbon, brain_mask, min_overlap = 0.5) {
  overlap <- resampled_overlap(ribbon > 0L, brain_mask)

  if (is.na(overlap)) {
    warn_solid_cortex_context("the resampled {.field aseg} has no cortex")
    return(FALSE)
  }
  if (overlap < min_overlap) {
    # nolint next: object_usage_linter.
    pct <- round(100 * overlap)
    warn_solid_cortex_context(
      "only {pct}% of the {.field aseg} cortex lands inside the volume,
      so the two are not in the same space"
    )
    return(FALSE)
  }
  TRUE
}


#' Warn that the context silhouette falls back to the solid cortical mask
#' @noRd
warn_solid_cortex_context <- function(reason, .envir = parent.frame()) {
  reason <- cli::format_inline(reason, .envir = .envir)
  cli::cli_warn(
    c(
      "Drawing the cortical context as a solid silhouette: {reason}.",
      "i" = "With a FreeSurfer {.field aseg} the context keeps its sulci
      and gyri instead."
    ),
    wrap = TRUE
  )
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
