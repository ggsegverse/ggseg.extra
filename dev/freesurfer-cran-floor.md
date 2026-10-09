# Vendor `fs_sitrep()` / fix `fs_cmd()` ordering to unblock CRAN submission

Status: open. Blocks the first CRAN submission of ggseg.extra.
Written 2026-10-05 while preparing `chore/cran-prep`.

## The problem

DESCRIPTION suggests `freesurfer (>= 1.8.1.902)` and `freesurfer_min_version()`
(`R/freesurfer.R:80`) enforces the same floor at run time. CRAN has freesurfer
**1.8.1**; 1.8.1.902 exists only at `muschellij2/freesurfer`, and CRAN ignores
`Remotes:`. A CRAN user therefore gets 1.8.1, trips the gate, and finds every
FreeSurfer-backed pipeline — the headline feature — unreachable.

Resolving it needs either freesurfer >= 1.8.1.902 on CRAN, or the two gaps
below closed here so the floor can drop to `>= 1.8.1`.

## What the floor is actually protecting against

The in-source comment at `R/freesurfer.R:76-78` names `fs_sitrep()` and
`fs_cmd(validate_inputs = )`. **The second half of that comment is wrong.**
`validate_inputs` is never passed anywhere in `R/`, `tests/`, the vignettes or
the tutorials — grep the repository. Fix the comment along with the rest.

Of the nine `freesurfer::` symbols the package uses, eight are exported by
CRAN 1.8.1: `fs_cmd`, `fs_dir`, `fs_help`, `fs_subj_dir`, `get_fs`, `have_fs`,
`mri_convert`, `mris_convert`. Only `fs_sitrep` is absent. The signatures of
`mri_convert(file, outfile)` and `mris_convert(infile, outfile, verbose)` are
compatible at the two call sites that use them.

So there are exactly two gaps, and one of them is not the one the comment
claims.

### Gap 1 — `fs_sitrep()` is missing from CRAN 1.8.1

One call site: `R/sitrep.R:64`, inside `check_freesurfer()`, reached only when
`sitrep(detail = "full")`. Output is diagnostic text; nothing downstream reads
its return value.

Vendoring it verbatim is a trap. The 1.8.1.902 body is 66 lines but calls ten
further internals that 1.8.1 does not have (`get_fs_home()`,
`get_fs_license()`, `get_fs_verbosity()`, `get_fs_source()`,
`get_fs_subdir()`, `get_mni_bin()`, `get_fs_output()`, `sys_info()`,
`alert_info()`, `mri_info.help()`), so a faithful copy is closer to 200 lines.

A faithful copy is not what is wanted. What `sitrep("full")` needs is a
FreeSurfer diagnostics block, and one can be built from CRAN 1.8.1's own
public API: `fs_dir()`, `fs_subj_dir()`, `have_fs()`, `get_fs()` and
`fs_version()` (all exported by 1.8.1), plus `Sys.getenv("FREESURFER_HOME")`
and a `file.exists()` check for the license file. That is roughly **30-40
lines** of `cli` calls in `R/sitrep.R`, replacing one line.

Risk: low. Cosmetic output, one code path, no behaviour depends on it.
Tests: extend `tests/testthat/test-sitrep.R`, which already mocks
`fs_sitrep`; about **25 lines** covering present/absent FreeSurfer and the
`detail = "full"` branch. The existing mock of `fs_sitrep` goes away.

### Gap 2 — `fs_cmd(opts_after_outfile = TRUE)` orders arguments differently

**This is the real incompatibility, and it is a silent one.** Verified by
reading both sources:

- 1.8.1 (`R/fs_cmd.R`): `cmd <- paste(cmd, sprintf(' "%s" %s;', outfile, opts))`
  — output file, *then* the trailing options.
- 1.8.1.902: the output file is appended *after* `opts`.

The single call site is `R/prepare_subcortical_mni152.R:133`, which passes
`opts = "--targ <aseg> <registration> --interp nearest --o"` and relies on the
output path landing after `--o`. Under CRAN 1.8.1 the command becomes

```
mri_vol2vol --mov "parcels.nii.gz" "registered.nii.gz" --targ ... --interp nearest --o;
```

`--o` with no argument, and the registered volume is never written. So
lowering the floor without touching this call site would not merely lose a
diagnostic — it would break `prepare_subcortical_mni152()` on exactly the
freesurfer version CRAN users have.

1.8.1 also lacks 1.8.1.902's `check_fs_result()` assertion that the output
file appeared, so the failure would surface as a confusing
`RNifti::readNifti()` error on a missing file rather than as a FreeSurfer
error.

Fix: stop routing this one command through `freesurfer::fs_cmd()` and build it
with the package's own `run_cmd()` helper (`R/utils_snapshot.R:4`), which
already prefixes `freesurfer::get_fs()` and captures stderr. This is the
pattern `mri_surf2surf_rereg()` (`R/freesurfer.R:37`) and the `mri_vol2surf`
wrapper (`R/freesurfer.R:472`) already use, so there is in-package precedent
and no new abstraction. About **15-20 lines** replacing the 15-line `fs_cmd()`
call, plus **5 lines** asserting `file.exists(registered)` with a `cli_abort()`
naming `mri_vol2vol`, to keep the error quality 1.8.1.902 gave for free.

Risk: moderate. It is the registration step of the subcortical MNI152
pipeline, and the command string must be reproduced exactly. It needs a real
FreeSurfer run to confirm, not just a mocked one.
Tests: `tests/testthat/test-prepare_subcortical_mni152.R` exists and mocks the
FreeSurfer calls; the mock changes from `fs_cmd` to `run_cmd`. Add a case
asserting the composed command puts the output path after `--o`, and one for
the missing-output-file abort. About **40 lines**.

## Total scope and recommendation

| Item | Source | Tests | Risk |
| --- | --- | --- | --- |
| Gap 1, `fs_sitrep()` replacement | 30-40 lines | ~25 lines | low |
| Gap 2, `mri_vol2vol` via `run_cmd()` | ~25 lines | ~40 lines | moderate |
| Drop floor to `>= 1.8.1`, delete `freesurfer_repos()`, fix the stale comment, delete `Remotes:` | ~10 lines removed | — | low |

Call it **half a day of work plus one manual FreeSurfer verification run** —
materially less than the "1-2 days" the readiness assessment estimated, because
only one of the two named features was ever used and the other turned out to be
an argument-ordering difference at a single call site.

**After both gaps are closed, dropping the floor to `>= 1.8.1` is safe.** It is
not safe before: Gap 2 alone would ship a broken subcortical pipeline to every
CRAN user.

**Recommendation: ask first, vendor second.** John Muschelli is already a `ctb`
on this package. A freesurfer release to CRAN costs us nothing, keeps the
better `fs_cmd()` (input validation, output-existence checks, timeouts) and
keeps `fs_sitrep()` maintained upstream. Vendoring is the fallback if that
release does not materialise, and the half-day above is the price.
