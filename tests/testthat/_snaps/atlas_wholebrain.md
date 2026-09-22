# wholebrain_classify_labels verbose output / prints classification summary when verbose

    Code
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE)
    Condition
      Warning:
      Classified 2 labels by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 1 cortical, 1 subcortical, 0 cerebellar labels
      > Subcortical: small (10v)
    Output
      $cortical_labels
      [1] "big"
      
      $subcortical_labels
      [1] "small"
      
      $cerebellar_labels
      character(0)
      
      $vertex_counts
        big small 
        100    10 
      

# wholebrain_classify_labels verbose output / prints subcortical detail when subcortical labels exist

    Code
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE)
    Condition
      Warning:
      Classified 2 labels by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 1 cortical, 1 subcortical, 0 cerebellar labels
      > Subcortical: tiny (5v)
    Output
      $cortical_labels
      [1] "big"
      
      $subcortical_labels
      [1] "tiny"
      
      $cerebellar_labels
      character(0)
      
      $vertex_counts
       big tiny 
       200    5 
      

# wholebrain_classify_labels verbose output / does not print subcortical detail when all cortical

    Code
      wholebrain_classify_labels(ad, min_vertices = 50L, verbose = TRUE)
    Condition
      Warning:
      Classified 2 labels by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 2 cortical, 0 subcortical, 0 cerebellar labels
    Output
      $cortical_labels
      [1] "big"    "bigger"
      
      $subcortical_labels
      character(0)
      
      $cerebellar_labels
      character(0)
      
      $vertex_counts
         big bigger 
         200    300 
      

# create_wholebrain_from_volume verbose and cleanup / logs verbose output, cleans up temp files, and removes directory

    Code
      invisible(create_wholebrain_from_volume(input_volume = vol_file, steps = 1:4,
      verbose = TRUE, cleanup = TRUE))
    Message
      
      -- Creating whole-brain atlas "wb" ---------------------------------------------
      ! This pipeline combines volume-to-surface projection with automatic
      cortical/subcortical classification. Both steps are heuristic and require
      manual validation. Run with `steps = 1:2` first to inspect the label split
      before committing to the full pipeline.
      i Volume: 'wb.nii.gz'
      i Setting output directory to 'out'
      
      -- Surface projection --
      
      i Projecting volume onto surface
    Condition
      Warning:
      No color lookup table provided
      i Region names will be generic (e.g., 'region_0010')
      i The atlas will have no palette; plotting picks its own colours
    Message
      v Projecting volume onto surface [<time>]
      
      
      -- Label classification --
      
      i Classifying cortical/subcortical/cerebellar labels
    Condition
      Warning:
      Classified 1 label by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 1 cortical, 0 subcortical, 0 cerebellar labels
      i Classifying cortical/subcortical/cerebellar labels
      v Classifying cortical/subcortical/cerebellar labels [<time>]
      
      v Temporary files removed
      v Whole-brain atlas created: 1 cortical, 0 subcortical, 0 cerebellar

# create_wholebrain_from_volume verbose and cleanup / logs elapsed time for early return at step 2

    Code
      invisible(create_wholebrain_from_volume(input_volume = vol_file, steps = 1:2,
      verbose = TRUE, cleanup = FALSE))
    Message
      
      -- Creating whole-brain atlas "wb" ---------------------------------------------
      ! This pipeline combines volume-to-surface projection with automatic
      cortical/subcortical classification. Both steps are heuristic and require
      manual validation. Run with `steps = 1:2` first to inspect the label split
      before committing to the full pipeline.
      i Volume: 'wb.nii.gz'
      i Setting output directory to 'out'
      
      -- Surface projection --
      
      i Projecting volume onto surface
    Condition
      Warning:
      No color lookup table provided
      i Region names will be generic (e.g., 'region_0010')
      i The atlas will have no palette; plotting picks its own colours
    Message
      v Projecting volume onto surface [<time>]
      
      
      -- Label classification --
      
      i Classifying cortical/subcortical/cerebellar labels
    Condition
      Warning:
      Classified 1 label by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 1 cortical, 0 subcortical, 0 cerebellar labels
      i Classifying cortical/subcortical/cerebellar labels
      v Classifying cortical/subcortical/cerebellar labels [<time>]
      
      i Inspect `split$cortical_labels`, `split$subcortical_labels`, and
      `split$cerebellar_labels`. Override with
      `cortical_labels`/`subcortical_labels`/ `cerebellar_labels` if needed, then
      re-run with all steps.

