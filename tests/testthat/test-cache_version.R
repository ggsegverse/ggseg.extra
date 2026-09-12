testthat::describe("stamp_cache_files", {
  it("records the current format version for each stamped file", {
    dir <- withr::local_tempdir("cache_")
    file <- file.path(dir, "components.rds")
    saveRDS(list(a = 1), file)

    stamp_cache_files(file)

    manifest <- read_cache_manifest(dir)
    expect_identical(
      manifest[["components.rds"]],
      cache_format_version()
    )
  })

  it("keeps stamps for files in the same directory", {
    dir <- withr::local_tempdir("cache_")
    first <- file.path(dir, "first.rds")
    second <- file.path(dir, "second.rds")
    saveRDS(1, first)
    saveRDS(2, second)

    stamp_cache_files(first)
    stamp_cache_files(second)

    expect_identical(
      sort(names(read_cache_manifest(dir))),
      c("first.rds", "second.rds")
    )
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
})


testthat::describe("read_cache_manifest", {
  it("returns an empty vector when no manifest exists", {
    dir <- withr::local_tempdir("cache_")

    expect_identical(read_cache_manifest(dir), integer())
  })

  it("ignores a manifest that is not a named integer vector", {
    dir <- withr::local_tempdir("cache_")
    saveRDS(list("not a manifest"), cache_manifest_file(dir))

    expect_identical(read_cache_manifest(dir), integer())
  })

  it("ignores an unreadable manifest", {
    dir <- withr::local_tempdir("cache_")
    writeLines("not an rds file", cache_manifest_file(dir))

    expect_identical(read_cache_manifest(dir), integer())
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

  it("returns only the stale members of a mixed set", {
    dir <- withr::local_tempdir("cache_")
    fresh <- file.path(dir, "fresh.rds")
    old <- file.path(dir, "old.rds")
    save_cache_rds(1, fresh)
    saveRDS(2, old)

    expect_identical(stale_cache_files(c(fresh, old)), old)
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
