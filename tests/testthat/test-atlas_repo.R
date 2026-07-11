.cap <- new.env()

describe("setup_atlas_repo", {
  # Mock download to always use fallback for consistent testing
  use_fallback <- function() {
    local_mocked_bindings(
      download_atlas_template = function(url = NULL) {
        system.file(
          "templates",
          "atlas-fallback",
          package = "ggseg.extra"
        )
      }
    )
  }

  it("creates package with explicit atlas name", {
    tmp <- withr::local_tempdir("atlas_test_")
    use_fallback()

    expect_messages(
      {
        result <- setup_atlas_repo(tmp, "dkt", open = FALSE)
      },
      "Created atlas package",
      "Next steps"
    )

    expect_true(dir.exists(result))
    expect_true(dir.exists(tmp))
    expect_true(file.exists(file.path(tmp, "DESCRIPTION")))
  })

  it("derives atlas name from ggsegXxx path format", {
    parent <- withr::local_tempdir()
    tmp <- file.path(parent, paste0("ggsegSchaefer", Sys.getpid()))
    use_fallback()

    expect_messages(
      setup_atlas_repo(tmp, open = FALSE),
      "Created atlas package",
      "Next steps"
    )

    desc <- readLines(file.path(tmp, "DESCRIPTION"))
    pkg_line <- desc[grep("^Package:", desc)]

    expect_match(pkg_line, "ggsegSchaefer")
  })

  it("derives atlas name from plain directory name", {
    parent <- withr::local_tempdir()
    tmp <- file.path(parent, paste0("myatlas", Sys.getpid()))
    use_fallback()

    expect_messages(
      setup_atlas_repo(tmp, open = FALSE),
      "Created atlas package",
      "Next steps"
    )

    desc <- readLines(file.path(tmp, "DESCRIPTION"))
    pkg_line <- desc[grep("^Package:", desc)]

    expect_match(pkg_line, "ggsegMyatlas")
  })

  it("cleans atlas name (lowercase, alphanumeric only)", {
    tmp <- withr::local_tempdir("atlas_test_")
    use_fallback()

    expect_messages(
      setup_atlas_repo(tmp, "My-Atlas_123!", open = FALSE),
      "Created atlas package",
      "Next steps"
    )

    desc <- readLines(file.path(tmp, "DESCRIPTION"))
    pkg_line <- desc[grep("^Package:", desc)]

    expect_match(pkg_line, "ggsegMyatlas123")
  })

  it("errors on empty atlas name", {
    tmp <- withr::local_tempdir("atlas_test_")

    expect_error(
      setup_atlas_repo(file.path(tmp, "newpkg"), "---", open = FALSE),
      "must contain at least one letter"
    )
  })

  it("errors on non-empty directory", {
    tmp <- withr::local_tempdir("atlas_test_")
    writeLines("test", file.path(tmp, "existing.txt"))

    expect_error(
      setup_atlas_repo(tmp, "test", open = FALSE),
      "not empty"
    )
  })

  it("creates .Rproj file when rstudio = TRUE", {
    tmp <- withr::local_tempdir("atlas_test_")
    use_fallback()

    expect_messages(
      setup_atlas_repo(tmp, "test", open = FALSE, rstudio = TRUE),
      "Created atlas package",
      "Next steps"
    )

    rproj_files <- list.files(tmp, pattern = "\\.Rproj$")
    expect_length(rproj_files, 1)
    expect_identical(rproj_files, "ggsegTest.Rproj")
  })

  it("skips .Rproj file when rstudio = FALSE", {
    tmp <- withr::local_tempdir("atlas_test_")
    use_fallback()

    expect_messages(
      setup_atlas_repo(tmp, "test", open = FALSE, rstudio = FALSE),
      "Created atlas package",
      "Next steps"
    )

    rproj_files <- list.files(tmp, pattern = "\\.Rproj$")
    expect_length(rproj_files, 0)
  })
})


