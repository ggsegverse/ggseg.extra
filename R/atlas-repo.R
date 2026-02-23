#' Create a new ggseg atlas package
#'
#' Scaffold an R package for distributing a brain atlas. The generated
#' package follows ggseg conventions and includes everything you need:
#' template scripts for atlas creation, documentation stubs, a test suite,
#' and GitHub Actions for automated checking.
#'
#' The package will be named `ggseg{AtlasName}` (e.g., `ggsegSchaefer` for
#' a Schaefer parcellation). After creation, edit the files in `data-raw/`
#' to build your atlas, then run `devtools::document()` and `devtools::check()`.
#'
#' @param path Where to create the package. If the directory exists, it must
#'   be empty.
#' @param atlas_name Name of the atlas (lowercase, no spaces). The package
#'   name becomes `ggseg{AtlasName}`. If NULL, derived from the directory
#'   name (e.g., path `ggsegDkt` becomes atlas name `dkt`).
#' @param open If TRUE, opens the new project in RStudio. Default is TRUE
#'   when running interactively.
#' @param rstudio If TRUE, creates an `.Rproj` file for RStudio users.
#'
#' @return Invisibly returns the path to the created package.
#' @export
#'
#' @examples
#' \dontrun{
#' # Create atlas package in a new directory
#' setup_atlas_repo("ggsegDkt", "dkt")
#'
#' # Create in current directory, derive name from path
#' setup_atlas_repo("ggsegMyatlas")
#'
#' # Specify full path
#' setup_atlas_repo("~/projects/ggsegSchaefer", "schaefer")
#'
#' # Without opening in RStudio
#' setup_atlas_repo("ggsegHarvard", "harvard", open = FALSE)
#' }
setup_atlas_repo <- function(
  path,
  atlas_name = NULL,
  open = rlang::is_interactive(),
  rstudio = TRUE
) {
  path <- normalizePath(path, mustWork = FALSE)

  if (is.null(atlas_name)) {
    dir_name <- basename(path)
    if (grepl("^ggseg[A-Z]", dir_name)) {
      atlas_name <- sub("^ggseg", "", dir_name)
    } else if (grepl("^ggseg", dir_name, ignore.case = TRUE)) {
      atlas_name <- sub("^ggseg", "", dir_name, ignore.case = TRUE)
    } else {
      atlas_name <- dir_name
    }
  }

  atlas_name <- tolower(atlas_name)
  atlas_name <- gsub("[^a-z0-9]", "", atlas_name)
  repo_name <- paste0("ggseg", tools::toTitleCase(atlas_name))

  if (nchar(atlas_name) == 0) {
    cli::cli_abort(c(
      "Invalid atlas name",
      "x" = "atlas_name must contain at least one letter or number",
      "i" = "Example: {.code setup_atlas_repo('ggsegDkt', 'dkt')}"
    ))
  }

  if (dir.exists(path)) {
    files <- list.files(path, all.files = TRUE, no.. = TRUE)
    if (length(files) > 0) {
      cli::cli_abort(c(
        "Directory is not empty",
        "x" = "{.path {path}} already contains files",
        "i" = "Use an empty directory or a new path"
      ))
    }
  }

  create_atlas_from_template(path, atlas_name)

  if (rstudio) {
    create_rproj_file(path, repo_name)
  }

  cli::cli_alert_success("Created atlas package {.pkg {repo_name}}")
  cli::cli_alert_info("Location: {.path {path}}")

  cli::cli_h3("Next steps")
  cli::cli_bullets(c(
    "1" = "Edit {.file data-raw/create-atlas.R} to create your atlas",
    "2" = "Update {.file R/data.R} with documentation and citation",
    "3" = "Add atlas citation to {.file README.Rmd}",
    "4" = "Run {.code devtools::document()} to generate documentation",
    "5" = "Run {.code devtools::check()} to verify the package"
  ))

  if (open && rstudio) {
    open_rstudio_project(path)
  }

  invisible(path)
}


