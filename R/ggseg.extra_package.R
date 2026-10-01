#' @section Getting started:
#' `sitrep()` reports whether this machine has what each pipeline needs.
#' Run it first — most pipelines want FreeSurfer, and some want Connectome
#' Workbench or an optional R package.
#'
#' Pick the creator that matches the input you have:
#'
#' * **Cortical surface** — [create_cortical_from_annotation()] for a
#'   FreeSurfer `.annot`, [create_cortical_from_gifti()] or
#'   [create_cortical_from_cifti()] for surface formats,
#'   [create_cortical_from_labels()] for hand-drawn `.label` files, and
#'   [create_cortical_from_neuromaps()] for a neuromaps annotation.
#' * **Subcortical** — [create_subcortical_from_volume()] from a segmentation
#'   volume such as FreeSurfer's `aseg`.
#' * **Cerebellar** — [create_cerebellar_from_gifti()],
#'   [create_cerebellar_from_annotation()] or
#'   [create_cerebellar_from_volume()], all onto the SUIT flatmap.
#' * **White-matter tract** — [create_tract_from_tractography()] from
#'   streamlines, or [create_tract_from_volume()] from a tract label map.
#' * **Whole brain at once** — [create_wholebrain_from_volume()], which splits
#'   one volume across the three pipelines above.
#'
#' A freshly built atlas usually carries more vertices than a plot needs.
#' [atlas_polish()] simplifies and rounds it off in one call;
#' [atlas_simplify()], [atlas_smooth()] and [atlas_dilate()] are the separate
#' steps. [count_vertices()] is the number to watch.
#'
#' To ship an atlas as its own package, [setup_atlas_repo()] scaffolds the
#' repository and [use_atlas_github_actions()] adds its workflows.
#'
#' @importFrom ggseg.formats atlas_region_contextual atlas_region_op
#' @importFrom ggseg.formats atlas_region_remove atlas_view_remove ggseg_atlas
#' @importFrom ggseg.formats ggseg_data_cerebellar ggseg_data_cortical
#' @importFrom ggseg.formats ggseg_data_subcortical ggseg_data_tract
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom lifecycle badge
## usethis namespace: end
NULL

## quiets concerns of R CMD check
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    ".id",
    ".subid",
    "filenm",
    "geometry",
    "ggseg_3d",
    "hemi",
    "key",
    "L2",
    "label",
    "region",
    "val",
    "view",
    "X",
    "Y"
  ))
}
