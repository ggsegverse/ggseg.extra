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
#' 1. **The `labels` argument** (highest priority): `labels = list(cortical =
#'    ..., subcortical = ..., cerebellar = ...)` overrides everything for the
#'    labels it names.
#' 2. **LUT `type` column**: If the colour lookup table has a `type` column
#'    with values `"cortical"` or `"subcortical"`, that classification is
#'    used for any labels `labels` does not name. This is the recommended
#'    approach for reproducible atlas creation.
#' 3. **Vertex-count heuristic** (fallback): Labels with at least
#'    `projection_opts$min_vertices` vertices on the surface projection are
#'    classified as cortical; the rest as subcortical. It measures how much
#'    surface a label covers rather than where the label sits, so a small
#'    cortical parcel and a deep structure look the same to it. It warns
#'    whenever it runs; treat that warning as a request to declare the
#'    labels instead.
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
#' This is the most complex pipeline in ggseg.extra and the one most likely
#' to need manual correction. Recommended workflow:
#'
#' 1. Run `steps = 1:2` first to project the volume and classify labels.
#' 2. Inspect `result$cortical_labels` and `result$subcortical_labels`.
#'    If the automatic split is wrong, either add a `type` column to the
#'    LUT or name the labels in `labels`.
#' 3. Run the full pipeline once you are satisfied with the split.
#' 4. Visually inspect the resulting atlas with `plot()` for a quick
#'    overview, or `ggplot() + geom_brain()` and `ggseg3d()` for a figure.
#'
#' The cortical surface projection uses FreeSurfer's cortex label
#' (`{hemi}.cortex.label`) to prevent label dilation into the medial wall.
#' This file ships with fsaverage5 and is always required. Cortex vertices
#' left without a listed label take the most common label of their
#' neighbours. Everything outside the cortex label becomes the `unknown`
#' medial wall, which the cortical atlas keeps as grey context geometry
#' rather than as a region.
#'
#' @section Declared hemisphere:
#'
#' A cortical label carries no hemisphere of its own. The `lh_`/`rh_` prefix on
#' a finished region comes from whichever surface its vertices landed on, so a
#' parcel whose voxels cross the midline is sampled onto *both* surfaces and
#' becomes two regions the parcellation never had -- the larger one real, the
#' smaller one built from the spill.
#'
#' Give the lookup table a `hemi` column (`"left"` or `"right"`, or `lh`/`rh`)
#' and the parcel is kept only on the surface it belongs to. Where there is no
#' column the label's own name is read, which covers `Left-Thalamus`,
#' `lh.something`, `region_L` and FreeSurfer's `ctx-lh-superiorfrontal`.
#'
#' A label that declares nothing is left alone, on purpose: a lookup table that
#' names each structure once for both hemispheres is *meant* to produce `lh_`
#' and `rh_`. So this is opt-in, and a table without the column behaves exactly
#' as before.
#'
#' The column is passed on to the subcortical and cerebellar pipelines, where
#' it sets the region's hemisphere instead of the label's name doing so. There
#' it may also say `"midline"` or `"vermis"`.
#'
#' Hemisphere is never inferred from the voxels. The volume does know which side
#' a parcel sits on, but a majority vote is a guess made silently on every
#' build, whereas a column is a fact you can see and correct -- the same
#' reasoning as the `type` column and [lut_classify_anatomy()].
#'
#' @param input_volume Path to volumetric parcellation in MNI152 space
#'   (.mgz, .nii, .nii.gz).
#' @param input_lut Path to FreeSurfer-style colour lookup table, or a
#'   data.frame with columns `idx`, `label`, `R`, `G`, `B`, `A`.
#'   An optional `type` column with values `"cortical"`, `"subcortical"` or
#'   `"cerebellar"` controls label classification (see **Label
#'   classification**); any other value is an error, and `NA` leaves the
#'   label to the other classification steps. An optional
#'   `hemi` column with values `"left"` or `"right"` says which hemisphere a
#'   parcel belongs to (see **Declared hemisphere**). Voxel IDs
#'   not listed in the LUT are automatically zeroed out before surface
#'   projection (see **Volume pre-processing**).
#'   If NULL, generic names and no palette.
#' @template atlas_name
#' @template output_dir
#' @param ... Not used. Present so a mistyped or misplaced argument is
#'   reported against this function, naming the list that should hold it,
#'   rather than silently ignored; anything passed here is an error.
#' @param labels Named list routing labels to a sub-pipeline, overriding the
#'   lookup table's `type` column and the vertex-count heuristic. Entries:
#'   \itemize{
#'     \item `cortical`: label names to force as cortical.
#'     \item `subcortical`: label names to force as subcortical.
#'     \item `cerebellar`: label names to send through the cerebellar SUIT
#'       flatmap pipeline, using the bundled surfaces from
#'       [suit_flatmap_path()] and [suit_3d_path()].
#'   }
#'   Unnamed or unknown entries error.
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
#'   Unknown entries error.
#' @param cortical_opts Named list of extra arguments forwarded to the
#'   cortical sub-pipeline. Allowed entry: `views`. Unknown entries error.
#'   Leave empty to use defaults.
#' @param subcortical_opts Named list of extra arguments forwarded to
#'   [create_subcortical_from_volume()]. Any argument of that function may
#'   be set here except those managed by the wholebrain pipeline
#'   (`input_volume`, `input_lut`, `atlas_name`, `output_dir`, `verbose`,
#'   `cleanup`, `skip_existing`). Use this to tune `vertex_size_limits`,
#'   `decimate`, `slabs`.
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
#' @return For a full run, a named list with elements `cortical`,
#'   `subcortical` and `cerebellar`, each a `ggseg_atlas` object (or `NULL`
#'   if no regions of that type exist). A run that stops at or before step 2
#'   instead returns, invisibly, the label split to inspect:
#'   `cortical_labels`, `subcortical_labels`, `cerebellar_labels` and
#'   `vertex_counts`.
#' @family atlas creation
#' @seealso [atlas_polish()] to simplify and round off the result, which
#'   most builds want next.
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
  redirect_sub_pipeline_args(...names())
  rlang::check_dots_empty()
  labels <- resolve_opts(labels, "labels", WHOLEBRAIN_LABEL_DEFAULTS)
  projection <- resolve_opts(
    projection_opts,
    "projection_opts",
    WHOLEBRAIN_PROJECTION_DEFAULTS
  )
  cerebellar <- take_cerebellar_space(cerebellar_opts)

  start_time <- Sys.time()
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

