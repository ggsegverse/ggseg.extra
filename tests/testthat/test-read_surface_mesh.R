flat_space <- function(hemi = "left") {
  ggseg.formats::mesh_space(
    vertex_space = "fsaverage5",
    hemi = hemi,
    anatomical = FALSE,
    surface = "inflated"
  )
}

fsaverage5_surface <- function(hemi = "lh", surface = "inflated") {
  home <- Sys.getenv("FREESURFER_HOME")
  skip_if(!nzchar(home), "FREESURFER_HOME not set")
  path <- file.path(
    home,
    "subjects",
    "fsaverage5",
    "surf",
    paste0(hemi, ".", surface)
  )
  skip_if(!file.exists(path), "fsaverage5 surfaces not available")
  path
}

describe("detect_surface_format()", {
  it("recognises GIFTI by extension", {
    expect_identical(detect_surface_format("tpl-SUIT_3d.surf.gii"), "gifti")
    expect_identical(detect_surface_format("x.gii"), "gifti")
    expect_identical(detect_surface_format("X.SURF.GII"), "gifti")
  })

  it("falls back to FreeSurfer, which carries no useful extension", {
    expect_identical(detect_surface_format("lh.inflated"), "freesurfer")
    expect_identical(detect_surface_format("rh.pial"), "freesurfer")
  })
})

describe("shift_face_base()", {
  faces <- data.frame(i = 1L, j = 2L, k = 3L)

  it("returns the same indices when the base already matches", {
    expect_identical(shift_face_base(faces, from = 1L, to = 1L), faces)
  })

  it("returns integers even when handed doubles", {
    # read_fs_surface() and freesurferformats both hand back doubles, and a
    # vertex number stored as a measurement compares equal to its own
    # rounding error rather than exactly.
    out <- shift_face_base(
      data.frame(i = 1, j = 2, k = 3),
      from = 1L,
      to = 0L
    )
    expect_type(out$i, "integer")
    expect_type(out$j, "integer")
    expect_type(out$k, "integer")
  })

  it("moves every column, not just the first", {
    out <- shift_face_base(faces, from = 1L, to = 0L)
    expect_identical(out, data.frame(i = 0L, j = 1L, k = 2L))
  })

  it("is reversible", {
    out <- shift_face_base(faces, from = 1L, to = 0L)
    expect_identical(shift_face_base(out, from = 0L, to = 1L), faces)
  })
})

describe("read_surface_mesh()", {
  it("reads a FreeSurfer surface into a self-describing mesh", {
    mesh <- read_surface_mesh(fsaverage5_surface(), space = flat_space())

    expect_identical(names(mesh), c("vertices", "faces"))
    expect_identical(nrow(mesh$vertices), 10242L)
    expect_s3_class(ggseg.formats::get_mesh_space(mesh), "mesh_space")
    expect_identical(
      ggseg.formats::get_mesh_space(mesh)$vertex_space,
      "fsaverage5"
    )
  })

  it("returns the face base asked for, not the one the file held", {
    path <- fsaverage5_surface()

    zero <- read_surface_mesh(path, space = flat_space(), face_index_base = 0L)
    one <- read_surface_mesh(path, space = flat_space(), face_index_base = 1L)

    expect_identical(attr(zero, "face_index_base"), 0L)
    expect_identical(attr(one, "face_index_base"), 1L)
    expect_identical(min(unlist(zero$faces)), 0L)
    expect_identical(min(unlist(one$faces)), 1L)
    # Same surface either way: the conversion must not move geometry.
    expect_identical(zero$vertices, one$vertices)
    expect_identical(one$faces$i - 1L, zero$faces$i)
  })

  it("reads the same geometry FreeSurfer holds", {
    skip_if_not_installed("freesurferformats")
    path <- fsaverage5_surface()
    mesh <- read_surface_mesh(path, space = flat_space(), face_index_base = 1L)
    direct <- freesurferformats::read.fs.surface(path)

    expect_equal(
      as.numeric(as.matrix(mesh$vertices)),
      as.numeric(direct$vertices),
      tolerance = 1e-6
    )
  })

  it("errors on a path that is not there", {
    expect_error(
      read_surface_mesh("no/such/surface", space = flat_space()),
      "No surface file"
    )
  })

  it("errors on a path that is not a single string", {
    expect_error(
      read_surface_mesh(c("a", "b"), space = flat_space()),
      "single file path"
    )
  })

  it("rejects an unknown format rather than guessing", {
    expect_error(
      read_surface_mesh(
        fsaverage5_surface(),
        space = flat_space(),
        format = "obj"
      ),
      "must be one of"
    )
  })

  it("refuses a space that is not a mesh_space", {
    expect_error(
      read_surface_mesh(fsaverage5_surface(), space = list(hemi = "left")),
      "must be a"
    )
  })
})

