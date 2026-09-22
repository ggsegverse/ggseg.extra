# cerebellar_build_sf_flatmap smoothing and simplification / verbose mode prints progress messages

    Code
      result <- cerebellar_build_sf_flatmap(components, suit_flatmap_path(),
      tolerance = 0, smooth_refinements = 0, verbose = TRUE)
    Message
      i Reading SUIT flatmap surface
      i Building polygons from 28935 vertices, 56588 faces
      i Filling <n> small inter-region gaps

# download_suit_xfm / never leaves a partial download at the cached path

    Code
      download_suit_xfm("xfm.nii", cached)
    Message
      i Downloading 'xfm.nii' (~13 MB)
    Condition
      Error in `validate_suit_xfm_download()`:
      ! Downloaded file is not a valid NIfTI image. Please try again.

# download_suit_xfm / errors and cleans up when the download is too small

    Code
      download_suit_xfm("xfm.nii", cached)
    Message
      i Downloading 'xfm.nii' (~13 MB)
    Condition
      Error in `validate_suit_xfm_download()`:
      ! Download appears incomplete. Please try again.

# download_suit_xfm / atomically caches a valid downloaded NIfTI file

    Code
      result <- download_suit_xfm("xfm.nii", cached)
    Message
      i Downloading 'xfm.nii' (~13 MB)
      v Cached at '<tempfile>'

# run_cerebellar_creation verbose output / prints header and input files when verbose

    Code
      result <- run_cerebellar_creation(atlas_name = "test_verbose", config = config,
        read_fn = function() tibble(), input_files = c("file1.gii", "file2.gii"))
    Message
      
      -- Creating cerebellar atlas "test_verbose" ------------------------------------
      i Input files: 'file1.gii' and 'file2.gii'

# download_suit_xfm download failure / aborts when the download itself errors

    Code
      download_suit_xfm("xfm.nii", cached)
    Message
      i Downloading 'xfm.nii' (~13 MB)
    Condition
      Error in `download_suit_xfm()`:
      ! Failed to download deformation field
      i URL: <https://raw.githubusercontent.com/DiedrichsenLab/cerebellar_atlases/master/tpl-SUIT/xfm.nii>
      x connection reset

# cerebellar_read_data verbose and error branches / runs the verbose progress step when building fresh

    Code
      result <- cerebellar_read_data(config, dirs, read_fn = function() atlas_data)
    Message
      i Reading SUIT parcellation
      v Reading SUIT parcellation [<time>]
      

# cerebellar_project_and_build with deep nuclei / processes deep nuclei, merges views, and gathers when present

    Code
      atlas <- cerebellar_project_and_build(components = components, deep_data = deep_data,
        volume = "unused.nii.gz", atlas_name = "test_deep", config = config, dirs = dirs,
        start_time = Sys.time())
    Message
      i Projecting parcellation onto SUIT flatmap
      i Reading SUIT flatmap surface
      i Projecting parcellation onto SUIT flatmap
      i Building polygons from 28935 vertices, 56588 faces
      i Projecting parcellation onto SUIT flatmap
      i Filling <n> small inter-region gaps
      i Projecting parcellation onto SUIT flatmap
      v Projecting parcellation onto SUIT flatmap [<time>]
      
      v Brain atlas created with 1 regions
      i Pipeline completed in <n> minutes