#' Entries the grouped `labels` argument accepts
#' @noRd
WHOLEBRAIN_LABEL_DEFAULTS <- list(
  cortical = NULL,
  subcortical = NULL,
  cerebellar = NULL
)
# nolint end

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
  owners <- list(
    subcortical_opts = setdiff(
      names(formals(create_subcortical_from_volume)),
      c(SUB_PIPELINE_MANAGED_ARGS, "...")
    ),
    cerebellar_opts = setdiff(
      names(formals(create_cerebellar_from_volume)),
      c(SUB_PIPELINE_MANAGED_ARGS, "...")
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
    {.code labels = list(cortical = , subcortical = , cerebellar = )} if
    needed, then re-run with all steps.",
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
  allowed <- function(fn) {
    setdiff(names(formals(fn)), c(SUB_PIPELINE_MANAGED_ARGS, "..."))
  }

  list(
    # Only `views` is read by wholebrain_cortical_inputs(). Anything else
    # passed validation and was then silently discarded, so the allowed set
    # is the one entry the pipeline actually honours.
    cortical = validate_pipeline_opts(
      cortical_opts,
      "cortical_opts",
      CORTICAL_ALLOWED_ARGS
    ),
    subcortical = validate_pipeline_opts(
      subcortical_opts,
      "subcortical_opts",
      allowed(create_subcortical_from_volume)
    ),
    cerebellar = validate_pipeline_opts(
      cerebellar_opts,
      "cerebellar_opts",
      allowed(create_cerebellar_from_volume)
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
# Index values the subcortical pipeline writes into its own volume to build
# the grey brain outline: 3/42 are the FreeSurfer cortex labels the cortical
# hemispheres are remapped to, and 7/8/46/47/16 are the cerebellum and
# brainstem labels the outline is extended with. A subcortical structure
# carrying one of these indices would be fused with a whole hemisphere of
# cortex, which lands the silhouette in `core` instead of leaving it as
# context.
SUBCORT_RESERVED_IDX <- c(3L, 7L, 8L, 16L, 42L, 46L, 47L)


# The wholebrain call owns these for every sub-pipeline it drives, so a
# user cannot set them through a `*_opts` list.
SUB_PIPELINE_MANAGED_ARGS <- c(
  "input_volume",
  "input_lut",
  "atlas_name",
  "output_dir",
  "verbose",
  "cleanup",
  "skip_existing"
)
# Unlike subcortical/cerebellar, wholebrain does not call a single public
# cortical builder, so there are no formals to track: the cortical sub-
# pipeline reads exactly one option.
CORTICAL_ALLOWED_ARGS <- "views"
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
  lut <- if (is.character(input_lut)) read_lut(input_lut) else input_lut
  check_lut_type(lut)

  validate_registration(registration, subject, input_volume)

  config$output_dir <- absolute_path(config$output_dir)

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
  config$lut <- lut
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
    config$lut,
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
  if (!label_belongs_to_hemi(ct_row, label_name, hemi)) {
    return(NULL)
  }

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


#' Does a parcel belong to the surface it has just been found on?
#'
#' Nothing else in the package can answer this. A cortical label carries no
#' hemisphere in its own right -- the prefix in `lh_bankssts` comes from
#' whichever surface the vertices landed on, not from the lookup table -- so a
#' parcel whose voxels cross the midline is sampled onto *both* surfaces and
#' becomes two regions the parcellation never had. ggsegShen has one: 96.5% of
#' `Region_174`'s 826 voxels are left of the midline, and the right-hemisphere
#' region was built from the 3.5% that spill across.
#'
#' The answer is taken from what the lookup table *declares*, never inferred
#' from the voxels. A `hemi` column says it outright, as `type` does for
#' cortical/subcortical/cerebellar; failing that, the label's own name is read
#' with [detect_hemi()], which covers the `Left-`/`lh.`/`_L` spellings
#' parcellations already use. A label that declares nothing is left alone, so a
#' lookup table naming each structure once for both hemispheres keeps
#' producing `lh_` and `rh_` as it should.
#'
#' Declaring beats measuring here even though the volume knows: a voxel
#' majority is a guess made silently on every build, and a column is a fact the
#' atlas author can see and correct. [lut_classify_anatomy()] already sets this
#' precedent for `type`.
#'
#' @param ct_row The label's lookup table row.
#' @param label_name The label's source name.
#' @param hemi Long hemisphere name of the surface being read.
#' @return `TRUE` to keep the parcel on this surface.
#' @noRd
label_belongs_to_hemi <- function(ct_row, label_name, hemi) {
  declared <- declared_hemi(ct_row, label_name)
  !declared %in% c("left", "right") || identical(declared, hemi)
}


#' The hemisphere a lookup table row declares, or `NA` if it declares none
#'
#' The name is read strictly here: a parcel is dropped from the surface it
#' does not belong to, so a loose match on the word "left" inside a bilateral
#' label would delete half of it.
#' @noRd
declared_hemi <- function(ct_row, label_name) {
  lut_hemi(ct_row, label_name, from_name = function(label_name) {
    embedded <- embedded_hemi_token(label_name)
    if (!is.na(embedded)) {
      return(embedded)
    }
    detect_hemi(label_name, strict = TRUE)
  })
}


#' Hemisphere from an `lh`/`rh` token in the middle of a label
#'
#' FreeSurfer's own cortical labels put it there -- `ctx-lh-superiorfrontal` --
#' and a wholebrain build from `aparc+aseg` is full of them, so
#' [detect_hemi()]'s prefix and suffix patterns miss the commonest declared
#' form the volume path sees.
#'
#' Separators are required on both sides. A bare substring search for `lh` or
#' `rh` assigns a hemisphere to any label that happens to contain those
#' letters -- `Entorhinal` reads as right -- and a bounded token cannot do
#' that.
#' @noRd
embedded_hemi_token <- function(label_name) {
  if (grepl("[-_. ]lh[-_. ]", label_name, ignore.case = TRUE)) {
    return("left")
  }
  if (grepl("[-_. ]rh[-_. ]", label_name, ignore.case = TRUE)) {
    return("right")
  }
  NA_character_
}


#' Read a declared hemisphere in any of its usual spellings
#'
#' `NA` for anything unrecognised rather than an error: an unexpected value
#' means the column says nothing usable about this label, and the label is
#' then treated as undeclared, which is the behaviour of a table without the
#' column at all.
#' @noRd
normalise_hemi <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    return(NA_character_)
  }
  switch(
    tolower(trimws(x)),
    "left" = ,
    "lh" = ,
    "l" = "left",
    "right" = ,
    "rh" = ,
    "r" = "right",
    "midline" = "midline",
    "vermis" = "vermis",
    NA_character_
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

  check_lut_type(colortable)
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
  warn_volume_only_subcortical(volume_only)

  auto_cortical <- projected_remaining[
    vertex_counts[projected_remaining] >= min_vertices
  ]
  auto_subcortical <- c(
    projected_remaining[vertex_counts[projected_remaining] < min_vertices],
    volume_only
  )

  list(cortical = auto_cortical, subcortical = auto_subcortical)
}


#' Say that labels absent from the surface were taken to be subcortical
#'
#' A label in the volume that reached no cortical vertex is put in the
#' subcortical bucket. That is a reasonable default -- a structure the
#' cortical surface does not see is usually deep -- but it is a default, not a
#' measurement, and it was applied in silence.
#'
#' Reported separately from the vertex-count fallback because the two are
#' different claims. That one says a label was sized and found small; this one
#' says a label was never measured at all. They were easy to confuse when only
#' the first was reported: a run that put nineteen labels in the subcortical
#' bucket while announcing fourteen vertex-count guesses left the other five
#' unaccounted for.
#' @noRd
warn_volume_only_subcortical <- function(volume_only) {
  if (length(volume_only) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "{length(volume_only)} label{?s} {?is/are} in the volume but not on the
      cortical surface, and {?was/were} taken to be subcortical.",
      "x" = "Assumed subcortical: {.val {volume_only}}",
      "i" = "Nothing measured these; a structure the cortical surface does
      not reach is usually deep, but declare them with a {.field type} column
      if any is not."
    ),
    wrap = TRUE
  )
  invisible(NULL)
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
      {.code labels = list(cortical = , subcortical = , cerebellar = )}."
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
  requested <- list(
    cortical = cortical_labels,
    subcortical = subcortical_labels,
    cerebellar = cerebellar_labels
  )

  warn_unmatched_overrides(requested, all_labels)

  lapply(requested, function(labels) {
    if (is.null(labels)) character(0) else intersect(labels, all_labels)
  })
}


#' Say which manually classified labels the atlas does not have
#'
#' An override names labels the caller knows better than the pipeline does.
#' One that matches nothing is almost always a typo or a spelling from another
#' parcellation, and `intersect()` drops it without a word -- so the label the
#' caller meant is never overridden and goes to automatic classification
#' instead. The override does not fail; it is quietly replaced by a guess,
#' which is worse than being refused.
#'
#' All three arguments are checked through one path. Three near-identical
#' branches are how only `subcortical_labels` came to be checked: the other
#' two were written by copying the branch that did the work and dropping the
#' part that validates.
#'
#' @param requested Named list of the three override arguments, `NULL` where
#'   not supplied.
#' @param all_labels Every label the volume and the projection have between
#'   them.
#' @noRd
warn_unmatched_overrides <- function(requested, all_labels) {
  unmatched <- lapply(requested, setdiff, y = all_labels)
  unmatched <- unmatched[lengths(unmatched) > 0L]
  if (length(unmatched) == 0L) {
    return(invisible(NULL))
  }

  bullets <- vapply(
    names(unmatched),
    function(group) {
      cli::format_inline(
        "{.arg {paste0(group, '_labels')}}: {.val {unmatched[[group]]}}"
      )
    },
    character(1),
    USE.NAMES = FALSE
  )
  total <- sum(lengths(unmatched)) # nolint: object_usage_linter.

  cli::cli_warn(
    c(
      "{total} manually classified label{?s} {?is/are} not in this atlas, so
      {?that override/those overrides} had no effect.",
      stats::setNames(bullets, rep("x", length(bullets))),
      "i" = "Check the spelling against the lookup table. A label named here
      that the atlas does not have leaves the one you meant to be classified
      automatically instead."
    ),
    wrap = TRUE
  )
  invisible(NULL)
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
    report_projection_losses(colortable, projection$atlas_data)
    return(projection)
  }

  surf_dir <- as.character(fs::path(dirs$base, "surface_overlays"))
  atlas_data <- refine_cortical_overlays(config, surf_dir, colortable)
  report_projection_losses(colortable, atlas_data)

  list(
    atlas_data = atlas_data,
    colortable = colortable
  )
}


#' Say which declared cortical labels the surface projection did not deliver
#'
#' Projecting a volume onto a surface is lossy in two ways that both read as
#' success. A parcel can land on no vertex at all, and it then has no row in
#' `atlas_data` and no row in the finished atlas -- the region count is simply
#' lower than the lookup table, with nothing saying which parcels went or
#' that any did. And a parcel whose voxels cross the midline can land on both
#' surfaces, and each fragment becomes a region of its own, so one entry in
#' the lookup table turns into `lh_` and `rh_` parcels that the parcellation
#' never had.
#'
#' Neither is reported anywhere else, and neither is necessarily wrong:
#' a lookup table that names a structure once for both hemispheres is
#' *supposed* to produce `lh_` and `rh_`, and a label the parcellation put
#' outside the cortical ribbon has nowhere on the surface to go. So this
#' reports rather than aborts, and names what it found so the numbers can be
#' checked against the parcellation.
#'
#' The both-hemispheres report is only worth making for a parcellation that
#' gives each hemisphere its own entry, where a label on both surfaces is a
#' label in the wrong place. Whether this is such a parcellation is read off
#' the labels themselves -- whether most of them came back on one surface
#' only -- rather than configured, so a bilateral lookup table stays quiet
#' instead of listing every label it has.
#'
#' @param colortable The cortical rows of the lookup table: what was asked
#'   for.
#' @param atlas_data The projected surface data: what arrived.
#' @noRd
report_projection_losses <- function(colortable, atlas_data) {
  arrived <- atlas_data[atlas_data$source_label %in% colortable$label, ]

  warn_unprojected_labels(
    setdiff(colortable$label, arrived$source_label)
  )
  warn_split_labels(arrived)
  invisible(NULL)
}


#' Warn that a declared cortical label reached no vertex on either surface
#' @noRd
warn_unprojected_labels <- function(missing) {
  if (length(missing) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "{length(missing)} cortical label{?s} reached no surface vertex and
      {?is/are} not in the atlas.",
      "x" = "Dropped: {.val {missing}}",
      "i" = "A label the parcellation placed off the cortical ribbon -
      in white matter or a subcortical structure - has nowhere on the
      surface to land. Check these are meant to be cortical."
    ),
    wrap = TRUE
  )
}


