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
      region = label_to_region(label_name),
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

  manifest <- read_snapshot_manifest(dirs$snapshots)
  signatures <- subcort_snapshot_structures(
    vol,
    dims,
    colortable,
    slabs,
    dirs,
    skip_existing,
    manifest
  )

  cortex_vol <- subcort_cortex_volume(vol, dims, cortex_labels)

  # The context silhouette is one slice, never a projection. Projecting it
  # through the slab unions every sulcus the slab passes through, which fills
  # them in and leaves a smooth blob instead of a brain; a single slice keeps
  # the gyri. cortex_slice_for_slab() already picks the slice - the densest
  # cortex slice within the slab - for every view type. Skip entirely if
  # cortex_vol has no voxels (consistent with how empty structures are
  # skipped above).
  if (sum(cortex_vol) > 0) {
    signatures <- c(
      signatures,
      subcort_snapshot_cortex(
        cortex_vol,
        cortex_slices,
        dirs,
        skip_existing,
        manifest
      )
    )
  }

  # Written once, from the main thread, after every pass that draws.
  record_snapshot_signatures(
    dirs$snapshots,
    signatures[file.exists(fs::path(dirs$snapshots, names(signatures)))]
  )

  list(slabs = slabs, cortex_slices = cortex_slices)
}


#' Every snapshot filename this run can produce
#'
#' A structure with no voxels in a slab is skipped rather than drawn, so this
#' is a superset of what actually appears. It is used to tell this run's
#' output from an earlier one's, which only needs the superset.
#' @noRd
subcort_snapshot_names <- function(colortable, slabs, cortex_slices = NULL) {
  grid <- expand.grid(
    label = colortable$label,
    view = slabs$name,
    stringsAsFactors = FALSE
  )
  structures <- projection_name(grid$view, sanitize_label(grid$label))

  if (is.null(cortex_slices)) {
    return(structures)
  }

  c(structures, cortex_snapshot_names(cortex_slices))
}


#' Delete snapshots, and the images made from them, that this run cannot draw
#'
#' The snapshot directory is read back whole - contour extraction traces
#' every projection it finds - so a file left behind by a run with different
#' slabs is silently assembled into the atlas. It carries a view name the
#' current configuration does not know, which lands in the atlas as a row with
#' no view and no geometry, and `st_coordinates()` then fails on the mix of
#' empty and non-empty geometries with "number of columns of matrices must
#' match". Nothing downstream can tell those files from this run's, so they
#' are cleared here, where the configuration that names them is known.
#' @noRd
prune_stale_snapshots <- function(dirs, expected, verbose = TRUE) {
  stale <- unlist(lapply(
    dirs$snapshots,
    function(dir) {
      files <- list.files(dir, pattern = "\\.rda$")
      as.character(fs::path(dir, setdiff(files, expected)))
    }
  ))

  if (length(stale) == 0L) {
    return(invisible(character()))
  }

  unlink(stale)
  if (verbose) {
    cli::cli_alert_info(
      "Removed {length(stale)} image{?s} left by an earlier slab configuration"
    )
  }
  invisible(stale)
}


#' Snapshot every structure x view combination of a subcortical atlas
#'
#' Returns the signature of every snapshot the grid names, keyed by file
#' name, for the caller to record once the drawing is done. The signatures
#' are built here, in the main thread, so the workers only look theirs up.
#' @noRd
subcort_snapshot_structures <- function(
  vol,
  dims,
  colortable,
  slabs,
  dirs,
  skip_existing,
  manifest = character()
) {
  snapshot_grid <- expand.grid(
    struct_idx = seq_len(nrow(colortable)),
    view_idx = seq_len(nrow(slabs)),
    stringsAsFactors = FALSE
  )
  args <- subcort_snapshot_args(colortable, slabs, snapshot_grid)
  args$signature <- subcort_structure_signatures(
    vol,
    dims,
    colortable,
    slabs,
    snapshot_grid
  )
  signatures <- stats::setNames(
    args$signature,
    projection_name(args$view_name, sanitize_label(args$label_name))
  )

  p <- progressor(steps = nrow(snapshot_grid))

  written <- safe_future_pmap(
    args,
    function(
      label_id,
      label_name,
      view_type,
      view_start,
      view_end,
      view_name,
      signature
    ) {
      outfile <- subcort_snapshot_one(
        vol = vol,
        dims = dims,
        dirs = dirs,
        skip_existing = skip_existing,
        label_id = label_id,
        label_name = label_name,
        view_type = view_type,
        view_start = view_start,
        view_end = view_end,
        view_name = view_name,
        signature = signature,
        manifest = manifest
      )
      p()
      outfile
    },
    .options = furrr_options(
      packages = "ggseg.extra",
      globals = c("dims", "vol", "dirs", "skip_existing", "manifest", "p")
    )
  )
  stamp_cache_files(written)

  signatures
}


