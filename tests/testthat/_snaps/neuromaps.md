# create_cortical_from_neuromaps / warns for non-default space/density

    Code
      invisible(create_cortical_from_neuromaps(source = "test", desc = "test", space = "fsLR",
        density = "32k", verbose = FALSE, cleanup = FALSE))
    Condition
      Warning:
      Non-default space/density: "fsLR" / "32k"
      i The cortical pipeline requires fsaverage5 (space='fsaverage', density='10k'). Other values may cause vertex count mismatches.
      Warning:
      Atlas has <n> vertices (threshold: 10000)
      i Large atlases may be slow to plot and increase package size
      i Call `atlas_simplify(atlas, keep = 0.2)`, then `atlas_smooth(atlas)`, to tidy it and reduce vertices

