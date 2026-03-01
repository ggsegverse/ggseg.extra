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
#' @importFrom magick image_read image_convert
#'   image_transparent image_morphology image_write
process_snapshot_image <- function(
  input_file,
  output_file,
  dilate = NULL,
  transparent_color = "black",
  fuzz = 10,
  skip_existing = get_skip_existing()
) {
  if (skip_existing && file.exists(output_file)) {
    return(invisible(output_file))
  }

  img <- image_read(input_file) |>
    image_convert() |>
    image_transparent(color = transparent_color, fuzz = fuzz)

  if (!is.null(dilate) && dilate > 0) {
    img <- image_morphology(
      img,
      method = "DilateI",
      kernel = "diamond",
      iterations = dilate
    )
  }

  image_write(image = img, path = output_file)
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
      shQuote(input_file), "-alpha", "extract", shQuote(output_file)
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
#' @param skip_existing Skip files that already exist
#' @noRd
process_and_mask_images <- function(
  snap_dir,
  processed_dir,
  mask_dir,
  dilate = NULL,
  skip_existing = get_skip_existing()
) {
  files <- list.files(snap_dir, full.names = TRUE, pattern = "\\.png$")

  p <- progressor(steps = length(files))
  invisible(lapply(files, function(f) {
    process_snapshot_image(
      input_file = f,
      output_file = file.path(processed_dir, basename(f)),
      dilate = dilate,
      skip_existing = skip_existing
    )
    p()
  }))

  processed_files <- list.files(processed_dir, full.names = TRUE)
  invisible(lapply(processed_files, function(f) {
    extract_alpha_mask(
      f,
      file.path(mask_dir, basename(f)),
      skip_existing = skip_existing
    )
  }))

  invisible(NULL)
}


# Contour loading ----

#' Load and parse reduced contours file
#'
#' Loads the contours_reduced.rda file, flips coordinates, and parses
#' filenames into view/hemi/label components.
#'
#' @param base_dir Directory containing contours_reduced.rda
#' @return sf object with view, hemi_short, hemi, label columns added
#' @noRd
load_reduced_contours <- function(base_dir) {
  load_rda(file.path(base_dir, "contours_reduced.rda"))
  contours <- terra::vect(contours) |>
    terra::flip() |>
    sf::st_as_sf()

  parsed <- parse_contour_filenames(contours$filenm)
  contours$view <- parsed$view
  contours$hemi_short <- parsed$hemi_short
  contours$hemi <- parsed$hemi
  contours$label <- parsed$label

  contours
}


# Filename parsing ----

#' Parse contour filename into components
#'
#' Extracts view, hemisphere, and label from standardized filename format.
#' Supports formats like: "label_hemi_view.png" or "coords_view_label.png"
#'
#' @param filenames Character vector of filenames (without path)
#' @return Data frame with label, hemi_short, hemi, view columns
#' @noRd
parse_contour_filenames <- function(filenames) {
  filenames_no_ext <- tools::file_path_sans_ext(filenames)
  fn_parts <- strsplit(filenames_no_ext, "_")
  too_short <- vapply(fn_parts, length, integer(1)) < 3
  if (any(too_short)) {
    cli::cli_abort(paste(
      "Contour filenames must have at least",
      "3 underscore-separated parts:",
      "{.val {filenames[too_short]}}"
    ))
  }

  result <- data.frame(
    filenm = filenames,
    view = vapply(fn_parts, function(x) x[length(x)], character(1)),
    hemi_short = vapply(fn_parts, function(x) x[length(x) - 1], character(1)),
    stringsAsFactors = FALSE
  )

  result$hemi <- ifelse(
    result$hemi_short == "lh",
    "left",
    ifelse(result$hemi_short == "rh", "right", result$hemi_short)
  )

  result$label <- vapply(
    fn_parts,
    function(x) {
      paste(x[1:(length(x) - 2)], collapse = "_")
    },
    character(1)
  )

  result
}


# ImageMagick utilities ----

#' @noRd
has_magick <- function() {
  k <- magick_version()
  any(grepl("Version: ImageMagick", k))
}

check_magick <- function() {
  k <- has_magick()
  if (!k) {
    cli::cli_abort(c(
      "ImageMagick not installed, cannot run pipeline.",
      "i" = "See {.url https://imagemagick.org/script/download.php}"
    ))
  }
}

#' @noRd
magick_version <- function() {
  tryCatch(
    system2("magick", "--version", stdout = TRUE)[1],
    error = function(e) "",
    warning = function(w) ""
  )
}


# Command execution ----

#' @noRd
run_cmd <- function(cmd, verbose = get_verbose(), no_ui = FALSE) {
  # nolint: object_usage_linter
  if (no_ui) {
    if (Sys.info()["sysname"] == "Darwin") {
      fv_args <- sub("^freeview[[:space:]]*", "", cmd)
      cmd <- paste(
        "open -g -j -n -W",
        shQuote(paste0(Sys.getenv("FREESURFER_HOME"), "/Freeview.app")),
        "--args",
        fv_args
      )
    } else {
      cmd <- paste("fsxvfb", cmd)
    }
  }
  full_cmd <- paste0(get_fs(), cmd)
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
#' @importFrom terra global rast as.polygons
#' @importFrom sf st_as_sf st_is_empty st_geometry
get_contours <- function(
  raster_object,
  max_val = 255,
  vertex_size_limits = c(3 * 10^6, 3 * 10^7),
  verbose = get_verbose() # nolint: object_usage_linter
) {
  mx <- global(raster_object, fun = "max", na.rm = TRUE)[1, 1]

  if (mx < max_val) {
    return(NULL)
  }

  tmp_rst <- raster_object
  tmp_rst[tmp_rst == 0] <- NA

  contours_raw <- as.polygons(tmp_rst, values = TRUE, na.rm = TRUE)

  coords <- st_as_sf(contours_raw)

  if (all(nrow(coords) > 0 & !st_is_empty(coords))) {
    coords <- to_coords(coords, 1)
    coords <- coords2sf(coords, vertex_size_limits)

    return(coords)
  }
  NULL
}


#' Isolate region to alpha channel
#'
#' @param input_file image file path
#' @param output_file output file path
#' @param interim_file interim image path
#' @param skip_existing If TRUE, skip if output file already exists
#' @noRd
#' @importFrom magick image_read image_convert image_transparent image_write
isolate_region <- function(
  input_file,
  output_file,
  interim_file = tempfile(),
  skip_existing = get_skip_existing()
) {
  if (skip_existing && file.exists(output_file)) {
    return(invisible(output_file))
  }

  tmp <- image_read(input_file)
  tmp <- image_convert(tmp, "png")

  tmp <- image_transparent(tmp, "white", fuzz = 30)
  image_write(tmp, interim_file)

  if (has_magick()) {
    system2(
      "magick",
      args = c(
        shQuote(interim_file), "-alpha", "extract", shQuote(output_file)
      ),
      stdout = FALSE,
      stderr = FALSE
    )
  } else {
    cli::cli_abort(paste(
      "Cannot complete last extraction step,",
      "missing imagemagick. Please install"
    ))
  }
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


#' Create cortex reference slices from views
#'
#' Generates cortex slice positions that match the view specifications.
#' For sagittal views, uses hemisphere-appropriate x positions.
#' For axial/coronal views, uses the midpoint of the projection range.
#'
#' @param views data.frame with columns: name, type, start, end
#' @param dims Volume dimensions (3-element vector)
#' @param cortex_x X coordinate for non-hemisphere-specific sagittal slices
#'
#' @return data.frame with columns: x, y, z, view, name
#' @noRd
create_cortex_slices <- function(views, dims, cortex_x = NULL) {
  if (is.null(cortex_x)) {
    scale <- dims[1] / 256
    cortex_x <- round(119 * scale)
  }

  slices <- lapply(seq_len(nrow(views)), function(i) {
    v <- views[i, ]

    if (v$type == "sagittal") {
      if (grepl("left", v$name, ignore.case = TRUE)) {
        x_pos <- round(dims[1] * 0.55)
      } else if (grepl("right", v$name, ignore.case = TRUE)) {
        x_pos <- round(dims[1] * 0.45)
      } else {
        x_pos <- cortex_x
      }
      data.frame(
        x = x_pos,
        y = NA,
        z = NA,
        view = v$type,
        name = v$name,
        stringsAsFactors = FALSE
      )
    } else {
      mid_pos <- round((v$start + v$end) / 2)
      data.frame(
        x = NA,
        y = if (v$type == "coronal") mid_pos else NA,
        z = if (v$type == "axial") mid_pos else NA,
        view = v$type,
        name = v$name,
        stringsAsFactors = FALSE
      )
    }
  })
  do.call(rbind, slices)
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
