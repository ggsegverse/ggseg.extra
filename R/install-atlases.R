#' List available ggseg atlas packages
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function has moved to the ggseg.hub package. Please use
#' [ggseg.hub::ggseg_atlas_repos()] instead.
#'
#' @inheritParams ggseg.hub::ggseg_atlas_repos
#' @return A data.frame of available atlas packages.
#' @export
ggseg_atlas_repos <- function(pattern = NULL, ...) {
  lifecycle::deprecate_warn(
    "2.0.0",
    "ggseg.extra::ggseg_atlas_repos()",
    "ggseg.hub::ggseg_atlas_repos()"
  )
  rlang::check_installed("ggseg.hub", reason = "for atlas discovery functions")
  ggseg.hub::ggseg_atlas_repos(pattern = pattern, ...)
}


#' Install a ggseg atlas package
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function has moved to the ggseg.hub package. Please use
#' [ggseg.hub::install_ggseg_atlas()] instead.
#'
#' @inheritParams ggseg.hub::install_ggseg_atlas
#' @param repos Repository URLs to install from.
#' @return None, called for side effects (package installation).
#' @export
install_ggseg_atlas <- function(
  package,
  repos = c(
    ggsegverse = "https://ggsegverse.r-universe.dev",
    getOption("repos")
  ),
  ...
) {
  lifecycle::deprecate_warn(
    "2.0.0",
    "ggseg.extra::install_ggseg_atlas()",
    "ggseg.hub::install_ggseg_atlas()"
  )
  rlang::check_installed(
    "ggseg.hub",
    reason = "for atlas installation functions"
  )
  ggseg.hub::install_ggseg_atlas(package = package, repos = repos, ...)
}


#' Install all available ggseg atlas packages
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function has moved to the ggseg.hub package. Please use
#' [ggseg.hub::install_ggseg_atlas_all()] instead.
#'
#' @inheritParams ggseg.hub::install_ggseg_atlas_all
#' @param repos Repository URLs to install from.
#' @return None, called for side effects (package installation).
#' @export
install_ggseg_atlas_all <- function(
  repos = c(
    ggsegverse = "https://ggsegverse.r-universe.dev",
    getOption("repos")
  ),
  ...
) {
  lifecycle::deprecate_warn(
    "2.0.0",
    "ggseg.extra::install_ggseg_atlas_all()",
    "ggseg.hub::install_ggseg_atlas_all()"
  )
  rlang::check_installed(
    "ggseg.hub",
    reason = "for atlas installation functions"
  )
  ggseg.hub::install_ggseg_atlas_all(repos = repos, ...)
}