describe("setup_atlas_repo template files", {
  tmp <- withr::local_tempdir("atlas_template_test_")
  local_mocked_bindings(
    download_atlas_template = function(url = NULL) {
      system.file(
        "templates",
        "atlas-fallback",
        package = "ggseg.extra"
      )
    }
  )
  expect_messages(
    setup_atlas_repo(tmp, "testatlas", open = FALSE),
    "Created atlas package",
    "Next steps"
  )

  it("creates all required directories", {
    expect_true(dir.exists(file.path(tmp, "R")))
    expect_true(dir.exists(file.path(tmp, "data-raw")))
    expect_true(dir.exists(file.path(tmp, "tests", "testthat")))
  })

  it("creates all required files", {
    expected_files <- c(
      "DESCRIPTION",
      "NAMESPACE",
      "LICENSE",
      "NEWS.md",
      "README.qmd",
      "_pkgdown.yml",
      ".gitignore",
      ".Rbuildignore",
      "R/data.R",
      "data-raw/create-atlas.R",
      "tests/testthat.R",
      "tests/testthat/test-data.R"
    )

    for (f in expected_files) {
      expect_true(
        file.exists(file.path(tmp, f)),
        info = paste("Missing file:", f)
      )
    }
  })

  it("renames package-level documentation file", {
    expect_true(
      file.exists(file.path(tmp, "R", "ggsegTestatlas-package.R"))
    )
    expect_false(
      file.exists(file.path(tmp, "R", "REPO-package.R"))
    )
  })

  it("replaces {GGSEG} placeholder with atlas name", {
    data_r <- readLines(file.path(tmp, "R/data.R"))

    expect_false(any(grepl("{GGSEG}", data_r, fixed = TRUE)))
    expect_true(any(grepl("testatlas", data_r, fixed = TRUE)))
  })

  it("replaces {REPO} placeholder with package name", {
    desc <- readLines(file.path(tmp, "DESCRIPTION"))

    expect_false(any(grepl("{REPO}", desc, fixed = TRUE)))
    expect_true(any(grepl("ggsegTestatlas", desc, fixed = TRUE)))
  })

  it("creates valid DESCRIPTION file", {
    desc <- readLines(file.path(tmp, "DESCRIPTION"))

    expect_true(any(grepl("^Package: ggsegTestatlas", desc)))
    expect_true(any(grepl("^License: CC0", desc)))
    expect_true(any(grepl("ggseg.formats", desc)))
  })

  it("creates valid test file", {
    test_file <- readLines(file.path(tmp, "tests/testthat/test-data.R"))

    expect_true(any(grepl("describe.*testatlas", test_file)))
    expect_true(any(grepl("ggseg_atlas", test_file, fixed = TRUE)))
  })

  it("creates data-raw script with correct atlas name", {
    create_script <- readLines(file.path(tmp, "data-raw/create-atlas.R"))

    expect_true(any(grepl("testatlas", create_script, fixed = TRUE)))
    expect_false(any(grepl("{GGSEG}", create_script, fixed = TRUE)))
  })

  it("creates README with correct package references", {
    readme <- readLines(file.path(tmp, "README.qmd"))

    expect_true(any(grepl("ggsegTestatlas", readme, fixed = TRUE)))
    expect_true(any(grepl("testatlas", readme, fixed = TRUE)))
    expect_true(any(grepl("Citation", readme, fixed = TRUE)))
    expect_false(any(grepl("{REPO}", readme, fixed = TRUE)))
  })

  it("scaffold contains all pipeline methods", {
    create_script <- readLines(file.path(tmp, "data-raw/create-atlas.R"))
    script_text <- paste(create_script, collapse = "\n")

    expect_match(script_text, "CORTICAL ATLAS")
    expect_match(script_text, "SUBCORTICAL ATLAS")
    expect_match(script_text, "CEREBELLAR ATLAS")
    expect_match(script_text, "TRACT ATLAS")
    expect_match(script_text, "WHOLEBRAIN ATLAS")
  })
})


describe("download_atlas_template", {
  it("falls back to bundled template on download failure", {
    local_mocked_bindings(
      template_url = function() "https://invalid.example.com/nonexistent.tar.gz"
    )

    expect_messages(
      {
        result <- download_atlas_template()
      },
      "Download failed",
      "fallback"
    )

    expect_true(dir.exists(result))
    expect_true(file.exists(file.path(result, "DESCRIPTION")))
  })
})


describe("setup_atlas_repo .Rproj file", {
  it("contains correct package build settings", {
    tmp <- withr::local_tempdir("atlas_rproj_test_")

    local_mocked_bindings(
      download_atlas_template = function(url = NULL) {
        system.file(
          "templates",
          "atlas-fallback",
          package = "ggseg.extra"
        )
      }
    )

    expect_messages(
      setup_atlas_repo(tmp, "test", open = FALSE),
      "Created atlas package",
      "Next steps"
    )

    rproj <- readLines(file.path(tmp, "ggsegTest.Rproj"))

    expect_true(any(grepl("BuildType: Package", rproj, fixed = TRUE)))
    expect_true(any(grepl("PackageUseDevtools: Yes", rproj, fixed = TRUE)))
    expect_true(any(grepl("PackageRoxygenize:", rproj, fixed = TRUE)))
  })
})


