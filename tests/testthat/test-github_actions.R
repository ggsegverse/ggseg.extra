describe("atlas_github_actions", {
  it("lists the workflows shipped with the package", {
    available <- atlas_github_actions()

    expect_type(available, "character")
    expect_setequal(
      available,
      c(
        "R-CMD-check",
        "code-quality",
        "pkgdown",
        "render-readme",
        "update-codemeta"
      )
    )
  })

  it("names a bundled template for every workflow it lists", {
    for (workflow in atlas_github_actions()) {
      src <- system.file(
        "templates",
        "workflows",
        paste0(workflow, ".yaml"),
        package = "ggseg.extra"
      )
      expect_true(nzchar(src), info = workflow)
    }
  })
})


describe("use_atlas_github_actions", {
  local_pkg <- function() {
    tmp <- withr::local_tempdir(.local_envir = parent.frame())
    writeLines("Package: ggsegTest", file.path(tmp, "DESCRIPTION"))
    tmp
  }

  it("writes every workflow by default", {
    tmp <- local_pkg()

    expect_message(use_atlas_github_actions(path = tmp), "Added 5 workflows")

    written <- list.files(file.path(tmp, ".github", "workflows"))
    expect_setequal(written, paste0(atlas_github_actions(), ".yaml"))
  })

  it("writes only the requested workflows", {
    tmp <- local_pkg()

    use_atlas_github_actions("pkgdown", path = tmp)

    expect_identical(
      list.files(file.path(tmp, ".github", "workflows")),
      "pkgdown.yaml"
    )
  })

  it("returns the paths it wrote", {
    tmp <- local_pkg()

    written <- use_atlas_github_actions("pkgdown", path = tmp)

    expect_length(written, 1)
    expect_true(file.exists(written))
  })

  it("keeps existing workflows unless overwrite is TRUE", {
    tmp <- local_pkg()
    use_atlas_github_actions("pkgdown", path = tmp)
    target <- file.path(tmp, ".github", "workflows", "pkgdown.yaml")
    writeLines("edited by hand", target)

    expect_message(
      use_atlas_github_actions("pkgdown", path = tmp),
      "Kept 1 existing workflow"
    )
    expect_identical(readLines(target), "edited by hand")

    use_atlas_github_actions("pkgdown", path = tmp, overwrite = TRUE)
    expect_false(identical(readLines(target), "edited by hand"))
  })

  it("errors when the directory is not a package", {
    tmp <- withr::local_tempdir()

    expect_error(
      use_atlas_github_actions(path = tmp),
      "No package found"
    )
  })

  it("errors on an unknown workflow name", {
    tmp <- local_pkg()

    expect_error(
      use_atlas_github_actions("deploy-to-prod", path = tmp),
      "Unknown workflow"
    )
  })

  it("writes workflows that call the shared ggsegverse workflow", {
    tmp <- local_pkg()
    use_atlas_github_actions(path = tmp)

    for (workflow in atlas_github_actions()) {
      yaml <- readLines(
        file.path(tmp, ".github", "workflows", paste0(workflow, ".yaml"))
      )
      expect_true(
        any(grepl("ggsegverse/.github/.github/workflows/", yaml, fixed = TRUE)),
        info = workflow
      )
    }
  })

  it("renders the README source that atlas packages actually use", {
    tmp <- local_pkg()
    use_atlas_github_actions("render-readme", path = tmp)

    yaml <- paste(
      readLines(file.path(tmp, ".github", "workflows", "render-readme.yaml")),
      collapse = "\n"
    )

    expect_match(yaml, "readme-file: README.qmd", fixed = TRUE)
    expect_no_match(yaml, "README.Rmd", fixed = TRUE)
  })
})
