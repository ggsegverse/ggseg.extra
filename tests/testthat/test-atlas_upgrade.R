# A package-shaped directory holding `objects` in R/sysdata.rda.
fake_atlas_package <- function(objects) {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  dir.create(file.path(dir, "R"))
  env <- list2env(objects, parent = emptyenv())
  save(
    list = ls(env, all.names = TRUE),
    file = file.path(dir, "R", "sysdata.rda"),
    envir = env
  )
  dir
}

legacy_copy_of <- function(atlas) {
  structure(
    as.list(atlas),
    class = c(
      paste0(ggseg.formats::atlas_type(atlas), "_atlas"),
      "ggseg_atlas",
      "list"
    )
  )
}


describe("upgrade_atlas_package()", {
  it("reports what would change and writes nothing on a dry run", {
    dir <- fake_atlas_package(list(.dk = legacy_copy_of(ggseg.formats::dk())))
    before <- file.mtime(file.path(dir, "R", "sysdata.rda"))

    result <- suppressMessages(upgrade_atlas_package(dir))

    expect_identical(nrow(result), 1L)
    expect_identical(result$status, "upgraded")
    expect_true(result$changed)
    expect_identical(file.mtime(file.path(dir, "R", "sysdata.rda")), before)
  })

  it("writes the upgraded atlas when asked", {
    dir <- fake_atlas_package(list(.dk = legacy_copy_of(ggseg.formats::dk())))
    suppressMessages(upgrade_atlas_package(dir, dry_run = FALSE))

    env <- new.env(parent = emptyenv())
    load(file.path(dir, "R", "sysdata.rda"), envir = env)
    expect_true(
      ggseg.formats::atlas_schema_is_current(get(".dk", envir = env))
    )
  })

  it("carries the atlas across untouched", {
    # The whole claim of an upgrade: the container changes, the contents do
    # not. If this ever fails, the upgrade has become a rebuild.
    original <- ggseg.formats::dk()
    dir <- fake_atlas_package(list(.dk = legacy_copy_of(original)))
    suppressMessages(upgrade_atlas_package(dir, dry_run = FALSE))

    env <- new.env(parent = emptyenv())
    load(file.path(dir, "R", "sysdata.rda"), envir = env)
    upgraded <- get(".dk", envir = env)

    expect_identical(
      as.data.frame(ggseg.formats::atlas_core(upgraded)),
      as.data.frame(ggseg.formats::atlas_core(original))
    )
    expect_identical(
      ggseg.formats::atlas_palette(upgraded),
      ggseg.formats::atlas_palette(original)
    )
    expect_identical(
      ggseg.formats::atlas_geom(upgraded),
      ggseg.formats::atlas_geom(original)
    )
  })

  it("leaves an already-current atlas alone", {
    dir <- fake_atlas_package(list(.dk = ggseg.formats::dk()))
    result <- suppressMessages(upgrade_atlas_package(dir))
    expect_false(result$changed)
  })

  it("ignores objects that are not atlases", {
    dir <- fake_atlas_package(list(
      .dk = legacy_copy_of(ggseg.formats::dk()),
      .notes = list(a = 1),
      .mesh = data.frame(x = 1)
    ))
    result <- suppressMessages(upgrade_atlas_package(dir))
    expect_identical(result$object, ".dk")
  })

  it("preserves the non-atlas objects it ignores", {
    dir <- fake_atlas_package(list(
      .dk = legacy_copy_of(ggseg.formats::dk()),
      .notes = list(a = 1)
    ))
    suppressMessages(upgrade_atlas_package(dir, dry_run = FALSE))

    env <- new.env(parent = emptyenv())
    load(file.path(dir, "R", "sysdata.rda"), envir = env)
    expect_identical(get(".notes", envir = env), list(a = 1))
  })

  it("errors when there is no sysdata to upgrade", {
    expect_error(
      upgrade_atlas_package(withr::local_tempdir()),
      "sysdata"
    )
  })
})


