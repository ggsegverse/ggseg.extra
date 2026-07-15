# Snapshot functions ----

# Volume extraction helpers ----
# These functions handle all orientation logic for converting 3D volumes
# to 2D images with correct neuroimaging orientation.
#
# Standard neuroimaging conventions (RAS coordinates):
# - Axial: looking from above, anterior at top, left on left (neurological)
# - Coronal: looking from front, superior at top, left on left
# - Sagittal: looking from left, superior at top, anterior at right

#' Extract 2D slice from 3D volume
#'
#' Extracts a single slice with correct orientation for display.
#' Handles all view-specific transformations internally.
#'
#' @param vol 3D array in RAS orientation
#' @param view "axial", "coronal", or "sagittal"
#' @param pos Slice position (x for sagittal, y for coronal, z for axial)
#'
#' @return 2D matrix ready for image() display
#' @keywords internal
#' @noRd
extract_slice_2d <- function(vol, view, pos, hemi = NULL) {
  # nolint start: commas_linter.
  slice <- switch(
    view,
    "axial" = vol[,, pos, drop = TRUE],
    "coronal" = vol[, pos, , drop = TRUE],
    "sagittal" = vol[pos, , , drop = TRUE]
  )
  # nolint end

  if (is.null(slice) || length(slice) == 0) {
    return(NULL)
  }

  if (!is.matrix(slice)) {
    dims <- dim(vol)
    new_dims <- switch(
      view,
      "axial" = dims[1:2],
      "coronal" = dims[c(1, 3)],
      "sagittal" = dims[2:3]
    )
    slice <- matrix(slice, nrow = new_dims[1], ncol = new_dims[2])
  }

  orient_slice_2d(slice, view, hemi = hemi)
}


#' Create maximum intensity projection of volume
#'
#' Projects a 3D volume onto a 2D plane by taking the maximum value along
#' each ray. Optionally restricts to a subset of slices.
#'
#' @param vol 3D array in RAS orientation
#' @param view "axial", "coronal", or "sagittal"
#' @param start First slice index (NULL for full projection)
#' @param end Last slice index (NULL for full projection)
#' @param hemi Hemisphere for sagittal views: "left" or "right"
#'
#' @return 2D matrix ready for image() display
#' @keywords internal
#' @noRd
volume_projection <- function(
  vol,
  view,
  start = NULL,
  end = NULL,
  hemi = NULL
) {
  dims <- dim(vol)

  if (is.null(start)) {
    start <- 1
  }
  if (is.null(end)) {
    end <- switch(
      view,
      "axial" = dims[3],
      "coronal" = dims[2],
      "sagittal" = dims[1]
    )
  }

  # nolint start: commas_linter.
  sub_vol <- switch(
    view,
    "axial" = vol[,, start:end, drop = FALSE],
    "coronal" = vol[, start:end, , drop = FALSE],
    "sagittal" = vol[start:end, , , drop = FALSE]
  )
  # nolint end

  proj <- switch(
    view,
    "axial" = apply(sub_vol, c(1, 2), max),
    "coronal" = apply(sub_vol, c(1, 3), max),
    "sagittal" = apply(sub_vol, c(2, 3), max)
  )

  orient_slice_2d(proj, view, hemi = hemi)
}


#' Orient 2D slice for display
#'
#' With RAS+ input, `image()` already displays axial and coronal correctly.
#' Only left-hemisphere sagittal needs a horizontal flip so hemispheres
#' face each other when plotted side-by-side.
#'
#' @param slice 2D matrix
#' @param view "axial", "coronal", or "sagittal"
#' @param hemi Hemisphere for sagittal views: "left" or "right". Left sagittal
#'   is flipped horizontally so left and right face each other when plotted.
#'
#' @return Transformed 2D matrix
#' @keywords internal
#' @noRd
orient_slice_2d <- function(slice, view, hemi = NULL) {
  if (view == "sagittal" && identical(hemi, "left")) {
    return(slice[rev(seq_len(nrow(slice))), ])
  }
  slice
}


