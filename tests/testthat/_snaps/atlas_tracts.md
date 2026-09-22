# create_tract_from_tractography pipeline flow / loads cached data for skipped steps and proceeds

    Code
      result <- create_tract_from_tractography(input_tracts = tract_file, input_aseg = aseg_file,
        steps = 3:6, verbose = TRUE)
    Message
      
      -- Creating tractography atlas -------------------------------------------------
      i Tract files: 'tract.trk'
      i Anatomical reference: 'aseg.mgz'
      v 1/7 Loaded existing tract data
      v 2/7 Loaded existing snapshots
      v Temporary files removed
      v Completed steps 3, 4, 5, and 6
      i Pipeline completed [<time>]

# create_tract_from_tractography pipeline flow / step 1 returns 3D-only atlas with verbose and cleanup

    Code
      atlas <- create_tract_from_tractography(input_tracts = tract_file, steps = 1,
        verbose = TRUE, cleanup = TRUE)
    Message
      
      -- Creating tractography atlas -------------------------------------------------
      i Tract files: 'tract.trk'
      i Auto-detected coordinate space: "voxel"
      i 1/7 Creating tube meshes for 1 tracts
      v 1/7 Creating tube meshes for 1 tracts [<time>]
      
      v Temporary files removed
      v 3D atlas created with 1 tracts
      i Pipeline completed [<time>]

# create_tract_from_tractography pipeline flow / step 7 builds final atlas with cleanup

    Code
      atlas <- create_tract_from_tractography(input_tracts = tract_file, input_aseg = aseg_file,
        steps = 7, verbose = TRUE, cleanup = TRUE)
    Message
      
      -- Creating tractography atlas -------------------------------------------------
      i Tract files: 'tract.trk'
      i Anatomical reference: 'aseg.mgz'
      v 1/7 Loaded existing tract data
      v 2/7 Loaded existing snapshots
    Condition
      Warning:
      Atlas has no 2D geometry
    Message
      v Temporary files removed
      v Tract atlas created with 1 tracts
      i Pipeline completed [<time>]

# create_tract_from_tractography tube_opts / lands the retired flat arguments where tube_opts now holds them

    Code
      old <- capture_tube(list(tube_radius = 3, tube_segments = 16, n_points = 25,
        centerline_method = "medoid"))
    Condition
      Warning:
      The `tube_radius` argument of `create_tract_from_tractography()` is deprecated as of ggseg.extra 1.9.9.9053.
      i Please use the `tube_opts` argument instead.
      Warning:
      The `tube_segments` argument of `create_tract_from_tractography()` is deprecated as of ggseg.extra 1.9.9.9053.
      i Please use the `tube_opts` argument instead.
      Warning:
      The `n_points` argument of `create_tract_from_tractography()` is deprecated as of ggseg.extra 1.9.9.9053.
      i Please use the `tube_opts` argument instead.
      Warning:
      The `centerline_method` argument of `create_tract_from_tractography()` is deprecated as of ggseg.extra 1.9.9.9053.
      i Please use the `tube_opts` argument instead.

