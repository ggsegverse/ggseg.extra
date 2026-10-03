# create_subcortical_from_volume pipeline flow / returns 3D-only atlas with correct structure count

    Code
      atlas <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 1:3, verbose = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: 'aseg.mgz'
      i Color LUT: 'lut.txt'
      i Setting output directory to '<workdir>/out'
      i 1/6 Extracting labels from volume
      v Found 2 subcortical structures
      i 1/6 Extracting labels from volume
      v 1/6 Extracting labels from volume [<time>]
      
      i 2/6 Creating meshes for each structure
      v 2/6 Creating meshes for each structure [<time>]
      
      i 3/6 Building atlas data
      v 3/6 Building atlas data [<time>]
      
      v Temporary files removed
      v 3D atlas created with 2 structures
      i Pipeline completed [<time>]

# create_subcortical_from_volume pipeline flow / loads cached data for skipped steps and proceeds

    Code
      result <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 5, verbose = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: 'aseg.mgz'
      i Color LUT: 'lut.txt'
      i Setting output directory to '<workdir>/out'
      v 1/6 Loaded existing labels
      v 2/6 Loaded existing meshes
      v 3/6 Loaded existing components
      v 4/6 Loaded existing slabs
      v Temporary files removed
      v Completed step 5
      i Pipeline completed [<time>]

# create_subcortical_from_volume pipeline flow / step 6 builds final atlas with cleanup

    Code
      atlas <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 6, verbose = TRUE, cleanup = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: 'aseg.mgz'
      i Color LUT: 'lut.txt'
      i Setting output directory to '<workdir>/out'
      v 1/6 Loaded existing labels
      v 2/6 Loaded existing meshes
      v 3/6 Loaded existing components
      v 4/6 Loaded existing slabs
    Condition
      Warning:
      Atlas has no 2D geometry
    Message
      v Temporary files removed
      v Subcortical atlas created with 1 structures
      i Pipeline completed [<time>]

# create_subcortical_from_volume pipeline flow / returns invisible NULL for partial steps

    Code
      result <- create_subcortical_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 5L, verbose = TRUE)
    Message
      
      -- Creating subcortical atlas "aseg" -------------------------------------------
      i Volume: 'aseg.mgz'
      i Color LUT: 'lut.txt'
      i Setting output directory to '<workdir>/out'
      v 1/6 Loaded existing labels
      v 2/6 Loaded existing meshes
      v 3/6 Loaded existing components
      v 4/6 Loaded existing slabs
      v Temporary files removed
      v Completed step 5
      i Pipeline completed [<time>]

# subcort_resolve_snapshots / runs snapshots and logs progress when the step executes with verbose

    Code
      result <- subcort_resolve_snapshots(config, dirs, colortable, NULL)
    Message
      i 4/6 Creating projection snapshots
      v 4/6 Creating projection snapshots [<time>]
      