# wholebrain_resolve_projection cached path / returns cached data and logs when verbose

    Code
      result <- wholebrain_resolve_projection(config, dirs)
    Message
      
      -- Surface projection --
      
      v Loaded existing surface projection

# wholebrain_resolve_split cached path / returns cached split and logs when verbose

    Code
      result <- wholebrain_resolve_split(config, dirs, projection)
    Message
      
      -- Label classification --
      
      v Loaded existing label classification

# wholebrain_run_cortical verbose logging / logs progress step and validates cortical config

    Code
      result <- wholebrain_run_cortical(config, dirs, projection, split)
    Message
      
      -- Cortical pipeline (1 regions) --
      

# wholebrain_run_subcortical verbose logging / logs progress step and filters subcortical data

    Code
      result <- wholebrain_run_subcortical(config, dirs, split, colortable = colortable)
    Message
      -- Subcortical pipeline (1 regions) --
      

# create_wholebrain_from_volume oversight warning / warns about manual validation when verbose

    Code
      invisible(create_wholebrain_from_volume(input_volume = vol_file, steps = 1:2,
      verbose = TRUE))
    Message
      
      -- Creating whole-brain atlas "wb" ---------------------------------------------
      ! This pipeline combines volume-to-surface projection with automatic
      cortical/subcortical classification. Both steps are heuristic and require
      manual validation. Run with `steps = 1:2` first to inspect the label split
      before committing to the full pipeline.
      i Volume: 'wb.nii.gz'
      i Setting output directory to 'out'
      
      -- Surface projection --
      
      i Projecting volume onto surface
    Condition
      Warning:
      No color lookup table provided
      i Region names will be generic (e.g., 'region_0010')
      i The atlas will have no palette; plotting picks its own colours
    Message
      v Projecting volume onto surface [<time>]
      
      
      -- Label classification --
      
      i Classifying cortical/subcortical/cerebellar labels
    Condition
      Warning:
      Classified 1 label by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 1 cortical, 0 subcortical, 0 cerebellar labels
      i Classifying cortical/subcortical/cerebellar labels
      v Classifying cortical/subcortical/cerebellar labels [<time>]
      
      i Inspect `split$cortical_labels`, `split$subcortical_labels`, and
      `split$cerebellar_labels`. Override with
      `cortical_labels`/`subcortical_labels`/ `cerebellar_labels` if needed, then
      re-run with all steps.

# create_wholebrain_from_volume verbose LUT path / prints LUT path when verbose and input_lut is not NULL

    Code
      invisible(create_wholebrain_from_volume(input_volume = vol_file, input_lut = lut_file,
        steps = 1:2, verbose = TRUE))
    Message
      
      -- Creating whole-brain atlas "wb" ---------------------------------------------
      ! This pipeline combines volume-to-surface projection with automatic
      cortical/subcortical classification. Both steps are heuristic and require
      manual validation. Run with `steps = 1:2` first to inspect the label split
      before committing to the full pipeline.
      i Volume: 'wb.nii.gz'
      i Color LUT: 'lut.txt'
      i Setting output directory to 'out'
      
      -- Surface projection --
      
      i Projecting volume onto surface
      v Projecting volume onto surface [<time>]
      
      -- Label classification --
      
      i Classifying cortical/subcortical/cerebellar labels
    Condition
      Warning:
      Classified 1 label by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 1 cortical, 0 subcortical, 0 cerebellar labels
      i Classifying cortical/subcortical/cerebellar labels
      v Classifying cortical/subcortical/cerebellar labels [<time>]
      
      i Inspect `split$cortical_labels`, `split$subcortical_labels`, and
      `split$cerebellar_labels`. Override with
      `cortical_labels`/`subcortical_labels`/ `cerebellar_labels` if needed, then
      re-run with all steps.

