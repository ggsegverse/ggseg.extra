testthat::describe("stamp_cache_files", {
  it("records the current format version for each stamped file", {
    file <- local_cache_file(name = "components.rds")

    expect_identical(
      read_cache_manifest(dirname(file))[["components.rds"]],
      cache_format_version()
    )
  })

  it("keeps stamps for other files in the same directory", {
    first <- local_cache_file(name = "first.rds")
    second <- file.path(dirname(first), "second.rds")
    saveRDS(2, second)

    stamp_cache_files(second)

    expect_identical(
      sort(names(read_cache_manifest(dirname(first)))),
      c("first.rds", "second.rds")
    )
  })

  it("replaces rather than duplicates an existing stamp", {
    file <- local_cache_file()

    stamp_cache_files(file)

    expect_length(read_cache_manifest(dirname(file)), 1L)
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
    file <- local_cache_file()

    expect_identical(
      sort(list.files(dirname(file))),
      c("cache_manifest.rds", "step.rds")
    )
  })
})


testthat::describe("stamp_cache_dir", {
  it("marks a stamped directory current", {
    dir <- withr::local_tempdir("cache_")

    stamp_cache_dir(dir)

    expect_identical(check_cache_dir(dir, "Rerun the image step"), dir)
  })

  it("aborts for a directory no ggseg.extra stamped", {
    dir <- withr::local_tempdir("cache_")

    expect_error(
      check_cache_dir(dir, "Rerun the image-processing step"),
      "Rerun the image-processing step"
    )
  })
})


testthat::describe("read_cache_manifest", {
  it("returns an empty manifest when none exists", {
    dir <- withr::local_tempdir("cache_")

    expect_identical(read_cache_manifest(dir), integer())
  })

  it("ignores a manifest that is not a name-to-version vector", {
    dir <- withr::local_tempdir("cache_")
    saveRDS(list("not a manifest"), cache_manifest_file(dir))

    expect_identical(read_cache_manifest(dir), integer())
  })

  it("ignores a truncated manifest, marking everything stale", {
    file <- local_cache_file()
    writeLines("truncated", cache_manifest_file(dirname(file)))

    expect_identical(read_cache_manifest(dirname(file)), integer())
    expect_identical(stale_cache_files(file), file)
  })
})


testthat::describe("write_cache_manifest", {
  it("warns when the manifest cannot be moved into place", {
    dir <- withr::local_tempdir("cache_")
    local_mocked_bindings(file.rename = function(...) FALSE, .package = "base")

    expect_warning(
      write_cache_manifest(dir, c(step.rds = cache_format_version())),
      "cache manifest"
    )
  })
})


testthat::describe("save_cache_rds", {
  it("writes each object to its named file and stamps it", {
    dir <- withr::local_tempdir("cache_")

    files <- save_cache_rds(dir, first.rds = list(a = 1), second.rds = 2)

    expect_identical(readRDS(files[1]), list(a = 1))
    expect_identical(stale_cache_files(files), character())
  })

  it("writes the manifest once for a batch of files", {
    dir <- withr::local_tempdir("cache_")
    writes <- new.env()
    writes$n <- 0L
    local_mocked_bindings(
      write_cache_manifest = function(dir, manifest) {
        writes$n <- writes$n + 1L
        invisible(NULL)
      }
    )

    save_cache_rds(dir, first.rds = 1, second.rds = 2)

    expect_identical(writes$n, 1L)
  })
})


testthat::describe("save_cache_rda", {
  it("round-trips contours through a stamped cache", {
    dir <- withr::local_tempdir("cache_")
    contours <- mock_sf_polygon()
    loaded <- new.env()

    file <- save_cache_rda(contours, dir, "contours.rda")
    load_cached_rda(file, "Rerun the contour steps", envir = loaded)

    expect_s3_class(loaded$contours, "sf")
  })
})


testthat::describe("load_cached_rda", {
  it("rejects a stale cache before deserializing it", {
    dir <- withr::local_tempdir("cache_")
    file <- save_cache_rda(mock_sf_polygon(), dir, "contours.rda")
    local_mocked_bindings(cache_format_version = function() 9999L)

    expect_error(
      load_cached_rda(file, "Rerun the contour steps", envir = new.env()),
      "Rerun the contour steps"
    )
  })

  it("still reports a missing file as missing", {
    dir <- withr::local_tempdir("cache_")

    expect_error(
      load_cached_rda(
        file.path(dir, "absent.rda"),
        "Rerun the contour steps",
        envir = new.env()
      ),
      "not found"
    )
  })
})


testthat::describe("stale_cache_files", {
  it("reports unstamped files as stale", {
    file <- local_cache_file(stamped = FALSE)

    expect_identical(stale_cache_files(file), file)
  })

  it("reports files stamped by another format version as stale", {
    file <- local_cache_file()
    local_mocked_bindings(cache_format_version = function() 9999L)

    expect_identical(stale_cache_files(file), file)
  })

  it("returns only the stale members of a mixed set", {
    fresh <- local_cache_file(name = "fresh.rds")
    old <- file.path(dirname(fresh), "old.rds")
    saveRDS(2, old)

    expect_identical(stale_cache_files(c(fresh, old)), old)
  })
})


testthat::describe("check_cache_current", {
  it("passes stamped files through unchanged", {
    file <- local_cache_file()

    expect_identical(check_cache_current(file, "Rerun step 1"), file)
  })

  it("reports an unstamped cache as having no format version", {
    file <- local_cache_file(stamped = FALSE)

    expect_error(
      check_cache_current(file, "Rerun step 1"),
      "written by cache format none"
    )
  })

  it("names both the found and the expected format version", {
    file <- local_cache_file()
    local_mocked_bindings(cache_format_version = function() 9999L)

    expect_error(
      check_cache_current(file, "Rerun step 1"),
      "written by cache format 1"
    )
  })
})


testthat::describe("step_rerun_remedy", {
  it("names the step to include", {
    expect_match(step_rerun_remedy(3L), "Include step 3")
  })
})
