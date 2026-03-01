# FreeSurfer check ----

#' Check if FS can be run
#' @param abort logical. If function should error
#'     if Freesurfer is not installed. Defaults to FALSE.
#' @return logical
#' @keywords internal
check_fs <- function(abort = FALSE) {
  x <- freesurfer::have_fs()

  if (!x) {
    msg <- paste0(
      "System does not have Freesurfer or ",
      "Freesurfer has not been setup correctly.\n",
      "Aborting.\n"
    )
    if (abort) {
      cli::cli_abort(msg)
    }
    cli::cli_alert_danger(msg)
  }
  invisible(x)
}


# FreeSurfer command wrappers ----

#' Convert volume to surface
#'
#' @param input_file input volume
#' @template output_file
#' @template hemisphere
#' @param projfrac single cortical depth fraction (0-1). Ignored if
#'   `projfrac_range` is provided.
#' @param projfrac_range numeric vector `c(min, max, delta)` for multi-depth
#'   projection via `--projfrac-max`. Takes the maximum value across depths,
#'   giving much better coverage for volumetric parcellations.
#' @template verbose
#' @template opts
#' @importFrom freesurfer get_fs
#' @noRd
mri_vol2surf <- function(
  input_file,
  output_file,
  hemisphere,
  projfrac = .5,
  projfrac_range = NULL,
  mni152reg = TRUE,
  opts = NULL,
  verbose = get_verbose() # nolint: object_usage_linter
) {
  check_fs(abort = TRUE)

  fs_cmd <- "mri_vol2surf"

  if (!is.null(opts)) {
    fs_cmd <- paste(fs_cmd, opts)
  }

  cmd <- paste(
    fs_cmd,
    "--mov", shQuote(input_file),
    "--o", shQuote(output_file)
  )

  if (mni152reg) {
    cmd <- paste(cmd, "--mni152reg")
  }

  hemisphere <- match.arg(hemisphere, c("lh", "rh"))
  cmd <- paste(cmd, "--hemi", hemisphere)

  if (!is.null(projfrac_range)) {
    cmd <- paste(
      cmd, "--projfrac-max",
      projfrac_range[1], projfrac_range[2], projfrac_range[3]
    )
  } else {
    cmd <- paste(cmd, "--projfrac", projfrac)
  }

  suppressWarnings(
    k <- run_cmd(cmd, verbose = verbose)
  )

  invisible(k)
}


#' Run pre-tesselation on file
#'
#' @param template template mgz
#' @param label label to run
#' @template output_file
#' @template verbose
#' @template opts
#' @importFrom freesurfer get_fs
#' @noRd
mri_pretess <- function(
  template,
  label,
  output_file,
  verbose = get_verbose(), # nolint: object_usage_linter
  opts = NULL
) {
  check_fs(abort = TRUE)

  fscmd <- "mri_pretess"

  if (!is.null(opts)) {
    fscmd <- paste(fscmd, opts)
  }

  label <- as.integer(label)
  cmd <- paste(
    fscmd, shQuote(template), label,
    shQuote(template), shQuote(output_file)
  )

  run_cmd(cmd, verbose = verbose)
}


#' Tesselate data
#'
#' @param label label to run
#' @template verbose
#' @template output_file
#' @param input_file input file
#' @template opts
#' @importFrom freesurfer get_fs
#' @noRd
mri_tessellate <- function(
  input_file,
  label,
  output_file,
  verbose,
  opts = NULL
) {
  check_fs(abort = TRUE)

  fscmd <- "mri_tessellate"

  if (!is.null(opts)) {
    fscmd <- paste(fscmd, opts)
  }

  label <- as.integer(label)
  cmd <- paste(fscmd, shQuote(input_file), label, shQuote(output_file))

  run_cmd(cmd, verbose = verbose)
}


#' Smooth data
#'
#' @param input_file input file to smooth
#' @template output_file
#' @template verbose
#' @template opts
#' @importFrom freesurfer get_fs
#' @noRd
mri_smooth <- function(input_file, output_file, verbose, opts = NULL) {
  check_fs(abort = TRUE)

  fscmd <- "mris_smooth"
  if (!is.null(opts)) {
    fscmd <- paste(fscmd, opts)
  }

  cmd <- paste(
    fscmd,
    "-nw",
    shQuote(normalizePath(input_file, mustWork = FALSE)),
    shQuote(normalizePath(output_file, mustWork = FALSE))
  )

  k <- run_cmd(cmd, verbose = verbose)
  invisible(k)
}


#' Re-register an annotation file
#'
#' Annotation files are subject specific.
#' Most are registered for fsaverage, but
#' we recommend using fsaverage5 for the mesh
#' plots in ggseg3d, as these contain a decent
#' balance in number of vertices for detailed
#' rendering and speed.
#'
#' @param subject subject the original annotation file is registered to
#' @param annot annotation file name (as found in subjects_dir)
#' @param hemi hemisphere (one of "lh" or "rh")
#' @param target_subject subject to re-register the annotation
#'   (default fsaverage5)
#' @template output_dir
#' @template verbose
#' @importFrom freesurfer get_fs
#' @return nothing
#' @export
#' @examples
#' \dontrun{
#' # For help see:
#' freesurfer::fs_help("mri_surf2surf")
#'
#' mri_surf2surf_rereg(
#'   subject = "bert",
#'   annot = "aparc.DKTatlas",
#'   target_subject = "fsaverage5"
#' )
#' }
mri_surf2surf_rereg <- function(
  subject,
  annot,
  hemi = c("lh", "rh"),
  target_subject = "fsaverage5",
  output_dir = file.path(fs_subj_dir(), subject, "label"),
  verbose = get_verbose() # nolint: object_usage_linter
) {
  check_fs(abort = TRUE)

  hemi <- match.arg(hemi, c("lh", "rh"))

  mkdir(output_dir)

  fscmd <- "mri_surf2surf"

  cmd <- paste(
    fscmd,
    "--srcsubject", shQuote(subject),
    "--sval-annot", shQuote(annot),
    "--trgsubject", shQuote(target_subject),
    "--tval", shQuote(file.path(output_dir, paste(hemi, annot, sep = "."))),
    "--hemi", hemi
  )

  run_cmd(cmd, verbose = verbose)
}


# Surface/curvature to ASCII ----

#' Convert Freesurfer surface file to ascii
#'
#' @param input_file path to input surface file to convert
#' @template output_file
#' @template verbose
#' @importFrom freesurfer get_fs
#' @return ascii data
#' @noRd
surf2asc <- function(input_file, output_file, verbose = get_verbose()) {
  check_fs(abort = TRUE)

  ext <- tools::file_ext(output_file)
  if (ext != "dpv") {
    cli::cli_abort("{.arg output_file} must end with {.file .dpv}")
  }

  if (!file.exists(input_file)) {
    if (verbose) {
      cli::cli_warn(
        "Input file does not exist: {.file {input_file}}"
      )
    }
    return(invisible(NULL))
  }

  old_fs_verbose <- options(freesurfer.verbose = (verbose >= 2))
  on.exit(options(old_fs_verbose), add = TRUE)

  freesurfer::mris_convert(
    infile = input_file,
    outfile = gsub("\\.dpv", "\\.asc", output_file),
    verbose = (verbose >= 2)
  )

  asc_path <- gsub("\\.dpv", "\\.asc", output_file)
  if (!file.rename(asc_path, output_file)) {
    cli::cli_abort(
      "Failed to rename {.path {asc_path}} to {.path {output_file}}"
    )
  }

  read_dpv(output_file)
}
