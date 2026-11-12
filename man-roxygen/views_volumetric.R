#' @param views The views to build, as a data.frame with columns `name`,
#'   `type` ("axial", "coronal", "sagittal"), `start` (first slice) and `end`
#'   (last slice). Each row is one view of the finished atlas: `name` becomes
#'   its `view`, the value [ggseg.formats::atlas_views()] reports and the name
#'   the view verbs match on. `start`/`end` are the band of slices that view
#'   is projected through --- unlike a single slice, a projection shows every
#'   structure in the band in its spatial relationships, like an X-ray.
#'   `NULL`, the default, derives a set from the volume's own labels.
#' @param slabs `r lifecycle::badge("deprecated")` Renamed to `views`.
