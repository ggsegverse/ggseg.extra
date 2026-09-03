# Image processing ----

#' Process snapshot image for contour extraction
#'
#' Applies transparency and optional dilation to prepare image for
#' contour extraction.
#'
#' @param input_file Path to input image
#' @param output_file Path for output image
#' @param dilate Optional dilation iterations
#' @param transparent_color Color to make transparent (default "black")
#' @param fuzz Fuzz factor for transparency (default 10)
#' @param skip_existing If TRUE, skip if output file already exists
#' @noRd
process_snapshot_image <- function(
  input_file,
  output_file,
  dilate = NULL,
  transparent_color = "black",
  fuzz = 10,
  skip_existing = get_skip_existing()
) {
  rlang::check_installed("magick", reason = "for snapshot image processing")
  if (skip_existing && file.exists(output_file)) {
    return(invisible(output_file))
  }

  img <- magick::image_read(input_file) |>
    magick::image_convert() |>
    magick::image_transparent(color = transparent_color, fuzz = fuzz)

  if (!is.null(dilate) && dilate > 0) {
    img <- magick::image_morphology(
      img,
      method = "DilateI",
      kernel = "diamond",
      iterations = dilate
    )
  }

  magick::image_write(image = img, path = output_file)
  invisible(output_file)
}


#' Extract alpha channel from image using ImageMagick
#' @noRd
extract_alpha_mask <- function(
  input_file,
  output_file,
  skip_existing = get_skip_existing()
) {
  if (skip_existing && file.exists(output_file)) {
    return(invisible(output_file))
  }

  exit_code <- system2(
    "magick",
    args = c(
      shQuote(input_file),
      "-alpha",
      "extract",
      shQuote(output_file)
    ),
    stdout = FALSE,
    stderr = FALSE
  )
  if (exit_code != 0) {
    cli::cli_abort(
      "ImageMagick failed to extract alpha from {.path {input_file}}"
    )
  }
  invisible(output_file)
}


#' Process snapshots and extract alpha masks
#'
#' Runs `process_snapshot_image` on each PNG in `snap_dir`, then
#' `extract_alpha_mask` on each processed file to produce binary masks.
#'
#' @param snap_dir Directory containing raw snapshot PNGs
#' @param processed_dir Directory for processed (transparency) images
#' @param mask_dir Directory for alpha mask output
#' @param dilate Dilation iterations passed to `process_snapshot_image`
#' @param dilate_exclude Regular expression matching snapshots that must not
#'   be dilated. Defaults to the anatomical context silhouettes: dilation
#'   exists to keep small deep structures visible, and applied to the grey
#'   brain it closes the sulci and flattens the mantle.
#' @param skip_existing Skip files that already exist
#' @noRd
process_and_mask_images <- function(
  snap_dir,
  processed_dir,
  mask_dir,
  dilate = NULL,
  dilate_exclude = context_snapshot_pattern(),
  skip_existing = get_skip_existing()
) {
  files <- list.files(snap_dir, full.names = TRUE, pattern = "\\.png$")

  p <- progressor(steps = length(files))
  invisible(lapply(files, function(f) {
    is_context <- !is.null(dilate_exclude) &&
      grepl(dilate_exclude, basename(f))
    process_snapshot_image(
      input_file = f,
      output_file = as.character(fs::path(processed_dir, basename(f))),
      dilate = if (is_context) NULL else dilate,
      skip_existing = skip_existing
    )
    p()
  }))

  processed_files <- list.files(processed_dir, full.names = TRUE)
  invisible(lapply(processed_files, function(f) {
    extract_alpha_mask(
      f,
      as.character(fs::path(mask_dir, basename(f))),
      skip_existing = skip_existing
    )
  }))

  invisible(NULL)
}


# Contour loading ----

# Filename parsing ----

# ImageMagick utilities ----

#' @noRd
has_magick <- function() {
  k <- magick_version()
  any(grepl("Version: ImageMagick", k, fixed = TRUE))
}


#' @noRd
magick_version <- function() {
  tryCatch(
    system2("magick", "--version", stdout = TRUE, stderr = FALSE)[1],
    error = function(e) "",
    warning = function(w) ""
  )
}


# Command execution ----

