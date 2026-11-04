# reverse_order — the scripts behind the reversed-order section

The section **"What the external mixes measure, and what they do not"** in
`validation/synthetic/README_results.md` quotes two sets of numbers:

1. how many nights in the study data have times out of order, and in what forms;
2. what the pipeline does with each form when the benchmark injects them in the
   study's own proportions.

This directory holds the scripts that produce both, so the table in that section
is re-runnable rather than merely recorded.

## Scripts

| Script | Produces | Needs |
|---|---|---|
| `class_counts.R` | the counts in the first column of the table (2,848 complete nights, 140 reversed, 134 after setting aside 6 impossible get-up values) and the per-mechanism split | a pipeline run's `output/cleaned_data_full.rds`, and a build with `classify_reversals()` |
| `run_real_mix.R` | `results/real_mix_outcome.csv` — the injection table (350 injected, 74.0% flagged or corrected, 91 wrong repairs, no clean row altered) | the installed package and `validation/synthetic/` (it calls `generate_clean_data.R` and `run_one.R`) |

Both write **counts only**. No participant identifiers, no timestamps: the
row-level scoring stays in the scratch directory (`--work=`, or `tempdir()` by
default) and is never written into the repository.

## Running them

From the repository root:

```sh
# the injection table (~1 minute; reproduces validation/synthetic/results/real_mix_outcome.csv)
Rscript --vanilla validation/reverse_order/run_real_mix.R

# the study-data counts (needs the study data, which are not in this repo)
Rscript --vanilla -e '
  devtools::load_all(".")
  source("validation/reverse_order/class_counts.R")'
```

`run_real_mix.R` is frozen at 500 participants x 14 days, 5% injection, seed
20260817, split 36:38:14:14:9:6:6:1. Two runs give byte-identical output
(md5 `4be56d661c8f9d53c115a86b613255bc`), which matches the copy already
committed at `validation/synthetic/results/real_mix_outcome.csv`.

## Results in this directory

| File | Contents |
|---|---|
| `results/real_mix_outcome.csv` | per-mechanism injection outcome (counts, Wilson CI bounds) |
| `results/real_mix_clean_rows.csv` | clean rows flagged or altered (both 0) |
| `results/real_mix_run_info.csv` | package version, seed, sizes — quote this when citing the table |
| `results/reversal_class_counts.csv` | per-mechanism counts in the study data |

`results/real_mix_outcome.csv` is a byte-identical mirror of
`validation/synthetic/results/real_mix_outcome.csv`, the copy the results section
quotes. Keep them identical: if you re-run the script, diff the two.
`real_mix_run_info.csv` records the package version the table came from
(1.7.2 at the time of writing, while the source tree is on the 1.8.0
development version); re-run and compare if the version changes.

The study is healthy young adults on one protocol. These numbers describe that
sample; they are not a claim about clinical, older-adult or shift-work diaries.
See `work_logs/PLAN_validation_next_2026-11-04.md` for what is planned there.
