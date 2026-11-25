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
#' @param output_dir Where to write the re-registered annotation. Defaults to
#'   `subject`'s own `label/` directory inside FreeSurfer's `SUBJECTS_DIR`,
#'   beside the annotation being re-registered - so the default writes into
#'   your FreeSurfer installation, not a temporary directory. Pass a path of
#'   your own to write elsewhere.
#' @template verbose
#' @return The command's exit status, invisibly. Called for the annotation
#'   file it writes to `output_dir`.
#' @export
#' @examples
#' \dontrun{
#' # For help see:
#' freesurfer::fs_help("mri_surf2surf")
#'
#' mri_surf2surf_rereg(
#'   subject = "fsaverage5",
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
  verbose = get_verbose() # nolint: object_usage_linter
) {
  check_fs(abort = TRUE)
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

  invisible(run_cmd(cmd, verbose = verbose))
}

# Releases before 1.9.0 lack `fs_sitrep()`, and lack `mri_vol2vol()` and
# `fs_flag_cmd()` entirely -- both are new in 1.9.0 and both are reached by
# `prepare_subcortical_mni152()`. A bare presence check passes on an older
# release and the pipeline fails later, so the floor is a version. Tests that
# mock a 1.9.0-only binding must name this floor too: mocking a binding that
# does not exist errors rather than skips.
#' @noRd
freesurfer_min_version <- function() {
  "1.9.0"
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
    reason = "to interact with FreeSurfer"
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


#' Resolve a registration specification into an `mri_vol2vol` registration
#'
#' `mri_vol2vol` says the same two things as `mri_vol2surf` with one argument
#' rather than a set: the volume is already on the target's grid
#' (`"header"`, which becomes `--regheader`), or a transform file says where
#' it sits.
#'
#' A tkregister matrix cannot be handed to `mri_vol2vol` directly. FreeSurfer
#' 8 refuses one whose source geometry it cannot establish -- "LTAchangeType:
#' src geometry must be valid" -- and writes no output, because a
#' `REGISTER_DAT` transform carries no geometry of its own and is only
#' meaningful between COR-type volumes with `c_(r,a,s) = 0`. FreeSurfer 7
#' assumed that silently. So the matrix is converted to an LTA against this
#' call's own volumes first, which states the geometry rather than assuming
#' it, and is the better transform on either version.
#'
#' `mri_vol2surf` is unaffected and takes the matrix as it is.
#'
#' @param registration One of `"mni152"`, `"header"`, or a path to a
#'   register.dat or LTA file.
#' @param mov,targ The volumes this call registers between, which are what
#'   give the LTA its geometry.
#' @param envir Frame whose exit removes the LTA, so a temporary file does
#'   not outlive the command it was built for.
#' @noRd
vol2vol_registration <- function(
  registration,
  mov,
  targ,
  envir = parent.frame()
) {
  spec <- resolve_registration(registration)

  if (identical(spec$kind, "header")) {
    return("header")
  }

  vol2vol_transform_file(spec$path, mov, targ, envir)
}


#' The same registration as a flag for a hand-built `mri_vol2vol` command
#'
#' [freesurfer::mri_vol2vol()] takes the registration as a value, but the
#' per-label probability resampling builds its command text itself so it can
#' run through `run_cmd()`, which captures the stderr that says why a
#' FreeSurfer tool failed and raises a classed condition. This states the
#' flag spelling once for that caller.
#'
#' @param registration One of `"mni152"`, `"header"`, or a path to a
#'   register.dat or LTA file.
#' @param mov,targ The volumes this call registers between.
#' @param envir Frame whose exit removes a converted LTA.
#' @noRd
vol2vol_registration_opt <- function(
  registration,
  mov,
  targ,
  envir = parent.frame()
) {
  reg <- vol2vol_registration(
    registration,
    mov = mov,
    targ = targ,
    envir = envir
  )

  if (identical(reg, "header")) {
    return("--regheader")
  }

  paste("--reg", shQuote(reg))
}


#' An `mri_vol2vol` transform with geometry FreeSurfer 8 accepts
#'
#' An LTA already states its geometry and is passed through untouched. A
#' tkregister matrix is converted against the volumes at hand.
#' @noRd
vol2vol_transform_file <- function(path, mov, targ, envir = parent.frame()) {
  if (identical(tolower(fs::path_ext(path)), "lta")) {
    return(path)
  }
  lta_from_register_dat(path, mov = mov, targ = targ, envir = envir)
}


#' Convert a tkregister matrix into an LTA carrying explicit geometry
#' @noRd
lta_from_register_dat <- function(
  path,
  mov,
  targ,
  envir = parent.frame(),
  verbose = get_verbose()
) {
  lta <- tempfile(fileext = ".lta")
  withr::defer(unlink(lta), envir = envir)

  cmd <- paste(
    "lta_convert",
    "--inreg",
    shQuote(path),
    "--src",
    shQuote(mov),
    "--trg",
    shQuote(targ),
    "--outlta",
    shQuote(lta)
  )
  suppressWarnings(run_cmd(cmd, verbose = max(0L, verbose - 1L)))
  check_fs_output(lta, "lta_convert", path)

  lta
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


#' Voxel grid of a volume, or NULL when its header cannot be read
#'
#' Advisory probe: a header the reader cannot parse leaves the space unknown
#' rather than surfacing that reader's own warnings.
#' @noRd
volume_grid <- function(input_volume) {
  if (!file.exists(input_volume)) {
    return(NULL)
  }

  grid <- tryCatch(
    suppressWarnings(read_volume_grid(input_volume)),
    error = function(e) NULL
  )

  # read_volume_grid() screens both extensions, so this is belt-and-braces for
  # a reader that grows a third branch without one.
  if (is.null(grid) || !affine_is_invertible(grid$vox2ras)) {
    return(NULL)
  }
  if (length(grid$dim) != 3L || anyNA(grid$dim) || any(grid$dim < 1L)) {
    return(NULL)
  }

  grid
}


#' Voxel-to-RAS matrix of a volume, or NULL when its header cannot be read
#' @noRd
volume_vox2ras <- function(input_volume) {
  volume_grid(input_volume)$vox2ras
}


#' The grid `mni152.register.dat` was built for
#'
#' FreeSurfer ships `$FREESURFER_HOME/average/mni152.register.dat`, whose
#' header declares an in-plane resolution and slice thickness of
#' `1.000000`/`1.000000` -- it is a 1 mm transform. The volume it was built
#' against is the FSL `MNI152_T1_1mm` template: 182x218x182, left-handed
#' (LAS), with the affine below. register.dat records the resolution but not
#' the dimensions, so the field of view has to be named here.
#' @noRd
mni152_1mm_grid <- function() {
  list(
    vox2ras = matrix(
      c(
        -1,
        0,
        0,
        90,
        0,
        1,
        0,
        -126,
        0,
        0,
        1,
        -72,
        0,
        0,
        0,
        1
      ),
      nrow = 4,
      byrow = TRUE
    ),
    dim = c(182L, 218L, 182L)
  )
}


#' Scanner-RAS to tkregister transform for a voxel grid
#'
#' tkregister coordinates are not a property of the anatomy: FreeSurfer forces
#' the axis order to LIA and the origin to the volume's own field-of-view
#' centre, discarding `c_ras`. So the same anatomical point gets different
#' tkreg coordinates in two volumes of different extent or axis order, which is
#' why a tkregister matrix only applies to the grid it was built for.
#' @noRd
scanner_to_tkreg <- function(grid) {
  voxel_sizes <- sqrt(colSums(grid$vox2ras[1:3, 1:3]^2))
  mdc <- cbind(c(-1, 0, 0), c(0, 0, -1), c(0, 1, 0))
  linear <- mdc %*% diag(voxel_sizes)
  vox2tkr <- rbind(
    cbind(linear, -linear %*% (grid$dim / 2)),
    c(0, 0, 0, 1)
  )
  vox2tkr %*% solve(grid$vox2ras)
}


#' How far a grid's tkreg frame departs from the reference's
#'
#' Splits the difference between the two scanner-to-tkreg maps into the two
#' kinds of error, which are not equally bad:
#'
#' - `axes`: the largest absolute difference in the linear part. The voxel
#'   sizes cancel out of that product, so this is purely the axis order and
#'   handedness. Non-zero means a reflection or a permutation -- a label drawn
#'   on the wrong side or along the wrong axis. Categorical.
#' - `offset_mm`: the distance between the translation parts, in millimetres.
#'   A shift along the correct axes.
#'
#' A mirrored volume has `axes > 0` and `offset_mm == 0`, so measuring the
#' offset alone would miss it entirely; a cropped volume has `axes == 0` and a
#' non-zero offset, so the axis test alone would miss that. Both are needed.
#' @noRd
tkreg_mismatch <- function(grid, reference = mni152_1mm_grid()) {
  a <- scanner_to_tkreg(grid)
  b <- scanner_to_tkreg(reference)
  list(
    axes = max(abs(a[1:3, 1:3] - b[1:3, 1:3])),
    offset_mm = sqrt(sum((a[1:3, 4] - b[1:3, 4])^2))
  )
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


#' Check that mni152.register.dat applies to this volume's grid
#'
#' `mni152.register.dat` is a tkregister matrix, so it is exact only for the
#' grid it was built for: the 1 mm LAS FSL MNI152 template, 182x218x182. See
#' [tkreg_mismatch()] for what "the same grid" actually means -- it is the
#' axis order and the field of view, NOT the voxel size, which cancels out of
#' the transform entirely.
#'
#' The two ways a volume can depart from that grid are not equally bad, and
#' this package draws anatomical guidance rather than precision geometry:
#'
#' - A different axis order or handedness is CATEGORICAL: the label is drawn
#'   on the wrong side, or along the wrong axis. Refused. This covers the
#'   right-handed (RAS) mirror and the LIA order `mri_convert --conform`
#'   produces, which a determinant-sign test cannot tell apart from LAS.
#' - A different field of view only SHIFTS regions along the correct axes.
#'   Warned about, in millimetres, and allowed through -- except that a shift
#'   below one voxel is indistinguishable from resampling, so that is silent.
#'
#' This replaces a voxel-size test that was wrong in both directions: it
#' warned about the FSL 2 mm and 1.6 mm CIFTI grayordinate grids, where the
#' transform is exact, and said nothing about a conformed 1 mm volume, which
#' is displaced by over 100 mm.
#' @noRd
check_mni152_grid <- function(input_volume, call = rlang::caller_env()) {
  grid <- volume_grid(input_volume)

  if (is.null(grid)) {
    cli::cli_abort(
      c(
        "{.val mni152} registration does not apply to {.path {input_volume}}.",
        "x" = "No voxel-to-world affine could be read, so this volume's
        orientation is unknown, and {.file mni152.register.dat} assumes a
        left-handed (LAS) order: applying it may swap left and right.",
        "i" = "Use {.code registration = \"header\"} where the caller offers it,
        or convert the volume with {.code mri_convert} so its header carries
        an affine."
      ),
      call = call
    )
  }

  mismatch <- tkreg_mismatch(grid)

  # Reported before the general axis-order message because it is the common
  # case and names the consequence, which "the axis order differs" does not.
  if (det(grid$vox2ras[1:3, 1:3]) > 0) {
    cli::cli_abort(
      c(
        "{.val mni152} registration does not apply to {.path {input_volume}}.",
        "x" = "{.file mni152.register.dat} assumes a left-handed (LAS) voxel
          order, and this volume is right-handed (RAS): applying it swaps left
          and right.",
        "i" = "A mirrored atlas still looks plausible, so this is refused
          rather than warned about.",
        "i" = "Use {.code registration = \"header\"}, or convert the volume to
          LAS order first."
      ),
      call = call
    )
  }

  if (mismatch$axes > 1e-6) {
    cli::cli_abort(
      c(
        "{.val mni152} registration does not apply to {.path {input_volume}}.",
        "x" = "{.file mni152.register.dat} was built for a left-handed (LAS)
          volume, and this volume's voxel axes run in a different order, so
          the parcels would be drawn along the wrong axes.",
        "i" = "A conformed volume is {.val LIA}, not {.val LAS}, so a volume
          that has been through {.code mri_convert --conform} lands here.",
        "i" = "Use {.code registration = \"header\"}, or resample onto the 1 mm
          LAS MNI152 grid first."
      ),
      call = call
    )
  }

  voxel_sizes <- sqrt(colSums(grid$vox2ras[1:3, 1:3]^2))
  if (mismatch$offset_mm > max(voxel_sizes)) {
    cli::cli_warn(
      c(
        "{.path {input_volume}} is not on the field of view
          {.file mni152.register.dat} was built for
          ({.val {c(182, 218, 182)}} mm).",
        "!" = "Regions will be shifted by about
          {.val {round(mismatch$offset_mm, 1)}} mm. They stay on the correct
          side, so this is a warning rather than a refusal.",
        # Not every caller exposes `registration`: read_neuromaps_volume()
        # hardcodes "mni152" and takes no such argument, so the remedy must
        # not name one unconditionally.
        "i" = "If the placement must be exact, resample onto the 1 mm LAS
          MNI152 grid first. Callers that expose {.arg registration} also
          accept {.code registration = \"header\"}."
      ),
      class = "ggseg_extra_mni152_displacement_warning",
      call = call
    )
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
