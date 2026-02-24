# Subcortical step functions ----

#' @noRd
subcort_create_meshes <- function(
  input_volume,
  colortable,
  dirs,
  skip_existing,
  verbose,
  decimate = 0.5
) {
  p <- progressor(steps = nrow(colortable))

  meshes_list <- safe_future_map2(
    colortable$idx,
    colortable$label,
    function(label_id, label_name) {
      mesh <- tryCatch(
        tessellate_label(
          volume_file = input_volume,
          label_id = label_id,
          output_dir = dirs$meshes,
          verbose = get_verbose(), # nolint: object_usage_linter
          skip_existing = skip_existing
        ),
        error = function(e) {
          if (verbose) {
            cli::cli_warn(
              "Failed to create mesh for {label_name}: {e$message}"
            )
          }
          NULL
        }
      )
      p()
      mesh
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("input_volume", "dirs", "verbose", "skip_existing", "p")
    )
  )
  names(meshes_list) <- colortable$label
  meshes_list <- Filter(Negate(is.null), meshes_list)

  if (length(meshes_list) == 0) {
    cli::cli_abort("No meshes were successfully created")
  }

  meshes_list <- center_meshes(meshes_list)

  if (!is.null(decimate) && decimate < 1) {
    if (verbose) {
      orig_faces <- sum(vapply(
        meshes_list,
        function(m) nrow(m$faces),
        integer(1)
      ))
      cli::cli_alert_info(
        "Decimating meshes to {decimate * 100}% of original faces"
      )
    }
    meshes_list <- lapply(meshes_list, decimate_mesh, percent = decimate)
    if (verbose) {
      new_faces <- sum(vapply(
        meshes_list,
        function(m) nrow(m$faces),
        integer(1)
      ))
      # fmt: skip
      pct <- round(new_faces / orig_faces * 100) # nolint
      cli::cli_alert_success(
        "Reduced from {orig_faces} to {new_faces} faces ({pct}%)"
      )
    }
  }

  if (verbose) {
    cli::cli_alert_success("Created {length(meshes_list)} meshes")
  }

  meshes_list
}


#' @noRd
subcort_build_components <- function(colortable, meshes_list) {
  all_data <- lapply(names(meshes_list), function(label_name) {
    ct_row <- colortable[colortable$label == label_name, ]
    tibble(
      hemi = detect_hemi(label_name),
      region = clean_region_name(label_name),
      label = label_name,
      colour = ct_row$color[1],
      mesh = list(meshes_list[[label_name]])
    )
  })

  atlas_data <- bind_rows(all_data)
  build_atlas_components(atlas_data)
}


#' @noRd
subcort_create_snapshots <- function(
  input_volume,
  colortable,
  views,
  dirs,
  skip_existing
) {
  vol <- read_volume(input_volume)
  dims <- dim(vol)

  if (is.null(views)) {
    views <- default_subcortical_views(dims)
  }

  cortex_slices <- create_cortex_slices(views, dims)
  cortex_labels <- detect_cortex_labels(vol)

  snapshot_grid <- expand.grid(
    struct_idx = seq_len(nrow(colortable)),
    view_idx = seq_len(nrow(views)),
    stringsAsFactors = FALSE
  )

  p <- progressor(steps = nrow(snapshot_grid))

  invisible(safe_future_pmap(
    list(
      label_id = colortable$idx[snapshot_grid$struct_idx],
      label_name = colortable$label[snapshot_grid$struct_idx],
      view_type = views$type[snapshot_grid$view_idx],
      view_start = views$start[snapshot_grid$view_idx],
      view_end = views$end[snapshot_grid$view_idx],
      view_name = views$name[snapshot_grid$view_idx]
    ),
    function(
      label_id,
      label_name,
      view_type,
      view_start,
      view_end,
      view_name
    ) {
      structure_vol <- array(0L, dim = dims)
      structure_vol[vol == label_id] <- 1L

      if (sum(structure_vol) > 0) {
        hemi <- extract_hemi_from_view(view_type, view_name)
        snapshot_partial_projection(
          vol = structure_vol,
          view = view_type,
          start = view_start,
          end = view_end,
          view_name = view_name,
          label = label_name,
          output_dir = dirs$snapshots,
          colour = "red",
          hemi = hemi,
          skip_existing = skip_existing
        )
      }
      p()
      NULL
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("dims", "vol", "dirs", "skip_existing", "p")
    )
  ))

  cortex_vol <- array(0L, dim = dims)
  for (lbl in c(cortex_labels$left, cortex_labels$right)) {
    cortex_vol[vol == lbl] <- 1L
  }

  invisible(lapply(seq_len(nrow(cortex_slices)), function(i) {
    cs <- cortex_slices[i, ]
    hemi <- extract_hemi_from_view(cs$view, cs$name)
    snapshot_cortex_slice(
      vol = cortex_vol,
      x = cs$x,
      y = cs$y,
      z = cs$z,
      slice_view = cs$view,
      view_name = cs$name,
      hemi = hemi,
      output_dir = dirs$snapshots,
      skip_existing = skip_existing
    )
  }))

  list(views = views, cortex_slices = cortex_slices)
}


#' Default subcortical atlas view configuration
#'
#' Creates projection views calibrated for subcortical structures.
#' Uses anatomically-calibrated ranges based on typical aseg label positions.
#'
#' @param dims Volume dimensions (3-element vector)
#'
#' @return data.frame with columns: name, type, start, end
#' @keywords internal
default_subcortical_views <- function(dims) {
  mid_x <- dims[1] %/% 2
  chunk_size <- 10
  scale <- dims[1] / 256

  z_lo <- min(round(85 * scale), dims[3])
  z_hi <- min(round(152 * scale), dims[3])
  y_lo <- min(round(110 * scale), dims[2])
  y_hi <- min(round(154 * scale), dims[2])

  axial_views <- make_view_chunks(z_lo, z_hi, chunk_size, "axial")
  coronal_views <- make_view_chunks(y_lo, y_hi, chunk_size, "coronal")

  sagittal_views <- data.frame(
    name = "sagittal",
    type = "sagittal",
    start = mid_x,
    end = mid_x,
    stringsAsFactors = FALSE
  )

  rbind(axial_views, coronal_views, sagittal_views)
}
