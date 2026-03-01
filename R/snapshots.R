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
extract_slice_2d <- function(vol, view, pos, hemi = NULL) {
  slice <- switch(
    view,
    "axial" = vol[, , pos, drop = TRUE],
    "coronal" = vol[, pos, , drop = TRUE],
    "sagittal" = vol[pos, , , drop = TRUE]
  )

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

  sub_vol <- switch(
    view,
    "axial" = vol[, , start:end, drop = FALSE],
    "coronal" = vol[, start:end, , drop = FALSE],
    "sagittal" = vol[start:end, , , drop = FALSE]
  )

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
orient_slice_2d <- function(slice, view, hemi = NULL) {
  if (view == "sagittal" && identical(hemi, "left")) {
    return(slice[rev(seq_len(nrow(slice))), ])
  }
  slice
}


#' Snapshot a volumetric slice
#'
#' Creates a PNG image of a single slice from a volumetric label file.
#' Supports MGZ and NIfTI formats.
#'
#' @param lab Path to volume file (.mgz, .nii, .nii.gz) or .label file.
#'   If a .label file is provided, label_file must also be provided.
#' @param x,y,z Slice coordinates
#' @param view View type: "axial", "sagittal", or "coronal"
#' @param label_file Path to volume file (required when lab is a .label file)
#' @param output_dir Output directory for PNG
#' @param skip_existing Skip if output file exists
#' @param width,height Image dimensions in pixels
#'
#' @return Invisible NULL
#' @importFrom grDevices png dev.off
#' @importFrom graphics par image
#' @keywords internal
snapshot_slice <- function(
  lab,
  x,
  y,
  z,
  view,
  label_file = NULL,
  output_dir,
  skip_existing = get_skip_existing(),
  width = 400,
  height = 400
) {
  coords <- sprintf(c(x, y, z), fmt = "%03d")
  vv <- paste0(strsplit(view, "")[[1]][1:5], collapse = "")
  lab_name <- tools::file_path_sans_ext(basename(lab))

  filenm <- paste0(
    paste(c(coords, vv), collapse = "_"),
    "_",
    lab_name,
    ".png"
  )

  outfile <- file.path(output_dir, filenm)

  if (file.exists(outfile) && skip_existing) {
    return(invisible(NULL))
  }

  if (grepl("\\.label$", lab)) {
    if (is.null(label_file)) {
      cli::cli_abort("label_file must be provided when lab is a .label file")
    }
    label_id <- as.numeric(gsub("[^0-9.]", "", lab_name))
    vol <- read_volume(label_file)
    vol[vol != label_id] <- 0
  } else {
    vol <- read_volume(lab)
  }

  pos <- switch(view, "axial" = z, "coronal" = y, "sagittal" = x)
  slice_data <- extract_slice_2d(vol, view, pos)
  render_slice_png(slice_data, outfile, width = width, height = height)
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
    if (!inherits(result, "error")) break
    if (attempt <= max_retries) {
      try(chromote::default_chromote_object()$close(), silent = TRUE)
      Sys.sleep(2)
    } else {
      stop(result)
    }
  }

  invisible(outfile)
}


#' Snapshot full brain with vertex coloring
#' @noRd
snapshot_brain_full <- function(
  atlas,
  hemisphere,
  view,
  surface,
  output_dir,
  skip_existing = get_skip_existing(),
  snapshot_dim = 800
) {
  outfile <- file.path(output_dir, sprintf("full_%s_%s.png", hemisphere, view))

  snapshot_brain_helper(
    atlas,
    hemisphere,
    view,
    surface,
    outfile,
    na_colour = "#CCCCCC",
    skip_existing = skip_existing,
    snapshot_dim = snapshot_dim
  )
}


#' Snapshot single region with vertex coloring
#' @noRd
snapshot_region <- function(
  atlas,
  region_label,
  hemisphere,
  view,
  surface,
  output_dir,
  skip_existing = get_skip_existing(),
  snapshot_dim = 800
) {
  outfile <- file.path(
    output_dir,
    sprintf("%s_%s_%s.png", region_label, hemisphere, view)
  )

  highlight_data <- data.frame(
    label = atlas$core$label,
    highlight = ifelse(atlas$core$label == region_label, "#FF0000", "#FFFFFF"),
    stringsAsFactors = FALSE
  )

  snapshot_brain_helper(
    atlas,
    hemisphere,
    view,
    surface,
    outfile,
    .data = highlight_data,
    colour = "highlight",
    na_colour = "#FFFFFF",
    skip_existing = skip_existing,
    snapshot_dim = snapshot_dim
  )
}


#' Snapshot NA (unlabeled) brain regions
#' @noRd
snapshot_na_regions <- function(
  atlas,
  hemisphere,
  view,
  surface,
  output_dir,
  skip_existing = get_skip_existing(),
  snapshot_dim = 800
) {
  outfile <- file.path(
    output_dir,
    sprintf("%s____nolabel____%s_%s.png", hemisphere, hemisphere, view)
  )

  white_data <- data.frame(
    label = atlas$core$label,
    highlight = rep("#FFFFFF", nrow(atlas$core)),
    stringsAsFactors = FALSE
  )

  snapshot_brain_helper(
    atlas,
    hemisphere,
    view,
    surface,
    outfile,
    .data = white_data,
    colour = "highlight",
    na_colour = "#FF0000",
    skip_existing = skip_existing,
    snapshot_dim = snapshot_dim
  )
}


