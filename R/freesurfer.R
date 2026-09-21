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
  fs_home <- freesurfer::fs_dir()

  if (length(fs_home) != 1L || is.na(fs_home) || !nzchar(fs_home)) {
    cli::cli_abort(c(
      "Cannot locate FreeSurfer's MNI152 registration.",
      "x" = "FreeSurfer was not found, and {.envvar FREESURFER_HOME} is
        not set.",
      "i" = "{.code registration = \"mni152\"} needs FreeSurfer's
        {.file average/mni152.register.dat}.",
      "i" = "Use {.code registration = \"header\"}, or pass a register.dat
        or LTA file, to project without FreeSurfer's transform."
    ))
  }

  as.character(fs::path(fs_home, "average", "mni152.register.dat"))
}


#' Check that a registration specification is a single string
#' @noRd
check_registration_spec <- function(registration) {
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

  invisible(registration)
}


#' Resolve a registration specification to a readable registration file
#'
#' @param registration `"mni152"` or a path to a register.dat or LTA file.
#' @noRd
registration_file <- function(registration) {
  check_registration_spec(registration)

  is_mni152 <- identical(registration, "mni152")
  file <- if (is_mni152) mni152_register_path() else registration

  if (!file.exists(file) || dir.exists(file)) {
    cli::cli_abort(c(
      "Registration file not found: {.path {file}}",
      "i" = if (is_mni152) {
        "Is {.envvar FREESURFER_HOME} pointing at a complete installation?"
      } else {
        "Give a register.dat or LTA file, {.val mni152}, or {.val header}."
      }
    ))
  }

  file
}


#' Map a deprecated `registration = NULL` onto the word it used to mean
#'
#' `NULL` meant "apply the MNI152 transform" in one exported function and
#' "trust the header" in another -- opposite instructions under one spelling.
#' Each caller names the word its own `NULL` stood for, so existing code keeps
#' working while the vocabulary converges.
#' @noRd
registration_from_null <- function(registration, meant) {
  if (!is.null(registration)) {
    return(registration)
  }

  lifecycle::deprecate_warn(
    "1.9.9.9038",
    I("registration = NULL"),
    details = paste0("Use registration = \"", meant, "\" instead.")
  )
  meant
}


#' Normalise a registration specification into what it actually is
#'
#' One vocabulary -- `"mni152"`, `"header"`, or a path to a register.dat or
#' LTA file -- resolved in one place, so the exported functions cannot drift
#' into meaning different things by the same word. `"mni152"` is a named
#' shorthand for a file, so it and a user-supplied path collapse to the same
#' `"file"` kind here; only `"header"` is a genuinely different instruction.
#'
#' @param registration One of `"mni152"`, `"header"`, or a path.
#' @return `list(kind = "header" | "file", path = NULL | <file>)`.
#' @noRd
resolve_registration <- function(registration) {
  check_registration_spec(registration)

  if (identical(registration, "header")) {
    return(list(kind = "header", path = NULL))
  }

  list(kind = "file", path = registration_file(registration))
}


#' Translate a registration specification into `mri_vol2surf` flags
#'
#' The flags come as a set because they constrain one another. `--reg`
#' always travels with `--srcsubject`: without it `mri_vol2surf` samples onto
#' `fsaverage` and then reaches the target subject through `mri_surf2surf`
#' nearest-neighbour averaging, which turns integer labels into fractional
#' values the volume never held. `--regheader` is the other way of saying
#' where the volume already sits, and so never accompanies `--reg`.
#'
#' @param registration One of `"mni152"`, `"header"`, or a path to a
#'   register.dat or LTA file.
#' @param subject Subject whose surfaces the volume is sampled onto.
#' @noRd
resolve_vol2surf_registration <- function(registration, subject) {
  spec <- resolve_registration(registration)

  if (identical(spec$kind, "header")) {
    return(list(reg = NULL, srcsubject = NULL, regheader = subject))
  }

  list(
    reg = spec$path,
    srcsubject = subject,
    regheader = NULL
  )
}


#' Translate a registration specification into the `mri_vol2vol` option
#'
#' `mri_vol2vol` says the same two things as `mri_vol2surf` with one option
#' rather than a set: `--regheader` for a volume already on the target's grid,
#' `--reg <file>` otherwise.
#' @noRd
vol2vol_registration_opt <- function(registration) {
  spec <- resolve_registration(registration)

  if (identical(spec$kind, "header")) {
    return("--regheader")
  }

  paste("--reg", shQuote(spec$path))
}


#' Voxel-to-RAS matrix of a subject's conformed volume
#' @noRd
subject_vox2ras <- function(subject, subjects_dir = freesurfer::fs_subj_dir()) {
  orig <- as.character(fs::path(subjects_dir, subject, "mri", "orig.mgz"))
  if (!file.exists(orig)) {
    return(NULL)
  }
  read_vox2ras(orig)
}


#' Voxel-to-RAS matrix of a volume, or NULL when its header cannot be read
#'
#' Advisory probe: a header the reader cannot parse leaves the space unknown
#' rather than surfacing that reader's own warnings.
#' @noRd
volume_vox2ras <- function(input_volume) {
  if (!file.exists(input_volume)) {
    return(NULL)
  }

  vox2ras <- tryCatch(
    suppressWarnings(read_vox2ras(input_volume)),
    error = function(e) NULL
  )

  # A reader handed an unreadable file can return a default header whose
  # matrix is all zeros, which would otherwise read as a valid orientation.
  if (is.null(vox2ras) || det(vox2ras[1:3, 1:3]) == 0) {
    return(NULL)
  }

  vox2ras
}


