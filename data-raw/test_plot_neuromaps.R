devtools::load_all()

future::plan(future::sequential)
progressr::handlers("cli")
progressr::handlers(global = TRUE)

atlas <- create_cortical_from_neuromaps(
  source = "abagen",
  desc = "genepc1",
  breaks = NULL,
  atlas_name = "abagen_genepc1",
  output_dir = "data-raw",
  skip_existing = TRUE,
  cleanup = FALSE
)

print(atlas)
ggseg3d::ggseg3d(atlas = atlas, hemisphere = "right")
