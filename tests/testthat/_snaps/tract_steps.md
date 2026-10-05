# tract_log_header / prints info when verbose

    Code
      tract_log_header(config, "tract.trk", "aseg.mgz")
    Message
      
      -- Creating tractography atlas -------------------------------------------------
      i Tract files: 'tract.trk'
      i Anatomical reference: 'aseg.mgz'

# tract_check_aseg / aborts when a 2D step is asked for without a segmentation

    Code
      tract_check_aseg(NULL, 1L:4L)
    Condition
      Error in `tract_check_aseg()`:
      ! `input_aseg` is required for steps 2-4.
      i The 2D views are drawn against a segmentation volume, such as 'aparc+aseg.mgz'.
      i Pass `steps = 1` for a 3D-only atlas, which needs none.