#' @noRd
run_cmd <- function(cmd, verbose = get_verbose(), no_ui = FALSE) {
  # nolint: object_usage_linter
  # nocov start
  # Rewrites the command to launch the Freeview GUI headlessly via `open -g`
  # (macOS) or `fsxvfb` (Linux virtual framebuffer); neither can run under a
  # headless CI without a display, so this branch is excluded from coverage.
  if (no_ui) {
    if (Sys.info()["sysname"] == "Darwin") {
      fv_args <- sub("^freeview[[:space:]]*", "", cmd)
      cmd <- paste(
        "open -g -j -n -W",
        shQuote(as.character(fs::path(
          Sys.getenv("FREESURFER_HOME"),
          "Freeview.app"
        ))),
        "--args",
        fv_args
      )
    } else {
      cmd <- paste("fsxvfb", cmd)
    }
  }
  # nocov end
  full_cmd <- paste0(freesurfer::get_fs(), cmd)
  suppress <- verbose < 2
  exit_code <- system(
    paste("bash -c", shQuote(full_cmd)),
    ignore.stdout = suppress,
    ignore.stderr = suppress
  )
  if (exit_code != 0) {
    cli::cli_abort("FreeSurfer command failed (exit {exit_code}): {cmd}")
  }
  exit_code
}


# Contour extraction ----

#' @noRd
#' @importFrom sf st_as_sf st_is_empty st_geometry
get_contours <- function(
  raster_object,
  max_val = 255,
  vertex_size_limits = c(3 * 10^6, 3 * 10^7)
) {
  rlang::check_installed("terra", reason = "for contour extraction")
  mx <- terra::global(raster_object, fun = "max", na.rm = TRUE)[1, 1]

  if (is.na(mx) || mx < max_val) {
    return(NULL)
  }

  tmp_rst <- raster_object
  tmp_rst[tmp_rst == 0] <- NA

  contours_raw <- terra::as.polygons(tmp_rst, values = TRUE, na.rm = TRUE)

  coords <- st_as_sf(contours_raw)

  keep <- !st_is_empty(coords)
  if (nrow(coords) > 0 && any(keep)) {
    coords <- coords[keep, ]
    coords <- to_coords(coords, 1)
    coords <- coords2sf(coords, vertex_size_limits)

    return(coords)
  }
  NULL
}


# View generation utilities ----

#' Create chunked view ranges for projections
#'
#' Generates a data.frame of view specifications by dividing a range into
#' chunks. Used by both subcortical and tract atlas pipelines.
#'
#' @param lo Start of range
#' @param hi End of range
#' @param chunk_size Size of each chunk
#' @param type View type: "axial", "coronal", or "sagittal"
#'
#' @return data.frame with columns: name, type, start, end
#' @noRd
make_view_chunks <- function(lo, hi, chunk_size, type) {
  starts <- seq(lo, hi, by = chunk_size)
  ends <- pmin(starts + chunk_size - 1, hi)
  n <- length(starts)
  data.frame(
    name = paste0(type, "_", seq_len(n)),
    type = type,
    start = starts,
    end = ends,
    stringsAsFactors = FALSE
  )
}


#' Create cortex reference slices from slabs
#'
#' Generates cortex slice positions that match the slab specifications.
#' For sagittal slabs, uses hemisphere-appropriate x positions.
#' For axial/coronal slabs, uses the midpoint of the projection range.
#'
#' @param slabs data.frame with columns: name, type, start, end
#' @inheritParams default_subcortical_slabs
#' @param cortex_x X coordinate for non-hemisphere-specific sagittal slices
#'
#' @return data.frame with columns: x, y, z, view, name
#' @noRd
create_cortex_slices <- function(
  slabs,
  dims,
  cortex_x = NULL,
  vol = NULL
) {
  cortex_ids <- if (is.null(vol)) {
    NULL
  } else {
    unlist(detect_cortex_labels(vol), use.names = FALSE)
  }

  slices <- lapply(seq_len(nrow(slabs)), function(i) {
    cortex_slice_for_slab(slabs[i, ], dims, cortex_x, vol, cortex_ids)
  })
  do.call(rbind, slices)
}


