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
