# setup_atlas_repo / derives the package name from a ggsegXxx path

    Code
      setup_atlas_repo(tmp, open = FALSE)
    Message
      
      -- Creating ggsegSchaefer --
      
      v Created 'R/', 'tests/', 'data-raw/'
      v Replaced template placeholders
      v Added 5 workflows to '.github/workflows/'
      * R-CMD-check.yaml
      * code-quality.yaml
      * pkgdown.yaml
      * render-readme.yaml
      * update-codemeta.yaml
      v Created 'ggsegSchaefer.Rproj'
      --------------------------------------------------------------------------------
      v Created atlas package ggsegSchaefer
      i Location: '<tempfile>'
      
      -- Next steps 
      Edit 'data-raw/create-atlas.R' to create your atlas
      Update 'R/data.R' with documentation and citation
      Add atlas citation to 'README.qmd'
      Run `devtools::document()` to generate documentation
      Run `devtools::check()` to verify the package

# setup_atlas_repo / skips .Rproj file when rstudio = FALSE

    Code
      setup_atlas_repo(tmp, atlas_name = "test", open = FALSE, rstudio = FALSE)
    Message
      
      -- Creating ggsegTest --
      
      v Created 'R/', 'tests/', 'data-raw/'
      v Replaced template placeholders
      v Added 5 workflows to '.github/workflows/'
      * R-CMD-check.yaml
      * code-quality.yaml
      * pkgdown.yaml
      * render-readme.yaml
      * update-codemeta.yaml
      --------------------------------------------------------------------------------
      v Created atlas package ggsegTest
      i Location: '<tempfile>'
      
      -- Next steps 
      Edit 'data-raw/create-atlas.R' to create your atlas
      Update 'R/data.R' with documentation and citation
      Add atlas citation to 'README.qmd'
      Run `devtools::document()` to generate documentation
      Run `devtools::check()` to verify the package

# setup_atlas_repo template files

    Code
      result <- setup_atlas_repo(tmp, atlas_name = "testatlas", open = TRUE)
    Message
      
      -- Creating ggsegTestatlas --
      
      v Created 'R/', 'tests/', 'data-raw/'
      v Replaced template placeholders
      v Added 5 workflows to '.github/workflows/'
      * R-CMD-check.yaml
      * code-quality.yaml
      * pkgdown.yaml
      * render-readme.yaml
      * update-codemeta.yaml
      v Created 'ggsegTestatlas.Rproj'
      --------------------------------------------------------------------------------
      v Created atlas package ggsegTestatlas
      i Location: '<tempfile>'
      
      -- Next steps 
      Edit 'data-raw/create-atlas.R' to create your atlas
      Update 'R/data.R' with documentation and citation
      Add atlas citation to 'README.qmd'
      Run `devtools::document()` to generate documentation
      Run `devtools::check()` to verify the package

# setup_atlas_repo github actions / with the shared workflows

    Code
      setup_atlas_repo(tmp, atlas_name = "gha", open = FALSE, rstudio = FALSE)
    Message
      
      -- Creating ggsegGha --
      
      v Created 'R/', 'tests/', 'data-raw/'
      v Replaced template placeholders
      v Added 5 workflows to '.github/workflows/'
      * R-CMD-check.yaml
      * code-quality.yaml
      * pkgdown.yaml
      * render-readme.yaml
      * update-codemeta.yaml
      --------------------------------------------------------------------------------
      v Created atlas package ggsegGha
      i Location: '<tempfile>'
      
      -- Next steps 
      Edit 'data-raw/create-atlas.R' to create your atlas
      Update 'R/data.R' with documentation and citation
      Add atlas citation to 'README.qmd'
      Run `devtools::document()` to generate documentation
      Run `devtools::check()` to verify the package

# setup_atlas_repo github actions / skips workflows when github_actions is FALSE

    Code
      setup_atlas_repo(tmp, atlas_name = "gha", open = FALSE, rstudio = FALSE,
        github_actions = FALSE)
    Message
      
      -- Creating ggsegGha --
      
      v Created 'R/', 'tests/', 'data-raw/'
      v Replaced template placeholders
      --------------------------------------------------------------------------------
      v Created atlas package ggsegGha
      i Location: '<tempfile>'
      
      -- Next steps 
      Edit 'data-raw/create-atlas.R' to create your atlas
      Update 'R/data.R' with documentation and citation
      Add atlas citation to 'README.qmd'
      Run `devtools::document()` to generate documentation
      Run `devtools::check()` to verify the package

# template_replace error handling / returns NULL and warns for unreadable files

    Code
      result <- template_replace("/nonexistent/path/file.txt", "test")
    Condition
      Warning in `file()`:
      cannot open file '/nonexistent/path/file.txt': No such file or directory
      Warning:
      Failed to process template '/nonexistent/path/file.txt': cannot open the connection

