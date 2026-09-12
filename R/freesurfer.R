# FreeSurfer check ----

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
#' @param hemisphere hemisphere (one of "lh" or "rh")
#' @param target_subject subject to re-register the annotation
#'   (default fsaverage5)
#' @template output_dir
#' @template verbose
#' @param hemi `r lifecycle::badge("deprecated")` Use `hemisphere` instead.
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
  hemisphere = c("lh", "rh"),
  target_subject = "fsaverage5",
  output_dir = as.character(fs::path(
    freesurfer::fs_subj_dir(),
    subject,
    "label"
  )),
  verbose = get_verbose(), # nolint: object_usage_linter
  hemi = lifecycle::deprecated()
) {
  check_fs(abort = TRUE)

  if (lifecycle::is_present(hemi)) {
    lifecycle::deprecate_warn(
      "1.9.9.9005",
      "mri_surf2surf_rereg(hemi = )",
      "mri_surf2surf_rereg(hemisphere = )"
    )
    hemisphere <- hemi
  }
  hemisphere <- match.arg(hemisphere, c("lh", "rh"))

  mkdir(output_dir)

  fscmd <- "mri_surf2surf"

  cmd <- paste(
    fscmd,
    "--srcsubject",
    shQuote(subject),
    "--sval-annot",
    shQuote(annot),
    "--trgsubject",
    shQuote(target_subject),
    "--tval",
    shQuote(as.character(fs::path(
      output_dir,
      paste(hemisphere, annot, sep = ".")
    ))),
    "--hemi",
    hemisphere
  )

  run_cmd(cmd, verbose = verbose)
}

# The CRAN release lacks what the pipelines use (`fs_sitrep()`,
# `fs_cmd(validate_inputs = )`), so a bare presence check passes on it and the
# pipeline fails later. CRAN is also why installs go through r-universe.
#' @noRd
freesurfer_min_version <- function() {
  "1.8.1.902"
}

#' @noRd
freesurfer_repos <- function() {
  c(ggsegverse = "https://ggsegverse.r-universe.dev", getOption("repos"))
}

#' Check if FS can be run
#' @param abort logical. If function should error
#'     if Freesurfer is not installed. Defaults to FALSE.
#' @return logical
#' @keywords internal
#' @noRd
check_fs <- function(abort = FALSE) {
  rlang::check_installed(
    "freesurfer",
    version = freesurfer_min_version(),
    reason = "to interact with FreeSurfer",
    action = function(...) {
      utils::install.packages("freesurfer", repos = freesurfer_repos())
    }
  )
  x <- freesurfer::have_fs()

  if (!x) {
    msg <- "System does not have Freesurfer or Freesurfer has not been setup
      correctly. Aborting."
    if (abort) {
      cli::cli_abort(msg)
    }
    cli::cli_alert_danger(msg, wrap = TRUE)
  }
  invisible(x)
}


# Registration ----

#' Path to FreeSurfer's MNI152-to-MNI305 registration
#'
#' `mni152.register.dat` maps FSL/SPM MNI152 scanner RAS onto the MNI305
#' space that `fsaverage` and its downsampled subjects live in.
#' @noRd
mni152_register_path <- function() {
  as.character(
    fs::path(freesurfer::fs_dir(), "average", "mni152.register.dat")
  )
}


#' Translate a registration specification into `mri_vol2surf` flags
#'
#' @param registration One of `"mni152"`, `"header"`, or a path to a
#'   register.dat or LTA file.
#' @param subject Subject whose surfaces the volume is sampled onto.
#' @return List with elements `reg`, `srcsubject` and `regheader`, each
#'   either a string or NULL.
#' @noRd
resolve_vol2surf_registration <- function(registration, subject) {
  if (
    !is.character(registration) ||
      length(registration) != 1L ||
      is.na(registration)
  ) {
    cli::cli_abort(c(
      "{.arg registration} must be a single string.",
      "i" = "Use {.val mni152}, {.val header}, or a path to a registration file." # nolint
    ))
  }

  if (identical(registration, "header")) {
    return(list(reg = NULL, srcsubject = NULL, regheader = subject))
  }

  is_mni152 <- identical(registration, "mni152")
  reg_file <- if (is_mni152) mni152_register_path() else registration

  if (dir.exists(reg_file)) {
    cli::cli_abort(c(
      "{.arg registration} must be a file, not a directory: {.path {reg_file}}",
      "i" = "Give a register.dat or LTA file, {.val mni152}, or {.val header}."
    ))
  }

  if (!file.exists(reg_file)) {
    cli::cli_abort(c(
      "Registration file not found: {.path {reg_file}}",
      "i" = if (is_mni152) {
        "Is {.envvar FREESURFER_HOME} pointing at a complete installation?"
      } else {
        "Give a register.dat or LTA file, {.val mni152}, or {.val header}."
      }
    ))
  }

  list(reg = reg_file, srcsubject = subject, regheader = NULL)
}


