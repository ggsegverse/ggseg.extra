# resolve_tract_coord_space / reports which space is in force, and how it was settled

    Code
      declared <- resolve_tract_coord_space(tracts, verbose = TRUE,
        coords_are_voxels = TRUE)
    Message
      i Coordinate space (as declared): "voxel"
    Code
      inferred <- resolve_tract_coord_space(tracts, verbose = TRUE)
    Message
      i Auto-detected coordinate space: "voxel"
      i Set `coord_space` to declare it instead of relying on the heuristic.

