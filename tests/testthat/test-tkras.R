describe("mesh_tkras_to_world()", {
  mesh <- function() {
    list(
      vertices = data.frame(x = c(1, -2, 3), y = c(4, 5, -6), z = c(7, -8, 9)),
      faces = data.frame(i = 1L, j = 2L, k = 3L)
    )
  }

  it("leaves a mesh alone under the identity", {
    # Which is what a FreeSurfer-conformed volume produces, and is why the
    # missing transform was invisible: every atlas built from conformed data
    # was correct by coincidence.
    out <- mesh_tkras_to_world(mesh(), diag(4))
    expect_equal(out$vertices, mesh()$vertices, ignore_attr = TRUE)
  })

  it("reflects x when the transform does", {
    flip <- diag(4)
    flip[1, 1] <- -1
    out <- mesh_tkras_to_world(mesh(), flip)
    expect_identical(out$vertices$x, -mesh()$vertices$x)
    expect_identical(out$vertices$y, mesh()$vertices$y)
  })

  it("permutes axes when the transform does", {
    # MCALT's real transform: x negated, y and z swapped.
    m <- rbind(c(-1, 0, 0, 0), c(0, 0, -1, 0), c(0, 1, 0, 0), c(0, 0, 0, 1))
    out <- mesh_tkras_to_world(mesh(), m)
    expect_identical(out$vertices$x, -mesh()$vertices$x)
    expect_identical(out$vertices$y, -mesh()$vertices$z)
    expect_identical(out$vertices$z, mesh()$vertices$y)
  })

  it("carries the translation", {
    m <- diag(4)
    m[1:3, 4] <- c(10, -20, 30)
    out <- mesh_tkras_to_world(mesh(), m)
    expect_identical(out$vertices$x, mesh()$vertices$x + 10)
    expect_identical(out$vertices$z, mesh()$vertices$z + 30)
  })

  it("passes a NULL mesh or transform straight through", {
    expect_null(mesh_tkras_to_world(NULL, diag(4)))
    expect_identical(mesh_tkras_to_world(mesh(), NULL), mesh())
  })

  it("keeps the faces", {
    out <- mesh_tkras_to_world(mesh(), diag(4))
    expect_identical(out$faces, mesh()$faces)
  })
})


describe("a tessellated structure keeps its side", {
  it("puts a left-sided label on the left of a non-conformed volume", {
    # The regression this file exists for. tkRAS is derived from a volume's
    # dimensions alone, so for a volume that is not in FreeSurfer's conformed
    # order the x axis can come back reflected -- and a mesh on the wrong
    # side is a defect, not an approximation, however tight its vertices are.
    skip_if_no_freesurfer()
    skip_if_not_installed("RNifti")

    # Two blobs either side of the midline, in a right-handed (RAS) volume:
    # +x is anatomical right, so label 10 is left and label 20 is right.
    arr <- array(0L, dim = c(40L, 40L, 40L))
    arr[8:14, 18:24, 18:24] <- 10L
    arr[26:32, 18:24, 18:24] <- 20L
    img <- RNifti::asNifti(
      arr,
      reference = list(
        sform_code = 1L,
        srow_x = c(1, 0, 0, -20),
        srow_y = c(0, 1, 0, -20),
        srow_z = c(0, 0, 1, -20)
      )
    )
    volume <- withr::local_tempfile(fileext = ".nii.gz")
    RNifti::writeNifti(img, volume)
    expect_gt(det(RNifti::xform(RNifti::readNifti(volume))[1:3, 1:3]), 0)

    work <- withr::local_tempdir()
    tkr <- get_tkras_to_world(volume)
    side <- function(id) {
      mesh <- tessellate_label(
        volume_file = volume,
        label_id = id,
        output_dir = work,
        verbose = FALSE,
        skip_existing = FALSE
      )
      mean(as.matrix(mesh_tkras_to_world(mesh, tkr)$vertices)[, 1])
    }

    expect_lt(side(10L), 0)
    expect_gt(side(20L), 0)
  })
})


describe("check_mesh_hemispheres()", {
  meshes_with <- function(x_left, x_right, hemis = c("left", "right")) {
    mesh <- function(x) {
      list(
        vertices = data.frame(x = c(x, x + 1), y = 0:1, z = 0:1),
        faces = data.frame(i = 1L, j = 2L, k = 1L)
      )
    }
    out <- data.frame(
      label = c("a", "b"),
      hemi = hemis,
      stringsAsFactors = FALSE
    )
    out$mesh <- list(mesh(x_left), mesh(x_right))
    out
  }

  it("passes meshes that honour the convention", {
    expect_no_error(check_mesh_hemispheres(meshes_with(-20, 20)))
  })

  it("aborts on mirrored meshes", {
    # The MCALT shape: left-labelled structures sitting right of the midline.
    expect_error(
      check_mesh_hemispheres(meshes_with(20, -20)),
      "wrong side of the midline"
    )
  })

  it("names both averages so the direction is readable", {
    expect_error(check_mesh_hemispheres(meshes_with(20, -20)), "20.5")
  })

  it("ignores meshes from only one hemisphere", {
    # Nothing to compare, so nothing to claim.
    expect_no_error(
      check_mesh_hemispheres(meshes_with(-20, -18, hemis = c("left", "left")))
    )
  })

  it("ignores structures with no hemisphere", {
    expect_no_error(
      check_mesh_hemispheres(meshes_with(20, -20, hemis = c(NA, NA)))
    )
  })

  it("passes a frame with no meshes in it", {
    # A subcortical atlas can legitimately carry none.
    expect_no_error(check_mesh_hemispheres(data.frame(label = "a")))
    expect_no_error(check_mesh_hemispheres(NULL))
  })
})