#' Voxel-to-RAS matrix of a subject's conformed volume
#'
#' @return The 4x4 matrix, or NULL when the volume cannot be read.
#' @noRd
subject_vox2ras <- function(subject, subjects_dir = freesurfer::fs_subj_dir()) {
  orig <- as.character(fs::path(subjects_dir, subject, "mri", "orig.mgz"))
  if (!file.exists(orig)) {
    return(NULL)
  }
  read_vox2ras(orig, "mgz")
}


#' Direction and scale block of a volume's voxel-to-RAS matrix
#' @noRd
volume_direction_block <- function(input_volume) {
  ext <- tolower(tools::file_ext(input_volume))
  if (ext == "gz") {
    ext <- tools::file_ext(sub("\\.gz$", "", input_volume))
  }
  # Advisory geometry probe: a header the reader cannot parse must leave the
  # space unknown rather than surface that reader's own warnings.
  vox2ras <- tryCatch(
    suppressWarnings(read_vox2ras(input_volume, ext)),
    error = function(e) NULL
  )
  if (is.null(vox2ras)) {
    return(NULL)
  }
  vox2ras[1:3, 1:3]
}


#' Check that FreeSurfer's MNI152 transform applies to a subject
#'
#' `mni152.register.dat` is registered against `fsaverage`. It is meaningful
#' for subjects sharing fsaverage's conformed geometry, which the
#' downsampled `fsaverageN` subjects do, and wrong for anyone else.
#' @noRd
check_mni152_subject <- function(subject) {
  if (identical(subject, "fsaverage")) {
    return(invisible(TRUE))
  }

  reference <- subject_vox2ras("fsaverage")
  candidate <- subject_vox2ras(subject)

  if (is.null(reference) || is.null(candidate)) {
    cli::cli_warn(c(
      "Could not confirm that {.val {subject}} shares fsaverage's geometry.",
      "i" = "{.file mni152.register.dat} is registered against
        {.val fsaverage}."
    ))
    return(invisible(NA))
  }

  if (!isTRUE(all.equal(reference, candidate, tolerance = 1e-4))) {
    cli::cli_abort(c(
      "{.val mni152} registration does not apply to subject {.val {subject}}.",
      "x" = "{.file mni152.register.dat} is registered against
        {.val fsaverage}, and {.val {subject}} does not share its conformed
        geometry.",
      "i" = "Supply your own register.dat or LTA file as {.arg registration}."
    ))
  }

  invisible(TRUE)
}


#' Warn when a volume is already in the surface subject's own space
#'
#' A volume sharing the subject's conformed voxel grid is native or
#' fsaverage-space rather than an MNI152 template, and registering it as
#' MNI152 gives an atlas that looks plausible but is displaced.
#' @noRd
warn_if_subject_space_volume <- function(input_volume, subject) {
  volume <- volume_direction_block(input_volume)
  conformed <- subject_vox2ras(subject)

  if (is.null(volume) || is.null(conformed)) {
    return(invisible(FALSE))
  }
  if (!isTRUE(all.equal(conformed[1:3, 1:3], volume, tolerance = 1e-4))) {
    return(invisible(FALSE))
  }

  cli::cli_warn(c(
    "{.path {input_volume}} shares {.val {subject}}'s conformed voxel grid.",
    "!" = "{.code registration = \"mni152\"} treats it as an MNI152 template.
      If it is a native, conformed or fsaverage-space volume the atlas will
      be displaced by roughly 2 mm and still look plausible.",
    "i" = "Use {.code registration = \"header\"} for volumes already in the
      target subject's own scanner RAS."
  ))
  invisible(TRUE)
}


