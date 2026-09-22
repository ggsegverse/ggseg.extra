# create_subcortical_from_volume pipeline flow / returns 3D-only atlas with correct structure count

    Code
      atlas <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 1:3, verbose = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: '<tempfile>'
      i Color LUT: '<tempfile>'
      i Setting output directory to '<tempfile>'
      i 1/9 Extracting labels from volume
      v Found 2 subcortical structures
      i 1/9 Extracting labels from volume
      v 1/9 Extracting labels from volume [<time>]
      
      i 2/9 Creating meshes for each structure
      v 2/9 Creating meshes for each structure [<time>]
      
      i 3/9 Building atlas data
      v 3/9 Building atlas data [<time>]
      
      v Temporary files removed
      v 3D atlas created with 2 structures
      i Pipeline completed in <n> minutes

# create_subcortical_from_volume pipeline flow / loads cached data for skipped steps and proceeds

    Code
      result <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 5:8, verbose = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: '<tempfile>'
      i Color LUT: '<tempfile>'
      i Setting output directory to '<tempfile>'
      v 1/9 Loaded existing labels
      v 2/9 Loaded existing meshes
      v 3/9 Loaded existing components
      v 4/9 Loaded existing slabs
      v Temporary files removed
      v Completed steps 5, 6, 7, and 8
      i Pipeline completed in <n> minutes

# create_subcortical_from_volume pipeline flow / step 9 builds final atlas with cleanup

    Code
      atlas <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 9, verbose = TRUE, cleanup = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: '<tempfile>'
      i Color LUT: '<tempfile>'
      i Setting output directory to '<tempfile>'
      v 1/9 Loaded existing labels
      v 2/9 Loaded existing meshes
      v 3/9 Loaded existing components
      v 4/9 Loaded existing slabs
    Condition
      Warning:
      Atlas has no 2D geometry
    Message
      v Temporary files removed
      v Subcortical atlas created with 1 structures
      i Pipeline completed in <n> minutes

# create_subcortical_from_volume pipeline flow / returns invisible NULL for partial steps

    Code
      result <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 5L, verbose = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: '<tempfile>'
      i Color LUT: '<tempfile>'
      i Setting output directory to '<tempfile>'
      v 1/9 Loaded existing labels
      v 2/9 Loaded existing meshes
      v 3/9 Loaded existing components
      v 4/9 Loaded existing slabs
      v Temporary files removed
      v Completed steps 5
      i Pipeline completed in <n> minutes

# subcort_resolve_snapshots early-return NULL / runs snapshots and logs progress when the step executes with verbose

    Code
      result <- subcort_resolve_snapshots(config, dirs, colortable, NULL)
    Message
      i 4/9 Creating projection snapshots
      v 4/9 Creating projection snapshots [<time>]
      

# subcort_drop_missing_labels / treats non-data.frame sf_data as having no labels and aborts

    Code
      subcort_drop_missing_labels(make_components(), NULL)
    Condition
      Warning:
      Dropping 2 labels with no valid contour data.
      i Dropped: "region_a" and "region_b".
      Error in `subcort_drop_missing_labels()`:
      ! No labels with valid contour data remain. Cannot build atlas.

