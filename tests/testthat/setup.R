# cli prints how long each progress step took, which differs between runs.
# Rendering every timestamp as a fixed placeholder keeps snapshots stable
# without rewriting their text afterwards.
withr::local_options(
  cli.user_theme = list(
    span.timestamp = list(transform = function(x) "<time>")
  ),
  .local_envir = teardown_env()
)
cli::start_app(.envir = teardown_env())

# setup_atlas_repo() fills DESCRIPTION from `usethis.description` when the
# developer has one set. Clearing it keeps the scaffold snapshots the same
# here as on a runner, where nobody has a profile.
withr::local_options(
  usethis.description = NULL,
  .local_envir = teardown_env()
)