#' Core snapshot helper for brain rendering
#'
#' Shared logic for taking brain snapshots with different palettes.
#' Uses [ggseg3d::ggseg3d()] with webshot2 for headless rendering,
#' allowing safe parallelization without X11 context issues.
#'
#' @param atlas Brain atlas object
#' @param hemisphere Short hemisphere code ("lh" or "rh")
#' @param view View name
#' @param surface Surface to render
#' @param outfile Output file path
#' @param .data Optional data frame for custom coloring
#' @param colour Column name to use for coloring
#' @param na_colour Colour for NA regions
#' @param skip_existing Skip if file exists
#' @noRd
#' @importFrom ggseg3d ggseg3d pan_camera set_background set_flat_shading
#'   set_orthographic set_legend snapshot_brain
snapshot_brain_helper <- function(
  atlas,
  hemisphere,
  view,
  surface,
  outfile,
  .data = NULL,
  colour = "colour",
  na_colour = "#CCCCCC",
  skip_existing = get_skip_existing(),
  snapshot_dim = 800,
  delay = 2,
  max_retries = 2
) {
  if (skip_existing && file.exists(outfile)) {
    return(invisible(NULL))
  }

  hemi_long <- hemi_to_long(hemisphere)

  take_snapshot <- function() {
    ggseg3d(
      .data = .data,
      atlas = atlas,
      hemisphere = hemi_long,
      surface = surface,
      colour = colour,
      na_colour = na_colour
    ) |>
      set_flat_shading() |>
      set_orthographic() |>
      pan_camera(paste(hemi_long, view)) |>
      set_background("white") |>
      set_legend(show = FALSE) |>
      snapshot_brain(
        outfile,
        width = snapshot_dim,
        height = snapshot_dim,
        delay = delay
      )
  }

  for (attempt in seq_len(max_retries + 1L)) {
    result <- tryCatch(take_snapshot(), error = function(e) e)
    if (!inherits(result, "error")) {
      break
    }
    if (attempt <= max_retries) {
      try(chromote::default_chromote_object()$close(), silent = TRUE)
      Sys.sleep(2)
    } else {
      stop(result)
    }
  }

  invisible(outfile)
}


# Batch snapshot engine ----

#' @noRd
snapshot_widget_batch <- function(
  widget,
  views,
  files,
  width = 800,
  height = 800,
  zoom = 2,
  delay = 1,
  render_delay = 0.3,
  max_retries = 2
) {
  rlang::check_installed("chromote", reason = "for browser-based screenshots")
  rlang::check_installed("htmlwidgets", reason = "for saving widget HTML")

  tmphtml <- tempfile(fileext = ".html")
  libdir <- paste0(tools::file_path_sans_ext(tmphtml), "_files")
  on.exit(unlink(c(tmphtml, libdir), recursive = TRUE), add = TRUE)

  htmlwidgets::saveWidget(widget, tmphtml, selfcontained = FALSE)

  for (attempt in seq_len(max_retries + 1L)) {
    result <- tryCatch(
      snapshot_widget_session(
        tmphtml = tmphtml,
        views = views,
        files = files,
        width = width,
        height = height,
        zoom = zoom,
        delay = delay,
        render_delay = render_delay
      ),
      error = function(e) e
    )
    if (!inherits(result, "error")) {
      break
    }
    if (attempt <= max_retries) {
      try(chromote::default_chromote_object()$close(), silent = TRUE)
      Sys.sleep(2)
    } else {
      stop(result)
    }
  }

  invisible(files)
}


