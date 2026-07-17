#' Create a new ggseg atlas package
#'
#' Scaffold an R package for distributing a brain atlas. Downloads a
#' modern template from the
#' [ggseg-atlas-template](https://github.com/ggsegverse/ggseg-atlas-template)
#' GitHub repository and customises it for your atlas. The generated
#' package follows ggseg conventions and includes GitHub Actions workflows,
#' pkgdown configuration, a test suite, and a multi-method scaffold for
#' building your atlas.
#'
#' The package will be named `ggseg{AtlasName}` (e.g., `ggsegSchaefer` for
#' a Schaefer parcellation). After creation, edit the files in `data-raw/`
#' to build your atlas, then run `devtools::document()` and `devtools::check()`.
#'
#' If the template cannot be downloaded (e.g. no internet), a minimal bundled
#' fallback is used instead. The fallback omits GitHub Actions workflows; you
#' can copy them from the template repository later.
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

  atlas_name <- atlas_name_from_path(path, atlas_name)
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

  cli::cli_h2("Creating {.pkg {repo_name}}")

  template_dir <- download_atlas_template()
  populate_from_template(path, template_dir, atlas_name, repo_name)

  if (rstudio) {
    create_rproj_file(path, repo_name)
    cli::cli_alert_success("Created {.file {repo_name}.Rproj}")
  }

  report_atlas_repo_created(repo_name, path)

  if (open && rstudio) {
    open_rstudio_project(path)
  }

  invisible(path)
}

#' RStudio project template binding
#'
#' Backs the "Create ggseg brain atlas" entry in the RStudio New Project wizard,
#' declared in `inst/rstudio/templates/project/create-ggseg-atlas.dcf`. RStudio
#' resolves the `Binding:` field against the package's exports, so this must be
#' exported even though it is not meant to be called directly — use
#' [setup_atlas_repo()] instead.
#'
#' @param dir Directory RStudio creates for the new project.
#' @param ... Template parameters supplied by the wizard, notably `atlas_name`.
#' @return Invisible `NULL`, called for its side effects.
#' @keywords internal
#' @export
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


#' Clean an atlas name, deriving it from the directory name when absent
#' @noRd
atlas_name_from_path <- function(path, atlas_name) {
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
  gsub("[^a-z0-9]", "", atlas_name)
}


#' Report the created package and the next steps for the user
#' @noRd
report_atlas_repo_created <- function(repo_name, path) {
  cli::cli_rule()
  cli::cli_alert_success("Created atlas package {.pkg {repo_name}}")
  cli::cli_alert_info("Location: {.path {path}}")

  cli::cli_h3("Next steps")
  cli::cli_bullets(c(
    "1" = "Edit {.file data-raw/create-atlas.R} to create your atlas",
    "2" = "Update {.file R/data.R} with documentation and citation",
    "3" = "Add atlas citation to {.file README.qmd}",
    "4" = "Run {.code devtools::document()} to generate documentation",
    "5" = "Run {.code devtools::check()} to verify the package"
  ))

  invisible(NULL)
}


template_url <- function() {
  paste0(
    "https://github.com/ggsegverse/ggseg-atlas-template/",
    "archive/refs/heads/main.tar.gz"
  )
}