# wholebrain_project_to_surface / prints verbose fill_surface_labels message

    Code
      result <- wholebrain_project_to_surface(input_volume = "fake.nii.gz",
        colortable = colortable, subject = "fsaverage5", projfrac = 0.5,
        projfrac_range = NULL, registration = "header", output_dir = tmp_dir,
        verbose = TRUE)
    Message
      > lh: 5 -> 10 labeled vertices (100% cortex, 0 medial wall)
      > rh: 5 -> 10 labeled vertices (100% cortex, 0 medial wall)

# wholebrain_run_cortical verbose progress_done / calls cli_progress_done when verbose

    Code
      result <- wholebrain_run_cortical(config, dirs, projection, split)
    Message
      
      -- Cortical pipeline (1 regions) --
      

# wholebrain_classify_labels additional verbose branches / prints cerebellar detail when cerebellar labels exist and verbose

    Code
      wholebrain_classify_labels(ad, min_vertices = 50L, cerebellar_labels = "lobule_I",
        verbose = TRUE)
    Condition
      Warning:
      Classified 1 label by surface vertex count, not by anatomy.
      ! The vertex count measures how much surface a label covers, so a small cortical parcel and a deep structure look the same to it.
      i Declare the labels instead: `lut_classify_anatomy()` fills in a type column from FreeSurfer's aparc+aseg, or pass `cortical_labels`/`subcortical_labels`/ `cerebellar_labels`.
    Message
      i 1 cortical, 0 subcortical, 1 cerebellar labels
      > Cerebellar: lobule_I (80v)
    Output
      $cortical_labels
      [1] "cortex_a"
      
      $subcortical_labels
      character(0)
      
      $cerebellar_labels
      [1] "lobule_I"
      
      $vertex_counts
      cortex_a lobule_I 
           100       80 
      

# wholebrain_run_cerebellar / prints verbose header

    Code
      result <- wholebrain_run_cerebellar(config, dirs, split, colortable)
    Message
      
      -- Cerebellar pipeline (1 regions) --
      
      i Treating the cerebellar volume as already in SUIT space (`cerebellar_space =
      "suit"`).

# wholebrain_log_summary / counts present atlases and reports absent ones as zero

    Code
      result <- wholebrain_log_summary(cortical_atlas = NULL, subcortical_atlas = subcortical, cerebellar_atlas = cerebellar, start_time = Sys.time())
    Message
      v Whole-brain atlas created: 0 cortical, 2 subcortical, 1 cerebellar
      i Pipeline completed [<time>]

# wholebrain_refine_cortical_projection verbose / logs progress steps when verbose is enabled

    Code
      result <- wholebrain_refine_cortical_projection(config, dirs, projection, split)
    Message
      i Refining cortical projection (keeping 1 cortical labels on the surface)
      v Refining cortical projection (keeping 1 cortical labels on the surface) [<t...
      

# create_wholebrain_from_volume argument groups / lands the retired flat arguments where the lists now hold them

    Code
      old <- capture_setup(list(cortical_labels = c("a", "b"), subcortical_labels = "c",
      projfrac = 0.7, subject = "fsaverage6"))
    Condition
      Warning:
      The `cortical_labels` argument of `create_wholebrain_from_volume()` is deprecated as of ggseg.extra 1.9.9.9052.
      i Please use the `labels` argument instead.
      Warning:
      The `subcortical_labels` argument of `create_wholebrain_from_volume()` is deprecated as of ggseg.extra 1.9.9.9052.
      i Please use the `labels` argument instead.
      Warning:
      The `projfrac` argument of `create_wholebrain_from_volume()` is deprecated as of ggseg.extra 1.9.9.9052.
      i Please use the `projection_opts` argument instead.
      Warning:
      The `subject` argument of `create_wholebrain_from_volume()` is deprecated as of ggseg.extra 1.9.9.9052.
      i Please use the `projection_opts` argument instead.

