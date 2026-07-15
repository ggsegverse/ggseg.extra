describe("read_fs_mesh", {
  it("requires FreeSurfer", {
    local_mocked_bindings(
      check_fs = function(msg = NULL, abort = FALSE) {
        if (abort) {
          cli::cli_abort("Freesurfer not found")
        }
        FALSE
      }
    )
    expect_error(read_fs_mesh(), "Freesurfer")
  })

  it("validates hemisphere argument", {
    skip_if_no_freesurfer()

    expect_error(
      read_fs_mesh(hemisphere = "invalid"),
      "arg"
    )
  })

  it("validates surface argument", {
    skip_if_no_freesurfer()

    expect_error(
      read_fs_mesh(surface = "invalid"),
      "arg"
    )
  })

  it("returns mesh structure", {
    skip_if_no_freesurfer()

    mesh <- read_fs_mesh(hemisphere = "lh", surface = "inflated")

    expect_type(mesh, "list")
    expect_true(all(c("vertices", "faces") %in% names(mesh)))
    expect_s3_class(mesh$vertices, "data.frame")
    expect_s3_class(mesh$faces, "data.frame")
    expect_named(mesh$vertices, c("x", "y", "z"))
    expect_named(mesh$faces, c("i", "j", "k"))
  })

  it("includes metadata", {
    skip_if_no_freesurfer()

    mesh <- read_fs_mesh(hemisphere = "rh", surface = "white")

    expect_identical(mesh$hemisphere, "rh")
    expect_identical(mesh$surface, "white")
    expect_identical(mesh$subject, "fsaverage5")
  })
})


describe("read_fs_mesh surface file not found", {
  it("errors when surface file does not exist", {
    local_mocked_bindings(
      check_fs = function(...) TRUE
    )

    fake_dir <- withr::local_tempdir("fake_fs_")
    dir.create(file.path(fake_dir, "fsaverage5", "surf"), recursive = TRUE)

    expect_error(
      read_fs_mesh(
        subject = "fsaverage5",
        hemisphere = "lh",
        surface = "inflated",
        subjects_dir = fake_dir
      ),
      "Surface file not found"
    )
  })
})
