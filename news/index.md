# Changelog

## sleepcleanr 1.4.3

Fixes a correction rule flagged by the redundant-channel validation on
real data (Channel B, 2026-08-12/13).

### Fixed

- **`sleep_awake_swap_3h` guard**: the swap now only fires when
  `bed <= awake`. Previously, swapping when the old awake time preceded
  bed put the new sleep time before bed, worsening the (bed→sleep) SOL
  gap; validation measured this as a real negative effect (7/10
  corrected rows moved farther from self-reported SOL). Real-data rerun
  after the guard: 10 → 4 swap rows, all order-valid, 3/4 closer to
  self-report. Guarded rows are left uncorrected and picked up by the
  downstream temporal-order check for human review.

## sleepcleanr 1.4.2

Adds the calibrated synthetic-error-injection benchmark harness to the
tracked repo (`validation/synthetic/`). No cleaning logic changed.

### New

- **Benchmark harness**: `generate_clean_data.R` (structurally-pure and
  population-realistic synthetic data), `error_catalog.yaml`
  (12-category error taxonomy with provenance tags), `inject_errors.R`
  (participant-clustered injector with ground-truth logging),
  `evaluate_fcr.R` / `evaluate_detection.R` (false-alteration and
  per-category detection/recall evaluators).
- **First-pass results**
  (`validation/synthetic/SYNTHETIC_BENCHMARK_RESULTS.md`): 0/10,000
  false alterations on structurally-clean synthetic input;
  population-stratified flag-rate gradient (0.0% healthy_adult to 7.7%
  insomnia_like); per-category detection results across 12
  injected-error types. This harness is what found and verified the two
  bugs fixed in v1.4.1 (field-misentry silent misrepair, missing
  human-review CSVs).
- **README**: Validation section’s benchmark row corrected from
  “planned” to “first pass done”, linking to the results doc.

### Not yet done

Full recall/specificity/PPV-curve treatment with cluster-bootstrap CIs,
multiverse analysis (needs a prerequisite refactor: the 3-hour
adjacent-swap threshold and cross-participant MAD constants are
currently hardcoded, not configurable), leave-one-out ablation, and
downstream sleep-metric sensitivity analysis. See `benchmark-design.md`.

------------------------------------------------------------------------

## sleepcleanr 1.4.1

Bug-fix release. No cleaning logic changed outside the two items below.

### Bug fixes

- **SOL/WASO high-risk duration-reinterpretation flag
  (`checkforerrors_processing.R`, Part A4).** Synthetic benchmark
  testing (n=400/class) found `field_misentry_sol` /
  `field_misentry_waso` (clock-time text typed into a duration field)
  were silently misrepaired 95.8% / 96.0% of the time:
  `process_interval.R`’s `MM:SS` / `dd:00` reinterpretation heuristic
  turns the misentry into a small, plausible-looking number, and the
  downstream `sol_duration_for_review_status` /
  `waso_duration_for_metrics_status` checks
  (`calculate_sleep_time_end.R`) only ever flag values that are too
  *large*, never too *small* – so nothing catches it. New Part A4 block
  flags any row whose `_correctionsmade` note matches the
  `MM:SS`/`dd:00` reinterpretation pattern and routes it to human
  review. Reduces SOL silent misrepair to 3.5% (14/400 – a disclosed
  residual blind spot for “01:XX”-shaped values that leave no
  reinterpretation trace) and WASO to 0% (0/400). Verified 0/10,000 new
  false positives on clean synthetic data and 0/10,000 unrelated-field
  false alterations, both unchanged from pre-patch.

