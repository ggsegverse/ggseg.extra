describe("tessellate_label", {
  it("creates mesh from volume label", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")

    vol <- read_volume(vol_file)
    labels <- unique(c(vol))
    labels <- labels[labels != 0]
    skip_if(length(labels) == 0, "No labels in test volume")

    output_dir <- tempdir()
    mesh <- tessellate_label(
      volume_file = vol_file,
      label_id = labels[1],
      output_dir = output_dir,
      verbose = FALSE
    )

    expect_type(mesh, "list")
    expect_true(all(c("vertices", "faces") %in% names(mesh)))
    expect_gt(nrow(mesh$vertices), 0)
    expect_gt(nrow(mesh$faces), 0)
  })
})


describe("decimate_mesh", {
  it("reduces face count by specified percent", {
    skip_if_not_installed("Rvcg")
    skip_if_not_installed("rgl")

    mesh <- list(
      vertices = data.frame(
        x = c(0, 1, 0, 0, 1, 1, 0, 1),
        y = c(0, 0, 1, 0, 1, 0, 1, 1),
        z = c(0, 0, 0, 1, 0, 1, 1, 1)
      ),
      faces = data.frame(
        i = c(1, 1, 1, 2, 2, 3, 3, 5, 4, 4, 6, 7),
        j = c(2, 3, 4, 5, 6, 5, 7, 7, 6, 7, 8, 8),
        k = c(3, 4, 2, 3, 4, 7, 4, 8, 8, 8, 5, 6)
      )
    )

    result <- decimate_mesh(mesh, percent = 0.5)

    expect_lte(nrow(result$faces), nrow(mesh$faces))
    expect_lte(nrow(result$vertices), nrow(mesh$vertices))
  })

  it("returns correct data.frame structure", {
    skip_if_not_installed("Rvcg")
    skip_if_not_installed("rgl")

    mesh <- list(
      vertices = data.frame(
        x = c(0, 1, 0, 0, 1, 1, 0, 1),
        y = c(0, 0, 1, 0, 1, 0, 1, 1),
        z = c(0, 0, 0, 1, 0, 1, 1, 1)
      ),
      faces = data.frame(
        i = c(1, 1, 1, 2, 2, 3, 3, 5, 4, 4, 6, 7),
        j = c(2, 3, 4, 5, 6, 5, 7, 7, 6, 7, 8, 8),
        k = c(3, 4, 2, 3, 4, 7, 4, 8, 8, 8, 5, 6)
      )
    )

    result <- decimate_mesh(mesh, percent = 0.75)

    expect_named(result$vertices, c("x", "y", "z"))
    expect_named(result$faces, c("i", "j", "k"))
    expect_true(all(result$faces$i >= 1))
    expect_true(all(result$faces$j >= 1))
    expect_true(all(result$faces$k >= 1))
    expect_lte(max(result$faces$i), nrow(result$vertices))
    expect_lte(max(result$faces$j), nrow(result$vertices))
    expect_lte(max(result$faces$k), nrow(result$vertices))
  })

  it("works on real aseg meshes", {
    skip_if_not_installed("Rvcg")
    skip_if_not_installed("rgl")

    mesh <- ggseg.formats::aseg()$data$meshes$mesh[[1]]

    result <- decimate_mesh(mesh, percent = 0.5)

    expect_lt(nrow(result$faces), nrow(mesh$faces))
    expect_lt(nrow(result$vertices), nrow(mesh$vertices))
  })
})


