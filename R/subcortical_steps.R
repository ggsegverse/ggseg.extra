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
      mesh <- subcort_mesh_one(
        input_volume,
        label_id,
        label_name,
        dirs,
        skip_existing,
        verbose
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

  meshes_list <- subcort_decimate_meshes(meshes_list, decimate, verbose)

  if (verbose) {
    cli::cli_alert_success("Created {length(meshes_list)} meshes")
  }

  meshes_list
}


#' Tessellate one label, warning and returning NULL when it fails
#' @noRd
subcort_mesh_one <- function(
  input_volume,
  label_id,
  label_name,
  dirs,
  skip_existing,
  verbose
) {
  tryCatch(
    tessellate_label(
      volume_file = input_volume,
      label_id = label_id,
      output_dir = dirs$meshes,
      verbose = verbose,
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
}


#' Decimate meshes to a proportion of their original face count
#' @noRd
subcort_decimate_meshes <- function(meshes_list, decimate, verbose) {
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
      # nolint next: object_usage_linter.
      pct <- if (orig_faces > 0) {
        round(new_faces / orig_faces * 100)
      } else {
        NA_integer_
      }
      cli::cli_alert_success(
        "Reduced from {orig_faces} to {new_faces} faces ({pct}%)"
      )
    }
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
  slabs,
  dirs,
  skip_existing
) {
  vol <- read_volume(input_volume)
  dims <- dim(vol)

  if (is.null(slabs)) {
    slabs <- default_subcortical_slabs(dims)
  }

  cortex_slices <- create_cortex_slices(slabs, dims)
  cortex_labels <- detect_cortex_labels(vol)

  subcort_snapshot_structures(vol, dims, colortable, slabs, dirs, skip_existing)

  cortex_vol <- subcort_cortex_volume(vol, dims, cortex_labels)

  # Cortex outline must use the same slice-range projection as structures,
  # otherwise structures (max-projected over start..end) appear larger than
  # the single-slice cortex silhouette and overflow the brain shape. For
  # sagittal cortex slices (hemisphere-specific, no start/end), keep the
  # single-slice rendering. Skip entirely if cortex_vol has no voxels
  # (consistent with how empty structures are skipped above).
  if (sum(cortex_vol) > 0) {
    subcort_snapshot_cortex(
      cortex_vol,
      cortex_slices,
      slabs,
      dirs,
      skip_existing
    )
  }

  list(slabs = slabs, cortex_slices = cortex_slices)
}


#' Snapshot every structure x view combination of a subcortical atlas
#' @noRd
subcort_snapshot_structures <- function(
  vol,
  dims,
  colortable,
  slabs,
  dirs,
  skip_existing
) {
  snapshot_grid <- expand.grid(
    struct_idx = seq_len(nrow(colortable)),
    view_idx = seq_len(nrow(slabs)),
    stringsAsFactors = FALSE
  )

  p <- progressor(steps = nrow(snapshot_grid))

  invisible(safe_future_pmap(
    subcort_snapshot_args(colortable, slabs, snapshot_grid),
    function(
      label_id,
      label_name,
      view_type,
      view_start,
      view_end,
      view_name
    ) {
      subcort_snapshot_one(
        vol = vol,
        dims = dims,
        dirs = dirs,
        skip_existing = skip_existing,
        label_id = label_id,
        label_name = label_name,
        view_type = view_type,
        view_start = view_start,
        view_end = view_end,
        view_name = view_name
      )
      p()
      NULL
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("dims", "vol", "dirs", "skip_existing", "p")
    )
  ))
}


#' Column vectors driving the structure x view snapshot grid
#' @noRd
subcort_snapshot_args <- function(colortable, slabs, snapshot_grid) {
  list(
    label_id = colortable$idx[snapshot_grid$struct_idx],
    label_name = colortable$label[snapshot_grid$struct_idx],
    view_type = slabs$type[snapshot_grid$view_idx],
    view_start = slabs$start[snapshot_grid$view_idx],
    view_end = slabs$end[snapshot_grid$view_idx],
    view_name = slabs$name[snapshot_grid$view_idx]
  )
}


#' Snapshot a single structure in a single view, skipping empty structures
#' @noRd
subcort_snapshot_one <- function(
  vol,
  dims,
  dirs,
  skip_existing,
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
  invisible(NULL)
}


#' Binary brain-outline volume: cortex plus cerebellum and brainstem
#' @noRd
subcort_cortex_volume <- function(vol, dims, cortex_labels) {
  cortex_vol <- array(0L, dim = dims)
  for (lbl in c(cortex_labels$left, cortex_labels$right)) {
    cortex_vol[vol == lbl] <- 1L
  }
  # Also include cerebellum and brainstem (FS labels 7,8,46,47 = cerebellum
  # WM/cortex per hemisphere; 16 = brain-stem). The "brain outline" context
  # must span the full brain extent — otherwise atlases that label
  # cerebellar regions (e.g. HOA-2) draw structures that extend below the
  # cerebrum-only outline, making the structures look oversized.
  for (lbl in c(7L, 8L, 46L, 47L, 16L)) {
    cortex_vol[vol == lbl] <- 1L
  }

  cortex_vol
}


#' Render the cortex reference outline for each cortex slice
#' @noRd
subcort_snapshot_cortex <- function(
  cortex_vol,
  cortex_slices,
  slabs,
  dirs,
  skip_existing
) {
  invisible(lapply(seq_len(nrow(cortex_slices)), function(i) {
    cs <- cortex_slices[i, ]
    hemi <- extract_hemi_from_view(cs$view, cs$name)
    matched_view <- slabs[slabs$name == cs$name, ]

    if (cs$view %in% c("axial", "coronal") && nrow(matched_view) == 1) {
      snapshot_partial_projection(
        vol = cortex_vol,
        view = cs$view,
        start = matched_view$start,
        end = matched_view$end,
        view_name = cs$name,
        label = paste0("cortex_", hemi),
        output_dir = dirs$snapshots,
        colour = "red",
        hemi = hemi,
        skip_existing = skip_existing
      )
    } else {
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
    }
  }))
}


#' Default subcortical atlas slab configuration
#'
#' Creates projection slabs calibrated for subcortical structures.
#' Uses anatomically-calibrated ranges based on typical aseg label positions.
#'
#' @param dims Volume dimensions (3-element vector)
#'
#' @return data.frame with columns: name, type, start, end
#' @keywords internal
#' @noRd
default_subcortical_slabs <- function(dims) {
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