describe("read_surface_mesh() reproduces the bundled meshes", {
  # The reason this matters: formats' build script asserts the geometry it
  # writes is identical to what is already bundled. If reading through here
  # moved a coordinate, switching that script over would either fail the
  # assertion or silently replace the geometry every atlas indexes.
  it("returns exactly the vertices and faces ggseg.formats ships", {
    home <- Sys.getenv("FREESURFER_HOME")
    skip_if(!nzchar(home), "FREESURFER_HOME not set")

    for (hemi in c("lh", "rh")) {
      path <- file.path(
        home,
        "subjects",
        "fsaverage5",
        "surf",
        paste0(hemi, ".inflated")
      )
      skip_if(!file.exists(path), "fsaverage5 surfaces not available")

      mesh <- read_surface_mesh(
        path,
        space = flat_space(if (hemi == "lh") "left" else "right"),
        face_index_base = 0L
      )
      bundled <- ggseg.formats::get_brain_mesh(hemi, "inflated")

      expect_equal(mesh$vertices, bundled$vertices, tolerance = 0)
      expect_identical(mesh$faces, bundled$faces)
    }
  })
})

describe("read_surface_mesh() on GIFTI", {
  suit_space <- function() {
    ggseg.formats::mesh_space(
      vertex_space = "suit",
      hemi = "midline",
      anatomical = FALSE,
      surface = "suit-3d",
      source = "SUIT tpl-SUIT_3d.surf.gii"
    )
  }

  it("reads a surface GIFTI and detects the format from the name", {
    path <- suit_3d_path()
    mesh <- read_surface_mesh(path, space = suit_space())

    expect_identical(nrow(mesh$vertices), 28935L)
    expect_identical(attr(mesh, "face_index_base"), 0L)
    expect_identical(
      ggseg.formats::get_mesh_space(mesh)$vertex_space,
      "suit"
    )
  })

  it("returns the geometry the GIFTI holds", {
    path <- suit_3d_path()
    mesh <- read_surface_mesh(path, space = suit_space())
    gii <- gifti::readgii(path)

    expect_equal(
      as.numeric(as.matrix(mesh$vertices)),
      as.numeric(gii$data$pointset),
      tolerance = 1e-6
    )
  })

  it("converts a GIFTI's 0-based faces when 1-based is asked for", {
    path <- suit_3d_path()
    zero <- read_surface_mesh(path, space = suit_space(), face_index_base = 0L)
    one <- read_surface_mesh(path, space = suit_space(), face_index_base = 1L)

    expect_identical(min(unlist(zero$faces)), 0L)
    expect_identical(min(unlist(one$faces)), 1L)
    expect_identical(zero$vertices, one$vertices)
  })

  it("refuses a GIFTI that is not a surface", {
    # A label or shape GIFTI has no pointset/triangle pair, and reading one as
    # a surface would otherwise fail somewhere less informative.
    tmp <- withr::local_tempfile(fileext = ".gii")
    local_mocked_bindings(
      readgii = function(...) list(data = list(labels = 1:3)),
      .package = "gifti"
    )
    file.create(tmp)
    expect_error(
      read_surface_mesh(tmp, space = suit_space()),
      "not a surface GIFTI"
    )
  })
})