#' @keywords internal
#' @noRd
download_atlas_template <- function(url = template_url()) {
  tmp_tar <- tempfile(fileext = ".tar.gz")
  tmp_dir <- tempfile("ggseg-template-")

  cli::cli_alert_info("Downloading atlas template from GitHub...")

  ok <- tryCatch(
    {
      utils::download.file(url, tmp_tar, quiet = TRUE, mode = "wb")
      TRUE
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )

  if (ok && file.exists(tmp_tar) && file.size(tmp_tar) > 0) {
    utils::untar(tmp_tar, exdir = tmp_dir)
    unlink(tmp_tar)
    extracted <- list.dirs(tmp_dir, full.names = TRUE, recursive = FALSE)
    if (length(extracted) == 1) {
      cli::cli_alert_success("Downloaded template")
      return(extracted)
    }
  }

  cli::cli_alert_warning(
    "Download failed, using bundled fallback template"
  )
  cli::cli_alert_info(
    "Workflows not included \u2014 copy from
    {.url https://github.com/ggsegverse/ggseg-atlas-template}",
    wrap = TRUE
  )

  fallback <- system.file(
    "templates",
    "atlas-fallback",
    package = "ggseg.extra"
  )

  if (!dir.exists(fallback)) {
    cli::cli_abort(c(
      "Template not found",
      "x" = "Could not download template or find bundled fallback",
      "i" = "Is ggseg.extra installed correctly?"
    ))
  }

  fallback
}


#' @keywords internal
#' @noRd
populate_from_template <- function(path, template_dir, atlas_name, repo_name) {
  mkdir(path)
  create_template_dirs(path, template_dir)
  copy_template_files(path, template_dir)

  pkg_file <- as.character(fs::path(path, "R", "REPO-package.R"))
  if (file.exists(pkg_file)) {
    file.rename(
      pkg_file,
      as.character(fs::path(path, "R", paste0(repo_name, "-package.R")))
    )
  }

  replace_template_placeholders(path, atlas_name)

  invisible(path)
}


#' @keywords internal
#' @noRd
create_template_dirs <- function(path, template_dir) {
  dirs <- list.dirs(template_dir, full.names = FALSE, recursive = TRUE)
  dirs <- dirs[nchar(dirs) > 0 & !grepl("^\\.", dirs)]
  for (d in dirs) {
    mkdir(as.character(fs::path(path, d)))
  }
  cli::cli_alert_success(
    "Created {.path R/}, {.path tests/}, {.path data-raw/}"
  )

  has_workflows <- dir.exists(as.character(fs::path(template_dir, ".github")))
  if (has_workflows) {
    dirs_hidden <- list.dirs(template_dir, full.names = FALSE, recursive = TRUE)
    dirs_hidden <- dirs_hidden[grepl("^\\.github", dirs_hidden)]
    for (d in dirs_hidden) {
      mkdir(as.character(fs::path(path, d)))
    }
    cli::cli_alert_success("Created {.path .github/workflows/}")
  }

  invisible(path)
}


#' @keywords internal
#' @noRd
copy_template_files <- function(path, template_dir) {
  files <- list.files(
    template_dir,
    recursive = TRUE,
    all.files = TRUE,
    no.. = TRUE
  )
  files <- files[!grepl("^\\.git/", files) & files != ".git"]

  for (f in files) {
    src <- as.character(fs::path(template_dir, f))
    dst_name <- gsub("(^|/)dot-", "\\1.", f)
    dst <- as.character(fs::path(path, dst_name))
    mkdir(dirname(dst))
    file.copy(src, dst, overwrite = TRUE)
  }

  invisible(path)
}


#' @keywords internal
#' @noRd
replace_template_placeholders <- function(path, atlas_name) {
  all_files <- list.files(
    path,
    full.names = TRUE,
    recursive = TRUE,
    all.files = TRUE
  )
  all_files <- all_files[
    !grepl("^\\.git/", basename(all_files)) &
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

  cli::cli_alert_success("Replaced template placeholders")

  invisible(path)
}


#' @keywords internal
#' @noRd
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

  rproj_file <- as.character(fs::path(path, paste0(repo_name, ".Rproj")))
  writeLines(rproj_content, rproj_file)

  invisible(rproj_file)
}


#' @keywords internal
#' @noRd
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
#' @noRd
rstudioapi_available <- function() {
  requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable()
}


#' @keywords internal
#' @noRd
template_replace <- function(file, atlas_name) {
  repo_name <- paste0("ggseg", tools::toTitleCase(atlas_name))

  tryCatch(
    {
      input <- readLines(file, warn = FALSE)
      output <- gsub("{GGSEG}", atlas_name, input, fixed = TRUE)
      output <- gsub("{REPO}", repo_name, output, fixed = TRUE)
      output <- gsub("{YEAR}", format(Sys.Date(), "%Y"), output, fixed = TRUE)
      writeLines(output, file)
    },
    error = function(e) {
      cli::cli_warn("Failed to process template {.file {file}}: {e$message}")
      invisible(NULL)
    }
  )
}
