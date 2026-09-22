# subcort_create_meshes / warns and skips when tessellation fails with verbose

    Code
      subcort_create_meshes("fake.mgz", colortable, dirs, FALSE, TRUE)
    Condition
      Warning:
      Failed to create mesh for Left-Putamen: mesh error
      Warning:
      Failed to create mesh for Right-Putamen: mesh error
      Error in `subcort_create_meshes()`:
      ! No meshes were successfully created

# subcort_decimate_meshes / reports NA%, not NaN%, when all meshes have zero faces

    Code
      result <- subcort_decimate_meshes(empty_meshes, decimate = 0.5, verbose = TRUE)
    Message
      i Decimating meshes to 50% of original faces
      v Reduced from 0 to 0 faces (NA%)

# subcort_log_header / prints volume path when verbose

    Code
      subcort_log_header(config)
    Message
      
      -- Creating subcortical atlas "test_atlas" -------------------------------------
      i Volume: '/path/to/volume.mgz'
      i Color LUT: '/path/to/lut.txt'
      i Setting output directory to '/tmp/output'

# subcort_create_meshes / logs decimation stats when verbose and decimate < 1

    Code
      result <- subcort_create_meshes("fake.mgz", colortable, dirs, skip_existing = FALSE,
        verbose = TRUE, decimate = 0.5)
    Message
      i Decimating meshes to 50% of original faces
      v Reduced from 5 to 3 faces (60%)
      v Created 1 meshes

