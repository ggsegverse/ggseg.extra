# project_volume_anatomical execution / projects labels end-to-end with FreeSurfer steps mocked

    Code
      result <- project_volume_anatomical("atlas.nii.gz", registration = "header",
        subjects_dir = "subjects", output_file = "merged.nii.gz", id_offset = 200L,
        verbose = TRUE)
    Message
      i Projecting 2 labels onto "cvs_avg35_inMNI152" aparc+aseg grid
      v Wrote anatomical-context volume: 'merged.nii.gz' (id_offset = 200, 4 labels)