#' Do two volumes sit on the same voxel grid?
#' @noRd
same_geometry <- function(a, b) {
  !is.null(a) && !is.null(b) && isTRUE(all.equal(a, b, tolerance = 1e-4))
}


#' Check that FreeSurfer's MNI152 transform applies to a subject
#'
#' `mni152.register.dat` is registered against `fsaverage`. It is meaningful
#' for subjects sharing fsaverage's conformed geometry, which the downsampled
#' `fsaverageN` subjects do, and wrong for anyone else.
#' @noRd
check_mni152_subject <- function(subject) {
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

  if (!same_geometry(reference, candidate)) {
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


#' Warn when a volume already sits on the surface subject's own voxel grid
#'
#' Grid identity is the one claim a header supports: a volume on the
#' subject's exact grid is in that subject's space, not an MNI152 template,
#' and registering it as one displaces the atlas while it still looks
#' plausible. A volume in some other non-MNI152 space cannot be recognised.
#' @noRd
#' Stop when mni152.register.dat does not apply to this volume's grid
#'
#' `mni152.register.dat` is a tkregister matrix, and tkreg coordinates are
#' derived from the volume's own voxel order, size and field of view. It is
#' therefore exact only for the 1 mm left-handed (LAS) MNI152 grid it was
#' built for. On a right-handed volume it mirrors left and right outright; on
#' an LAS volume of another resolution it mislocates by a few per cent of
#' vertices (7.7% measured at 1.5 mm, ~28% at 4 mm, against the same volume
#' resampled to 1 mm first). Both produce an atlas that still looks
#' plausible, so this refuses rather than warns.
#' @noRd
check_mni152_grid <- function(input_volume) {
  vox2ras <- volume_vox2ras(input_volume)

  if (is.null(vox2ras)) {
    return(invisible(NA))
  }

  voxel_sizes <- sqrt(colSums(vox2ras[1:3, 1:3]^2))
  handed <- det(vox2ras[1:3, 1:3]) < 0
  millimetre <- all(abs(voxel_sizes - 1) < 0.01)

  if (handed && millimetre) {
    return(invisible(TRUE))
  }

  cli::cli_abort(c(
    "{.val mni152} registration does not apply to {.path {input_volume}}.",
    "x" = if (handed) {
      "{.file mni152.register.dat} is built for a 1 mm grid, and this volume
        has {.val {round(voxel_sizes, 3)}} mm voxels: applying it shifts
        regions off their anatomy."
    } else {
      "{.file mni152.register.dat} assumes a left-handed (LAS) voxel order,
        and this volume is right-handed (RAS): applying it swaps left and
        right."
    },
    "i" = "Either way the atlas still looks plausible, so this is refused
      rather than warned about.",
    "i" = "Use {.code registration = \"header\"}, or resample the volume onto
      the 1 mm LAS MNI152 grid first."
  ))
}


warn_if_subject_space_volume <- function(input_volume, subject) {
  if (!same_geometry(volume_vox2ras(input_volume), subject_vox2ras(subject))) {
    return(invisible(FALSE))
  }

  cli::cli_warn(c(
    "{.path {input_volume}} sits on {.val {subject}}'s own voxel grid.",
    "!" = "{.code registration = \"mni152\"} treats it as an MNI152 template,
      which displaces the atlas by roughly 2 mm in a way that still looks
      plausible.",
    "i" = "Use {.code registration = \"header\"} for a volume already in the
      target subject's own scanner RAS."
  ))
  invisible(TRUE)
}


#' Validate a registration specification against its subject and volume
#'
#' Runs the checks that cost nothing before a long pipeline starts: that the
#' specification is a single string, and that a user-supplied registration
#' file exists. FreeSurfer's own `mni152.register.dat` is deliberately left
#' to the projection step, so a run that never projects, because its
#' projection is cached or its steps exclude it, needs no FreeSurfer
#' installation. The subject and volume space checks need FreeSurfer to read
#' geometries at all, and are skipped when it is absent.
#' @noRd
validate_registration <- function(registration, subject, input_volume = NULL) {
  check_registration_spec(registration)

  if (identical(registration, "header")) {
    return(invisible(NULL))
  }

  if (!identical(registration, "mni152")) {
    registration_file(registration)
    return(invisible(NULL))
  }

  # FreeSurfer's own transform is resolved at projection time, so a pipeline
  # whose projection is cached or skipped needs no FreeSurfer installation.
  if (!is.null(input_volume)) {
    check_mni152_grid(input_volume)
  }

  if (freesurfer::have_fs()) {
    check_mni152_subject(subject)
    if (!is.null(input_volume)) {
      warn_if_subject_space_volume(input_volume, subject)
    }
  }

  invisible(NULL)
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
  verbose = get_verbose(), # nolint: object_usage_linter
  projfrac_range = NULL,
  reg = NULL,
  srcsubject = NULL,
  regheader = NULL,
  opts = NULL
) {
  check_fs(abort = TRUE)

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
