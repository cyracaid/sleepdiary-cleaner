# Resolve the stable, never-wiped verification directory for a run

Verification artifacts (S3-vs-legacy snapshot `.rds` pairs, the Markdown
verification report, advisory analyses such as Bland-Altman plots) must
survive the \*next\* pipeline run. The figure run directory returned by
[`figure_run_dir`](https://cyracaid.github.io/sleepdiary-cleaner/reference/figure_run_dir.md)
does not survive it – every run of `sleep_visualization.R` deletes and
rebuilds that directory from scratch.

## Usage

``` r
verification_run_dir(cfg = NULL, data_tag, n_records = NULL)
```

## Arguments

- cfg:

  Optional. Pipeline configuration list (preferred; falls back to the
  global environment when omitted).

- data_tag:

  Character. "real", "synth", or "unknown".

- n_records:

  Numeric or NULL. Row count appended to the directory name.

## Value

Character. Relative path to the stable verification directory, e.g.
`"output/verification/real_n13990"` or `"verification/synth_n280"`.

## Details

Earlier, `verification/` was nested \*inside\* the wiped run directory
and rescued around each wipe with a rename-out/rename-back dance
implemented once, in `sleep_visualization.R`. That single implementation
was the only thing standing between the wipe and data loss; on
2026-08-11 a wipe ran before the dance existed and permanently deleted
that day's verification report (it was gitignored, so it could not be
recovered from git either – see the "History note" in
`output/verification/real_n13990/VERIFICATION_2026-08-10.md`). This
function fixes the root cause instead of guarding the symptom: it
returns a path that is a \*sibling\* of the run directory, not a child
of it, so no wipe – current or future, in this script or any other – can
reach it. No preserve logic is required anywhere, and none can be
forgotten.
