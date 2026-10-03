# create_cortical_from_neuromaps / warns for non-default space/density

    Code
      invisible(create_cortical_from_neuromaps(source = "test", desc = "test", space = "fsLR",
        density = "32k", verbose = FALSE, cleanup = FALSE))
    Condition
      Warning:
      Non-default space/density: "fsLR" / "32k"
      i The cortical pipeline requires fsaverage5 (space='fsaverage', density='10k'). Other values may cause vertex count mismatches.
      Warning:
      Atlas has <n> vertices, against a budget of 10000 for 2 cortical region.
      i A large atlas is slow to plot and makes the package that ships it bigger.
      i `atlas_polish(atlas)` simplifies and smooths it in one step.

