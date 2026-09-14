stopifnot(freesurfer::have_fs(), nzchar(Sys.which("mri_info")))

results <- testthat::test_local(
  reporter = testthat::ProgressReporter$new(),
  stop_on_failure = TRUE
)

skips <- unlist(lapply(results, function(test) {
  vapply(
    test$results,
    function(r) if (inherits(r, "skip")) conditionMessage(r) else NA_character_,
    character(1)
  )
}))
skips <- skips[!is.na(skips)]
fs_skips <- skips[grepl("FreeSurfer not available", skips, fixed = TRUE)]

if (length(fs_skips) > 0) {
  stop(length(fs_skips), " tests skipped for missing FreeSurfer", call. = FALSE)
}
cat("FreeSurfer-gated tests ran; total skips in suite:", length(skips), "\n")