#' Cortex reference slice for a single slab
#'
#' @param v One row of the slab data.frame.
#' @inheritParams create_cortex_slices
#' @param cortex_ids Cortical label values, or `NULL` to skip slice selection.
#' @return One-row data.frame with columns x, y, z, view, name.
#' @noRd
cortex_slice_for_slab <- function(v, dims, cortex_x, vol, cortex_ids) {
  mid_pos <- round((v$start + v$end) / 2)

  if (v$type == "sagittal") {
    return(data.frame(
      x = sagittal_cortex_x(v, dims, cortex_x, vol, cortex_ids, mid_pos),
      y = NA,
      z = NA,
      view = v$type,
      name = v$name,
      stringsAsFactors = FALSE
    ))
  }

  axis <- if (v$type == "coronal") 2L else 3L
  pos <- densest_cortex_slice(vol, cortex_ids, dims, axis, v$start, v$end) %||%
    mid_pos
  data.frame(
    x = NA,
    y = if (v$type == "coronal") pos else NA,
    z = if (v$type == "axial") pos else NA,
    view = v$type,
    name = v$name,
    stringsAsFactors = FALSE
  )
}


#' Resolve the x position of a sagittal cortex reference slice
#'
#' An explicit `cortex_x` wins; otherwise prefer the densest cortical slice,
#' then a hemisphere-appropriate plane for hemisphere-named views, and finally
#' the slab's own midpoint rather than a fixed plane, so a sagittal slab at an
#' explicit position gets its cortex reference from the same place -- axial and
#' coronal already do this.
#'
#' @inheritParams cortex_slice_for_slab
#' @param mid_pos Midpoint of the slab's range.
#' @return A single x index.
#' @noRd
sagittal_cortex_x <- function(v, dims, cortex_x, vol, cortex_ids, mid_pos) {
  if (!is.null(cortex_x)) {
    return(cortex_x)
  }
  thinnest <- thinnest_cortex_slice(vol, cortex_ids, dims, 1L, v$start, v$end)
  if (!is.null(thinnest)) {
    return(thinnest)
  }
  if (grepl("left", v$name, ignore.case = TRUE)) {
    return(round(dims[1] * 0.55))
  }
  if (grepl("right", v$name, ignore.case = TRUE)) {
    return(round(dims[1] * 0.45))
  }
  mid_pos
}


#' Index of the slice holding the most cortex within a slab
#'
#' Within a slab, take the slice holding the most cortex rather than the slab
#' midpoint. The silhouette is context, not a measurement, so it should be
#' chosen for legibility -- and a midpoint can land somewhere with almost
#' nothing to draw. A mid-sagittal slab centred exactly on the midline cuts
#' the interhemispheric fissure: cvs_avg35_inMNI152 has 797 cortical voxels
#' at x=128 against 6703 four voxels away, so the outline came out in
#' fragments while the structures in front of it were fine.
#'
#' @inheritParams cortex_slice_for_slab
#' @param axis Which array margin to slice along (1, 2 or 3).
#' @param from,to Slab bounds along `axis`.
#' @return The chosen index, or `NULL` when no cortex is present.
#' @noRd
densest_cortex_slice <- function(vol, cortex_ids, dims, axis, from, to) {
  if (is.null(cortex_ids) || !length(cortex_ids)) {
    return(NULL)
  }
  idx <- seq.int(max(1L, from), min(dims[axis], to))
  if (!length(idx)) {
    return(NULL)
  }
  counts <- vapply(
    idx,
    function(i) sum(slice_along_axis(vol, axis, i) %in% cortex_ids),
    numeric(1)
  )
  if (all(counts == 0)) {
    return(NULL)
  }
  # Break ties toward the slab midpoint, so a slab whose slices are equally
  # informative keeps the position it would have had anyway.
  best <- idx[counts == max(counts)]
  mid <- (from + to) / 2
  best[which.min(abs(best - mid))]
}


#' Extract one slice from a 3D array along a given axis
#' @noRd
slice_along_axis <- function(vol, axis, i) {
  if (axis == 1L) {
    return(vol[i, , ])
  }
  if (axis == 2L) {
    return(vol[, i, ])
  }
  # nolint next: commas_linter. air formats empty subscripts unspaced.
  vol[,, i]
}


