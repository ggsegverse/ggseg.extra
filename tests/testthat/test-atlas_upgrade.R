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