#' @keywords internal
create_atlas_from_template <- function(path, atlas_name) {
  template_dir <- system.file(
    file.path("rstudio", "templates", "project", "create-ggseg-atlas"),
    package = "ggseg.extra"
  )

  if (!dir.exists(template_dir)) {
    cli::cli_abort(c(
      "Template not found",
      "x" = "Could not find atlas template directory",
      "i" = "Is ggseg.extra installed correctly?"
    ))
  }

  mkdir(path)

  dirs <- list.dirs(template_dir, full.names = FALSE, recursive = TRUE)
  dirs <- dirs[!grepl("^\\.", dirs)]
  for (d in dirs) {
    if (nchar(d) > 0) {
      mkdir(file.path(path, d))
    }
  }

  files <- list.files(template_dir, recursive = TRUE, all.files = FALSE)

  for (f in files) {
    src <- file.path(template_dir, f)
    dst <- file.path(path, f)
    mkdir(dirname(dst))
    file.copy(src, dst, overwrite = TRUE)
  }

  write_gitignore(path)
  write_rbuildignore(path)
  write_github_workflows(path)

  all_files <- list.files(
    path,
    full.names = TRUE,
    recursive = TRUE,
    all.files = TRUE
  )
  all_files <- all_files[
    !grepl(
      "\\.(png|jpg|jpeg|gif|ico|rda|RData|rds)$",
      all_files,
      ignore.case = TRUE
    )
  ]

  for (f in all_files) {
    if (file.exists(f) && !dir.exists(f)) {
      template_replace(f, atlas_name)
    }
  }

  invisible(path)
}


#' @keywords internal
create_rproj_file <- function(path, repo_name) {
  rproj_content <- c(
    "Version: 1.0",
    "",
    "RestoreWorkspace: No",
    "SaveWorkspace: No",
    "AlwaysSaveHistory: Default",
    "",
    "EnableCodeIndexing: Yes",
    "UseSpacesForTab: Yes",
    "NumSpacesForTab: 2",
    "Encoding: UTF-8",
    "",
    "RnwWeave: Sweave",
    "LaTeX: pdfLaTeX",
    "",
    "AutoAppendNewline: Yes",
    "StripTrailingWhitespace: Yes",
    "LineEndingConversion: Posix",
    "",
    "BuildType: Package",
    "PackageUseDevtools: Yes",
    "PackageInstallArgs: --no-multiarch --with-keep.source",
    "PackageRoxygenize: rd,collate,namespace"
  )

  rproj_file <- file.path(path, paste0(repo_name, ".Rproj"))
  writeLines(rproj_content, rproj_file)

  invisible(rproj_file)
}


#' @keywords internal
open_rstudio_project <- function(path) {
  if (!rstudioapi_available()) {
    return(invisible(FALSE))
  }

  rproj_files <- list.files(path, pattern = "\\.Rproj$", full.names = TRUE)
  if (length(rproj_files) == 0) {
    return(invisible(FALSE))
  }

  if (rstudioapi::isAvailable()) {
    rstudioapi::openProject(rproj_files[1], newSession = TRUE)
  }

  invisible(TRUE)
}


#' @keywords internal
rstudioapi_available <- function() {
  requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable()
}


#' @keywords internal
template_replace <- function(file, atlas_name) {
  repo_name <- paste0("ggseg", tools::toTitleCase(atlas_name))

  tryCatch(
    {
      input <- readLines(file, warn = FALSE)
      output <- gsub("\\{GGSEG\\}", atlas_name, input)
      output <- gsub("\\{REPO\\}", repo_name, output)
      output <- gsub("\\{YEAR\\}", format(Sys.Date(), "%Y"), output)
      writeLines(output, file)
    },
    error = function(e) {
      cli::cli_warn("Failed to process template {.file {file}}: {e$message}")
      invisible(NULL)
    }
  )
}


#' @keywords internal
write_gitignore <- function(path) {
  content <- c(
    "# R specific",
    ".Rproj.user",
    ".Rhistory",
    ".RData",
    ".Ruserdata",
    "",
    "# Package specific",
    "*.Rcheck",
    "*.tar.gz",
    "",
    "# IDE",
    ".idea/",
    "*.swp",
    "*~",
    "",
    "# OS specific",
    ".DS_Store",
    "Thumbs.db",
    "",
    "# pkgdown",
    "docs/",
    "",
    "# Temporary files",
    "inst/doc"
  )

  invisible(writeLines(content, file.path(path, ".gitignore")))
}


#' @keywords internal
write_rbuildignore <- function(path) {
  content <- c(
    "^.*\\.Rproj$",
    "^\\.Rproj\\.user$",
    "^README\\.Rmd$",
    "^LICENSE\\.md$",
    "^\\.github$",
    "^data-raw$",
    "^docs$",
    "^pkgdown$",
    "^_pkgdown\\.yml$",
    "^\\.lintr$",
    "^codecov\\.yml$"
  )

  invisible(writeLines(content, file.path(path, ".Rbuildignore")))
}


