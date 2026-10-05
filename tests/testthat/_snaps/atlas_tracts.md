# create_tract_from_tractography pipeline flow / loads cached data for skipped steps and proceeds

    Code
      result <- create_tract_from_tractography(input_tracts = tract_file, input_aseg = aseg_file,
        steps = 3, verbose = TRUE)
    Message
      
      -- Creating tractography atlas -------------------------------------------------
      i Tract files: 'tract.trk'
      i Anatomical reference: 'aseg.mgz'
      v 1/4 Loaded existing tract data
      v 2/4 Loaded existing snapshots
      i Keeping the working directory so step 4 can reuse it. The run that finishes
      the atlas removes it.
      v Completed step 3
      i Pipeline completed [<time>]

# create_tract_from_tractography pipeline flow / step 1 returns 3D-only atlas with verbose and cleanup

    Code
      atlas <- create_tract_from_tractography(input_tracts = tract_file, steps = 1,
        verbose = TRUE, cleanup = TRUE)
    Message
      
      -- Creating tractography atlas -------------------------------------------------
      i Tract files: 'tract.trk'
      i Coordinate space (from the tractography files): "mm"
      i 1/4 Creating tube meshes for 1 tracts
      v 1/4 Creating tube meshes for 1 tracts [<time>]
      
      i Keeping the working directory so steps 2, 3, and 4 can reuse it. The run that
      finishes the atlas removes it.
      v 3D atlas created with 1 tracts
      i Pipeline completed [<time>]

# create_tract_from_tractography pipeline flow / step 4 builds final atlas with cleanup

    Code
      atlas <- create_tract_from_tractography(input_tracts = tract_file, input_aseg = aseg_file,
        steps = 4, verbose = TRUE, cleanup = TRUE)
    Message
      
      -- Creating tractography atlas -------------------------------------------------
      i Tract files: 'tract.trk'
      i Anatomical reference: 'aseg.mgz'
      v 1/4 Loaded existing tract data
      v 2/4 Loaded existing snapshots
    Condition
      Warning:
      Atlas has no 2D geometry
    Message
      v Temporary files removed
      v Tract atlas created with 1 tracts
      i Pipeline completed [<time>]

# coord_space_to_voxels / rejects a space it does not know

    Code
      coord_space_to_voxels("ras")
    Condition
      Error in `coord_space_to_voxels()`:
      ! `coord_space` must be one of "infer", "voxel", or "mm", not "ras".

# coord_space_to_voxels / rejects voxel space for tractography files

    Code
      coord_space_to_voxels("voxel", from_files = TRUE)
    Condition
      Error in `coord_space_to_voxels()`:
      ! `coord_space` cannot be "voxel" for tractography files.
      i '.trk' and '.tck' files are read into RAS world millimetres, whatever space they store.
      i `coord_space` describes streamlines passed as coordinate matrices. Leave it out for files.

