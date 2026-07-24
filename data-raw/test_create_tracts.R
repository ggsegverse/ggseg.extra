devtools::load_all("../ggseg.formats")
devtools::load_all("../ggseg")
devtools::load_all("../ggseg3d")
devtools::load_all(".")
library(dplyr)
library(ggplot2)

# Tract atlas creation using TRACULA training data ----
# Uses HCP training data from FreeSurfer installation@@
future::plan(future::multicore(workers = 4))
progressr::handlers("cli")
progressr::handlers(global = TRUE)


output_dir <- "data-raw/tracula_test"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

tract_dir <- file.path(
  freesurfer::get_fs_home(),
  "trctrain/hcp/mgh_1017/mni"
)
template_file <- file.path(tract_dir, "aparc+aseg.nii.gz")

tract_files <- file.path(
  tract_dir,
  c(
    "lh.cst.bbr.prep.trk",
    "rh.cst.bbr.prep.trk",
    "lh.ilf.bbr.prep.trk",
    "rh.ilf.bbr.prep.trk",
    "cc.genu.bbr.prep.trk",
    "cc.splenium.bbr.prep.trk"
  )
)

tract_names <- c(
  "cst_left",
  "cst_right",
  "ilf_left",
  "ilf_right",
  "cc_genu",
  "cc_splenium"
)

# Create complete tract atlas (3D + 2D) ----
cli::cli_h1("Creating TRACULA tract atlas")

atlas <- create_tract_from_tractography(
  tract_files = tract_files,
  tract_names = tract_names,
  tube_radius = 0.8,
  tube_segments = 12,
  centerline_method = "mean",
  n_points = 50,
  include_geometry = TRUE,
  aseg_file = template_file,
  output_dir = output_dir,
  coords_are_voxels = TRUE,
  smoothness = 5,
  geometry_tolerance = 0,
  cleanup = FALSE,
  verbose = TRUE
)

cli::cli_h2("Atlas structure")
print(atlas)

# Test 3D rendering ----
cli::cli_h2("Testing 3D rendering")

ggseg3d(atlas = atlas, hemisphere = "subcort") |>
  add_glassbrain(hemisphere = c("left", "right"), opacity = 0.15) |>
  pan_camera("right lateral")

# Test 2D rendering ----
cli::cli_h2("Testing 2D rendering")

ggplot() +
  geom_brain(atlas = atlas, show.legend = FALSE) +
  theme_void() +
  labs(title = "TRACULA tract atlas")

ggsave(
  file.path(output_dir, "tracula_2d.png"),
  width = 10,
  height = 10,
  bg = "white"
)

# Plot with data mapping
test_data <- data.frame(
  stringsAsFactors = FALSE,
  label = c(
    "cst_left",
    "cst_right",
    "ilf_left",
    "ilf_right",
    "cc_genu",
    "cc_splenium"
  ),
  value = c(0.8, 0.7, 0.5, 0.4, 0.3, 0.9)
)

ggplot(test_data) +
  geom_brain(
    atlas = atlas,
    mapping = aes(fill = value)
  ) +
  scale_fill_viridis_c() +
  theme_void() +
  labs(title = "TRACULA with data")

ggsave(
  file.path(output_dir, "tracula_2d_data.png"),
  width = 10,
  height = 10,
  bg = "white"
)
saveRDS(atlas, "data-raw/tracts.rds")
