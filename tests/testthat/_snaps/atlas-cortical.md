# cortical_project_and_build verbose and cleanup paths / logs verbose messages for each step

    Code
      cortical_project_and_build(components = mock_components(), atlas_name = "test",
      hemisphere = "lh", views = "lateral", config = list(steps = 1:2, skip_existing = FALSE,
      tolerance = 1, cleanup = FALSE, verbose = TRUE), dirs = mock_dirs(),
      start_time = Sys.time())
    Message
      i Projecting mesh to 2D polygons
      v Projecting mesh to 2D polygons [<TIME>]
      
      v Brain atlas created with 1 regions
      
      -- test ggseg atlas ------------------------------------------------------------
      Type: cortical
      Regions: 1
      Hemispheres: left
      Views: lateral
      Palette: v
      Rendering: v ggseg
      v ggseg3d (vertices)
      --------------------------------------------------------------------------------
    Output
      # A tibble: 1 x 3
        hemi  region label
        <chr> <chr>  <chr>
      1 left  r      lh_r 

# create_cortical_from_annotation verbose output / prints atlas name and paths when verbose is TRUE

    Code
      create_cortical_from_annotation(input_annot = c("lh.test.annot"), verbose = TRUE)
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
      
      -- test ggseg atlas ------------------------------------------------------------
      Type: cortical
      Regions: 1
      Hemispheres: left
      Views: inferior, lateral, medial, superior
      Palette: v
      Rendering: v ggseg
      v ggseg3d (vertices)
      --------------------------------------------------------------------------------
    Output
      # A tibble: 1 x 3
        hemi  region  label     
        <chr> <chr>   <chr>     
      1 left  frontal lh_frontal

# create_cortical_from_labels verbose and LUT paths / prints verbose output when verbose is TRUE

    Code
      create_cortical_from_labels(labels, atlas_name = "test_atlas", verbose = TRUE)
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
      
      -- test_atlas ggseg atlas ------------------------------------------------------
      Type: cortical
      Regions: 2
      Hemispheres: left, right
      Views: lateral, medial
      Palette: v
      Rendering: v ggseg
      v ggseg3d (vertices)
      --------------------------------------------------------------------------------
    Output
      # A tibble: 3 x 3
        hemi  region  label     
        <chr> <chr>   <chr>     
      1 left  region1 lh_region1
      2 left  region2 lh_region2
      3 right region1 rh_region1