describe("generate_colortable_from_volume", {
  it("creates color table with correct structure", {
    skip_if_no_freesurfer()

    vol_file <- test_mgz_file()
    skip_if(!file.exists(vol_file), "Test volume file not found")

    result <- generate_colortable_from_volume(vol_file)

    expect_s3_class(result, "data.frame")
    expect_true(all(
      c("idx", "label", "R", "G", "B", "A", "roi", "color") %in%
        names(result)
    ))
    expect_gt(nrow(result), 0)
    expect_true(all(result$idx > 0))
    expect_true(all(grepl("^region_", result$label)))
  })

  it("generates colortable from mocked volume", {
    local_mocked_bindings(
      read_volume = function(f) {
        vol <- array(0L, dim = c(3, 3, 3))
        vol[1, 1, 1] <- 10L
        vol[2, 2, 2] <- 20L
        vol
      }
    )

    result <- generate_colortable_from_volume("fake_file.mgz")

    expect_s3_class(result, "data.frame")
    expect_identical(nrow(result), 2L)
    expect_identical(result$idx, c(10L, 20L))
    expect_identical(result$label, c("region_0010", "region_0020"))
    expect_true(all(is.na(result$color)))
  })
})


describe("tessellate_label", {
  it("returns cached result when smooth file exists", {
    tmp_dir <- withr::local_tempdir()
    smooth_file <- file.path(tmp_dir, "0010_smooth")

    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      read_fs_surface = function(f, verbose = 0L) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 1, j = 2, k = 3)
        )
      }
    )
    writeLines("placeholder", smooth_file)

    result <- tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = TRUE)
    expect_type(result, "list")
    expect_true("vertices" %in% names(result))
  })

  it("runs full pipeline when no cached files", {
    skip_if_not_installed("RNifti")
    tmp_dir <- withr::local_tempdir()

    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_pretess.mgz"))
      },
      mri_tessellate = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_tess"))
      },
      mri_smooth = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_smooth"))
      },
      read_fs_surface = function(f, verbose = 0L) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 1, j = 2, k = 3)
        )
      }
    )

    result <- tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = FALSE)
    expect_true("vertices" %in% names(result))
  })

  it("errors when pretess fails", {
    skip_if_not_installed("RNifti")
    tmp_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) NULL
    )

    expect_error(
      tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = FALSE),
      "Pre-tessellation failed"
    )
  })

  it("errors when tessellation fails", {
    skip_if_not_installed("RNifti")
    tmp_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_pretess.mgz"))
      },
      mri_tessellate = function(...) NULL
    )

    expect_error(
      tessellate_label("vol.mgz", 10, tmp_dir, skip_existing = FALSE),
      "Tessellation failed"
    )
  })

  it("falls back to unsmoothed mesh when smoothing fails", {
    skip_if_not_installed("RNifti")
    tmp_dir <- withr::local_tempdir()
    local_mocked_bindings(
      check_fs = function(abort = FALSE) invisible(TRUE),
      mri_pretess = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_pretess.mgz"))
      },
      mri_tessellate = function(...) {
        writeLines("ok", file.path(tmp_dir, "0010_tess"))
      },
      mri_smooth = function(...) stop("smooth failed"),
      read_fs_surface = function(file, ...) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 1L, j = 2L, k = 3L)
        )
      }
    )

    expect_warning(
      result <- tessellate_label(
        "vol.mgz",
        10,
        tmp_dir,
        skip_existing = FALSE
      ),
      "Smoothing failed.*using unsmoothed"
    )
    expect_type(result, "list")
    expect_true("vertices" %in% names(result))
  })
})


