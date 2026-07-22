# NA

### Quick orientation — what this repo is

- This is an R package that provides atlas creation pipelines and
  datasets for the `ggseg` / `ggseg3d` plotting ecosystem. See
  `DESCRIPTION` for package dependencies and system requirements
  (notably: FreeSurfer for annotation reading, ImageMagick for
  subcortical/tract pipelines). The user-facing documentation and
  tutorials live in `vignettes/` and `docs/`.

### Big-picture architecture

- Core R code lives in `R/` (e.g. `R/atlas-cortical.R`,
  `R/atlas-subcortical.R`, `R/mesh-projection.R`). Cortical pipelines
  use direct mesh-to-polygon projection (no screenshots/external
  rendering). Subcortical and tract pipelines still use multi-step
  disk-based workflows. All return `ggseg_atlas` objects.
- Data and generated surfaces are under `inst/` and `data-raw/`.
- Documentation is generated with `pkgdown` into `docs/` (see
  `_pkgdown.yml`). CI builds and renders on macOS (see
  `.github/workflows/*.yaml`).

### Important conventions & patterns an AI should follow

- Pipeline steps: subcortical/tract/wholebrain functions accept a
  `steps` numeric vector and write files to an `output_dir`. Cortical
  functions (`create_cortical_from_*()`) do NOT have a `steps` parameter
  — they always read data and project to 2D in one pass.
- Atlas naming: ggseg3d atlases often use `_3d` suffixes and palettes
  are created with `make_palette_ggseg()` (see
  `R/create-ggseg-atlas.R`). When generating atlases, ensure names and
  palette keys match repository conventions (see usage of
  `brain_atlas()` in the R code).
- External binaries: subcortical/tract functions call system tools
  (ImageMagick, FreeSurfer). Cortical functions only need FreeSurfer to
  read annotations. Guard changes that call or parse external tool
  outputs and add clear error messages if binaries are missing.
- Reporting/progress: code uses `cli`, `progressr` and verbose text
  output. Preserve this behaviour in edits (use `cli::cli_*` and
  `progressr::progress()` patterns).

### Developer workflows (how to build / test / debug)

- Install dependencies (match CI): prefer
  `remotes::install_deps(dependencies=TRUE)` or use
  [`pak::local_install()`](https://pak.r-lib.org/reference/local_install.html)
  as in `pkgdown.yaml`.
- Local checks / tests:
  - Run R CMD check: `R CMD check .` or via `devtools::check()`.
  - Run tests: `devtools::test()` or
    `Rscript -e 'testthat::test_dir("tests/testthat")'`.
  - CI runs on macOS and installs system deps via `brew` (see
    `.github/workflows/*`). If a change touches code depending on
    GDAL/ImageMagick/FreeSurfer/orca, run tests on macOS or a matching
    environment.
- Documentation and pkgdown: docs are published with
  [`pkgdown::deploy_to_branch()`](https://pkgdown.r-lib.org/reference/deploy_to_branch.html)
  in CI (`.github/workflows/pkgdown.yaml`).

### Files to read first when editing or creating features

- `DESCRIPTION` — package dependencies & SystemRequirements
- `inst/surfaces/` and `data-raw/` — examples and raw assets used by
  pipelines
- `_pkgdown.yml`, `vignettes/`, — examples and tutorials to mirror for
  usage patterns and function signatures
- `.github/workflows/*.yaml` — CI setup; useful for reproducing
  environment & install order

### Integration points & gotchas

- Heavy dependencies (`freesurfer`, `magick`, `chromote`, `terra`,
  `RNifti`, `htmlwidgets`) are in Suggests, not Imports. They are loaded
  at runtime via
  [`rlang::check_installed()`](https://rlang.r-lib.org/reference/is_installed.html).
  The cortical pipeline needs only base Imports (`sf`, `dplyr`, `cli`,
  `ggseg.formats`, `furrr`). Subcortical/tract pipelines need the full
  set.
- Subcortical/wholebrain pipelines require FreeSurfer and ImageMagick as
  system tools — CI installs them via Homebrew on macOS.
- Code uses `terra` and `sf` — watch for platform-specific binary issues
  and prefer high-level R APIs when possible.
- Intermediate files have expected directory layout (e.g.
  `output_dir/<atlas>/{img,regions,masks}`). If you change file naming,
  update all downstream readers (contour extraction, smoothing, vertex
  reduction).

### Example edits the agent can safely make

- Small refactors inside `R/` that preserve the step pipeline signatures
  (`steps`, `output_dir`, `cleanup`) and retain CLI messages and
  progress reporting.
- Add unit tests under `tests/testthat/` that run quickly and mock
  external binaries where possible. Prefer to test pure-R logic (e.g.
  coordinate transforms, palette creation `make_palette_ggseg()`), and
  add `skip_on_ci()` when tests require heavy system tools.

### When to ask for human help

- Any change that modifies on-disk file naming, image formats, or calls
  to external binaries (ImageMagick, GDAL, FreeSurfer, orca) should get
  a human review and a short compatibility test on macOS.
- Any large refactor of atlas-building pipelines that changes function
  signatures or the atlas object structure.

### Updating NEWS.md

only add information that is relevant for the R-package to NEWS.md. Any
other changes related to workflows, pkgdown etc are not relevant to the
R-package releases and thus dont shouldnt be listed in NEWS.

Organise NEWS by user-facing and developer facing changes, and headings
for minor vs breaking changes.
