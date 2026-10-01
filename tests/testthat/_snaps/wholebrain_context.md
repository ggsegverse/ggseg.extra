# aseg_context_volume resampling / warns and falls back when the resampling fails

    Code
      expect_null(aseg_context_volume("a.nii.gz", "subj", c(2L, 2L, 2L), array(TRUE,
        c(2, 2, 2))))
    Condition
      Warning:
      Drawing the cortical context as a solid silhouette: `mri_vol2vol` failed.
      i With a FreeSurfer aseg the context keeps its sulci and gyri instead.
      Caused by error in `run_cmd()`:
      ! FreeSurfer command failed (exit 1).
      i FreeSurfer said:
        ERROR: bad header

