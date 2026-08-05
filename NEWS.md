# splsleep 1.3.3

Bug-fix release. No cleaning logic changed other than the guard described below.

## Bug fixes

* `calculate_sleep_time_end.R` -- **sleep efficiency had no denominator guard.**
  `self_diffcalc_sleepefficiency_percent` was computed as a bare division of TST
  by total-try-sleep. A try-sleep duration of zero produced `Inf`, which
  propagated into the contract column `sleep_efficiency_pct` (`Inf * 100`), broke
  plot axes, and contaminated any un-guarded `mean()`/`summary()` of the column.
  A zero or missing denominator now yields `NA_real_`: the efficiency is unknown,
  not infinite. Fixed in **both** the repository-root and `inst/scripts/` copies.

  This fix had been reported as applied in an earlier session but was absent from
  `main`, which is why the sync test below now exists.

* `flag_standards.R` -- `eval_flag_severity()` and `eval_duration_extreme()` now
  guard with `is.finite()` rather than `!is.na()`. `is.na(Inf)` is `FALSE`, so a
  non-finite metric previously passed the guard and reached the threshold
  comparison. `eval_flag_severity()` behaviour is unchanged for real data (both
  paths already scored a non-finite metric as un-flagged); `eval_duration_extreme()`
  now reports an infinite duration as `NA` instead of "Too long (>12h)", since an
  infinite duration is a failed computation rather than a long sleep.

## Tests

* `test-nonfinite-guards.R` -- pins both bugs: missing and infinite durations
  must be reported as unknown, non-finite metrics must not be scored, and finite
  values must still classify correctly.
* `test-script-copies-in-sync.R` -- several pipeline scripts exist in both the
  repository root and `inst/scripts/`. This test fails on any **new** divergence
  and asserts the Bug 2 guard is present in both copies of
  `calculate_sleep_time_end.R`.

## Script copies brought back into sync

Five scripts had drifted between the repository root and `inst/scripts/`:
`apply_metric_review_acceptances.R`, `apply_nap_exercise_corrections.R`,
`apply_second_review.R`, `apply_sleep_metric_duration_corrections.R` and
`checkforerrors_processing.R`. In every case the `inst/scripts/` copy resolved
its file paths through `cfg_get()` while the root copy still hardcoded
filenames -- a half-finished configuration migration.

Which copy runs depends on how the pipeline is started: `run_pipeline()` sources
from `system.file("scripts")`, whereas `source("00_MAIN_entry.R")` falls back to
`getwd()`. Under the default config the two behaved identically, because each
`cfg_get()` default was the same string as the hardcoded filename, so nothing was
visibly broken. The latent trap was that any config overriding `data.files.*`
would be honoured by one copy and silently ignored by the other -- the affected
run would read the default filename without raising an error.

Resolved by making the config-aware `inst/scripts/` copies canonical and copying
them over the root copies. No behaviour change under `config_default.yaml`.
All 20 shared scripts are now byte-identical and `KNOWN_DIVERGENT` in the sync
test is empty.

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
