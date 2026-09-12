testthat::describe("stamp_cache_files", {
  it("records the current format version for each stamped file", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "components.rds")
    saveRDS(list(a = 1), file)

    stamp_cache_files(file)

    manifest <- read_cache_manifest(dir)
    expect_identical(manifest$file, "components.rds")
    expect_identical(as.integer(manifest$version), cache_format_version())
  })

  it("records the modification time of each stamped file", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    saveRDS(list(a = 1), file)

    stamp_cache_files(file)

    expect_identical(
      read_cache_manifest(dir)$mtime,
      as.numeric(file.mtime(file))
    )
  })

  it("keeps stamps for other files in the same directory", {
    dir <- withr::local_tempdir("cache_")
    first <- file.path(dir, "first.rds")
    second <- file.path(dir, "second.rds")
    saveRDS(1, first)
    saveRDS(2, second)

    stamp_cache_files(first)
    stamp_cache_files(second)

    expect_identical(
      sort(read_cache_manifest(dir)$file),
      c("first.rds", "second.rds")
    )
  })

  it("replaces rather than duplicates an existing stamp", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    saveRDS(1, file)

    stamp_cache_files(file)
    stamp_cache_files(file)

    expect_identical(nrow(read_cache_manifest(dir)), 1L)
  })

  it("stamps files across several directories at once", {
    base <- withr::local_tempdir("cache_")
    dirs <- file.path(base, c("one", "two"))
    invisible(lapply(dirs, dir.create))
    files <- file.path(dirs, "step.rds")
    invisible(lapply(files, function(f) saveRDS(1, f)))

    stamp_cache_files(files)

    expect_identical(stale_cache_files(files), character())
  })

  it("leaves no staging file behind", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    saveRDS(1, file)

    stamp_cache_files(file)

    expect_identical(
      sort(list.files(dir)),
      c("cache_manifest.rds", "step.rds")
    )
  })
})


testthat::describe("read_cache_manifest", {
  it("returns an empty manifest when none exists", {
    dir <- withr::local_tempdir("cache_")

    expect_identical(nrow(read_cache_manifest(dir)), 0L)
  })

  it("ignores a manifest that is not a manifest table", {
    dir <- withr::local_tempdir("cache_")
    saveRDS(list("not a manifest"), cache_manifest_file(dir))

    expect_identical(nrow(read_cache_manifest(dir)), 0L)
  })

  it("ignores a manifest missing the expected columns", {
    dir <- withr::local_tempdir("cache_")
    saveRDS(data.frame(file = "step.rds"), cache_manifest_file(dir))

    expect_identical(nrow(read_cache_manifest(dir)), 0L)
  })

  it("ignores a truncated manifest, marking everything stale", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    save_cache_rds(1, file)
    writeLines("truncated", cache_manifest_file(dir))

    expect_identical(nrow(read_cache_manifest(dir)), 0L)
    expect_identical(stale_cache_files(file), file)
  })
})


testthat::describe("write_cache_manifest", {
  it("warns when the manifest cannot be moved into place", {
    dir <- withr::local_tempdir("cache_")
    local_mocked_bindings(file.rename = function(...) FALSE, .package = "base")

    expect_warning(
      write_cache_manifest(dir, empty_cache_manifest()),
      "cache manifest"
    )
  })
})


testthat::describe("save_cache_rds", {
  it("saves the object and stamps it in one step", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")

    save_cache_rds(list(a = 1), file)

    expect_identical(readRDS(file), list(a = 1))
    expect_identical(stale_cache_files(file), character())
  })
})


testthat::describe("stale_cache_files", {
  it("reports unstamped files as stale", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    saveRDS(1, file)

    expect_identical(stale_cache_files(file), file)
  })

  it("reports files stamped by another format version as stale", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    save_cache_rds(1, file)
    local_mocked_bindings(cache_format_version = function() 9999L)

    expect_identical(stale_cache_files(file), file)
  })

  it("reports a file rewritten after stamping as stale", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    save_cache_rds(1, file)

    Sys.setFileTime(file, Sys.time() + 5)

    expect_identical(stale_cache_files(file), file)
  })

  it("returns only the stale members of a mixed set", {
    dir <- withr::local_tempdir("cache_")
    fresh <- file.path(dir, "fresh.rds")
    old <- file.path(dir, "old.rds")
    save_cache_rds(1, fresh)
    saveRDS(2, old)

    expect_identical(stale_cache_files(c(fresh, old)), old)
  })
})


testthat::describe("stale_cache_origin", {
  it("names an older ggseg.extra for unstamped files", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    saveRDS(1, file)

    expect_identical(stale_cache_origin(file), "an older ggseg.extra")
  })

  it("names a newer ggseg.extra for stamps ahead of this version", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    save_cache_rds(1, file)
    local_mocked_bindings(cache_format_version = function() 0L)

    expect_identical(stale_cache_origin(file), "a newer ggseg.extra")
  })

  it("stays vague when the stale files disagree", {
    dir <- withr::local_tempdir("cache_")
    ahead <- file.path(dir, "ahead.rds")
    unstamped <- file.path(dir, "unstamped.rds")
    save_cache_rds(1, ahead)
    saveRDS(2, unstamped)
    local_mocked_bindings(cache_format_version = function() 0L)

    expect_identical(
      stale_cache_origin(c(ahead, unstamped)),
      "a different version of ggseg.extra"
    )
  })
})


testthat::describe("check_cache_current", {
  it("passes stamped files through unchanged", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    save_cache_rds(1, file)

    expect_identical(check_cache_current(file, "Rerun step 1"), file)
  })

  it("aborts with the given remedy for a stale file", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    saveRDS(1, file)

    expect_error(
      check_cache_current(file, "Rerun the contour extraction steps"),
      "Rerun the contour extraction steps"
    )
  })

  it("says the cache is newer when it was written ahead of this version", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "step.rds")
    save_cache_rds(1, file)
    local_mocked_bindings(cache_format_version = function() 0L)

    expect_error(
      check_cache_current(file, "Rerun step 1"),
      "a newer ggseg.extra"
    )
  })
})


testthat::describe("abort_stale_step_cache", {
  it("names the step to rerun", {
    expect_error(
      abort_stale_step_cache(
        "atlas_data.rds",
        1L,
        "Step 1 (Project to surface)"
      ),
      "Include step 1"
    )
  })
})
