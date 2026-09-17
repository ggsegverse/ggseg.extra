#' Generate a palette for a colourless lookup table
#'
#' Several atlas releases ship a lookup table of names only, with every RGB
#' channel set to zero. Handed to a creation pipeline as-is, the atlas
#' arrives with no palette and the plotting packages assign one, which
#' renders as large blocks of repeated hue. `lut_generate_colors()` fills the
#' `R`, `G` and `B` columns with a palette built from the label names, and
#' sets `A` to `0`.
#'
#' Colours are assigned per *structure*, not per region, so a structure's two
#' hemispheres share one the way FreeSurfer's own tables do. A hemisphere
#' marker is stripped from the label before the hue is chosen, in any of the
#' spellings the ecosystem uses: a `ctx-lh-` / `wm-rh-` or `lh_` / `rh.`
#' prefix, a `Left-` / `Right-` prefix, and a `_left` / `_right` or `-lh`
#' suffix. A label carrying none of them is a structure of its own.
#'
#' Hues are spread evenly around the colour circle in order of first
#' appearance, and stepped through `luminance` in turn so that neighbouring
#' hues still separate. Reordering the table's rows therefore reshuffles the
#' palette; generate it once and commit the result.
#'
#' Two structures are never given the same colour. They can still be given
#' close ones: one chroma and three luminances only hold so many colours, and
#' beyond roughly sixty structures neighbouring hues stop being tellable
#' apart. That is a limit of the ramp rather than a fault, and a parcellation
#' that fine is usually read by hovering a region rather than by matching it
#' to a legend.
#'
#' Rows with `idx = 0` are the background rather than a structure, and are
#' left exactly as they are. Every other row has its `R`, `G`, `B` and `A`
#' replaced, so run this on a table that has no palette worth keeping.
#'
#' @param lut A lookup table with `idx`, `label`, `R`, `G`, `B` and `A`
#'   columns, as returned by [read_lut()].
#' @param by Optional name of a column whose groups are each coloured from
#'   the full colour circle, rather than from a slice of one shared circle.
#'   Pass `by = "type"` for a whole-brain table, where the cortical and
#'   subcortical rows become two atlases that are never plotted together: a
#'   colour then has to be unique within an atlas rather than within the
#'   table, and each atlas gets the whole circle to spend. The default,
#'   `NULL`, colours the table as one atlas.
#' @param chroma Colour intensity, 0 to 360, passed to [grDevices::hcl()] and
#'   held constant across the palette.
#' @param luminance Lightness values, 0 to 100, passed to [grDevices::hcl()]
#'   and cycled through in order as the hue advances.
#'
#' @return `lut`, with `R`, `G` and `B` filled in and `A` set to `0` on every
#'   row that is not the background.
#'
#' @seealso [read_lut()] to read a table in, [write_lut()] to write the
#'   coloured table back out, and [lut_classify_anatomy()] to fill in the
#'   `type` column that `by` can group on.
#' @export
#' @examples
#' lut <- data.frame(
#'   idx = 1:4,
#'   label = c(
#'     "Left-Hippocampus", "Right-Hippocampus",
#'     "Amygdala_left", "Amygdala_right"
#'   ),
#'   R = 0L, G = 0L, B = 0L, A = 0L
#' )
#' lut_generate_colors(lut)
#'
#' # A whole-brain table, where each half becomes an atlas of its own.
#' lut$type <- c("subcortical", "subcortical", "cortical", "cortical")
#' lut_generate_colors(lut, by = "type")
lut_generate_colors <- function(
  lut,
  by = NULL,
  chroma = 75,
  luminance = c(45, 65, 82)
) {
  if (!is_lut(lut)) {
    cli::cli_abort("{.arg lut} must be a lookup table; see {.fn is_lut}.")
  }
  check_palette_args(chroma, luminance)
  colour_me <- palette_rows(lut)
  groups <- palette_groups(lut, by, colour_me)
  if (!any(colour_me)) {
    return(lut)
  }

  colors <- character(nrow(lut))
  for (group in unique(groups[colour_me])) {
    rows <- colour_me & groups == group
    colors[rows] <- structure_palette(
      lut$label[rows],
      chroma = chroma,
      luminance = luminance
    )
  }

  channels <- t(grDevices::col2rgb(colors[colour_me]))
  lut[colour_me, c("R", "G", "B")] <- as.data.frame(channels)
  lut[colour_me, "A"] <- 0L
  lut
}

palette_rows <- function(lut) {
  if (anyNA(lut$label)) {
    cli::cli_abort(
      "{.arg lut} has rows with no label, which cannot be coloured."
    )
  }
  lut$idx != 0L
}

palette_groups <- function(lut, by, colour_me) {
  if (is.null(by)) {
    return(rep_len("", nrow(lut)))
  }
  if (!rlang::is_string(by) || !by %in% names(lut)) {
    cli::cli_abort("{.arg by} must name a column of {.arg lut}.")
  }
  group <- as.character(lut[[by]])
  if (anyNA(group[colour_me])) {
    cli::cli_abort(
      "Column {.val {by}} has missing values; every structure needs a group."
    )
  }
  group
}

structure_palette <- function(labels, chroma, luminance) {
  of <- structure_of(labels)
  structures <- unique(of)
  n <- length(structures)
  colors <- grDevices::hcl(
    h = seq(0, 360, length.out = n + 1L)[seq_len(n)],
    c = chroma,
    l = rep_len(luminance, n)
  )
  if (anyDuplicated(colors) > 0L) {
    cli::cli_abort(c(
      "Cannot give {n} structure{?s} a colour of its own.",
      "x" = paste(
        "{.fn grDevices::hcl} clips out-of-gamut colours without saying so,",
        "and two structures came back the same colour."
      ),
      "i" = "Adjust {.arg chroma} or give {.arg luminance} more values."
    ))
  }
  colors[match(of, structures)]
}

structure_of <- function(labels) {
  stripped <- sub("^(ctx|wm)[-_.][lr]h[-_.]", "", labels)
  stripped <- sub("^[lr]h[-_.]", "", stripped)
  stripped <- sub("^(left|right)[-_.]", "", stripped, ignore.case = TRUE)
  stripped <- sub("[-_.](left|right)$", "", stripped, ignore.case = TRUE)
  sub("[-_.][lr]h$", "", stripped)
}

check_palette_args <- function(chroma, luminance) {
  if (length(chroma) != 1L || !is_in_range(chroma, 360)) {
    cli::cli_abort("{.arg chroma} must be a single number between 0 and 360.")
  }
  if (length(luminance) < 1L || !is_in_range(luminance, 100)) {
    cli::cli_abort(
      "{.arg luminance} must be one or more numbers between 0 and 100."
    )
  }
}

is_in_range <- function(x, max) {
  is.numeric(x) && all(is.finite(x)) && all(x >= 0 & x <= max)
}
