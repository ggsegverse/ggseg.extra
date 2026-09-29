describe("documented examples", {
  # Every example in the package is wrapped in \dontrun{}, so R CMD check
  # never executes one: they need FreeSurfer, a subject directory and hours.
  # \donttest{} would not help, because that *does* run under
  # --run-donttest and would fail for want of FreeSurfer. So the examples are
  # parsed rather than run, which catches the failure that can actually
  # happen here -- an argument renamed in a signature, leaving the example
  # calling something that no longer exists while every check stays green.

  # Arguments a function deliberately takes through `...` rather than as a
  # formal. Each entry is a decision, not an oversight, so the list is short
  # and explicit: anything absent from it must match a formal.
  dots_arguments <- list(
    # The RStudio New Project wizard passes its fields through `...`.
    new_project_setup_atlas_repo = "atlas_name"
  )

  # Functions whose `...` forwards to another exported function, so that
  # function's formals are legitimate arguments too. Declaring the target
  # rather than listing names keeps the check honest: an argument retired from
  # the target stops being a formal there and is caught here, which is exactly
  # how `tube_radius` was found still documented after `tube_opts` replaced it.
  dots_forwarded_to <- list(
    create_tract_from_volume = "create_tract_from_tractography"
  )

  # Under R CMD check the package is installed and its help database is the
  # thing to read. Under devtools the source man/ is present and the installed
  # database is either absent or stale, so that wins. Either way the Rd read
  # here is the Rd of the build being tested.
  package_rd_db <- function() {
    root <- test_path("..", "..")
    if (dir.exists(file.path(root, "man"))) {
      tools::Rd_db(dir = root)
    } else {
      tools::Rd_db("ggseg.extra")
    }
  }

  example_code <- function(rd) {
    tags <- vapply(rd, function(x) attr(x, "Rd_tag"), character(1))
    paste(unlist(rd[tags == "\\examples"]), collapse = "")
  }

  unknown_arguments <- function(call, exported) {
    fn <- call[[1]]
    if (!is.name(fn)) {
      return(character())
    }
    name <- as.character(fn)
    if (!name %in% exported) {
      return(character())
    }
    object <- get(name, envir = asNamespace("ggseg.extra"))
    if (!is.function(object)) {
      return(character())
    }
    supplied <- names(call)[-1]
    supplied <- supplied[!is.na(supplied) & nzchar(supplied)]
    forwarded <- dots_forwarded_to[[name]]
    allowed <- c(
      names(formals(object)),
      dots_arguments[[name]],
      if (!is.null(forwarded)) {
        names(formals(get(forwarded, envir = asNamespace("ggseg.extra"))))
      }
    )
    unknown <- setdiff(supplied, allowed)
    if (length(unknown) == 0L) {
      return(character())
    }
    sprintf("%s(%s = )", name, unknown)
  }

  calls_in <- function(expr) {
    if (!is.call(expr)) {
      return(list())
    }
    nested <- lapply(as.list(expr), calls_in)
    c(list(expr), unlist(nested, recursive = FALSE))
  }

  it("only pass arguments the documented function accepts", {
    db <- package_rd_db()
    exported <- getNamespaceExports("ggseg.extra")

    offenders <- unlist(lapply(names(db), function(topic) {
      code <- example_code(db[[topic]])
      if (!nzchar(trimws(code))) {
        return(character())
      }
      exprs <- parse(text = code)
      calls <- unlist(lapply(exprs, calls_in), recursive = FALSE)
      unknown <- unlist(lapply(calls, unknown_arguments, exported = exported))
      if (length(unknown) == 0L) {
        return(character())
      }
      sprintf("%s: %s", topic, unique(unknown))
    }))

    expect_identical(as.character(offenders), character())
  })

  it("parse, so a malformed one cannot ship unnoticed", {
    db <- package_rd_db()
    unparseable <- Filter(
      Negate(is.null),
      lapply(names(db), function(topic) {
        code <- example_code(db[[topic]])
        if (!nzchar(trimws(code))) {
          return(NULL)
        }
        parsed <- tryCatch(parse(text = code), error = function(cnd) cnd)
        if (inherits(parsed, "condition")) {
          sprintf("%s: %s", topic, conditionMessage(parsed))
        } else {
          NULL
        }
      })
    )

    expect_identical(unparseable, list())
  })
})
