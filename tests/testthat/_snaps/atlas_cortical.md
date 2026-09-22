# cortical_project_and_build verbose and cleanup paths / logs verbose messages for each step

    Code
      invisible(cortical_project_and_build(components = mock_components(),
      atlas_name = "test", hemisphere = "lh", views = "lateral", config = list(steps = 1:
        2, skip_existing = FALSE, tolerance = 1, cleanup = FALSE, verbose = TRUE),
      dirs = mock_dirs(), start_time = Sys.time()))
    Message
      i Projecting mesh to 2D polygons
      v Projecting mesh to 2D polygons [<time>]
      
      v Brain atlas created with 1 regions

# cortical_project_and_build verbose and cleanup paths / cleans up base directory and emits message when cleanup and verbose

    Code
      invisible(cortical_project_and_build(components = mock_components(),
      atlas_name = "test", hemisphere = "lh", views = "lateral", config = list(steps = 1:
        2, skip_existing = FALSE, tolerance = 1, cleanup = TRUE, verbose = TRUE),
      dirs = list(base = actual_base, snapshots = tempdir(), processed = tempdir(),
      masks = tempdir()), start_time = Sys.time()))
    Message
      i Projecting mesh to 2D polygons
      v Projecting mesh to 2D polygons [<time>]
      
      v Temporary files removed
      v Brain atlas created with 1 regions

# create_cortical_from_annotation verbose output / prints atlas name and paths when verbose is TRUE

    Code
      invisible(create_cortical_from_annotation(input_annot = "lh.test.annot",
        verbose = TRUE))
    Message
      
      -- Creating brain atlas "test" -------------------------------------------------
      i Input files: 'lh.test.annot'
      i Reading annotation files
      v Reading annotation files [<time>]
      
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
      v Projecting mesh to 2D polygons [<time>]
      
      v Temporary files removed
      v Brain atlas created with 1 regions

# cortical_read_data verbose paths / prints progress step when verbose is TRUE and step runs

    Code
      invisible(cortical_read_data(config = list(steps = 1:2, skip_existing = FALSE,
      verbose = TRUE), dirs = list(base = tmp_dir), atlas_name = "test", read_fn = read_fn,
      step_label = "Reading annotation files", cache_label = "Read annotations"))
    Message
      i Reading annotation files
      v Reading annotation files [<time>]
      

# create_cortical_from_labels verbose and LUT paths / prints verbose output when verbose is TRUE

    Code
      invisible(create_cortical_from_labels(labels, atlas_name = "test_atlas",
        verbose = TRUE))
    Message
      
      -- Creating brain atlas "test_atlas" -------------------------------------------
      i Input files: 'testdata/cortical/lh.region1.label', 'testdata/cortical/lh.region2.label', and 'testdata/cortical/rh.region1.label'
      i Reading 3 label files
      v Reading 3 label files [<time>]
      
      i Projecting mesh to 2D polygons
      i Projecting "lh" "lateral"
      i Projecting mesh to 2D polygons
      i Projecting "lh" "medial"
      i Projecting mesh to 2D polygons
      i Projecting "rh" "lateral"
      i Projecting mesh to 2D polygons
      i Projecting "rh" "medial"
      i Projecting mesh to 2D polygons
      v Projecting mesh to 2D polygons [<time>]
      
      v Temporary files removed
      v Brain atlas created with 3 regions

# create_cortical_from_gifti verbose / emits 'from GIFTI' message when verbose

    Code
      invisible(create_cortical_from_gifti(gifti_files = tmp, atlas_name = "test_gifti",
        verbose = TRUE))
    Message
      
      -- Creating brain atlas "test_gifti" from GIFTI --------------------------------
      i Input files: 'lh.test.label.gii'
      i Reading GIFTI annotation files
      v Reading GIFTI annotation files [<time>]
      

# create_cortical_from_cifti verbose / emits 'from CIFTI' message when verbose

    Code
      invisible(create_cortical_from_cifti(cifti_file = tmp, atlas_name = "test_cifti",
        verbose = TRUE))
    Message
      
      -- Creating brain atlas "test_cifti" from CIFTI --------------------------------
      i Input files: 'test.dlabel.nii'
      i Reading CIFTI file
      v Reading CIFTI file [<time>]
      

# create_cortical_from_neuromaps verbose / emits 'Fetching neuromaps' and 'from neuromaps' messages

    Code
      invisible(create_cortical_from_neuromaps(source = "test", desc = "testdesc",
        atlas_name = "test_neuromaps", verbose = TRUE))
    Message
      i Fetching neuromaps: source="test", desc="testdesc"
      
      -- Creating brain atlas "test_neuromaps" from neuromaps ------------------------
      i Input files: 'source-test_hemi-L_feature.func.gii' and 'source-test_hemi-R_feature.func.gii'
      i Reading neuromaps annotation
      v Reading neuromaps annotation [<time>]
      

# create_cortical_from_neuromaps verbose / emits 'Volume annotation detected' for .nii.gz files

    Code
      invisible(create_cortical_from_neuromaps(source = "test", desc = "vol",
        atlas_name = "test_vol", verbose = TRUE))
    Message
      i Fetching neuromaps: source="test", desc="vol"
      i Volume annotation detected -- projecting to fsaverage5 surface via
      mri_vol2surf
      
      -- Creating brain atlas "test_vol" from neuromaps ------------------------------
      i Input files: 'brain_map.nii.gz'
      i Reading neuromaps annotation
      v Reading neuromaps annotation [<time>]
      

