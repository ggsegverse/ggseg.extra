describe("absorb_retired_arg", {
  it("names the version the argument was actually retired in", {
    withr::local_options(lifecycle_verbosity = "warning")

    expect_warning(
      absorb_retired_arg(
        list(),
        "tube_radius",
        5,
        "tube_radius",
        "tube_opts",
        "create_tract_from_tractography",
        "1.9.9.9053"
      ),
      "1.9.9.9053"
    )
  })

  it("refuses to overwrite an entry the caller already set", {
    expect_error(
      absorb_retired_arg(
        list(tube_radius = 9),
        "tube_radius",
        5,
        "tube_radius",
        "tube_opts",
        "create_tract_from_tractography",
        "1.9.9.9053"
      ),
      "Cannot use both"
    )
  })
})


describe("group_retired_dots", {
  it("splits the mapping on its first dot, so an entry may contain one", {
    withr::local_options(lifecycle_verbosity = "quiet")

    out <- group_retired_dots(
      opts = list(o = list()),
      mapping = c(old = "o.some.entry"),
      dots = list(old = 1),
      fn = "f",
      when = "1.0.0"
    )

    expect_named(out$opts$o, "some.entry")
    expect_identical(out$opts$o[["some.entry"]], 1)
  })

  it("leaves dots that are not retired arguments alone", {
    out <- group_retired_dots(
      opts = list(o = list()),
      mapping = c(old = "o.entry"),
      dots = list(kept = 2),
      fn = "f",
      when = "1.0.0"
    )

    expect_identical(out$dots, list(kept = 2))
    expect_identical(out$opts$o, list())
  })

  it("copes with unnamed dots", {
    out <- group_retired_dots(
      opts = list(o = list()),
      mapping = c(old = "o.entry"),
      dots = list(7),
      fn = "f",
      when = "1.0.0"
    )

    expect_length(out$dots, 1L)
  })
})


describe("resolve_opts", {
  it("keeps an entry the caller explicitly set to NULL as NULL", {
    # modifyList drops a NULL rather than storing one, so the entry is absent
    # rather than NULL -- which reads back as NULL and is what the caller
    # asked for. Pinned because the two routes to NULL are not obviously the
    # same, and `projfrac_range = NULL` is a documented way to switch off
    # multi-depth sampling.
    out <- resolve_opts(
      list(b = NULL),
      "opts",
      list(a = 1, b = c(0, 1, 0.1))
    )

    expect_null(out$b)
    expect_identical(out$a, 1)
  })

  it("fills unset entries from the defaults", {
    out <- resolve_opts(list(a = 9), "opts", list(a = 1, b = 2))

    expect_identical(out$a, 9)
    expect_identical(out$b, 2)
  })
})
