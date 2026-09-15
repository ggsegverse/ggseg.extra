stopifnot(freesurfer::have_fs(), nzchar(Sys.which("mri_info")))

results <- testthat::test_local(
  reporter = testthat::ProgressReporter$new(),
  stop_on_failure = TRUE
)

skips <- unlist(lapply(results, function(test) {
  vapply(
    test$results,
    function(r) {
      if (inherits(r, "expectation_skip")) {
        conditionMessage(r)
      } else {
        NA_character_
      }
    },
    character(1)
  )
}))
skips <- skips[!is.na(skips)]
n_skipped <- sum(as.data.frame(results)$skipped)
if (length(skips) != n_skipped) {
  stop(
    "Skip guard saw ",
    length(skips),
    " skips but testthat reported ",
    n_skipped,
    "; the guard is broken",
    call. = FALSE
  )
}

fs_skips <- skips[grepl("FreeSurfer not available", skips, fixed = TRUE)]
if (length(fs_skips) > 0) {
  stop(length(fs_skips), " tests skipped for missing FreeSurfer", call. = FALSE)
}
cat("FreeSurfer-gated tests ran; skips in suite:\n")
if (length(skips) > 0) {
  cat(paste0("  ", unique(skips)), sep = "\n")
}
