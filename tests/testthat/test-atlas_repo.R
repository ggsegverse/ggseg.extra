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
      ".lintr",
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

  it("excludes only commented_code_linter, and only from create-atlas.R", {
    # A blanket data-raw exclusion would also silence object_usage_linter,
    # which is the one worth keeping there. create-atlas.R is a menu of
    # commented-out example invocations, so only that linter misfires.
    config <- readLines(file.path(tmp, ".lintr"), warn = FALSE)

    expect_match(config, "create-atlas\\.R", all = FALSE)
    expect_match(config, "commented_code_linter", all = FALSE)
    expect_false(any(grepl("object_usage_linter", config)))
  })

  it("declares the data-raw dependencies for the lint job", {
    # Without these, object_usage_linter cannot resolve what create-atlas.R
    # loads and reports every call through them as an undefined global.
    needs <- read.dcf(file.path(tmp, "DESCRIPTION"))[1, "Config/Needs/lint"]
    declared <- trimws(strsplit(needs, ",")[[1]])

    expect_setequal(
      declared,
      c("dplyr", "future", "progressr", "ggsegverse/ggseg.extra")
    )
  })

  it("adds the shared GitHub Actions workflows", {
    written <- list.files(file.path(tmp, ".github", "workflows"))

    expect_setequal(written, paste0(atlas_github_actions(), ".yaml"))
  })

  it("renames package-level documentation file", {
    expect_true(
      file.exists(file.path(tmp, "R", "ggsegTestatlas-package.R"))
    )
    expect_false(
      file.exists(file.path(tmp, "R", "PKGNAME-package.R"))
    )
    expect_false(
      file.exists(file.path(tmp, "R", "REPO-package.R"))
    )
  })

  it("replaces ATLASNAME placeholder with atlas name", {
    data_r <- readLines(file.path(tmp, "R/data.R"))

    expect_false(any(grepl("ATLASNAME", data_r, fixed = TRUE)))
    expect_true(any(grepl("testatlas", data_r, fixed = TRUE)))
  })

  it("replaces PKGNAME placeholder with package name", {
    desc <- readLines(file.path(tmp, "DESCRIPTION"))

    expect_false(any(grepl("PKGNAME", desc, fixed = TRUE)))
    expect_true(any(grepl("ggsegTestatlas", desc, fixed = TRUE)))
  })

  it("leaves no unsubstituted placeholders anywhere", {
    files <- list.files(tmp, recursive = TRUE, full.names = TRUE)
    files <- files[!grepl("\\.(png|rda|rds)$", files, ignore.case = TRUE)]

    leftovers <- Filter(
      function(f) {
        any(grepl(
          "ATLASNAME|PKGNAME|YEARNUM|\\{GGSEG\\}|\\{REPO\\}|\\{YEAR\\}",
          readLines(f, warn = FALSE)
        ))
      },
      files
    )

    expect_identical(leftovers, character(0))
  })

  it("generates syntactically valid R sources", {
    r_files <- list.files(
      tmp,
      pattern = "\\.R$",
      recursive = TRUE,
      full.names = TRUE
    )

    expect_gt(length(r_files), 0)
    for (f in r_files) {
      expect_no_error(parse(f))
    }
  })

  it("generates an atlas accessor returning the internal object", {
    data_r <- paste(readLines(file.path(tmp, "R/data.R")), collapse = "\n")

    expect_match(data_r, "testatlas <- function() .testatlas", fixed = TRUE)
  })

  it("creates valid DESCRIPTION file", {
    desc <- readLines(file.path(tmp, "DESCRIPTION"))

    expect_true(any(grepl("^Package: ggsegTestatlas", desc)))
    expect_true(any(grepl("^License: MIT \\+ file LICENSE", desc)))
    expect_true(any(grepl("ggseg.formats", desc)))
  })

  it("declares a LICENSE file that the template ships", {
    desc <- readLines(file.path(tmp, "DESCRIPTION"))
    license <- grep("^License:", desc, value = TRUE)

    expect_identical(
      grepl("file LICENSE", license, fixed = TRUE),
      file.exists(file.path(tmp, "LICENSE"))
    )
  })

  it("creates valid test file", {
    test_file <- readLines(file.path(tmp, "tests/testthat/test-data.R"))

    expect_true(any(grepl("describe.*testatlas", test_file)))
    expect_true(any(grepl("ggseg_atlas", test_file, fixed = TRUE)))
  })

  it("creates data-raw script with correct atlas name", {
    create_script <- readLines(file.path(tmp, "data-raw/create-atlas.R"))

    expect_true(any(grepl("testatlas", create_script, fixed = TRUE)))
    expect_false(any(grepl("ATLASNAME", create_script, fixed = TRUE)))
  })

  it("creates README with correct package references", {
    readme <- readLines(file.path(tmp, "README.qmd"))

    expect_true(any(grepl("ggsegTestatlas", readme, fixed = TRUE)))
    expect_true(any(grepl("testatlas", readme, fixed = TRUE)))
    expect_true(any(grepl("Citation", readme, fixed = TRUE)))
    expect_false(any(grepl("PKGNAME", readme, fixed = TRUE)))
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

  it("scaffold only calls functions ggseg.extra exports", {
    script_text <- paste(
      readLines(file.path(tmp, "data-raw/create-atlas.R")),
      collapse = "\n"
    )

    # Unqualified calls in the ggseg.extra naming families; namespaced calls
    # (here::here, freesurfer::fs_subj_dir) are somebody else's to validate.
    pattern <- paste0(
      "(?<!:)\\b(create|read|write|atlas|lut|transform|coregister|",
      "project|prepare)_[a-z_0-9]+(?=\\()"
    )
    called <- unique(unlist(regmatches(
      script_text,
      gregexpr(pattern, script_text, perl = TRUE)
    )))

    expect_gt(length(called), 0)
    expect_setequal(
      setdiff(called, getNamespaceExports("ggseg.extra")),
      character(0)
    )
  })

  it("scaffold passes argument names the pipelines accept", {
    calls <- scaffold_pipeline_calls(file.path(tmp, "data-raw/create-atlas.R"))

    expect_gte(length(calls), 9)
    for (call in calls) {
      fn_name <- as.character(call[[1]])
      supplied <- names(as.list(call))[-1]
      accepted <- names(formals(getExportedValue("ggseg.extra", fn_name)))

      expect_true(
        all(nzchar(supplied)),
        info = paste(fn_name, "passes an argument positionally")
      )
      expect_setequal(setdiff(supplied, accepted), character(0))
    }
  })

  it("scaffold supplies every required argument", {
    calls <- scaffold_pipeline_calls(file.path(tmp, "data-raw/create-atlas.R"))

    for (call in calls) {
      fn_name <- as.character(call[[1]])
      args <- formals(getExportedValue("ggseg.extra", fn_name))
      required <- names(args)[vapply(
        args,
        function(a) is.symbol(a) && !nzchar(as.character(a)),
        logical(1)
      )]

      expect_setequal(
        setdiff(required, names(as.list(call))[-1]),
        character(0)
      )
    }
  })

  it("scaffold does not use deprecated creation arguments", {
    create_script <- readLines(file.path(tmp, "data-raw/create-atlas.R"))
    script_text <- paste(create_script, collapse = "\n")

    expect_no_match(script_text, "tolerance\\s*=")
    expect_no_match(script_text, "smooth_refinements\\s*=")
    expect_no_match(script_text, "color_lut\\s*=")
  })
})