#' Signature of each structure x view snapshot the grid names
#'
#' The voxels a label holds are hashed once per structure rather than once
#' per structure x view: what the snapshot depends on is the voxel set, not
#' the index that happens to name it this time round.
#' @noRd
subcort_structure_signatures <- function(
  vol,
  dims,
  colortable,
  slabs,
  snapshot_grid
) {
  voxels <- vapply(
    colortable$idx,
    function(idx) rlang::hash(which(vol == idx)),
    character(1)
  )

  vapply(
    seq_len(nrow(snapshot_grid)),
    function(i) {
      view <- slabs[snapshot_grid$view_idx[i], ]
      snapshot_signature(
        voxels[[snapshot_grid$struct_idx[i]]],
        dims,
        view$type,
        view$start,
        view$end,
        view$name
      )
    },
    character(1)
  )
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
#'
#' An existing snapshot is reused only when its recorded signature matches
#' what this run would draw. When it does not, the old projection is deleted
#' before the redraw, so a structure that renders nothing this time leaves no
#' file standing in for a picture this run would not draw.
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
  view_name,
  manifest = character(),
  signature = NULL
) {
  outfile <- structure_snapshot_file(dirs$snapshots, view_name, label_name)
  if (snapshot_is_current(outfile, signature, manifest, skip_existing)) {
    return(invisible(NULL))
  }
  clear_stale_snapshot(outfile)

  structure_vol <- array(0L, dim = dims)
  structure_vol[vol == label_id] <- 1L

  if (sum(structure_vol) == 0) {
    return(invisible(NULL))
  }

  snapshot_partial_projection(
    vol = structure_vol,
    view = view_type,
    start = view_start,
    end = view_end,
    view_name = view_name,
    label = label_name,
    output_dir = dirs$snapshots,
    hemi = extract_hemi_from_view(view_type, view_name),
    skip_existing = FALSE
  )
}


#' Delete a snapshot before redrawing it
#'
#' A redraw does not always write: a structure with no voxels in the slab
#' renders nothing, and so does one whose projection is empty. Drawing over
#' the old file is therefore not enough - it would simply stay, and go on
#' standing in for a picture this run would not draw at all. That is how a
#' snapshot of the right cortical hemisphere, drawn when index 42 still meant
#' one, survived a rebuild as `axial_3_region_0042` and put a solid
#' hemisphere where an amygdala belongs. Clearing first makes an empty
#' redraw mean an absent snapshot, which is what it is.
#' @noRd
clear_stale_snapshot <- function(outfile) {
  unlink(outfile)
}


#' Path of a structure's snapshot in one view
#'
#' Defers to [projection_file()], which is the one place the spelling of a
#' projection on disk is decided.
#' @noRd
structure_snapshot_file <- function(output_dir, view_name, label) {
  projection_file(output_dir, view_name, sanitize_label(label))
}


#' The file names the cortex silhouette slices carry
#'
#' Stated once because two callers need the same answer and must not drift:
#' `prune_stale_snapshots()` deletes whatever this does not name, and
#' `subcort_snapshot_cortex()` keys its signatures by it.
#' @noRd
cortex_snapshot_names <- function(cortex_slices) {
  # Per row: extract_hemi_from_view() branches on a single view type and
  # returns NULL off the sagittal views, so it cannot take the columns whole.
  vapply(
    seq_len(nrow(cortex_slices)),
    function(i) {
      cs <- cortex_slices[i, ]
      projection_name(
        cs$name,
        cortex_slice_label(extract_hemi_from_view(cs$view, cs$name))
      )
    },
    character(1)
  )
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
#'
#' The silhouette is the snapshot whose content depends on how the pipeline
#' builds its context volume, so its signature hashes that volume's voxels
#' along with the slice taken through them. A snapshot whose signature does
#' not match is redrawn rather than aborted on - a handful of slices is
#' cheap.
#'
#' Returns the signatures keyed by file name, for the caller to record.
#' @noRd
subcort_snapshot_cortex <- function(
  cortex_vol,
  cortex_slices,
  dirs,
  skip_existing,
  manifest = character()
) {
  voxels <- rlang::hash(which(cortex_vol > 0))

  drawn <- lapply(
    seq_len(nrow(cortex_slices)),
    function(i) {
      cs <- cortex_slices[i, ]
      hemi <- extract_hemi_from_view(cs$view, cs$name)
      outfile <- cortex_slice_file(dirs$snapshots, cs$name, hemi)
      signature <- snapshot_signature(
        voxels,
        dim(cortex_vol),
        cs$x,
        cs$y,
        cs$z,
        cs$view,
        cs$name,
        hemi
      )

      written <- NULL
      if (!snapshot_is_current(outfile, signature, manifest, skip_existing)) {
        clear_stale_snapshot(outfile)
        written <- snapshot_cortex_slice(
          vol = cortex_vol,
          x = cs$x,
          y = cs$y,
          z = cs$z,
          slice_view = cs$view,
          view_name = cs$name,
          hemi = hemi,
          output_dir = dirs$snapshots,
          skip_existing = FALSE
        )
      }
      list(name = basename(outfile), signature = signature, written = written)
    }
  )

  # One stamp for the step, not one per slice: stamping rewrites the whole
  # directory manifest, which the structure pass has just filled.
  stamp_cache_files(lapply(drawn, `[[`, "written"))

  stats::setNames(
    vapply(drawn, `[[`, character(1), "signature"),
    vapply(drawn, `[[`, character(1), "name")
  )
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