describe("upgrade_atlas_package(repair =)", {
  # An atlas carrying a pre-vocabulary `hemi` is refused by the current
  # constructor, so it cannot be upgraded without being changed first. This
  # is `ggsegAal`'s `.aal3_cerebellum` in miniature.
  stale_hemi_atlas <- function() {
    atlas <- legacy_copy_of(ggseg.formats::dk())
    atlas$core$hemi[1] <- "middle"
    atlas
  }

  it("reports the failure rather than aborting the package", {
    dir <- fake_atlas_package(list(
      .ok = legacy_copy_of(ggseg.formats::dk()),
      .stale = stale_hemi_atlas()
    ))
    result <- suppressMessages(upgrade_atlas_package(dir))

    expect_setequal(result$status, c("upgraded", "failed"))
    expect_match(result$note[result$object == ".stale"], "hemi")
  })

  it("does not write when an atlas failed", {
    dir <- fake_atlas_package(list(.stale = stale_hemi_atlas()))
    before <- file.mtime(file.path(dir, "R", "sysdata.rda"))
    suppressMessages(upgrade_atlas_package(dir, dry_run = FALSE))
    expect_identical(file.mtime(file.path(dir, "R", "sysdata.rda")), before)
  })

  it("repairs it when asked, and says the data changed", {
    dir <- fake_atlas_package(list(.stale = stale_hemi_atlas()))
    result <- suppressMessages(
      upgrade_atlas_package(dir, dry_run = FALSE, repair = TRUE)
    )

    expect_identical(result$status, "repaired")

    env <- new.env(parent = emptyenv())
    load(file.path(dir, "R", "sysdata.rda"), envir = env)
    repaired <- get(".stale", envir = env)
    expect_true(ggseg.formats::atlas_schema_is_current(repaired))
    expect_false("middle" %in% ggseg.formats::atlas_hemi(repaired))
    expect_true("midline" %in% ggseg.formats::atlas_hemi(repaired))
  })

  it("repairing is off by default, because it rewrites the atlas", {
    dir <- fake_atlas_package(list(.stale = stale_hemi_atlas()))
    expect_identical(
      suppressMessages(upgrade_atlas_package(dir))$status,
      "failed"
    )
  })
})


