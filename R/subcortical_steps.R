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
    slabs <- default_subcortical_slabs(vol, labels = colortable$idx)
  }

  cortex_slices <- create_cortex_slices(slabs, dims, vol = vol)
  cortex_labels <- detect_cortex_labels(vol)

  subcort_snapshot_structures(vol, dims, colortable, slabs, dirs, skip_existing)

  cortex_vol <- subcort_cortex_volume(vol, dims, cortex_labels)

  # The context silhouette is one slice, never a projection. Projecting it
  # through the slab unions every sulcus the slab passes through, which fills
  # them in and leaves a smooth blob instead of a brain; a single slice keeps
  # the gyri. cortex_slice_for_slab() already picks the slice - the densest
  # cortex slice within the slab - for every view type. Skip entirely if
  # cortex_vol has no voxels (consistent with how empty structures are
  # skipped above).
  if (sum(cortex_vol) > 0) {
    subcort_snapshot_cortex(
      cortex_vol,
      cortex_slices,
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
  dirs,
  skip_existing
) {
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
}


#' Default subcortical atlas slab configuration
#'
#' Frames the projection slabs on the bounding box of the structures the
#' atlas actually draws, so the band follows the anatomy of *this* volume.
#'
#' This used to rescale slice indices calibrated on a 256^3 1 mm conformed
#' volume by the ratio `dims[1] / 256`. A dimension ratio carries neither
#' voxel size nor origin, and the x dimension was used to scale y and z, so
#' on a 4 mm atlas volume the axial band landed roughly 30 mm too superior
#' -- above the subcortex entirely -- while on 1.5 mm volumes the inferior
#' 40 mm of the atlas was never cut. A bounding box needs no affine and no
#' assumption about which anatomy a subcortical atlas covers, which is what
#' the hand-written slab calls in the ggsegHO build scripts already do.
#'
#' @param vol Label volume in the builder's frame (3D integer array).
#' @param labels Integer label ids to frame the slabs on. Defaults to every
#'   non-zero label in `vol`. Cortical context labels are dropped either way.
#'
#' @return data.frame with columns: name, type, start, end
#' @keywords internal
#' @noRd
default_subcortical_slabs <- function(vol, labels = NULL) {
  labels <- subcort_slab_labels(vol, labels)

  slabs <- subcortical_slabs(
    vol,
    labels = labels,
    coronal = 3,
    axial = 3
  )
  slabs <- rbind(slabs, sagittal_hemi_slab(vol, labels))

  drop_empty_slabs(slabs, vol, labels)
}


#' Labels a default slab band may be framed on
#'
#' The cortical context labels are excluded deliberately: the whole-brain
#' pipeline remaps each cortical hemisphere to FreeSurfer index 3 or 42, and
#' those two labels span the entire brain, so a bounding box that includes
#' them is the whole brain rather than the subcortex. `detect_cortex_labels()`
#' is the same source `subcort_cortex_volume()` uses, so the labels drawn as
#' the grey reference outline are exactly the ones that cannot frame a slab.
#' @noRd
subcort_slab_labels <- function(vol, labels = NULL) {
  present <- setdiff(unique(as.vector(vol)), 0L)
  cortex <- unlist(detect_cortex_labels(vol), use.names = FALSE)
  labels <- setdiff(intersect(labels %||% present, present), cortex)

  if (length(labels) == 0) {
    cli::cli_abort("No subcortical labels found in the volume.")
  }
  labels
}


#' Sagittal slab covering one hemisphere only
#'
#' A sagittal slab spanning the whole head flattens both hemispheres onto one
#' panel, drawing every left structure underneath its right twin. The slab is
#' therefore clipped at the midline -- estimated as the centre of the label
#' bounding box, which is symmetric about it -- and kept on the low-x side,
#' which is the left hemisphere in the builder's RAS frame.
#' @noRd
sagittal_hemi_slab <- function(vol, labels) {
  idx <- which(
    array(as.vector(vol) %in% labels, dim = dim(vol)),
    arr.ind = TRUE
  )
  x <- range(idx[, 1])
  mid <- round(mean(x))

  data.frame(
    name = "sagittal_left",
    type = "sagittal",
    start = x[1],
    end = max(mid, x[1]),
    stringsAsFactors = FALSE
  )
}


#' Drop slabs that no labelled voxel falls into
#'
#' Tiling a bounding box can still leave a panel blank when the structures
#' are sparse along an axis; an empty panel is worse than one fewer panel.
#' @noRd
drop_empty_slabs <- function(slabs, vol, labels) {
  mask <- array(as.vector(vol) %in% labels, dim = dim(vol))
  filled <- list(
    sagittal = apply(mask, 1L, any),
    coronal = apply(mask, 2L, any),
    axial = apply(mask, 3L, any)
  )

  keep <- vapply(
    seq_len(nrow(slabs)),
    function(i) {
      rng <- seq(slabs$start[i], slabs$end[i])
      any(filled[[slabs$type[i]]][rng])
    },
    logical(1)
  )

  out <- slabs[keep, , drop = FALSE]
  if (nrow(out) == 0) {
    cli::cli_abort("Every default slab came out empty.")
  }
  rownames(out) <- NULL
  out
}
