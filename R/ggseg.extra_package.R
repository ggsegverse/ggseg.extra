#' @section What these atlases are for:
#' These atlases are built for visualising results.
#' They are there to give general anatomical guidance —
#' roughly where in the brain an effect sits,
#' and which structures neighbour it.
#' They are not a source of precision geometry.
#' Nothing here is meant to be measured from:
#' not volumes, not surface areas, not distances,
#' and not the exact boundary between two neighbouring parcels.
#' An analysis that needs those numbers should take them from the
#' annotation, surface or volume the atlas was built from,
#' never from the atlas.
#'
#' That positioning buys the pipelines one specific kind of slack, and no more.
#' Acceptable by design:
#' vertices that sit a millimetre or so from where the source data puts them,
#' shape lost to mesh smoothing and decimation,
#' corners rounded off by polygon simplification
#' (the `keep` argument of [atlas_simplify()] and [atlas_polish()]),
#' and the difference between an atlas's own silhouette
#' and the same parcellation resampled onto a shared surface.
#' Not acceptable, and not excused by it:
#' anything categorically wrong.
#' A region drawn on the wrong hemisphere,
#' a label attached to the wrong structure,
#' or a region missing from a view where it is anatomically present
#' is a bug, however tight the tolerance on its vertices.
#' A tool that puts the left hippocampus on the right is not being imprecise;
#' it is giving confident wrong guidance, which is worse than giving none.
#' Please report those as bugs.
#'
#' @section What a 3D plot shows:
#' Cortical and cerebellar atlases do not carry their own 3D geometry.
#' They store vertex indices.
#' A cortical atlas records, for each region,
#' which vertices of the fsaverage5 surface it claims
#' (0 to 10241 per hemisphere);
#' a cerebellar atlas records which vertices of the SUIT surface it
#' claims (0 to 28934).
#' Rendering either in 3D therefore draws fsaverage5's or SUIT's anatomy
#' with the atlas's labels painted onto it.
#' The cortical shape of the brain the parcellation came from is never
#' shown, and cannot be.
#' Registration decides only which vertices each region claims.
#'
#' Subcortical and white-matter tract atlases are different.
#' Those carry a real mesh per structure,
#' tessellated from the source volume or from streamlines,
#' so the 3D geometry is their own.
#' A cerebellar atlas built from a volume carries meshes for its deep
#' nuclei for the same reason:
#' those sit off the flatmap surface.
#'
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
