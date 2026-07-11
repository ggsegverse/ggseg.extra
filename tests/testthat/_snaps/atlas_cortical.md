# cortical_project_and_build verbose and cleanup paths / logs verbose messages for each step

    Code
      invisible(cortical_project_and_build(components = mock_components(),
      atlas_name = "test", hemisphere = "lh", views = "lateral", config = list(steps = 1:
        2, skip_existing = FALSE, tolerance = 1, cleanup = FALSE, verbose = TRUE),
      dirs = mock_dirs(), start_time = Sys.time()))
    Message
      i Projecting mesh to 2D polygons
      v Projecting mesh to 2D polygons [<TIME>]
      
      v Brain atlas created with 1 regions

# create_cortical_from_annotation verbose output / prints atlas name and paths when verbose is TRUE

    Code
      invisible(create_cortical_from_annotation(input_annot = "lh.test.annot",
        verbose = TRUE))
    Message
      
      -- Creating brain atlas "test" -------------------------------------------------
      i Input files: 'lh.test.annot'
      i Reading annotation files
      v Reading annotation files [<TIME>]
      
      i Projecting mesh to 2D polygons
      i Projecting "rh" "lateral"
      i Projecting mesh to 2D polygons
      i Projecting "rh" "medial"
      i Projecting mesh to 2D polygons
      i Projecting "rh" "superior"
      i Projecting mesh to 2D polygons
      i Projecting "rh" "inferior"
      i Projecting mesh to 2D polygons
      i Projecting "lh" "lateral"
      i Projecting mesh to 2D polygons
      i Projecting "lh" "medial"
      i Projecting mesh to 2D polygons
      i Projecting "lh" "superior"
      i Projecting mesh to 2D polygons
      i Projecting "lh" "inferior"
      i Projecting mesh to 2D polygons
      v Projecting mesh to 2D polygons [<TIME>]
      
      v Temporary files removed
      v Brain atlas created with 1 regions

# create_cortical_from_labels verbose and LUT paths / prints verbose output when verbose is TRUE

    Code
      invisible(create_cortical_from_labels(labels, atlas_name = "test_atlas",
        verbose = TRUE))
    Message
      
      -- Creating brain atlas "test_atlas" -------------------------------------------
      i Input files: 'testdata/cortical/lh.region1.label', 'testdata/cortical/lh.region2.label', and 'testdata/cortical/rh.region1.label'
      i Reading 3 label files
      v Reading 3 label files [<TIME>]
      
      i Projecting mesh to 2D polygons
      i Projecting "lh" "lateral"
      i Projecting mesh to 2D polygons
      i Projecting "lh" "medial"
      i Projecting mesh to 2D polygons
      i Projecting "rh" "lateral"
      i Projecting mesh to 2D polygons
      i Projecting "rh" "medial"
      i Projecting mesh to 2D polygons
      v Projecting mesh to 2D polygons [<TIME>]
      
      v Temporary files removed
      v Brain atlas created with 3 regions

