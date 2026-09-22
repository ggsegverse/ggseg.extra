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