describe("upgrade_atlas_package() failures", {
  # A core missing a required column is refused by the constructor for a
  # reason no migration verb addresses, which is what separates it from the
  # legacy `hemi` spellings the boundary repairs on its own.
  broken_atlas <- function() {
    atlas <- legacy_copy_of(ggseg.formats::dk())
    atlas$core$label <- NULL
    atlas
  }

  it("says so when the file holds no atlases", {
    dir <- fake_atlas_package(list(.notes = list(a = 1)))
    expect_message(
      expect_null(upgrade_atlas_package(dir)),
      "No atlases"
    )
  })

  it("carries the constructor's own message into the failed row", {
    dir <- fake_atlas_package(list(.broken = broken_atlas()))
    result <- suppressMessages(upgrade_atlas_package(dir))

    expect_identical(result$status, "failed")
    expect_match(result$note, "invalid structure")
    expect_match(result$note, "label")
  })

  it("reports the migration verb's own failure", {
    # `repair = TRUE` reaches for the verbs, and a coreless atlas is refused
    # by the verb rather than by the constructor.
    dir <- fake_atlas_package(list(
      .coreless = structure(
        list(atlas = "x", type = "cortical"),
        class = c("ggseg_atlas", "list")
      )
    ))
    result <- suppressMessages(
      upgrade_atlas_package(dir, repair = TRUE)
    )

    expect_identical(result$status, "failed")
    expect_match(result$note, "must be a list with a")
  })

  it("reports the retry's failure when repairing did not help", {
    # The verb succeeds -- there is a core to rewrite -- and the atlas is
    # still refused, because the missing column was never a `hemi` problem.
    dir <- fake_atlas_package(list(.broken = broken_atlas()))
    result <- suppressMessages(
      upgrade_atlas_package(dir, repair = TRUE)
    )

    expect_identical(result$status, "failed")
    expect_match(result$note, "label")
  })

  it("classifies an atlas the verb rescues as repaired", {
    # Unreachable with the installed ggseg.formats, whose boundary repairs
    # every `hemi` spelling the verb knows, so the real retry always fails.
    # The branch is defence against that boundary ever repairing less, and
    # standing a rescuing verb in its place pins the contract: rescued by the
    # verb, so the contents never changed and `identical_contents` stays TRUE,
    # where the contents-changed path reports FALSE for the same status.
    nameless <- legacy_copy_of(ggseg.formats::dk())
    nameless$atlas <- NULL
    local_mocked_bindings(
      migrate_atlas_hemi = function(atlas) {
        legacy_copy_of(ggseg.formats::dk())
      },
      .package = "ggseg.formats"
    )

    dir <- fake_atlas_package(list(.nameless = nameless))
    result <- suppressMessages(upgrade_atlas_package(dir, repair = TRUE))

    expect_identical(result$status, "repaired")
    expect_true(result$identical_contents)
  })

  it("upgrades a legacy brain_atlas without leaking its deprecation", {
    # Converting a pre-2.0 `brain_atlas` is deprecated in ggseg.formats and
    # warns on every call. Upgrading a package is a loop over objects, so one
    # warning per atlas would bury the report this function exists to print.
    dir <- fake_atlas_package(list(
      .dk = structure(
        as.list(ggseg.formats::dk()),
        class = c("brain_atlas", "list")
      )
    ))
    # `expect_no_warning()` and `expect_silent()` both let a
    # `lifecycle_warning_deprecated` through, so the warning has to be
    # collected by hand for the assertion to mean anything.
    seen <- character()
    withCallingHandlers(
      result <- suppressMessages(upgrade_atlas_package(dir)),
      warning = function(w) {
        seen <<- c(seen, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )

    expect_identical(seen, character())
    expect_identical(result$status, "upgraded")
  })
})


describe("the note naming what an upgrade would rewrite", {
  it("names the core columns when the column set changed", {
    # A legacy atlas without `display` gains it at the boundary, which is a
    # changed column set rather than a changed value.
    core <- as.data.frame(ggseg.formats::atlas_core(ggseg.formats::dk()))
    dir <- fake_atlas_package(list(
      .legacy = structure(
        list(
          atlas = "dk",
          type = "cortical",
          palette = ggseg.formats::atlas_palette(ggseg.formats::dk()),
          core = core[, c("hemi", "region", "label")],
          sf = ggseg.formats::atlas_geom(ggseg.formats::dk())
        ),
        class = c("ggseg_atlas", "list")
      )
    ))
    result <- suppressMessages(upgrade_atlas_package(dir))

    expect_identical(result$status, "failed")
    expect_match(result$note, "core columns", fixed = TRUE)
    # No core value changed, so the note must not carry a dangling `core$`.
    expect_no_match(result$note, "core$,", fixed = TRUE)
  })

  # Conversion never rewrites a palette or a type, so the next three cannot
  # be reached through `upgrade_atlas_package()`; the note's contract is
  # still worth pinning, because it is what tells a maintainer which part
  # moved.

  it("names the palette", {
    recoloured <- ggseg.formats::set_atlas_palette(
      ggseg.formats::dk(),
      replace(
        ggseg.formats::atlas_palette(ggseg.formats::dk()),
        1,
        "#000000"
      )
    )
    expect_identical(
      upgrade_changed_parts(ggseg.formats::dk(), recoloured),
      "palette"
    )
  })

  it("names the type", {
    expect_match(
      upgrade_changed_parts(ggseg.formats::dk(), ggseg.formats::aseg()),
      "type"
    )
  })

  it("falls back when it cannot name a part", {
    # Every part it inspects compares equal, so it has nothing to name. The
    # fallback exists so the note is never empty.
    expect_identical(
      upgrade_changed_parts(ggseg.formats::dk(), ggseg.formats::dk()),
      "row count"
    )
  })
})