#' @keywords internal
write_github_workflows <- function(path) {
  mkdir(file.path(path, ".github", "workflows"))

  check_workflow <- c(
    paste0(
      "# Workflow derived from ",
      "https://github.com/r-lib/actions/tree/v2/examples"
    ),
    paste0(
      "# Need help debugging build failures? ",
      "Start at https://github.com/r-lib/actions#where-to-find-help"
    ),
    "",
    "on:",
    "  push:",
    "    branches: [main, master]",
    "  pull_request:",
    "    branches: [main, master]",
    "",
    "name: R-CMD-check",
    "",
    "jobs:",
    "  R-CMD-check:",
    "    runs-on: ${{ matrix.config.os }}",
    "",
    "    name: ${{ matrix.config.os }} (${{ matrix.config.r }})",
    "",
    "    strategy:",
    "      fail-fast: false",
    "      matrix:",
    "        config:",
    "          - {os: macos-latest,   r: 'release'}",
    "          - {os: windows-latest, r: 'release'}",
    "          - {os: ubuntu-latest,  r: 'devel', http-user-agent: 'release'}",
    "          - {os: ubuntu-latest,  r: 'release'}",
    "          - {os: ubuntu-latest,  r: 'oldrel-1'}",
    "",
    "    env:",
    "      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}",
    "      R_KEEP_PKG_SOURCE: yes",
    "",
    "    steps:",
    "      - uses: actions/checkout@v4",
    "",
    "      - uses: r-lib/actions/setup-pandoc@v2",
    "",
    "      - uses: r-lib/actions/setup-r@v2",
    "        with:",
    "          r-version: ${{ matrix.config.r }}",
    "          http-user-agent: ${{ matrix.config.http-user-agent }}",
    "          use-public-rspm: true",
    "",
    "      - uses: r-lib/actions/setup-r-dependencies@v2",
    "        with:",
    "          extra-packages: any::rcmdcheck",
    "          needs: check",
    "",
    "      - uses: r-lib/actions/check-r-package@v2",
    "        with:",
    "          upload-snapshots: true"
  )
  writeLines(
    check_workflow,
    file.path(path, ".github", "workflows", "R-CMD-check.yaml")
  )

  pkgdown_workflow <- c(
    paste0(
      "# Workflow derived from ",
      "https://github.com/r-lib/actions/tree/v2/examples"
    ),
    paste0(
      "# Need help debugging build failures? ",
      "Start at https://github.com/r-lib/actions#where-to-find-help"
    ),
    "",
    "on:",
    "  push:",
    "    branches: [main, master]",
    "  pull_request:",
    "    branches: [main, master]",
    "  release:",
    "    types: [published]",
    "  workflow_dispatch:",
    "",
    "name: pkgdown",
    "",
    "jobs:",
    "  pkgdown:",
    "    runs-on: ubuntu-latest",
    "    # Only restrict concurrency for non-PR jobs",
    "    concurrency:",
    paste0(
      "      group: pkgdown-${{ github.event_name",
      " != 'pull_request' || github.run_id }}"
    ),
    "    env:",
    "      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}",
    "    permissions:",
    "      contents: write",
    "    steps:",
    "      - uses: actions/checkout@v4",
    "",
    "      - uses: r-lib/actions/setup-pandoc@v2",
    "",
    "      - uses: r-lib/actions/setup-r@v2",
    "        with:",
    "          use-public-rspm: true",
    "",
    "      - uses: r-lib/actions/setup-r-dependencies@v2",
    "        with:",
    "          extra-packages: any::pkgdown, local::.",
    "          needs: website",
    "",
    "      - name: Build site",
    paste0(
      "        run: pkgdown::build_site_github_pages",
      "(new_process = FALSE, install = FALSE)"
    ),
    "        shell: Rscript {0}",
    "",
    "      - name: Deploy to GitHub pages",
    "        if: github.event_name != 'pull_request'",
    "        uses: JamesIves/github-pages-deploy-action@v4.5.0",
    "        with:",
    "          clean: false",
    "          branch: gh-pages",
    "          folder: docs"
  )
  invisible(writeLines(
    pkgdown_workflow,
    file.path(path, ".github", "workflows", "pkgdown.yaml")
  ))
}


#' @keywords internal
new_project_setup_atlas_repo <- function(dir, ...) {
  params <- list(...)
  atlas_name <- params$atlas_name

  setup_atlas_repo(
    path = dir,
    atlas_name = atlas_name,
    open = FALSE,
    rstudio = TRUE
  )
}
