# use_atlas_github_actions / writes every workflow by default, each calling the shared workflow

    Code
      use_atlas_github_actions(path = tmp)
    Message
      v Added 5 workflows to '.github/workflows/'
      * R-CMD-check.yaml
      * code-quality.yaml
      * pkgdown.yaml
      * render-readme.yaml
      * update-codemeta.yaml

# use_atlas_github_actions / writes only the requested workflows and returns their paths

    Code
      written <- use_atlas_github_actions("pkgdown", path = tmp)
    Message
      v Added 1 workflow to '.github/workflows/'
      * pkgdown.yaml

# use_atlas_github_actions / keeps existing workflows unless overwrite is TRUE

    Code
      use_atlas_github_actions("pkgdown", path = tmp)
    Message
      i Kept 1 existing workflow: 'pkgdown.yaml'
      i `overwrite = TRUE` replaces it

---

    Code
      use_atlas_github_actions("pkgdown", path = tmp, overwrite = TRUE)
    Message
      v Added 1 workflow to '.github/workflows/'
      * pkgdown.yaml

# use_atlas_github_actions / renders the README source that atlas packages actually use

    Code
      use_atlas_github_actions("render-readme", path = tmp)
    Message
      v Added 1 workflow to '.github/workflows/'
      * render-readme.yaml