#' Warn that a cortical label landed on both surfaces in a one-sided atlas
#' @noRd
warn_split_labels <- function(arrived) {
  sides <- split(arrived, arrived$source_label)
  hemis <- vapply(sides, function(rows) length(unique(rows$hemi)), integer(1))
  if (length(hemis) == 0L || mean(hemis == 1L) <= 0.5) {
    # Most labels are on both surfaces, so this lookup table names each
    # structure once for both hemispheres and is behaving as intended.
    return(invisible(NULL))
  }

  both <- names(hemis)[hemis > 1L]
  if (length(both) == 0L) {
    return(invisible(NULL))
  }

  # nolint next: object_usage_linter.
  splits <- describe_hemi_split(sides[both])
  cli::cli_warn(
    c(
      "{length(both)} cortical label{?s} landed on both surfaces, in an atlas
      whose labels are otherwise one hemisphere each.",
      "x" = "Split in two: {.val {both}}",
      "i" = "Each became a separate {.field lh_} and {.field rh_} region.
      Voxels crossing the midline project onto the far surface, so the
      smaller side is usually spill rather than anatomy: {.val {splits}}"
    ),
    wrap = TRUE
  )
}


#' Vertex counts per hemisphere, for a label that landed on both
#' @noRd
describe_hemi_split <- function(sides) {
  vapply(
    names(sides),
    function(label) {
      rows <- sides[[label]]
      counts <- vapply(rows$vertices, length, integer(1))
      short <- vapply(rows$hemi, hemi_to_short, character(1), USE.NAMES = FALSE)
      paste0(label, " ", paste0(short, " ", counts, collapse = " / "))
    },
    character(1),
    USE.NAMES = FALSE
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
    skip_existing = config$skip_existing
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

#' The lookup table a sub-pipeline is handed
#'
#' Passed as a data frame rather than written to a LUT file, because the file
#' format has no field for what the author declared: a `hemi` column would be
#' dropped on the way, and the sub-pipeline would go back to reading the
#' hemisphere out of the label's name.
#' @noRd
sub_pipeline_lut <- function(colortable) {
  columns <- c(
    "idx",
    "label",
    "R",
    "G",
    "B",
    "A",
    intersect("hemi", names(colortable))
  )
  lut <- as.data.frame(colortable[, columns, drop = FALSE])
  rownames(lut) <- NULL
  lut
}


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

  subcort_ct <- fill_missing_rgb(subcort_ct, "subcort")
  subcort_ct <- reindex_reserved_subcort_idx(subcort_ct, config$verbose)
  subcort_lut <- sub_pipeline_lut(subcort_ct)

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

  cer_lut <- sub_pipeline_lut(cer_ct)

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
  keep <- arr %in% cerebellar_idx
  result[keep] <- arr[keep]
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
  # One match() pass rather than a whole-array scan per label: a 400-parcel
  # atlas on a 1 mm grid is ~10^9 comparisons the loop way. match() reports
  # the first hit while the loop let a later entry win, so a repeated source
  # index is reduced to its last mapping first to keep that behaviour.
  last <- !duplicated(subcortical_idx, fromLast = TRUE)
  hit <- match(arr, subcortical_idx[last])
  found <- !is.na(hit)
  result[found] <- target_idx[last][hit[found]]
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
