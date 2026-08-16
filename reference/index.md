# Package index

## All functions

- [`STANDARD_LEVELS`](https://cyracaid.github.io/sleepdiary-cleaner/reference/STANDARD_LEVELS.md)
  : Fixed category vocabularies for the ledger
- [`adapt_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/adapt_columns.md)
  : Apply column mapping to a data frame
- [`as.data.frame(`*`<sleep_diary>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/as.data.frame.sleep_diary.md)
  : Extract the working data frame from a sleep_diary
- [`as_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/as_sleep_diary.md)
  : Coerce a data frame into a sleep_diary
- [`assert_contract_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/assert_contract_columns.md)
  : Assert that a sleep_diary carries the public contract columns
- [`bland_altman()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/bland_altman.md)
  : Bland-Altman analysis and threshold validation
- [`cfg_get()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/cfg_get.md)
  : Safe config_get – fetches pipeline_config from global env
  automatically
- [`cleaning_chain`](https://cyracaid.github.io/sleepdiary-cleaner/reference/cleaning_chain.md)
  : Pipeline step adapters and the cleaning chain
- [`dim(`*`<sleep_diary>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/dim.sleep_diary.md)
  : Dimensions of a sleep_diary
- [`.step_ledger_env`](https://cyracaid.github.io/sleepdiary-cleaner/reference/dot-step_ledger_env.md)
  : Per-step flag ledger (log_step)
- [`eval_checkforerrors()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_checkforerrors.md)
  : Evaluate checkforerrors (auto-detection flags)
- [`eval_data_category()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_data_category.md)
  : Evaluate data_category (temporal classification)
- [`eval_duration_extreme()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_duration_extreme.md)
  : Evaluate duration_extreme (separate from severity count)
- [`eval_field_misentry()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_field_misentry.md)
  : Evaluate field_misentry (cross-participant field misentry, Step 1.5)
- [`eval_flag_severity()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_flag_severity.md)
  : Evaluate flag_severity (computed metric flags)
- [`evaluate_all_standards()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/evaluate_all_standards.md)
  : Evaluate ALL standards, returning per-record label data frame.
- [`figure12_step_flag_table()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/figure12_step_flag_table.md)
  : Figure 12 (new) — Step x Flag ledger table
- [`figure_cleaning_effect()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/figure_cleaning_effect.md)
  : Figure 2 — Effect of cleaning (before vs after)
- [`figure_pipeline_workflow()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/figure_pipeline_workflow.md)
  : Figure 1 — Pipeline workflow flow diagram
- [`figure_run_dir()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/figure_run_dir.md)
  : Resolve the figure output directory for a run
- [`finalize_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/finalize_columns.md)
  : Build the analysis-facing datasets from the full pipeline output
- [`flag_statistical_outliers()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/flag_statistical_outliers.md)
  : Per-participant statistical outlier detection via IQR
- [`get_step_ledger_long()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/get_step_ledger_long.md)
  : Flatten the ledger into a long data frame
- [`get_step_ledger_wide()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/get_step_ledger_wide.md)
  : Wide ledger for one standard
- [`handle_missing()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/handle_missing.md)
  : Tag missing-data reason codes and optionally carry forward
  single-day gaps
- [`init_step_ledger()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/init_step_ledger.md)
  : Start a fresh ledger (call once at the top of run_pipeline).
- [`is_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/is_sleep_diary.md)
  : Test whether an object is a sleep_diary
- [`log_step()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/log_step.md)
  : Record the flag state after a step.
- [`missing_handler`](https://cyracaid.github.io/sleepdiary-cleaner/reference/missing_handler.md)
  : Missing-data reason codes and single-day LOCF
- [`new_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/new_sleep_diary.md)
  : Construct a sleep_diary object
- [`outlier_flags`](https://cyracaid.github.io/sleepdiary-cleaner/reference/outlier_flags.md)
  : Per-participant IQR outlier detection
- [`pipeline_steps`](https://cyracaid.github.io/sleepdiary-cleaner/reference/pipeline_steps.md)
  : Pipeline step adapters (wrapper layer)
- [`plot(`*`<bland_altman>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/plot.bland_altman.md)
  : Plot a Bland-Altman result
- [`plot(`*`<sleep_diary>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/plot.sleep_diary.md)
  : Plot the state of a sleep_diary
- [`plot(`*`<threshold_validation>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/plot.threshold_validation.md)
  : Plot a threshold validation report
- [`print(`*`<bland_altman>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/print.bland_altman.md)
  : Print a Bland-Altman summary
- [`print(`*`<sleep_diary>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/print.sleep_diary.md)
  : One-line status of a sleep_diary
- [`print(`*`<summary.sleep_diary>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/print.summary.sleep_diary.md)
  : Print a sleep_diary summary
- [`print(`*`<threshold_validation>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/print.threshold_validation.md)
  : Print a threshold validation report
- [`run_cleaning_chain()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_cleaning_chain.md)
  : The S3 cleaning chain
- [`run_figure_index()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_figure_index.md)
  : Regenerate the figure_index.png contact sheet
- [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
  : Run the full SPL Sleep pipeline
- [`run_report()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_report.md)
  : Run the reporting stage
- [`run_setup()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_setup.md)
  : Run the setup-only stage (package / input-file checks)
- [`run_visualization()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_visualization.md)
  : Run only the visualization stage on already-cleaned data
- [`sleep_diary`](https://cyracaid.github.io/sleepdiary-cleaner/reference/sleep_diary.md)
  : The sleep_diary S3 class
- [`step_apply_corrections()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_apply_corrections.md)
  : Step 6 – apply manual corrections
- [`step_apply_duration_corrections()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_apply_duration_corrections.md)
  : Step 6.5 – apply duration corrections
- [`step_compute_metrics()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_compute_metrics.md)
  : Step 7 – compute derived sleep metrics
- [`step_normalize_sequence()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_normalize_sequence.md)
  : Step 4 – normalise sleep time sequence
- [`step_process_intervals()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_process_intervals.md)
  : Step 3 – parse interval durations
- [`step_process_timestamps()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_process_timestamps.md)
  : Step 2 – parse timestamps
- [`summarise_missing()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/summarise_missing.md)
  : Summarise missing-data patterns per participant
- [`summarise_outliers()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/summarise_outliers.md)
  : Summarise IQR outlier flags
- [`summary(`*`<sleep_diary>`*`)`](https://cyracaid.github.io/sleepdiary-cleaner/reference/summary.sleep_diary.md)
  : Tabulate the whole pipeline chain recorded in a sleep_diary
- [`tally_standard()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/tally_standard.md)
  : Tally one standard's labels into a fixed-level count vector. Returns
  all-NA (named by levels) if the label vector is entirely NA.
- [`validate_column_types()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_column_types.md)
  : Validate column types in a data frame
- [`validate_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_columns.md)
  : Validate that required columns exist
- [`validate_no_r_code_in_paths()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_no_r_code_in_paths.md)
  : Validate config file paths for R code expressions
- [`validate_schema()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_schema.md)
  : Canonical input schema validator
- [`validate_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_sleep_diary.md)
  : Validate a sleep_diary object
- [`validate_thresholds()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_thresholds.md)
  : Validate cleaning thresholds against Bland-Altman agreement limits
- [`write_step_ledger()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/write_step_ledger.md)
  : Persist the ledger to CSV (long form)
