# whole-brain context declaration ----
#
# Which labels a whole-brain atlas draws as backdrop rather than as regions,
# and how the pipeline tells the sub-pipeline what it wrote. The declaration
# is the author's: it comes from the lookup table's `context` column, or from
# the classification when the table says nothing. Nothing here infers a
# backdrop from a label's name.

#' FreeSurfer `aseg` indices for the left and right cortical ribbon
#' @noRd
aseg_cortex_idx <- function() {
  c(left = 3L, right = 42L)
}


#' Record which indices a prepared volume holds as backdrop
#'
#' The subcortical pipeline has to be told, not left to recognise a backdrop
#' by its name. Carried as an attribute so the writers can report what they
#' wrote without changing their return type.
#' @param result A volume being written by the whole-brain pipeline.
#' @param idx Integer indices written as backdrop.
#' @noRd
record_context_idx <- function(result, idx) {
  attr(result, "context_idx") <- sort(unique(c(
    written_context_idx(result),
    as.integer(idx)
  )))
  result
}


#' The context indices a prepared volume reports holding
#'
#' `integer(0)` when nothing was written, which is the honest answer for a
#' parcellation with no cortical labels: there is no backdrop to declare.
#' @param result A volume written by the whole-brain pipeline.
#' @noRd
written_context_idx <- function(result) {
  as.integer(attr(result, "context_idx") %||% integer(0))
}


#' The cortical labels that stand in as backdrop for a slab view
#'
#' A subcortical or tract atlas is drawn against the cortex, and a
#' whole-brain volume already contains it, so the labels classified as
#' cortical are the backdrop by default. The author overrules that per row by
#' declaring `context = FALSE`, which keeps the label a region. A row that
#' says nothing, or a table with no `context` column at all, takes the
#' default.
#' @param colortable The lookup table whose `context` column may decline a
#'   label, or `NULL` when there is none.
#' @param cortical_labels Labels classification assigned to the cortex.
#' @return The subset of `cortical_labels` that serve as backdrop.
#' @noRd
default_backdrop_labels <- function(colortable, cortical_labels) {
  if (is.null(colortable) || !length(cortical_labels)) {
    return(as.character(cortical_labels))
  }
  if (!"context" %in% names(colortable)) {
    return(as.character(cortical_labels))
  }
  declared <- lut_context_values(colortable$context)
  declined <- colortable$label[!is.na(declared) & !declared]
  setdiff(as.character(cortical_labels), as.character(declined))
}


#' Name the backdrop a prepared volume wrote
#'
#' The pipeline writes the silhouette, so the pipeline declares it. Without
#' these rows the lookup table has nothing for those indices and the
#' subcortical build invents `context_<idx>` names that something downstream
#' then has to recognise by sight.
#' @param lut The subcortical lookup table, as [sub_pipeline_lut()] builds it.
#' @param context_idx Indices the writers reported, from
#'   [written_context_idx()].
#' @param group The silhouette's name; rows sharing it are one shape.
#' @return `lut` with the backdrop rows appended and a `context` column.
#' @noRd
declare_backdrop_rows <- function(lut, context_idx, group = "cortex") {
  if (!"context" %in% names(lut)) {
    lut$context <- NA_character_
  }
  context_idx <- setdiff(as.integer(context_idx), as.integer(lut$idx))
  if (!length(context_idx)) {
    return(lut)
  }
  sides <- names(aseg_cortex_idx())[match(context_idx, aseg_cortex_idx())]
  rows <- data.frame(
    idx = context_idx,
    label = ifelse(
      is.na(sides),
      paste0("context_", context_idx),
      paste0(substr(sides, 1, 1), "h_", group)
    ),
    R = 190L,
    G = 190L,
    B = 190L,
    A = 0L,
    context = group,
    stringsAsFactors = FALSE
  )
  missing <- setdiff(names(lut), names(rows))
  for (column in missing) {
    rows[[column]] <- NA
  }
  rbind(lut, rows[names(lut)])
}
