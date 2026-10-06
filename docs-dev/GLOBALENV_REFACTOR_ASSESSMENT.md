# Writing to the global environment: assessment (2026-10-06) and outcome (2026-10-07)

**Outcome:** done on a branch (`globalenv-refactor`), option 1 below, with the objects returned by the new `pipeline_results()` and an opt-in `export_env` argument. Gates passed: the full test suite, a differential run on the synthetic demo and on the study data (with and without the manual files) against 1.4.9, and `validation/run_all.R`. See NEWS.

`R CMD check --as-cran` reports, as a NOTE, assignments to `.GlobalEnv` in
`R/pipeline.R` (8 sites) and `R/manual_corrections.R` (1 site), and CRAN policy does
not allow a package to modify the user's global environment. This is the one
remaining issue that is likely to be raised in human review for CRAN, and it is the
kind of thing a reviewer from the R community will also notice in a methods paper.

## What the code does today

Counted on the 1.4.9 sources: 14 writes (`assign` / `list2env` into `.GlobalEnv`) and
17 reads (`get0` / `get` / `exists` with `envir = .GlobalEnv`), spread over 13 files
(`R/`: `pipeline.R`, `pipeline_chain.R`, `config.R`, `sleep_time_metrics.R`,
`bland_altman.R`, `publication_figures.R`, `manual_corrections.R`; `inst/scripts/`:
`00a_setup.R`, `00_MAIN_entry.R`, `checkforerrors_processing.R`,
`calculate_sleep_time_end.R`, `error_unusual_sleep_time_corrections.R`,
`sleep_visualization.R`). The objects that cross the boundary are `pipeline_config`,
`sleepcleanr_scripts_dir`, `sleepcleanr_loaded`, `ema_data_release_timecalc`,
`corrected_ema_data`, `review_output`, `checkforerrors_summary` and
`reasonable_unusual_df`. The pipeline's step scripts are `source()`d and read each
other's results through these globals; 12 lines in the test suite also touch them.
After a run, users and the validation scripts rely on `review_output` and
`corrected_ema_data` being in the global environment (for example the blind-audit
instructions say `saveRDS(review_output, ...)`).

## Options

1. **Package-private state environment.** Create one environment inside the package
   (for example `.sc_state`) and replace every `.GlobalEnv` in the 31 sites with it,
   through two small helpers (`state_set()`, `state_get()`). Mechanical, but the
   `source()`d scripts must be given the same environment, and the global objects
   that users rely on disappear. To keep them, `run_pipeline()` would **return** a
   list (`corrected`, `review`, `summary`, `config`) and optionally write the files
   it already writes. This is a behaviour change for anyone who reads the globals.
2. **Do nothing now.** State it as a limitation (done in the paper outline) and do the
   refactor with the next breaking release, version 2.0, when the return value of
   `run_pipeline()` can change.

## Recommendation

Option 2 for the BRM submission and option 1 as a dedicated change afterwards, on its
own branch, with the full test suite (498 tests) and `validation/run_all.R` as the
regression gate: the benchmark tables must regenerate identically. It touches the
running pipeline in 13 files and changes what a run leaves behind, so it should not be
mixed with the paper work or released as a patch. I estimate one to two days including
the tests that read the globals. Not started.
