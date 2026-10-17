describe("stamp_cache_files", {
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

  it("does nothing when a step wrote no files", {
    dir <- withr::local_tempdir("cache_")

    expect_no_error(stamp_cache_files(NULL))
    expect_no_error(stamp_cache_files(character()))
    expect_identical(list.files(dir), character())
  })

  it("leaves no staging file behind", {
    file <- local_cache_file()

    expect_identical(
      sort(list.files(dirname(file))),
      c("cache_manifest.rds", "step.rds")
    )
  })
})

describe("read_cache_manifest", {
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


describe("write_cache_manifest", {
  it("warns when the manifest cannot be moved into place", {
    dir <- withr::local_tempdir("cache_")
    local_mocked_bindings(file.rename = function(...) FALSE, .package = "base")

    expect_warning(
      write_cache_manifest(dir, c(step.rds = cache_format_version())),
      "cache manifest"
    )
  })
})


describe("save_cache_rds", {
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


describe("save_cache_rda", {
  it("round-trips contours through a stamped cache", {
    dir <- withr::local_tempdir("cache_")
    contours <- mock_sf_polygon()
    loaded <- new.env()

    file <- save_cache_rda(contours, dir, "contours.rda")
    load_cached_rda(file, "Rerun the contour steps", envir = loaded)

    expect_s3_class(loaded$contours, "sf")
  })
})


describe("load_cached_rda", {
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


describe("stale_cache_files", {
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


describe("check_cache_current", {
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
    stamped <- cache_format_version()
    local_mocked_bindings(cache_format_version = function() 9999L)

    expect_error(
      check_cache_current(file, "Rerun step 1"),
      paste("written by cache format", stamped)
    )
  })
})


describe("step_rerun_remedy", {
  it("names the step to include", {
    expect_match(step_rerun_remedy(3L), "Include step 3")
  })
})


describe("cache manifest ownership", {
  local_owner <- function(pid, env = parent.frame()) {
    withr::defer(claim_cache_manifests(), envir = env)
    cache_manifest_owner$pid <- pid
  }

  it("lets the claiming process stamp", {
    dir <- withr::local_tempdir()
    file <- file.path(dir, "step1_data.rds")
    saveRDS(1, file)

    claim_cache_manifests()
    expect_identical(stamp_cache_files(file), file)
    expect_identical(
      read_cache_manifest(dir)[["step1_data.rds"]],
      cache_format_version()
    )
  })

  it("refuses to stamp from a process that did not claim", {
    dir <- withr::local_tempdir()
    file <- file.path(dir, "step1_data.rds")
    saveRDS(1, file)
    local_owner(Sys.getpid() + 1L)

    expect_error(
      stamp_cache_files(file),
      class = "ggseg_extra_cache_manifest_thread_error"
    )
    expect_identical(read_cache_manifest(dir), integer())
  })

  it("refuses to stamp when nothing has claimed", {
    local_owner(NULL)
    expect_error(
      stamp_cache_files("anywhere/step1_data.rds"),
      class = "ggseg_extra_cache_manifest_thread_error"
    )
  })

  it("explains which process holds the claim", {
    local_owner(424242L)
    err <- expect_error(stamp_cache_files("anywhere/step1_data.rds"))
    # Not a snapshot: the calling pid is in the message, so it varies.
    expect_match(conditionMessage(err), "process 424242 has claimed them")
    expect_match(conditionMessage(err), "after `future_map\\(\\)` returns")
  })

  it("is claimed by setup_atlas_dirs, before any work is done", {
    local_owner(NULL)
    setup_atlas_dirs(withr::local_tempdir(), atlas_name = "test")
    expect_null(cache_manifest_owner_violation())
  })
})


describe("reusable_cache_file", {
  it("is TRUE for a file this ggseg.extra stamped", {
    expect_true(reusable_cache_file(local_cache_file()))
  })

  it("is FALSE for a file that does not exist", {
    expect_false(reusable_cache_file(file.path(tempdir(), "absent.rds")))
  })

  it("is FALSE for a file written under an older cache format", {
    file <- local_cache_file(stamped = FALSE)
    dir <- dirname(file)
    write_cache_manifest(dir, stats::setNames(0L, basename(file)))

    expect_false(reusable_cache_file(file))
  })
})


describe("step_signature", {
  it("changes when the package version changes", {
    # The reason a format integer is not enough: a release that computes
    # something different writes the same format, so the cache looked current
    # and the atlas came out built by the old code.
    before <- step_signature("a")
    local_mocked_bindings(
      packageVersion = function(...) package_version("99.9.9"),
      .package = "utils"
    )

    expect_false(identical(before, step_signature("a")))
  })

  it("changes when an input changes and not when it does not", {
    expect_identical(step_signature("a", 1L), step_signature("a", 1L))
    expect_false(identical(step_signature("a", 1L), step_signature("a", 2L)))
  })

  it("reads a path by its name, size and time, not its text", {
    dir <- withr::local_tempdir()
    f <- file.path(dir, "vol.nii.gz")
    writeLines("one", f)
    first <- step_signature(f)

    # moved, metadata intact: the build directory is allowed to move
    other <- file.path(withr::local_tempdir(), "vol.nii.gz")
    file.copy(f, other, copy.date = TRUE)
    expect_identical(step_signature(other), first)

    # changed contents: not allowed to go unnoticed
    writeLines(c("one", "two"), f)
    expect_false(identical(step_signature(f), first))
  })
})


describe("step_cache_matches", {
  it("is FALSE for a cache written before signatures existed", {
    file <- local_cache_file()

    expect_false(step_cache_matches(file, step_signature("a")))
  })

  it("is TRUE only for the signature the files were recorded under", {
    file <- local_cache_file()
    sig <- step_signature("a")
    record_step_signature(file, sig)

    expect_true(step_cache_matches(file, sig))
    expect_false(step_cache_matches(file, step_signature("b")))
  })

  it("asks nothing of a caller that supplies no signature", {
    expect_true(step_cache_matches(local_cache_file(), NULL))
  })
})


describe("clear_atlas_cache", {
  local_build_dir <- function(name, env = parent.frame()) {
    root <- withr::local_tempdir(.local_envir = env)
    dir <- file.path(root, name)
    dir.create(dir)
    saveRDS(1, file.path(dir, "step1_data.rds"))
    mark_working_dir(dir)
    list(root = root, dir = dir)
  }

  it("removes the atlas's intermediates", {
    b <- local_build_dir("glasser")

    expect_message(clear_atlas_cache("glasser", output_dir = b$root))
    expect_false(dir.exists(b$dir))
  })

  it("refuses a directory holding files it did not write", {
    root <- withr::local_tempdir()
    dir.create(file.path(root, "mine"))
    writeLines("precious", file.path(root, "mine", "data.csv"))

    expect_error(
      clear_atlas_cache("mine", output_dir = root),
      "did not write"
    )
    expect_true(file.exists(file.path(root, "mine", "data.csv")))
  })

  it("clears one anyway when forced", {
    root <- withr::local_tempdir()
    dir.create(file.path(root, "mine"))
    writeLines("x", file.path(root, "mine", "data.csv"))

    expect_message(clear_atlas_cache("mine", output_dir = root, force = TRUE))
    expect_false(dir.exists(file.path(root, "mine")))
  })

  it("clears every atlas when given no name", {
    root <- withr::local_tempdir()
    for (nm in c("a", "b")) {
      dir.create(file.path(root, nm))
      saveRDS(1, file.path(root, nm, "step1_data.rds"))
      mark_working_dir(file.path(root, nm))
    }

    expect_message(clear_atlas_cache(output_dir = root))
    expect_identical(list.dirs(root, recursive = FALSE), character())
  })

  it("says so rather than failing when there is nothing to clear", {
    expect_message(
      clear_atlas_cache("absent", output_dir = withr::local_tempdir()),
      "Nothing to clear"
    )
    expect_warning(
      clear_atlas_cache("absent", output_dir = file.path(tempdir(), "nope")),
      "does not exist"
    )
  })
})


describe("cache_input over several paths", {
  it("notices a change in any one of them", {
    # The creators take a vector of annotation files, and a signature that
    # only looked at a length-one path read the vector as plain text, so
    # touching one of two annots went unnoticed.
    dir <- withr::local_tempdir()
    f <- file.path(dir, c("lh.annot", "rh.annot"))
    writeLines("a", f[1])
    writeLines("b", f[2])
    before <- step_signature(f)

    writeLines("changed", f[2])

    expect_false(identical(step_signature(f), before))
  })
})