describe("read_fs_surface", {
  it("uses surf2asc and read_dpv when available", {
    local_mocked_bindings(
      surf2asc = function(file, dpv_file, ...) NULL,
      read_dpv = function(f) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 0:2, j = c(1L, 2L, 0L), k = c(2L, 0L, 1L))
        )
      },
      get_verbose = function() FALSE
    )

    result <- read_fs_surface("test_surface")
    expect_identical(result$vertices$x, 1:3)
    expect_identical(result$faces$i, 1:3)
  })

  local_fallback_surface <- function(faces, env = parent.frame()) {
    local_mocked_bindings(
      surf2asc = function(...) stop("mris_convert not found"),
      read_dpv = function(...) stop("no file"),
      get_verbose = function() FALSE,
      .env = env
    )
    local_mocked_bindings(
      read.fs.surface = function(file) {
        list(
          vertices = matrix(c(1, 2, 3, 4, 5, 6, 7, 8, 9), ncol = 3),
          faces = faces
        )
      },
      .package = "freesurferformats",
      .env = env
    )
  }

  it("falls back to freesurferformats when surf2asc fails", {
    local_fallback_surface(matrix(c(1, 2, 3), ncol = 3))

    result <- read_fs_surface("test_surface")
    expect_identical(result$vertices$x, c(1, 2, 3))
    expect_identical(result$faces$i, 1)
  })

  it("aborts when the fallback reader returns faces outside the vertex table", {
    local_fallback_surface(matrix(c(1, 2, 9), ncol = 3))

    err <- expect_error(
      read_fs_surface("test_surface"),
      "non-existent vertices"
    )
    expect_match(conditionMessage(err), "mris_convert not found")
  })

  it("aborts when the converted surface has faces outside the vertex table", {
    local_mocked_bindings(
      surf2asc = function(...) NULL,
      read_dpv = function(...) {
        list(
          vertices = data.frame(x = 1:3, y = 1:3, z = 1:3),
          faces = data.frame(i = 0L, j = 1L, k = 7L)
        )
      },
      get_verbose = function() FALSE
    )

    err <- expect_error(
      read_fs_surface("test_surface"),
      "non-existent vertices"
    )
    expect_no_match(conditionMessage(err), "mris_convert")
  })

  it("errors when surf2asc fails and freesurferformats unavailable", {
    local_mocked_bindings(
      surf2asc = function(...) stop("conversion failed"),
      read_dpv = function(...) stop("no file"),
      get_verbose = function() FALSE
    )

    orig_require <- base::requireNamespace
    local_mocked_bindings(
      requireNamespace = function(pkg, ...) {
        if (pkg == "freesurferformats") {
          return(FALSE)
        }
        orig_require(pkg, ...)
      },
      .package = "base"
    )

    expect_error(
      read_fs_surface("test_surface"),
      "Failed to read surface file"
    )
  })

  it("surfaces the underlying conversion error in the abort", {
    local_mocked_bindings(
      surf2asc = function(...) stop("bad QUAD header"),
      read_dpv = function(...) stop("no file"),
      get_verbose = function() FALSE
    )

    orig_require <- base::requireNamespace
    local_mocked_bindings(
      requireNamespace = function(pkg, ...) {
        if (pkg == "freesurferformats") {
          return(FALSE)
        }
        orig_require(pkg, ...)
      },
      .package = "base"
    )

    expect_error(
      read_fs_surface("test_surface"),
      "bad QUAD header"
    )
  })
})


describe("generate_colortable_from_volume", {
  it("generates colortable from volume labels", {
    local_mocked_bindings(
      read_volume = function(f, ...) {
        vol <- array(0L, dim = c(5, 5, 5))
        vol[1:2, , ] <- 10L
        vol[3:4, , ] <- 20L
        vol
      }
    )

    result <- generate_colortable_from_volume("test.mgz")
    expect_s3_class(result, "data.frame")
    expect_identical(result$idx, c(10L, 20L))
    expect_identical(result$label, c("region_0010", "region_0020"))
    expect_true(all(is.na(result$R)))
  })
})


describe("generate_region_palette", {
  it("returns no colours for non-positive n", {
    expect_identical(generate_region_palette(0), character(0))
    expect_identical(generate_region_palette(-3), character(0))
  })

  it("returns n distinct hex colours spread around the hue wheel", {
    pal <- generate_region_palette(5)
    expect_length(pal, 5)
    expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", pal)))
    expect_length(unique(pal), 5)
  })
})


