## R CMD check results

Local, macOS 26.6, R 4.6, `R CMD check --no-manual --as-cran`:
0 errors | 0 warnings | 1 note.

The note is the standard "New submission". Tests: 3215 pass, 0 fail, 0 skip.
Vignettes rebuild cleanly.

## First submission

ggseg.extra builds brain atlas data sets for the ggsegverse plotting
packages, ggseg and ggseg3d, which are already on CRAN. It has been
distributed on r-universe (<https://ggsegverse.r-universe.dev>) until now.

No reverse dependencies on CRAN.

## SystemRequirements

The atlas-construction pipelines drive FreeSurfer
(<https://surfer.nmr.mgh.harvard.edu/>) and, optionally, Connectome
Workbench. Neither can be bundled, and FreeSurfer is Linux and macOS only.
Nothing is touched at load time: each pipeline checks for the tool it needs
and errors informatively if it is absent, `sitrep()` reports what is
available, and the tests skip those paths, so the check is clean without
them. `V8` is listed because `rmapshaper`, used for polygon simplification
in every pipeline, requires it.

## `\dontrun{}` in examples

36 of 58 help pages use `\dontrun{}`. Most are the atlas-construction entry
points and external-format readers, which cannot run without FreeSurfer,
Connectome Workbench or a large source file we should not download during a
check; they are what the package is for, so we document the real call. The
rest are short follow-on blocks beside an already-executable example,
showing the two-pass idiom a real build uses.

`\donttest{}` would not help: those examples are run by `--as-cran` and
would fail on any machine without FreeSurfer. Every function that needs no
external tool has an executable example.

## Before submitting (internal note, not shipped)

Flip both together: `Version` in `DESCRIPTION` to `2.0.0`, and the top
`NEWS.md` heading to match, dropping its "becomes the release notes"
sentence. The package stays on a development version until then so a plain
`x.y.z` on `main` cannot auto-publish.