describe("setup_atlas_repo lowercase ggseg prefix", {
  it("derives atlas name from lowercase ggseg prefix path", {
    parent <- withr::local_tempdir()
    tmp <- file.path(parent, paste0("ggsegfoo", Sys.getpid()))

    local_mocked_bindings(
      download_atlas_template = function(url = NULL) {
        system.file(
          "templates",
          "atlas-fallback",
          package = "ggseg.extra"
        )
      }
    )

    expect_messages(
      setup_atlas_repo(tmp, open = FALSE),
      "Created atlas package",
      "Next steps"
    )

    desc <- readLines(file.path(tmp, "DESCRIPTION"))
    pkg_line <- desc[grep("^Package:", desc)]

    expect_match(pkg_line, "ggsegFoo")
  })

  it("calls open_rstudio_project when open and rstudio are TRUE", {
    tmp <- withr::local_tempdir("atlas_open_test_")
    .cap$opened <- FALSE

    local_mocked_bindings(
      download_atlas_template = function(url = NULL) {
        system.file(
          "templates",
          "atlas-fallback",
          package = "ggseg.extra"
        )
      },
      open_rstudio_project = function(path) {
        .cap$opened <- TRUE
        invisible(TRUE)
      }
    )

    expect_messages(
      setup_atlas_repo(tmp, "test", open = TRUE, rstudio = TRUE),
      "Created atlas package",
      "Next steps"
    )

    expect_true(.cap$opened)
  })
})


describe("open_rstudio_project", {
  it("returns FALSE when rstudioapi not available", {
    local_mocked_bindings(
      rstudioapi_available = function() FALSE
    )

    result <- open_rstudio_project("/tmp/some_path")

    expect_false(result)
  })

  it("returns FALSE when no .Rproj files found", {
    tmp <- withr::local_tempdir("rproj_test_")

    local_mocked_bindings(
      rstudioapi_available = function() TRUE
    )

    result <- open_rstudio_project(tmp)

    expect_false(result)
  })

  it("opens project when rstudioapi available and Rproj exists", {
    tmp <- withr::local_tempdir("rproj_test_")
    writeLines("Version: 1.0", file.path(tmp, "test.Rproj"))
    .cap$opened_path <- NULL

    local_mocked_bindings(
      rstudioapi_available = function() TRUE
    )
    local_mocked_bindings(
      isAvailable = function() TRUE,
      openProject = function(path, ...) {
        .cap$opened_path <- path
        invisible(NULL)
      },
      .package = "rstudioapi"
    )

    result <- open_rstudio_project(tmp)

    expect_true(result)
    expect_identical(.cap$opened_path, file.path(tmp, "test.Rproj"))
  })
})


describe("rstudioapi_available", {
  it("returns FALSE when rstudioapi is not installed", {
    local_mocked_bindings(
      requireNamespace = function(pkg, ...) FALSE,
      .package = "base"
    )

    expect_false(rstudioapi_available())
  })
})


describe("template_replace error handling", {
  it("returns NULL for unreadable files", {
    result <- suppressWarnings(
      template_replace("/nonexistent/path/file.txt", "test")
    )

    expect_null(result)
  })
})


describe("new_project_setup_atlas_repo", {
  it("delegates to setup_atlas_repo with correct parameters", {
    tmp <- withr::local_tempdir("wizard_test_")
    .cap$called_args <- NULL

    local_mocked_bindings(
      setup_atlas_repo = function(path, atlas_name, open, rstudio) {
        .cap$called_args <- list(
          path = path,
          atlas_name = atlas_name,
          open = open,
          rstudio = rstudio
        )
        invisible(path)
      }
    )

    new_project_setup_atlas_repo(tmp, atlas_name = "myatlas")

    expect_identical(.cap$called_args$path, tmp)
    expect_identical(.cap$called_args$atlas_name, "myatlas")
    expect_false(.cap$called_args$open)
    expect_true(.cap$called_args$rstudio)
  })

  it("passes NULL atlas_name when not provided", {
    tmp <- withr::local_tempdir("wizard_null_test_")
    .cap$called_args <- NULL

    local_mocked_bindings(
      setup_atlas_repo = function(path, atlas_name, open, rstudio) {
        .cap$called_args <- list(atlas_name = atlas_name)
        invisible(path)
      }
    )

    new_project_setup_atlas_repo(tmp)

    expect_null(.cap$called_args$atlas_name)
  })
})


describe("template_replace", {
  it("replaces both GGSEG and REPO placeholders", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines(
      c(
        "Package: {REPO}",
        "Atlas: {GGSEG}",
        "URL: https://github.com/ggsegverse/{REPO}"
      ),
      tmp
    )

    template_replace(tmp, "myatlas")

    result <- readLines(tmp)
    expect_identical(result[1], "Package: ggsegMyatlas")
    expect_identical(result[2], "Atlas: myatlas")
    expect_identical(
      result[3],
      "URL: https://github.com/ggsegverse/ggsegMyatlas"
    )
  })

  it("handles files without placeholders", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines("No placeholders here", tmp)

    expect_no_error(template_replace(tmp, "test"))

    result <- readLines(tmp)
    expect_identical(result, "No placeholders here")
  })
})