describe("ensure_fs_compatible_nifti", {
  it("returns the input unchanged when the header cannot be read", {
    skip_if_not_installed("RNifti")
    expect_identical(
      ensure_fs_compatible_nifti("/no/such/volume.nii.gz", tempdir()),
      "/no/such/volume.nii.gz"
    )
  })

  it("returns the input unchanged for a FreeSurfer-compatible datatype", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(6, 6, 6))
    arr[2:4, 2:4, 2:4] <- 5L
    f <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), f, datatype = "int16")

    expect_identical(
      ensure_fs_compatible_nifti(f, withr::local_tempdir()),
      f
    )
  })

  it("converts an incompatible datatype to INT32 in output_dir", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(6, 6, 6))
    arr[2:4, 2:4, 2:4] <- 1000L
    f <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), f, datatype = "uint16")

    out_dir <- withr::local_tempdir()
    converted <- ensure_fs_compatible_nifti(f, out_dir)

    expect_false(identical(converted, f))
    expect_true(file.exists(converted))
    expect_match(basename(converted), "^_fs_compat_")
    # datatype 8 == NIfTI INT32, the FreeSurfer-compatible target
    expect_identical(
      as.integer(RNifti::niftiHeader(converted)$datatype),
      8L
    )
  })

  it("reuses a previously converted file without rewriting it", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(6, 6, 6))
    arr[2:4, 2:4, 2:4] <- 1000L
    f <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), f, datatype = "uint16")

    out_dir <- withr::local_tempdir()
    first <- ensure_fs_compatible_nifti(f, out_dir)
    writeLines("sentinel", first)

    second <- ensure_fs_compatible_nifti(f, out_dir)
    expect_identical(second, first)
    expect_identical(readLines(second, warn = FALSE)[1], "sentinel")
  })
})


describe("tessellate_remap_label", {
  it("passes the volume through unchanged for labels <= 255", {
    res <- tessellate_remap_label("vol.nii.gz", 17L, "base", TRUE)
    expect_identical(res$pretess_input, "vol.nii.gz")
    expect_identical(res$tess_label, 17L)
  })

  it("remaps a label > 255 to a 0/1 mask with tessellation label 1", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(6, 6, 6))
    arr[2:4, 2:4, 2:4] <- 1000L
    arr[1, 1, 1] <- 5L
    f <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), f)

    res <- tessellate_remap_label(f, 1000L, withr::local_tempfile(), FALSE)

    expect_identical(res$tess_label, 1L)
    expect_true(file.exists(res$pretess_input))
    mask <- as.array(RNifti::readNifti(res$pretess_input))
    expect_setequal(unique(c(mask)), c(0, 1))
    # only the 3x3x3 block of label 1000
    expect_identical(as.integer(sum(mask)), 27L)
  })

  it("reuses an existing remapped file when skip_existing", {
    skip_if_not_installed("RNifti")
    arr <- array(0L, dim = c(6, 6, 6))
    arr[2:4, 2:4, 2:4] <- 1000L
    f <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(RNifti::asNifti(arr), f)

    base <- withr::local_tempfile()
    remap_file <- paste0(base, "_remap.nii.gz")
    writeLines("sentinel", remap_file)

    res <- tessellate_remap_label(f, 1000L, base, TRUE)

    expect_identical(res$pretess_input, remap_file)
    expect_identical(res$tess_label, 1L)
    expect_identical(readLines(remap_file, warn = FALSE)[1], "sentinel")
  })
})


describe("tessellate_smooth_mesh", {
  it("keeps the FreeSurfer failure attached to the fallback warning", {
    local_mocked_bindings(
      mri_smooth = function(...) {
        cli::cli_abort("FreeSurfer command failed (exit 1).")
      }
    )

    tmp <- withr::local_tempdir()
    warning <- expect_warning(
      tessellate_smooth_mesh(
        tess_file = file.path(tmp, "label.tess"),
        smooth_file = file.path(tmp, "label.smooth"),
        label_id = 17L,
        skip_existing = FALSE,
        verbose = FALSE
      ),
      "Smoothing failed for label 17"
    )
    expect_match(conditionMessage(warning), "FreeSurfer command failed")
  })
})