#' Validate a registration specification against its subject and volume
#'
#' Checks what the headers can reveal before a long pipeline starts: that
#' the specification resolves, that FreeSurfer's MNI152 transform applies to
#' the subject, and that the volume does not look like it is already in the
#' subject's own space.
#' @noRd
validate_registration <- function(registration, subject, input_volume = NULL) {
  resolved <- resolve_vol2surf_registration(registration, subject)

  if (identical(registration, "mni152")) {
    check_mni152_subject(subject)
    if (!is.null(input_volume)) {
      warn_if_subject_space_volume(input_volume, subject)
    }
  }

  invisible(resolved)
}


#' Check that the registration flags form a usable combination
#' @noRd
validate_vol2surf_flags <- function(reg, srcsubject, regheader) {
  if (!is.null(reg) && !is.null(regheader)) {
    cli::cli_abort(c(
      "{.arg reg} and {.arg regheader} cannot both be given.",
      "i" = "{.code mri_vol2surf} takes one registration, not two."
    ))
  }

  if (!is.null(reg) && is.null(srcsubject)) {
    cli::cli_abort(c(
      "{.arg srcsubject} is required when {.arg reg} is given.",
      "i" = "Without it FreeSurfer samples onto {.val fsaverage} and
        resamples to the target subject, averaging labels into values the
        volume never held."
    ))
  }

  if (is.null(reg) && !is.null(srcsubject)) {
    cli::cli_abort(
      "{.arg srcsubject} only applies together with {.arg reg}."
    )
  }

  invisible(TRUE)
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
#' @param reg registration file passed to `--reg`. Requires `srcsubject`.
#' @param srcsubject subject the registration resolves to, passed to
#'   `--srcsubject`.
#' @param regheader subject passed to `--regheader`, for volumes already in
#'   that subject's scanner RAS.
#' @template verbose
#' @template opts
#' @noRd
mri_vol2surf <- function(
  input_file,
  output_file,
  hemisphere,
  projfrac = 0.5,
  projfrac_range = NULL,
  reg = NULL,
  srcsubject = NULL,
  regheader = NULL,
  opts = NULL,
  verbose = get_verbose() # nolint: object_usage_linter
) {
  check_fs(abort = TRUE)

  validate_vol2surf_flags(reg, srcsubject, regheader)

  fs_cmd <- "mri_vol2surf"

  if (!is.null(opts)) {
    fs_cmd <- paste(fs_cmd, opts)
  }

  cmd <- paste(
    fs_cmd,
    "--mov",
    shQuote(input_file),
    "--o",
    shQuote(output_file)
  )

  if (!is.null(reg)) {
    cmd <- paste(
      cmd,
      "--reg",
      shQuote(reg),
      "--srcsubject",
      shQuote(srcsubject)
    )
  }

  if (!is.null(regheader)) {
    cmd <- paste(cmd, "--regheader", shQuote(regheader))
  }

  hemisphere <- match.arg(hemisphere, c("lh", "rh"))
  cmd <- paste(cmd, "--hemi", hemisphere)

  if (!is.null(projfrac_range)) {
    cmd <- paste(
      cmd,
      "--projfrac-max",
      projfrac_range[1],
      projfrac_range[2],
      projfrac_range[3]
    )
  } else {
    cmd <- paste(cmd, "--projfrac", projfrac)
  }

  k <- suppressWarnings(run_cmd(cmd, verbose = verbose))

  invisible(k)
}


#' Run pre-tesselation on file
#'
#' @param template template mgz
#' @param label label to run
#' @template output_file
#' @template verbose
#' @template opts
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
    fscmd,
    shQuote(template),
    label,
    shQuote(template),
    shQuote(output_file)
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


# Surface/curvature to ASCII ----

#' Convert Freesurfer surface file to ascii
#'
#' @param input_file path to input surface file to convert
#' @template output_file
#' @template verbose
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
    outfile = gsub(".dpv", ".asc", output_file, fixed = TRUE),
    verbose = (verbose >= 2)
  )

  asc_path <- gsub(".dpv", ".asc", output_file, fixed = TRUE)
  if (!file.rename(asc_path, output_file)) {
    cli::cli_abort(
      "Failed to rename {.path {asc_path}} to {.path {output_file}}"
    )
  }

  read_dpv(output_file)
}
