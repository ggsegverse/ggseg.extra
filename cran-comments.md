## R CMD check results

Local, macOS 26.6, R 4.6, `R CMD check --no-manual --as-cran`:
**0 errors | 0 warnings | 1 note**.

Tests: 3180 pass, 0 fail, 0 skip. Vignettes rebuild cleanly.

The one note is the standard new-submission note, plus the `Remotes` field:

```
* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Athanasia Mo Mowinckel <a.m.mowinckel@psykologi.uio.no>'

  New submission

  Unknown, possibly misspelled, fields in DESCRIPTION:
    'Remotes'
```

"New submission" is expected for a first submission. **The `Remotes` line
disappears once `Remotes:` is deleted, which must happen before submitting** —
see the next section.

## First submission

This is the first CRAN submission for ggseg.extra. The package has been
developed and distributed on r-universe
(<https://ggsegverse.r-universe.dev>) and is the atlas-construction half of
the ggsegverse ecosystem, whose plotting packages ggseg and ggseg3d are
already on CRAN.

## MUST BE DONE BEFORE SUBMITTING

This file is prepared ahead of time. The package is **not submittable until
the two items below are resolved**, because the `freesurfer` version it needs
is not yet on CRAN.

1. **Delete the `Remotes:` field from DESCRIPTION.** It currently reads
   `Remotes: muschellij2/freesurfer`. CRAN ignores `Remotes:` and flags it on
   incoming submissions.

2. **Confirm the CRAN `freesurfer` version satisfies the declared floor.**
   DESCRIPTION suggests `freesurfer (>= 1.8.1.902)` and the floor is also
   enforced at run time by an internal helper, `freesurfer_min_version()`.
   CRAN currently has freesurfer 1.8.1, which does not satisfy it: 1.8.1
   lacks `fs_sitrep()`, and its `fs_cmd(opts_after_outfile = TRUE)` places
   the output file *before* the trailing options rather than after, which
   breaks the `mri_vol2vol` invocation in
   `prepare_subcortical_mni152()`. A user on CRAN's freesurfer would
   therefore be refused by the version gate rather than silently given a
   broken pipeline, but every FreeSurfer-backed pipeline would be
   unreachable.

   Either wait for freesurfer >= 1.8.1.902 to reach CRAN, or vendor the two
   behaviours internally and lower the floor to `>= 1.8.1`. The scope of
   that work is written up in `dev/freesurfer-cran-floor.md` and tracked as a
   GitHub issue.

Once freesurfer is available at a satisfying version on CRAN, item 1 is the
only edit this file's advice requires, and the sections below stand as
written.

## Downstream dependencies

There are currently no reverse dependencies on CRAN.

## Notes for reviewers

### `SystemRequirements` and graceful degradation

The headline feature of this package is building brain atlases from
neuroimaging files, and the richest pipelines drive external command-line
tools: FreeSurfer (<https://surfer.nmr.mgh.harvard.edu/>) and, optionally,
Connectome Workbench for CIFTI resampling. These are large third-party
installations that cannot be bundled, and FreeSurfer is available for Linux
and macOS only.

The package degrades gracefully rather than failing to install or to check:

- No external tool is touched at load time. Every pipeline that needs one
  checks for it first and raises an informative error naming the missing
  tool if it is absent.
- `sitrep()` reports which system dependencies and optional R packages are
  present and which pipelines are consequently available, so a user can see
  what they can run before they try.
- The geometry verbs (`atlas_polish()`, `atlas_simplify()`,
  `atlas_smooth()`, `atlas_dilate()`), the lookup-table reader and writer,
  the legacy-atlas converters and the validation helpers need no external
  tool at all, and their examples and tests run everywhere.
- The test suite skips the external-tool paths when the tool is absent, so
  `R CMD check` is clean on a machine with no FreeSurfer, which is what we
  expect of CRAN's build machines.

`V8 (>= 6.0.0)` is listed in `SystemRequirements` because `rmapshaper`, an
`Imports` dependency used for topology-preserving polygon simplification in
every atlas pipeline, requires the V8 engine.

### `\dontrun{}` in examples

36 of 58 help pages contain a `\dontrun{}` block. They fall into two groups,
and we expect a reviewer to ask about them.

**The external-tool pipelines.** These genuinely cannot run without
FreeSurfer, Connectome Workbench, or a large atlas source file it would be
inappropriate to download during a check. They are the atlas-construction
entry points (the `create_cortical_from_*()`,
`create_subcortical_from_volume()`, `create_wholebrain_from_volume()`,
`create_cerebellar_from_*()` and `create_tract_from_*()` families), the
readers for external formats (`read_cifti_annotation()`,
`read_gifti_annotation()`, `read_neuromaps_annotation()`,
`read_tractography()` and friends), the FreeSurfer command wrappers
(`mri_surf2surf_rereg()`, `coregister_volume()`,
`prepare_subcortical_mni152()`), and the repository scaffolding helpers
(`setup_atlas_repo()`, `use_atlas_github_actions()`), which write files into
a new project directory. These are the reason the package exists, so we
document them with the real call rather than omitting the example.

We considered `\donttest{}` and rejected it: `\donttest{}` examples *are*
run by `R CMD check --as-cran`, and these would fail on any machine without
FreeSurfer, CRAN's included. We also considered `if (interactive())` guards
and rejected them as less honest about why the code does not run.

**Supplementary illustrations beside a runnable example.** The geometry verbs
(`atlas_polish()`, `atlas_simplify()`, `atlas_smooth()`) and
`context_pattern()` have fully executable examples that run on the `dk`
atlas from the suggested 'ggseg' package, guarded by `@examplesIf`, followed
by a short `\dontrun{}` block showing the two-pass idiom a real build uses.
Those blocks are not run because they would double the example's run time to
show a pattern the executable part has already demonstrated, not because
anything is missing.

Every function that requires no external tool has at least one executable
example.

### Suggested packages

Suggested packages ('ciftiTools', 'freesurfer', 'freesurferformats',
'gifti', 'RNifti', 'Rvcg', 'terra', 'smoothr', 'princurve', 'neuromapr' and
others) are checked at run time with `rlang::check_installed()` immediately
before first use, and the error names the pipeline that wanted them.
