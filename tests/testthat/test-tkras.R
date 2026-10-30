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
