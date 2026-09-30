# sitrep / returns list of results invisibly

    Code
      result <- sitrep("simple")
    Message
      v FreeSurfer
      v fsaverage5
      v R packages: freesurferformats, gifti, ciftiTools, RNifti, Rvcg, neuromapr, and princurve
      v SUIT surfaces (bundled)
      
      
      -- Pipeline readiness (13/13) 
      Cortical
      v from annotation
      v from GIFTI
      v from CIFTI
      v from neuromaps
      v from labels
      Subcortical
      v from volume
      Tract
      v from tractography
      v from volume
      Whole-brain
      v from volume
      Cerebellar
      v from GIFTI
      v from annotation
      v from volume
      v MNI to SUIT transform
      
      v All 13 pipelines ready

# sitrep / reports paths and options in full detail

    Code
      sitrep("full")
    Message
      v fsaverage5: 'subjects/fsaverage5'
      v R packages: freesurferformats, gifti, ciftiTools, RNifti, Rvcg, neuromapr, and princurve
      v SUIT surfaces (bundled)
      
      
      -- Pipeline options 
      verbose: 0
      cleanup: TRUE
      skip_existing: TRUE
      output_dir: '/atlas-output'
      
      i Set via `options(ggseg.extra.<name> = value)` or environment variables
        `GGSEG_EXTRA_<NAME>`
      i See `vignette("pipeline-configuration")` for details
      
      
      -- Pipeline readiness (13/13) 
      Cortical
      v from annotation
      v from GIFTI
      v from CIFTI
      v from neuromaps
      v from labels
      Subcortical
      v from volume
      Tract
      v from tractography
      v from volume
      Whole-brain
      v from volume
      Cerebellar
      v from GIFTI
      v from annotation
      v from volume
      v MNI to SUIT transform
      
      v All 13 pipelines ready

# summarize_pipelines / shows all pipelines ready when deps are met

    Code
      summarize_pipelines(make_results(), "simple")
    Message
      
      -- Pipeline readiness (13/13) 
      Cortical
      v from annotation
      v from GIFTI
      v from CIFTI
      v from neuromaps
      v from labels
      Subcortical
      v from volume
      Tract
      v from tractography
      v from volume
      Whole-brain
      v from volume
      Cerebellar
      v from GIFTI
      v from annotation
      v from volume
      v MNI to SUIT transform
      
      v All 13 pipelines ready

# summarize_pipelines / shows missing deps per pipeline

    Code
      summarize_pipelines(make_results(gifti = FALSE, cifti = FALSE), "simple")
    Message
      
      -- Pipeline readiness (9/13) 
      Cortical
      v from annotation
      v from GIFTI
      x from CIFTI: needs {ciftiTools}
      x from neuromaps: needs {gifti}
      v from labels
      Subcortical
      v from volume
      Tract
      v from tractography
      v from volume
      Whole-brain
      v from volume
      Cerebellar
      x from GIFTI: needs {gifti}
      v from annotation
      x from volume: needs {gifti}
      v MNI to SUIT transform
      
      i 9/13 pipelines ready
      i Run `sitrep("full")` for install instructions

# summarize_pipelines / minimal collapses ready groups

    Code
      summarize_pipelines(make_results(), "minimal")
    Message
      
      -- Pipeline readiness (13/13) 
      v Cortical: all 5 ready
      v Subcortical: all 1 ready
      v Tract: all 2 ready
      v Whole-brain: all 1 ready
      v Cerebellar: all 4 ready
      
      v All 13 pipelines ready

# summarize_pipelines / lists only failing pipelines and hints sitrep in minimal mode

    Code
      summarize_pipelines(make_results(gifti = FALSE), "minimal")
    Message
      
      -- Pipeline readiness (10/13) 
      x from neuromaps: needs {gifti}
      v Subcortical: all 1 ready
      v Tract: all 2 ready
      v Whole-brain: all 1 ready
      x from GIFTI: needs {gifti}
      x from volume: needs {gifti}
      
      i 10/13 pipelines ready
      i Run `sitrep()` for details

# summarize_pipelines / full shows install hints for missing deps

    Code
      summarize_pipelines(make_results(gifti = FALSE), "full")
    Message
      
      -- Pipeline readiness (10/13) 
      Cortical
      v from annotation
      v from GIFTI
      v from CIFTI
      x from neuromaps: needs {gifti}
      i `install.packages("gifti")`
      v from labels
      Subcortical
      v from volume
      Tract
      v from tractography
      v from volume
      Whole-brain
      v from volume
      Cerebellar
      x from GIFTI: needs {gifti}
      i `install.packages("gifti")`
      v from annotation
      x from volume: needs {gifti}
      i `install.packages("gifti")`
      v MNI to SUIT transform
      
      i 10/13 pipelines ready

# check_freesurfer when freesurfer package absent / shows install command in full detail

    Code
      invisible(check_freesurfer("full"))
    Message
      x freesurfer R package (>= 1.8.1.902) not installed
      i Install with: `remotes::install_github("muschellij2/freesurfer")`

# check_fsaverage additional branches / shows Ships-with-FreeSurfer hint in full detail when absent

    Code
      invisible(check_fsaverage("full"))
    Message
      x fsaverage5 not found
      i Ships with FreeSurfer in $SUBJECTS_DIR

# check_optional_packages additional branches / shows install command in full detail for missing packages

    Code
      invisible(check_optional_packages("full"))
    Message
      v R packages: RNifti
      x Missing R packages: freesurferformats, gifti, ciftiTools, Rvcg, neuromapr, and princurve
      i Install with: `install.packages(c("freesurferformats", "gifti", "ciftiTools",
        "Rvcg", "neuromapr", "princurve"))`

# check_suit_surfaces additional branches / shows reinstall hint in full detail when missing

    Code
      invisible(check_suit_surfaces("full"))
    Message
      x SUIT flatmap surface missing
      x SUIT 3D surface missing
      i These should be bundled with the package.
      i Try reinstalling: `remotes::install_github("ggsegverse/ggseg.extra")`

# setup_sitrep (deprecated) / warns and delegates to the renamed function

    Code
      invisible(setup_sitrep("minimal"))
    Condition
      Warning:
      `setup_sitrep()` was deprecated in ggseg.extra 1.9.9.9075.
      i Please use `sitrep()` instead.
    Message
      
      -- Pipeline readiness (13/13) 
      v Cortical: all 5 ready
      v Subcortical: all 1 ready
      v Tract: all 2 ready
      v Whole-brain: all 1 ready
      v Cerebellar: all 4 ready
      
      v All 13 pipelines ready