# Batch snapshot engine ----

#' @importFrom chromote ChromoteSession default_chromote_object
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
  tmphtml <- tempfile(fileext = ".html")
  libdir <- paste0(tools::file_path_sans_ext(tmphtml), "_files")
  on.exit(unlink(c(tmphtml, libdir), recursive = TRUE), add = TRUE)

  htmlwidgets::saveWidget(widget, tmphtml, selfcontained = FALSE)

  take_batch <- function() {
    session <- ChromoteSession$new()
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

  for (attempt in seq_len(max_retries + 1L)) {
    result <- tryCatch(take_batch(), error = function(e) e)
    if (!inherits(result, "error")) break
    if (attempt <= max_retries) {
      try(default_chromote_object()$close(), silent = TRUE)
      Sys.sleep(2)
    } else {
      stop(result)
    }
  }

  invisible(files)
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
    if (!any(needed)) return(invisible(files))
    views <- views[needed]
    files <- files[needed]
  }

  widget <- build_brain_widget(
    atlas, hemisphere, surface, na_colour = "#CCCCCC"
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
    if (!any(needed)) return(invisible(files))
    views <- views[needed]
    files <- files[needed]
  }

  highlight_data <- data.frame(
    label = atlas$core$label,
    highlight = ifelse(atlas$core$label == region_label, "#FF0000", "#FFFFFF"),
    stringsAsFactors = FALSE
  )

  widget <- build_brain_widget(
    atlas, hemisphere, surface,
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
    if (!any(needed)) return(invisible(files))
    views <- views[needed]
    files <- files[needed]
  }

  white_data <- data.frame(
    label = atlas$core$label,
    highlight = rep("#FFFFFF", nrow(atlas$core)),
    stringsAsFactors = FALSE
  )

  widget <- build_brain_widget(
    atlas, hemisphere, surface,
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
#' @param vol 3D array with voxel values
#' @param x,y,z Slice coordinates
#' @param slice_view "axial", "sagittal", or "coronal"
#' @param view_name Name for this view (used in filename)
#' @param hemi Hemisphere ("left" or "right")
#' @param output_dir Output directory
#' @param width,height Image dimensions
#' @param skip_existing If TRUE, skip if output file already exists
#'
#' @return Invisible path to output file, or NULL if no voxels
#' @keywords internal
#' Render a 2D matrix to PNG
#'
#' Shared rendering logic for all volumetric snapshot functions.
#' Writes a matrix as a single-colour image on a black background.
#'
#' @param slice_data 2D numeric matrix (zeros treated as transparent)
#' @param outfile Output PNG path
#' @param colour Colour for non-zero values
#' @param width,height Image dimensions in pixels
#' @return Invisible outfile path, or NULL if slice has no data
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
  if (is.null(slice_data)) return(invisible(NULL))

  slice_data[slice_data == 0] <- NA
  if (!any(is.finite(slice_data))) return(invisible(NULL))

  png(outfile, width = width, height = height, bg = "black")
  on.exit(dev.off())
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


#' Snapshot a volume slice
#'
#' Creates a PNG image of a volume at a specific slice position.
#'
#' @param vol 3D array with voxel values
#' @param x,y,z Slice coordinates
#' @param view "axial", "sagittal", or "coronal"
#' @param label Label for filename
#' @param output_dir Output directory
#' @param colour Colour for non-zero voxels
#' @param width,height Image dimensions
#' @param skip_existing If TRUE, skip if output file already exists
#'
#' @return Invisible path to output file, or NULL if no voxels in slice
#' @keywords internal
snapshot_volume_slice <- function(
  vol,
  x,
  y,
  z,
  view,
  label,
  output_dir,
  colour = "red",
  width = 400,
  height = 400,
  skip_existing = get_skip_existing()
) {
  output_dir <- path.expand(output_dir)
  coords <- sprintf(c(x, y, z), fmt = "%03d")
  vv <- paste0(strsplit(view, "")[[1]][1:5], collapse = "")

  outfile <- file.path(
    output_dir,
    paste0(paste(c(coords, vv), collapse = "_"), "_", label, ".png")
  )

  if (skip_existing && file.exists(outfile)) {
    return(invisible(outfile))
  }

  pos <- switch(view, "axial" = z, "coronal" = y, "sagittal" = x)
  slice <- extract_slice_2d(vol, view, pos)
  render_slice_png(
    slice, outfile, colour = colour, width = width, height = height
  )
}


#' Snapshot a partial volume projection
#'
#' Creates a PNG image showing maximum intensity projection of a volume subset.
#'
#' @param vol 3D array with voxel values
#' @param view "axial", "coronal", or "sagittal"
#' @param start First slice index
#' @param end Last slice index
#' @param view_name Name for this view (used in filename)
#' @param label Label for filename
#' @param output_dir Output directory
#' @param colour Colour for non-zero voxels
#' @param hemi Hemisphere for sagittal views: "left" or "right"
#' @param width,height Image dimensions
#' @param skip_existing If TRUE, skip if output file already exists
#'
#' @return Invisible path to output file, or NULL if no voxels
#' @keywords internal
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
    proj, outfile, colour = colour, width = width, height = height
  )
}