#' Screenshot every view of a saved widget in one chromote session
#' @noRd
snapshot_widget_session <- function(
  tmphtml,
  views,
  files,
  width,
  height,
  zoom,
  delay,
  render_delay
) {
  session <- chromote::ChromoteSession$new()
  on.exit(session$close(), add = TRUE)

  session$Emulation$setDeviceMetricsOverride(
    width = as.integer(width),
    height = as.integer(height),
    deviceScaleFactor = 1,
    mobile = FALSE
  )
  session$Emulation$setScrollbarsHidden(hidden = TRUE)

  session$Page$navigate(url = paste0("file://", tmphtml))
  session$Page$loadEventFired()
  Sys.sleep(delay)

  js_tpl <- paste0(
    "document.querySelector('.ggseg3d.html-widget')",
    "._ggseg3d_renderer.setCamera('%s')"
  )

  for (i in seq_along(views)) {
    session$Runtime$evaluate(sprintf(js_tpl, views[i]))
    Sys.sleep(render_delay)
    session$screenshot(filename = files[i], scale = zoom)
  }

  session$Runtime$evaluate(
    paste0(
      "var el = document.querySelector('.ggseg3d.html-widget');",
      " if (el && el._ggseg3d_renderer) {",
      " cancelAnimationFrame(el._ggseg3d_renderer.animationId); }"
    )
  )
}


#' @noRd
build_brain_widget <- function(
  atlas,
  hemisphere,
  surface,
  .data = NULL,
  colour = "colour",
  na_colour = "#CCCCCC"
) {
  hemi_long <- hemi_to_long(hemisphere)

  ggseg3d(
    .data = .data,
    atlas = atlas,
    hemisphere = hemi_long,
    surface = surface,
    colour = colour,
    na_colour = na_colour
  ) |>
    set_flat_shading() |>
    set_orthographic() |>
    set_background("white") |>
    set_legend(show = FALSE)
}


#' @noRd
snapshot_brain_full_batch <- function(
  atlas,
  hemisphere,
  views,
  surface,
  output_dir,
  skip_existing = get_skip_existing(),
  snapshot_dim = 800
) {
  hemi_long <- hemi_to_long(hemisphere)
  files <- file.path(output_dir, sprintf("full_%s_%s.png", hemisphere, views))

  if (skip_existing) {
    needed <- !file.exists(files)
    if (!any(needed)) {
      return(invisible(files))
    }
    views <- views[needed]
    files <- files[needed]
  }

  widget <- build_brain_widget(
    atlas,
    hemisphere,
    surface,
    na_colour = "#CCCCCC"
  )

  snapshot_widget_batch(
    widget,
    views = paste(hemi_long, views),
    files = files,
    width = snapshot_dim,
    height = snapshot_dim
  )
}


#' @noRd
snapshot_region_batch <- function(
  atlas,
  region_label,
  hemisphere,
  views,
  surface,
  output_dir,
  skip_existing = get_skip_existing(),
  snapshot_dim = 800
) {
  hemi_long <- hemi_to_long(hemisphere)
  files <- file.path(
    output_dir,
    sprintf("%s_%s_%s.png", region_label, hemisphere, views)
  )

  if (skip_existing) {
    needed <- !file.exists(files)
    if (!any(needed)) {
      return(invisible(files))
    }
    views <- views[needed]
    files <- files[needed]
  }

  highlight_data <- data.frame(
    label = atlas$core$label,
    highlight = ifelse(atlas$core$label == region_label, "#FF0000", "#FFFFFF"),
    stringsAsFactors = FALSE
  )

  widget <- build_brain_widget(
    atlas,
    hemisphere,
    surface,
    .data = highlight_data,
    colour = "highlight",
    na_colour = "#FFFFFF"
  )

  snapshot_widget_batch(
    widget,
    views = paste(hemi_long, views),
    files = files,
    width = snapshot_dim,
    height = snapshot_dim
  )
}


