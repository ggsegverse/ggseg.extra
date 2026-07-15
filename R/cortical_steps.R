# Cortical step functions ----

# Camera positions from ggseg3d::camera_preset_to_position
# Each vector is the camera position; it looks at the origin.
camera_presets <- list(
  lh_lateral = c(-350, 0, 0),
  lh_medial = c(350, 0, 0),
  lh_superior = c(-120, 0, 330),
  lh_inferior = c(-120, 0, -330),
  rh_lateral = c(350, 0, 0),
  rh_medial = c(-350, 0, 0),
  rh_superior = c(120, 0, 330),
  rh_inferior = c(120, 0, -330)
)


# Label atlas step functions ----

#' @noRd
labels_read_files <- function(
  label_files,
  region_names,
  colours,
  default_colours
) {
  p <- progressor(steps = length(label_files))

  all_data <- safe_future_pmap(
    list(
      label_file = label_files,
      i = seq_along(label_files)
    ),
    function(label_file, i) {
      filename <- basename(label_file)

      hemi_short <- if (grepl("^lh\\.", filename)) {
        "lh"
      } else if (grepl("^rh\\.", filename)) {
        "rh"
      } else {
        NA
      }
      hemi <- if (!is.na(hemi_short)) hemi_to_long(hemi_short) else NA

      region <- if (is.null(region_names)) {
        gsub("^[lr]h\\.", "", file_path_sans_ext(filename))
      } else {
        region_names[i]
      }

      label <- if (!is.na(hemi_short)) {
        paste(hemi_short, region, sep = "_")
      } else {
        region
      }
      colour <- if (is.null(colours)) default_colours[i] else colours[i]

      p()
      tibble(
        hemi = hemi,
        region = region,
        label = label,
        colour = colour,
        vertices = list(read_label_vertices(label_file))
      )
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("region_names", "colours", "default_colours", "p")
    )
  )

  bind_rows(all_data)
}