#' Detect cortex labels from segmentation volume
#'
#' Auto-detects cortical voxel labels from a segmentation volume.
#' Handles both aparc+aseg (labels 1000-2999) and plain aseg (labels 3, 42).
#'
#' @param vol 3D array of segmentation labels
#'
#' @return Named list with "left" and "right" vectors of label values
#' @noRd
detect_cortex_labels <- function(vol) {
  vol_labels <- unique(as.vector(vol))
  has_aparc <- any(vol_labels >= 1000 & vol_labels < 3000)

  if (has_aparc) {
    list(
      left = intersect(1000:1999, vol_labels),
      right = intersect(2000:2999, vol_labels)
    )
  } else {
    list(left = 3, right = 42)
  }
}


#' Subcortical structures used as anatomical context
#'
#' The cortical ribbon alone leaves tracts that descend through the brainstem
#' or reach into deep grey hanging outside the silhouette, which reads as a
#' misalignment. These structures are added to the reference so those tracts
#' have context.
#'
#' White matter is deliberately excluded, both cerebral and cerebellar: tracts
#' live there, and filling it would bury them in grey. Excluding it also keeps
#' the cerebellum a foliated shell like the cerebral ribbon rather than a solid
#' mass, which otherwise merges with the occipital lobe in sagittal views.
#'
#' @param vol 3D array of segmentation labels
#'
#' @return Integer vector of label values present in `vol`
#' @noRd
detect_context_labels <- function(vol) {
  context <- c(
    16, # brainstem
    8,
    47, # cerebellar cortex (white matter excluded, as for the cerebrum)
    28,
    60, # ventral DC
    10,
    49, # thalamus
    11,
    50, # caudate
    12,
    51, # putamen
    13,
    52, # pallidum
    17,
    53, # hippocampus
    18,
    54, # amygdala
    26,
    58 # accumbens
  )
  intersect(context, unique(as.vector(vol)))
}


#' Extract hemisphere from sagittal view name
#'
#' Determines hemisphere from view name for sagittal projections.
#' Returns NULL for non-sagittal views.
#'
#' @param view_type View type: "axial", "coronal", or "sagittal"
#' @param view_name View name (e.g., "sagittal_left", "axial_3")
#'
#' @return "left", "right", or NULL
#' @noRd
extract_hemi_from_view <- function(view_type, view_name) {
  if (view_type != "sagittal") {
    return(NULL)
  }
  if (grepl("left", view_name, ignore.case = TRUE)) {
    "left"
  } else if (grepl("right", view_name, ignore.case = TRUE)) {
    "right"
  } else {
    NULL
  }
}


#' Snapshots that carry anatomical context rather than a structure
#'
#' The grey silhouettes: the `cortex_<hemi>` outline this pipeline renders,
#' and FreeSurfer's own cerebral cortex labels. Deliberately case-sensitive so
#' it does not catch a `Cerebellar_Cortex_*` parcel, which is a structure in
#' its own right in some atlases.
#' @noRd
context_snapshot_pattern <- function() {
  "(^|_)cortex_[a-z]*\\.png$|Cerebral-Cortex\\.png$"
}


#' The sagittal slice that cuts the cortex rather than skimming it
#'
#' Sagittal is the one view where picking the slice with the most cortex is
#' actively wrong. Cortex area peaks at both tangential extremes - the medial
#' wall near the midline, and the lateral surface - where the slice skims
#' along the sheet and returns a solid blob. A true cross-section, the one
#' that reads as a gyrified ribbon, is where the area is *lowest*.
#'
#' The ends of the slab are trimmed before taking the minimum, so the search
#' cannot fall off into the midline gap or past the lateral surface, where
#' the cortex thins out for the opposite reason.
#'
#' @param trim Fraction of the slab to drop from each end before searching.
#' @noRd
thinnest_cortex_slice <- function(
  vol,
  cortex_ids,
  dims,
  axis,
  from,
  to,
  trim = 0.2
) {
  if (is.null(cortex_ids) || !length(cortex_ids)) {
    return(NULL)
  }
  idx <- seq.int(max(1L, from), min(dims[axis], to))
  if (length(idx) < 3L) {
    return(NULL)
  }

  drop <- floor(trim * length(idx))
  inner <- idx[seq.int(drop + 1L, length(idx) - drop)]
  if (!length(inner)) {
    inner <- idx
  }

  counts <- vapply(
    inner,
    function(i) sum(slice_along_axis(vol, axis, i) %in% cortex_ids),
    numeric(1)
  )
  if (all(counts == 0)) {
    return(NULL)
  }

  inner[which.min(replace(counts, counts == 0, Inf))]
}
