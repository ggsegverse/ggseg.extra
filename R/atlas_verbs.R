# The atlas vocabulary, attached with this package ----

#' Atlas manipulation verbs, from ggseg.formats
#'
#' @description
#' The vocabulary for reshaping a finished atlas -- dropping regions, gathering
#' views, boolean geometry between labels -- lives in ggseg.formats, because it
#' belongs to the atlas format rather than to any one builder. Every atlas
#' build reaches for both packages, so ggseg.extra carries ggseg.formats in
#' `Depends`: attaching this package attaches that one, and
#' `library(ggseg.extra)` is enough to have the verbs.
#'
#' They are therefore documented where they are defined rather than listed
#' again here, which is what kept this page going stale: it enumerated the
#' verbs by name, and a verb renamed, added or promoted out of a development
#' build left the list quietly wrong.
#'
#' @section Where to look:
#' [ggseg.formats::atlas_manipulation] is the overview: it groups the verbs by
#' what each one acts on -- the regions an atlas has, the views it has, and
#' which regions are drawn inside a view -- and links to the group pages.
#' Accessors such as [ggseg.formats::atlas_regions()] report what an atlas
#' holds, and `ggseg.formats::ggseg_atlas()` is the constructor that validates
#' a hand-edited one.
#'
#' Only `atlas_manipulation` is linked from here on purpose. Naming each group
#' page would tie this package's documentation to a particular ggseg.formats
#' version, which is the coupling this page exists to be rid of.
#'
#' @seealso [atlas_polish()], [atlas_simplify()], [atlas_smooth()] and
#'   [atlas_dilate()], which shape an atlas's geometry and are native to
#'   ggseg.extra.
#'
#' @name atlas-verbs
NULL
