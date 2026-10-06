devtools::load_all()
library(dplyr)
library(ggplot2)

# Sequential plan — rgl contexts exhaust with parallel workers
future::plan(future::sequential)
progressr::handlers("cli")
progressr::handlers(global = TRUE)

# Neuromaps atlas creation ----
# Uses abagen genepc1 (gene expression PC1) from the neuromaps registry.
# This is a continuous brain map — the pipeline auto-detects continuous
# data and discretizes into quantile bins.

atlas <- create_cortical_from_neuromaps(
  source = "abagen",
  desc = "genepc1",
  breaks = 7,
  atlas_name = "abagen_genepc1",
  output_dir = "data-raw",
  skip_existing = TRUE,
  cleanup = FALSE
)

print(atlas)

p <- plot(atlas, show.legend = FALSE)
ggsave(
  "data-raw/abagen_genepc1_test.png",
  p,
  width = 10,
  height = 8,
  bg = "white"
)
cli::cli_alert_success("2D plot saved to data-raw/abagen_genepc1_test.png")

p3d <- ggseg3d::ggseg3d(atlas = atlas, hemisphere = "left")
cli::cli_alert_success("3D rendering successful")

cat("\nCore:\n")
print(atlas$core)
cat("\nSF data:\n")
print(head(atlas$data$sf))
cat("\nVertices per region:\n")
verts <- vapply(atlas$data$vertices$vertices, length, integer(1))
names(verts) <- atlas$data$vertices$label
print(verts)