#' @noRd
snapshot_na_regions_batch <- function(
  atlas,
  hemisphere,
  views,
  surface,
  output_dir,
  skip_existing = get_skip_existing(),
  snapshot_dim = 800
) {
  hemi_long <- hemi_to_long(hemisphere)
  files <- file.path(
    output_dir,
    sprintf("%s____nolabel____%s_%s.png", hemisphere, hemisphere, views)
  )

  if (skip_existing) {
    needed <- !file.exists(files)
    if (!any(needed)) {
      return(invisible(files))
    }
    views <- views[needed]
    files <- files[needed]
  }

  white_data <- data.frame(
    label = atlas$core$label,
    highlight = rep("#FFFFFF", nrow(atlas$core)),
    stringsAsFactors = FALSE
  )

  widget <- build_brain_widget(
    atlas,
    hemisphere,
    surface,
    .data = white_data,
    colour = "highlight",
    na_colour = "#FF0000"
  )

  snapshot_widget_batch(
    widget,
    views = paste(hemi_long, views),
    files = files,
    width = snapshot_dim,
    height = snapshot_dim
  )
}


#' Snapshot cortex slice for tract atlas
#'
#' Creates a PNG with filename format matching tract projections.
#'
#' @inheritParams snapshot_volume_slice
#' @param slice_view "axial", "sagittal", or "coronal"
#' @param view_name Name for this view (used in filename)
#' @param hemi Hemisphere ("left" or "right")
#'
#' @return Invisible path to output file, or NULL if no voxels
#' @keywords internal
#' @noRd
#' @importFrom grDevices png dev.off
#' @importFrom graphics par image
render_slice_png <- function(
  slice_data,
  outfile,
  colour = "red",
  width = 400,
  height = 400
) {
  if (is.null(slice_data)) {
    return(invisible(NULL))
  }

  slice_data[slice_data == 0] <- NA
  if (!any(is.finite(slice_data))) {
    return(invisible(NULL))
  }

  png(outfile, width = width, height = height, bg = "black")
  on.exit(dev.off(), add = TRUE)
  par(mar = c(0, 0, 0, 0))

  image(
    slice_data,
    col = colour,
    useRaster = TRUE,
    axes = FALSE,
    asp = 1
  )

  invisible(outfile)
}


snapshot_cortex_slice <- function(
  vol,
  x,
  y,
  z,
  slice_view,
  view_name,
  hemi,
  output_dir,
  width = 400,
  height = 400,
  skip_existing = get_skip_existing()
) {
  output_dir <- path.expand(output_dir)
  outfile <- file.path(output_dir, paste0(view_name, "_cortex_", hemi, ".png"))

  if (skip_existing && file.exists(outfile)) {
    return(invisible(outfile))
  }

  pos <- switch(slice_view, "axial" = z, "coronal" = y, "sagittal" = x)
  slice <- extract_slice_2d(vol, slice_view, pos, hemi = hemi)
  render_slice_png(slice, outfile, width = width, height = height)
}


#' Snapshot a partial volume projection
#'
#' Creates a PNG image showing maximum intensity projection of a volume subset.
#'
#' @inheritParams snapshot_volume_slice
#' @param start First slice index
#' @param end Last slice index
#' @param view_name Name for this view (used in filename)
#' @param hemi Hemisphere for sagittal views: "left" or "right"
#'
#' @return Invisible path to output file, or NULL if no voxels
#' @keywords internal
#' @noRd
snapshot_partial_projection <- function(
  vol,
  view,
  start,
  end,
  view_name,
  label,
  output_dir,
  colour = "red",
  hemi = NULL,
  width = 400,
  height = 400,
  skip_existing = get_skip_existing()
) {
  output_dir <- path.expand(output_dir)
  label <- sanitize_label(label)
  outfile <- file.path(output_dir, paste0(view_name, "_", label, ".png"))

  if (skip_existing && file.exists(outfile)) {
    return(invisible(outfile))
  }

  proj <- volume_projection(vol, view, start, end, hemi = hemi)
  render_slice_png(
    proj,
    outfile,
    colour = colour,
    width = width,
    height = height
  )
}
