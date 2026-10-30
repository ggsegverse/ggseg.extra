# FreeSurfer is Unix-only, so anything that shells out to it is skipped on
# Windows unconditionally (the runner also segfaults intermittently under the
# parallel native geometry stack there).
# With GGSEG_REQUIRE_FREESURFER set, as in the container CI job, a missing
# FreeSurfer is a failure rather than a skip, so the job cannot go green while
# silently running none of the FreeSurfer tests.
# Does a representative binary actually run? Resolving one is not enough: an
# x86_64 FreeSurfer on an arm64 Mac resolves and then dies with "Bad CPU type
# in executable" on every call, which is a skip, not 18 test errors. Cached
# because it costs a process and the answer cannot change mid-run.
.fs_runs <- local({
  answer <- NULL
  function() {
    if (is.null(answer)) {
      binary <- Sys.which("mri_info")
      answer <<- nzchar(binary) &&
        identical(
          suppressWarnings(system2(
            binary,
            "--version",
            stdout = FALSE,
            stderr = FALSE
          )),
          0L
        )
    }
    answer
  }
})

freesurfer_is_usable <- function() {
  # have_fs() only checks for the FreeSurfer directory; it returns TRUE even
  # when the binaries are not on PATH, and being on PATH does not mean they
  # execute.
  freesurfer::have_fs() && .fs_runs()
}

skip_if_no_freesurfer <- function() {
  if (nzchar(Sys.getenv("GGSEG_REQUIRE_FREESURFER"))) {
    if (!freesurfer_is_usable()) {
      stop("GGSEG_REQUIRE_FREESURFER is set but FreeSurfer is not available")
    }
    return(invisible(TRUE))
  }
  skip_on_os("windows")
  skip_if_not_installed(
    "freesurfer",
    minimum_version = freesurfer_min_version()
  )
  if (!freesurfer_is_usable()) {
    skip("FreeSurfer not available")
  }
}

fsaverage5_file <- function(...) {
  file.path(freesurfer::fs_subj_dir(), "fsaverage5", ...)
}

# Stand in for FreeSurfer's MNI152 transform. Tests that mock the projection
# still resolve the registration first, so without this they need a real
# FreeSurfer installation.
local_mock_mni152_path <- function(env = parent.frame()) {
  reg_file <- withr::local_tempfile(fileext = ".dat", .local_envir = env)
  file.create(reg_file)
  local_mocked_bindings(
    mni152_register_path = function() reg_file,
    .env = env
  )
  reg_file
}
