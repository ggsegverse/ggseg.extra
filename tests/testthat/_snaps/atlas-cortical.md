# cortical_pipeline verbose and cleanup paths / logs verbose messages for each step

    Code
      cortical_pipeline(atlas_3d = structure(list(), class = "ggseg_atlas"),
      components = mock_components(), atlas_name = "test", hemisphere = "lh", views = "lateral",
      region_snapshot_fn = function(...) NULL, config = list(steps = 2:8,
      skip_existing = FALSE, tolerance = 1, smoothness = 5, cleanup = FALSE, verbose = TRUE),
      dirs = mock_dirs(), start_time = Sys.time())
    Message
      i 2/8 Taking full brain snapshots
      v 2/8 Taking full brain snapshots [<TIME>]
      
      i 3/8 Taking region snapshots
      v 3/8 Taking region snapshots [<TIME>]
      
      i 4/8 Isolating regions
      v 4/8 Isolating regions [<TIME>]
      
      i 8/8 Building final atlas
      v 8/8 Building final atlas [<TIME>]
      
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
      create_cortical_from_annotation(input_annot = c("lh.test.annot"), steps = 1,
      verbose = TRUE)
    Message
      
      -- Creating brain atlas "test" -------------------------------------------------
      i Input files: 'lh.test.annot'
      i Setting output directory to '<TMPDIR>'
      i 1/8 Reading annotation files
      v 1/8 Reading annotation files [<TIME>]
      
      v Temporary files removed
      v 3D atlas created with 1 regions
      
      -- test ggseg atlas ------------------------------------------------------------
      Type: cortical
      Regions: 1
      Hemispheres: left
      Palette: v
      Rendering: x ggseg
      v ggseg3d (vertices)
      --------------------------------------------------------------------------------
    Output
      # A tibble: 1 x 3
        hemi  region  label     
        <chr> <chr>   <chr>     
      1 left  frontal lh_frontal

# create_cortical_from_labels verbose and LUT paths / prints verbose output when verbose is TRUE

    Code
      create_cortical_from_labels(labels, atlas_name = "test_atlas", steps = 1,
        verbose = TRUE)
    Message
      
      -- Creating brain atlas "test_atlas" -------------------------------------------
      i Input files: 'testdata/cortical/lh.region1.label', 'testdata/cortical/lh.region2.label', and 'testdata/cortical/rh.region1.label'
      i Setting output directory to '<TMPDIR>'
      i 1/8 Reading 3 label files
    Condition
      Warning in `serializedSize()`:
      'package:grDevices' may not be available when loading
    Message
      v 1/8 Reading 3 label files [<TIME>]
      
      v Temporary files removed
      v 3D atlas created with 3 regions
      
      -- test_atlas ggseg atlas ------------------------------------------------------
      Type: cortical
      Regions: 2
      Hemispheres: left, right
      Palette: x
      Rendering: x ggseg
      v ggseg3d (vertices)
      --------------------------------------------------------------------------------
    Output
      # A tibble: 3 x 3
        hemi  region  label     
        <chr> <chr>   <chr>     
      1 left  region1 lh_region1
      2 left  region2 lh_region2
      3 right region1 rh_region1