describe("setup_atlas_repo github actions", {
  fake_template <- function(env = parent.frame()) {
    src <- withr::local_tempdir(.local_envir = env)
    dir.create(file.path(src, "R"), recursive = TRUE)
    writeLines("Package: PKGNAME", file.path(src, "DESCRIPTION"))
    writeLines("ATLASNAME <- function() .ATLASNAME", file.path(src, "R/data.R"))

    dir.create(file.path(src, ".github", "workflows"), recursive = TRUE)
    dir.create(file.path(src, ".github", "scripts"), recursive = TRUE)
    writeLines(
      "name: template-check",
      file.path(
        src,
        ".github",
        "workflows",
        "template-check.yaml"
      )
    )
    writeLines("stop()", file.path(src, ".github", "scripts", "render.R"))
    src
  }

  it("does not copy the template's own .github infrastructure", {
    src <- fake_template()
    tmp <- withr::local_tempdir()
    local_mocked_bindings(download_atlas_template = function(url = NULL) src)

    suppressMessages(setup_atlas_repo(
      tmp,
      "gha",
      open = FALSE,
      rstudio = FALSE
    ))

    expect_false(dir.exists(file.path(tmp, ".github", "scripts")))
    expect_false(
      file.exists(file.path(tmp, ".github", "workflows", "template-check.yaml"))
    )
  })

  it("still writes the shared workflows from bundled templates", {
    src <- fake_template()
    tmp <- withr::local_tempdir()
    local_mocked_bindings(download_atlas_template = function(url = NULL) src)

    suppressMessages(setup_atlas_repo(
      tmp,
      "gha",
      open = FALSE,
      rstudio = FALSE
    ))

    expect_setequal(
      list.files(file.path(tmp, ".github", "workflows")),
      paste0(atlas_github_actions(), ".yaml")
    )
  })

  it("skips workflows when github_actions is FALSE", {
    src <- fake_template()
    tmp <- withr::local_tempdir()
    local_mocked_bindings(download_atlas_template = function(url = NULL) src)

    suppressMessages(setup_atlas_repo(
      tmp,
      "gha",
      open = FALSE,
      rstudio = FALSE,
      github_actions = FALSE
    ))

    expect_false(dir.exists(file.path(tmp, ".github")))
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


describe("replace_template_placeholders", {
  it("skips files under .git", {
    tmp <- withr::local_tempdir()
    dir.create(file.path(tmp, ".git"))
    writeLines("ATLASNAME", file.path(tmp, ".git", "config"))
    writeLines("ATLASNAME", file.path(tmp, "DESCRIPTION"))

    expect_message(
      replace_template_placeholders(tmp, "myatlas"),
      "Replaced template placeholders"
    )

    expect_identical(readLines(file.path(tmp, ".git", "config")), "ATLASNAME")
    expect_identical(readLines(file.path(tmp, "DESCRIPTION")), "myatlas")
  })
})


describe("rename_package_doc", {
  it("renames the current PKGNAME-package.R name", {
    tmp <- withr::local_tempdir()
    dir.create(file.path(tmp, "R"))
    file.create(file.path(tmp, "R", "PKGNAME-package.R"))

    expect_true(rename_package_doc(tmp, "ggsegMyatlas"))
    expect_true(file.exists(file.path(tmp, "R", "ggsegMyatlas-package.R")))
  })

  it("renames the legacy REPO-package.R name", {
    tmp <- withr::local_tempdir()
    dir.create(file.path(tmp, "R"))
    file.create(file.path(tmp, "R", "REPO-package.R"))

    expect_true(rename_package_doc(tmp, "ggsegMyatlas"))
    expect_true(file.exists(file.path(tmp, "R", "ggsegMyatlas-package.R")))
  })

  it("is a no-op when neither name is present", {
    tmp <- withr::local_tempdir()
    dir.create(file.path(tmp, "R"))

    expect_false(rename_package_doc(tmp, "ggsegMyatlas"))
  })
})


describe("template_replace error handling", {
  it("returns NULL and warns for unreadable files", {
    result <- expect_warnings(
      template_replace("/nonexistent/path/file.txt", "test"),
      "cannot open file|Failed to process template"
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
  it("replaces both atlas and package placeholders", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines(
      c(
        "Package: PKGNAME",
        "Atlas: ATLASNAME",
        "URL: https://github.com/ggsegverse/PKGNAME"
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

  it("still replaces the legacy brace-wrapped placeholders", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines(
      c("Package: {REPO}", "Atlas: {GGSEG}", "Year: {YEAR}"),
      tmp
    )

    template_replace(tmp, "myatlas")

    result <- readLines(tmp)
    expect_identical(result[1], "Package: ggsegMyatlas")
    expect_identical(result[2], "Atlas: myatlas")
    expect_identical(result[3], paste("Year:", format(Sys.Date(), "%Y")))
  })

  it("substitutes the year placeholder", {
    tmp <- withr::local_tempfile(fileext = ".txt")
    writeLines("YEAR: YEARNUM", tmp)

    template_replace(tmp, "myatlas")

    expect_identical(
      readLines(tmp),
      paste("YEAR:", format(Sys.Date(), "%Y"))
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