- **`generate_correction_files.R` now actually writes the human-review
  CSVs (Section 13).** The
  [`write.csv()`](https://rdrr.io/r/utils/write.table.html) calls for
  `[NEW]manual_error_correction_review.csv` and
  `[NEW]manual_unusual_review.csv` were commented out, and
  [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
  immediately [`rm()`](https://rdrr.io/r/base/rm.html)’d the in-memory
  result afterward – so neither file was ever produced, even though the
  pipeline’s own log unconditionally printed “Files saved: …”. Human
  reviewers had nothing to review. Fixed; verified non-empty/expected
  output on a full real n=280 pipeline run and confirmed no collision
  with the Step 6 input filenames (`manual_error_corrections.csv` /
  `manual_unusual_corrections.csv`).

------------------------------------------------------------------------

## sleepcleanr 1.4.0

Delivery release. **No cleaning logic changed.** Run-to-run figures are
identical to 1.3.9: Clean 1,908 / Unusual 31 / Equal 903 / Corrected 81
/ mean TST 7.71 h / mean SOL 28.8 min.

### New

- **[`finalize_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/finalize_columns.md)
  now runs as Step 10 of
  [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md).**
  Previously it had to be called by hand, so a plain
  [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
  produced no Dataset A or B at all. Pass `finalize = FALSE` for the old
  behaviour. It runs after `final_summary()` on purpose: it only selects
  and renames columns, so a failure there leaves the cleaning run and
  every reported number intact.

- **`inst/extdata/column_dictionary.csv`** is the single source of truth
  for the delivered columns – whitelist, rename mapping and data
  dictionary in one table. Adding a column means editing one CSV row.

- **Dataset A (36 columns)** and **Dataset B (15 columns)**. B carries
  `row_id` so `A ⋈ B` on `(pid, day_num, row_id)` cannot multiply rows;
  `pid + day_num` alone is not unique.

- **`record_status`** replaces `data_category` in Dataset A. Six levels,
  not the five originally planned: `reasonable_unusual` records were
  reviewed and accepted by a human, and that is not the same claim as
  `unusual`. An unmapped level stops the build rather than shipping a
  blank.

- **`waso_computed_minutes`** (`getup - final awakening`, converted from
  hours to minutes). Not a substitute for `waso_selfreport_minutes`: on
  real data (n = 1,723 paired) the marginal distributions nearly
  coincide – both median 10 min, both Q3 20 min – but night-level
  correlation is r = 0.013. They are two variables, not two measurements
  of one quantity.

- **`verify_reference_fidelity.R`** – the fidelity check deferred in
  1.3. It pins each of the 8 metric formulas to its stated definition
  and records, per metric, whether it has been compared against the
  2026-05-19 baseline. Four are identical; four deviate, all
  deliberately and all documented. Previously “has anyone actually
  checked this formula?” had no answer anywhere in the repo, which is
  how the sleep-onset deviation survived three months.

- **CI now runs the standalone verification scripts.** `R CMD check`
  executes `tests/testthat/` only and never touched `verify_*.R`, so
  nothing enforced them on push. `verify_reference_fidelity.R` runs with
  `--strict`: a metric with no recorded comparison fails the build.

### Fixes

- **Affect-layer columns are now reserved, not dropped.** `pos_affect`,
  `neg_affect`, `stress_today_pm` and `copestress_today_pm` are declared
  as `status = reserved` in the dictionary. When a corrected dataset
  carries them,
  [`finalize_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/finalize_columns.md)
  passes them through untouched; when it does not (the current real
  data), no placeholder is fabricated. They exist so a future dataset
  with the EMA affect items can be finalised without a breaking change.

- **Export guard.**
  [`finalize_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/finalize_columns.md)
  stops the run if any of the 14 signed minute metrics (`tst_minutes`,
  `sol_computed_minutes`, `sleepperiod_minutes`, `waso_*`, exercise
  minutes, …) is negative in an analysable row (`record_status` neither
  `error` nor `not_reported`). `not_reported` (`skipped_na`) rows are
  whole missing nights; their negative fragments are arithmetic noise
  and are excluded, mirroring analyst filters.

- **Delivery is CI-verified.** `verify_delivery_wiring.R` checks the
  delivered files against the dictionary (exact column contract,
  finalize wiring, live guard) and joins
  `.github/workflows/R-CMD-check.yaml`; it defers gracefully when no
  `output/` exists in a checkout. `verify_reference_fidelity.R` runs in
  `--strict` mode (currently 16/16) and `verify_finalize_columns.R`
  (41/41). Full testthat suite 190 passing.

- **Development branch `v1.3-s3` deleted** (local and remote) and its
  trigger removed from the CI workflow. Phase 2 (analytics) and Phase 3
  (methods paper) are paused; this release is the Phase 1 delivery gate.

- `row_id 8502` – a manual correction fixed the awakening timestamp but
  left the get-up timestamp that the AM/PM normaliser had already
  shifted by 12 h, producing a WASO of -716 minutes. Corrected via the
  existing `column_to_correct_2` mechanism; no code changed.

- `.gitignore` – backups such as
  `manual_error_corrections.csv.bak_20260808` were untracked rather than
  ignored, because the existing rules matched exact filenames and no
  suffixed copy. Those files hold participant identifiers. Now covered
  by `*.bak*` and `manual_*.csv.*`.

### Known limitations

- `correction_type` records only the algorithmic action and is not
  rewritten when a later manual correction overrides it. On the 16 rows
  with `has_correction == "both"` it may name a rule whose effect is no
  longer present. Noted in the dictionary; see open issues S6.

- `calculate_sleep_time_vars_end()` writes
  `output/corrected_ema_data.rds` as a side effect, so calling it from a
  working directory that holds real output overwrites that output. See
  open issues S8.

- The AM/PM normaliser decides *which* timestamp carries the error by
  looking at one pair only, without cross-checking the other two. On the
  three affected records a human overruled it twice, correctly both
  times. Assessed and deliberately not changed: three records, all
  either flagged or already corrected. See open issues S7.

## sleepcleanr 1.3.3

Bug-fix release. No cleaning logic changed other than the guard
described below.

### Bug fixes

- `calculate_sleep_time_end.R` – **sleep efficiency had no denominator
  guard.** `self_diffcalc_sleepefficiency_percent` was computed as a
  bare division of TST by total-try-sleep. A try-sleep duration of zero
  produced `Inf`, which propagated into the contract column
  `sleep_efficiency_pct` (`Inf * 100`), broke plot axes, and
  contaminated any un-guarded
  [`mean()`](https://rdrr.io/r/base/mean.html)/[`summary()`](https://rdrr.io/r/base/summary.html)
  of the column. A zero or missing denominator now yields `NA_real_`:
  the efficiency is unknown, not infinite. Fixed in **both** the
  repository-root and `inst/scripts/` copies.

  This fix had been reported as applied in an earlier session but was
  absent from `main`, which is why the sync test below now exists.

- `flag_standards.R` –
  [`eval_flag_severity()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_flag_severity.md)
  and
  [`eval_duration_extreme()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_duration_extreme.md)
  now guard with [`is.finite()`](https://rdrr.io/r/base/is.finite.html)
  rather than `!is.na()`. `is.na(Inf)` is `FALSE`, so a non-finite
  metric previously passed the guard and reached the threshold
  comparison.
  [`eval_flag_severity()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_flag_severity.md)
  behaviour is unchanged for real data (both paths already scored a
  non-finite metric as un-flagged);
  [`eval_duration_extreme()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/eval_duration_extreme.md)
  now reports an infinite duration as `NA` instead of “Too long
  (\>12h)”, since an infinite duration is a failed computation rather
  than a long sleep.

### Tests

- `test-nonfinite-guards.R` – pins both bugs: missing and infinite
  durations must be reported as unknown, non-finite metrics must not be
  scored, and finite values must still classify correctly.
- `test-script-copies-in-sync.R` – several pipeline scripts exist in
  both the repository root and `inst/scripts/`. This test fails on any
  **new** divergence and asserts the Bug 2 guard is present in both
  copies of `calculate_sleep_time_end.R`.

### Script copies brought back into sync

Five scripts had drifted between the repository root and
`inst/scripts/`: `apply_metric_review_acceptances.R`,
`apply_nap_exercise_corrections.R`, `apply_second_review.R`,
`apply_sleep_metric_duration_corrections.R` and
`checkforerrors_processing.R`. In every case the `inst/scripts/` copy
resolved its file paths through
[`cfg_get()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/cfg_get.md)
while the root copy still hardcoded filenames – a half-finished
configuration migration.

Which copy runs depends on how the pipeline is started:
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
sources from `system.file("scripts")`, whereas
`source("00_MAIN_entry.R")` falls back to
[`getwd()`](https://rdrr.io/r/base/getwd.html). Under the default config
the two behaved identically, because each
[`cfg_get()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/cfg_get.md)
default was the same string as the hardcoded filename, so nothing was
visibly broken. The latent trap was that any config overriding
`data.files.*` would be honoured by one copy and silently ignored by the
other – the affected run would read the default filename without raising
an error.

Resolved by making the config-aware `inst/scripts/` copies canonical and
copying them over the root copies. No behaviour change under
`config_default.yaml`. All 20 shared scripts are now byte-identical and
`KNOWN_DIVERGENT` in the sync test is empty.

## sleepcleanr 1.3.0 (in development)

Phase 1 of the v2.0 roadmap: the trustworthy-cleaning foundation. This
release adds an interface contract without changing any cleaning result.

### New: the `sleep_diary` S3 class

- [`new_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/new_sleep_diary.md),
  [`as_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/as_sleep_diary.md),
  [`is_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/is_sleep_diary.md),
  [`validate_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_sleep_diary.md)
  – a container carrying the working data plus the provenance of every
  step that touched it.
- [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html),
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html),
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) and
  [`dim()`](https://rdrr.io/r/base/dim.html) methods.
  [`summary()`](https://rdrr.io/r/base/summary.html) returns one row per
  step (rows in/out, columns added, elapsed milliseconds) and joins the
  [`log_step()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/log_step.md)
  flag ledger when it is populated.

### New: step adapters and the cleaning chain

- [`step_process_timestamps()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_process_timestamps.md),
  [`step_process_intervals()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_process_intervals.md),
  [`step_normalize_sequence()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_normalize_sequence.md),
  [`step_apply_corrections()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_apply_corrections.md),
  [`step_apply_duration_corrections()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_apply_duration_corrections.md),
  [`step_compute_metrics()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_compute_metrics.md)
  wrap the existing `inst/scripts/` implementations.
- [`run_cleaning_chain()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_cleaning_chain.md)
  composes those six steps end to end and returns a `sleep_diary`.
- [`assert_contract_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/assert_contract_columns.md)
  makes the Step 7 output contract (`sleep_efficiency_pct`, `sol_h`,
  `waso_h`, `sleep_duration_h`) an assertion rather than an assumption.

### Snapshot verification (new in this release)

- `verify_v1_3_s3.R` – zero-dependency S3 layer structural test (39
  assertions, base R only).
- `verify_v1_3_snapshot.R` – end-to-end identity check: runs both the
  old pipeline (steps 2-7) and the S3 chain on the bundled synthetic
  dataset, then compares all 95 output columns. **Result: bit-identical
  on all 280 rows × 95 columns.** S3 chain is 2.6× faster (0.45 s vs
  1.16 s) because it avoids the repeated
  [`source()`](https://rdrr.io/r/base/source.html) overhead.

### Bug fixes (discovered during snapshot verification)

- `error_unusual_sleep_time_corrections.R`: replaced four `1:nrow(df)`
  patterns with `seq_len(nrow(df))`. In base R, `1:0` evaluates to
  `c(1, 0)` (a 2-element vector!), causing an iteration on empty data
  frames that previously crashed with
  `missing value where TRUE/FALSE needed`. This bug had been masked
  because the old pipeline never received a fully empty corrections data
  frame in production (stub files provided at least a header row).
- `check_swap_corrections()`: added early-return guard when
  `corrections_df` is empty or lacks the `correction_type` column.

### Compatibility

- **No cleaning logic changed.** The adapters call the v1.2.0 scripts
  unmodified; they only box and unbox the data frame and record timing
  and column diffs.
  [`log_step()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/log_step.md)
  is still called with the same arguments in the same order, so the flag
  ledger and Figure 12 are unaffected.
- [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
  is unchanged in this release. It will be switched onto the chain once
  snapshot tests pin each step’s output.
- Steps that write files or publish into the global environment – data
  loading, the field-misentry check, review-file generation,
  second-review consensus, auto-detection, the cross-participant check
  and visualisation – are intentionally outside the chain for now.

### Tests

- `test-sleep-diary.R` adds 11 tests covering construction, validation,
  coercion, the generic methods, the Step 7 contract assertion, and step
  provenance recording. All use synthetic data, so they run on CI with
  no dataset and no Suggests package present.

------------------------------------------------------------------------

## sleepcleanr 1.2.0

- Per-step flag ledger
  ([`log_step()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/log_step.md),
  `flag_standards.R`) with `output/step_flag_ledger.csv`.
- Figure 12 rebuilt as a three-panel step-by-flag table.
- `flag_severity` moved out of the visualisation layer into Step 7,
  which now emits the four public contract columns.
- `main_csv` made optional; data integrity audit added.
- `R CMD check`: 0 errors, 0 warnings, 3 acceptable notes. GitHub
  Actions green.
