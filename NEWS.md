# splsleep 1.3.0 (in development)

Phase 1 of the v2.0 roadmap: the trustworthy-cleaning foundation. This release
adds an interface contract without changing any cleaning result.

## New: the `sleep_diary` S3 class

* `new_sleep_diary()`, `as_sleep_diary()`, `is_sleep_diary()`,
  `validate_sleep_diary()` -- a container carrying the working data plus the
  provenance of every step that touched it.
* `print()`, `summary()`, `plot()`, `as.data.frame()` and `dim()` methods.
  `summary()` returns one row per step (rows in/out, columns added, elapsed
  milliseconds) and joins the `log_step()` flag ledger when it is populated.

## New: step adapters and the cleaning chain

* `step_process_timestamps()`, `step_process_intervals()`,
  `step_normalize_sequence()`, `step_apply_corrections()`,
  `step_apply_duration_corrections()`, `step_compute_metrics()` wrap the
  existing `inst/scripts/` implementations.
* `run_cleaning_chain()` composes those six steps end to end and returns a
  `sleep_diary`.
* `assert_contract_columns()` makes the Step 7 output contract
  (`sleep_efficiency_pct`, `sol_h`, `waso_h`, `sleep_duration_h`) an assertion
  rather than an assumption.

## Snapshot verification (new in this release)

* `verify_v1_3_s3.R` -- zero-dependency S3 layer structural test (39 assertions,
  base R only).
* `verify_v1_3_snapshot.R` -- end-to-end identity check: runs both the old
  pipeline (steps 2-7) and the S3 chain on the bundled synthetic dataset, then
  compares all 95 output columns. **Result: bit-identical on all 280 rows × 95
  columns.** S3 chain is 2.6× faster (0.45 s vs 1.16 s) because it avoids the
  repeated `source()` overhead.

## Bug fixes (discovered during snapshot verification)

* `error_unusual_sleep_time_corrections.R`: replaced four `1:nrow(df)` patterns
  with `seq_len(nrow(df))`. In base R, `1:0` evaluates to `c(1, 0)` (a
  2-element vector!), causing an iteration on empty data frames that previously
  crashed with `missing value where TRUE/FALSE needed`. This bug had been masked
  because the old pipeline never received a fully empty corrections data frame
  in production (stub files provided at least a header row).
* `check_swap_corrections()`: added early-return guard when `corrections_df` is
  empty or lacks the `correction_type` column.

## Compatibility

* **No cleaning logic changed.** The adapters call the v1.2.0 scripts unmodified;
  they only box and unbox the data frame and record timing and column diffs.
  `log_step()` is still called with the same arguments in the same order, so the
  flag ledger and Figure 12 are unaffected.
* `run_pipeline()` is unchanged in this release. It will be switched onto the
  chain once snapshot tests pin each step's output.
* Steps that write files or publish into the global environment -- data loading,
  the field-misentry check, review-file generation, second-review consensus,
  auto-detection, the cross-participant check and visualisation -- are
  intentionally outside the chain for now.

## Tests

* `test-sleep-diary.R` adds 11 tests covering construction, validation,
  coercion, the generic methods, the Step 7 contract assertion, and step
  provenance recording. All use synthetic data, so they run on CI with no
  dataset and no Suggests package present.

---

# splsleep 1.2.0

* Per-step flag ledger (`log_step()`, `flag_standards.R`) with
  `output/step_flag_ledger.csv`.
* Figure 12 rebuilt as a three-panel step-by-flag table.
* `flag_severity` moved out of the visualisation layer into Step 7, which now
  emits the four public contract columns.
* `main_csv` made optional; data integrity audit added.
* `R CMD check`: 0 errors, 0 warnings, 3 acceptable notes. GitHub Actions green.