describe("tessellate_remap_label", {
  a_volume <- function(label_id) {
    arr <- array(0L, dim = c(12L, 12L, 12L))
    arr[4:8, 4:8, 4:8] <- label_id
    arr
  }
  affine <- function() {
    matrix(
      c(-1, 0, 0, 6, 0, 0, 1, -7, 0, -1, 0, 8, 0, 0, 0, 1),
      nrow = 4,
      byrow = TRUE
    )
  }

  it("leaves a label at or below 255 to be tessellated in place", {
    # Nothing is written: mri_tessellate takes the label value directly, and
    # both formats are already readable by it.
    result <- tessellate_remap_label("aseg.mgz", 17L, "base", FALSE)

    expect_identical(result$pretess_input, "aseg.mgz")
    expect_identical(result$tess_label, 17L)
  })

  it("isolates an above-255 label from a NIfTI as a NIfTI", {
    dir <- withr::local_tempdir()
    vol <- file.path(dir, "v.nii.gz")
    RNifti::writeNifti(RNifti::asNifti(a_volume(8203L)), vol)

    result <- tessellate_remap_label(vol, 8203L, file.path(dir, "b"), FALSE)

    expect_identical(result$tess_label, 1L)
    expect_match(result$pretess_input, "\\.nii\\.gz$")
    expect_identical(
      sum(
        as.array(RNifti::readNifti(
          result$pretess_input
        )) ==
          1L
      ),
      125L
    )
  })

  it("isolates an above-255 label from an MGZ as an MGZ", {
    # RNifti cannot read .mgz, so this used to throw and the structure
    # vanished from the atlas. .mgz is a documented input, and FreeSurfer
    # thalamic nuclei and hippocampal subfields all use ids above 255.
    skip_if_not_installed("freesurferformats")
    dir <- withr::local_tempdir()
    vol <- file.path(dir, "v.mgz")
    freesurferformats::write.fs.mgh(
      vol,
      a_volume(8203L),
      vox2ras_matrix = affine()
    )

    result <- tessellate_remap_label(vol, 8203L, file.path(dir, "b"), FALSE)

    expect_identical(result$tess_label, 1L)
    expect_match(result$pretess_input, "\\.mgz$")

    back <- freesurferformats::read.fs.mgh(
      result$pretess_input,
      with_header = TRUE
    )
    expect_identical(sum(drop(back$data) == 1L), 125L)
  })

  it("keeps the affine, so the mesh is tessellated where the label is", {
    # Reading through read_volume() would hand back a bare array for .mgz,
    # leaving asNifti() no header to inherit: the mask would be written with a
    # default affine and the structure would move.
    skip_if_not_installed("freesurferformats")
    dir <- withr::local_tempdir()
    vol <- file.path(dir, "v.mgz")
    freesurferformats::write.fs.mgh(
      vol,
      a_volume(8203L),
      vox2ras_matrix = affine()
    )

    result <- tessellate_remap_label(vol, 8203L, file.path(dir, "b"), FALSE)
    back <- freesurferformats::read.fs.mgh(
      result$pretess_input,
      with_header = TRUE
    )

    expect_equal(
      freesurferformats::mghheader.vox2ras(back$header),
      affine(),
      tolerance = 1e-6
    )
  })

  it("reuses an isolated label it already wrote when skip_existing", {
    skip_if_not_installed("freesurferformats")
    dir <- withr::local_tempdir()
    vol <- file.path(dir, "v.mgz")
    freesurferformats::write.fs.mgh(vol, a_volume(8203L))

    first <- tessellate_remap_label(vol, 8203L, file.path(dir, "b"), TRUE)
    mtime <- file.info(first$pretess_input)$mtime
    second <- tessellate_remap_label(vol, 8203L, file.path(dir, "b"), TRUE)

    expect_identical(second$pretess_input, first$pretess_input)
    expect_identical(file.info(second$pretess_input)$mtime, mtime)
  })
})
