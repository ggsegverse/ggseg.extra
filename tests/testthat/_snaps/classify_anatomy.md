# resample_volume_to_grid() / is reported as an anatomy failure by the caller

    Code
      aparc_aseg_on_grid("aseg.mgz", volume, c(10L, 10L, 10L), array(TRUE, c(10, 10,
        10)), verbose = 0L)
    Condition
      Error in `aparc_aseg_on_grid()`:
      ! Cannot classify labels by anatomy: `mri_vol2vol` failed.
      i Classifying by anatomy needs FreeSurfer and a volume in the space its header claims.
      Caused by error in `run_cmd()`:
      ! FreeSurfer command failed (exit 1).
      i FreeSurfer said:
        ERROR: bad header

