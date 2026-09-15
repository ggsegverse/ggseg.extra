stopifnot(
  nzchar(Sys.getenv("GGSEG_REQUIRE_FREESURFER")),
  freesurfer::have_fs(),
  nzchar(Sys.which("mri_info"))
)

testthat::test_local(stop_on_failure = TRUE)
