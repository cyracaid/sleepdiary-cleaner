# sleepcleanr (development version)

## New
* `cleaning_report()`: a short factual description of the last run (entries and
  participants, entries corrected by each rule, reviewer corrections, entries left in the
  review queue, the reference thresholds), meant to be adapted for a Methods section.
  It reads only what the run produced and makes no claim about accuracy.

## Validation
* `validation/synthetic/prevalence_grid.R` (new; `run_all.R --with-grid`): the benchmark
  over four error rates (2, 5, 10, 20%) and four error-type mixes. At least 98.6% of
  injected errors were flagged or corrected to the true value in every one of the 16
  cells and no clean row was flagged or altered; the share corrected without a person
  ranged from 14% to 62% and the rows flagged per 1,000 from 8 to 151, depending on the
  mix. `inject_errors.R` accepts an optional per-category target in the catalog; the
  committed catalog is unchanged, so the main benchmark is unchanged.
* `evaluate_detection.R` failed on a ground-truth file with no multi-field rows (its
  `true_value` column was read as numeric); fixed.

# sleepcleanr 1.5.0

The package no longer writes to the global environment (a breaking change for code
that read `corrected_ema_data` or `review_output` from it); cleaning logic,
thresholds and every computed number are unchanged. Also new in this release: the
realistic-error-rate benchmark, `validation/run_all.R`, the blind-audit tooling, the
Zenodo DOI in the citation files, and corrected validation text.

## Breaking change: the package no longer writes to the global environment
* `run_pipeline()` used to leave `corrected_ema_data`, `review_output`,
  `checkforerrors_summary`, `pipeline_config`, `ema_data_release_timecalc`,
  `reasonable_unusual_df` (and, through the correction step, `equal_time_df`,
  `error_df`, `unusual_df`, `clean_df`) in the user's global environment. CRAN does
  not allow a package to do that, and it could overwrite a user's own objects of the
  same names. These objects are now kept in the package and returned by the new
  `pipeline_results()`.
* To keep the old behaviour, pass an environment: `run_pipeline(..., export_env =
  globalenv())` copies the same objects there.
* `run_visualization()` still works after a `run_pipeline()` in the same session.
* Cleaning logic, thresholds and every computed number are unchanged: on the
  synthetic demo and on the study data (with and without the manual files) the
  corrected data, the review queue and all output files are identical to those of
  1.4.9, and the ten synthetic benchmark tables regenerate identically.
* Tests: a new test checks that no `R/` file assigns into the global environment and
  that a pipeline run leaves it untouched; the legacy-entry leakage test now allows
  only the objects the legacy script itself creates.

## Corrections to earlier notes
* The 1.4.6 note "defaults (3, 12) validated as an operating point" overstated the
  sweep: the 20-point grid is flat (recall 0.9949 to 0.9957, false alarms 0), so
  the benchmark shows that results are *insensitive* to the swap and flip
  thresholds over that range. It cannot tell them apart and does not show that
  3 h and 12 h are optimal; they are retained as reference values.
* README: the real-data bullet no longer says "0 automatic fixes" (that figure
  described a report-only audit pass) and now gives the corrections the rules and
  the reviewers actually applied.

## Validation
* `validation/run_all.R` (new): regenerates nine synthetic benchmark tables from fixed
  seeds in a temporary copy and compares them with the committed ones (all nine
  identical with 1.4.9).
* The benchmark size is 5,391 injected rows in 14 categories plus 1,609 clean
  controls; the "4,736" in earlier notes described an older composition. The
  headline recall 0.995 (flagged or corrected to the true value) and the
  detection recall 1.0 in `correction_level_recall.csv` (any action, including
  26 wrong repairs) come from the same run and are defined in `validation/README.md`.

* `validation/synthetic/low_prevalence.R` (new): the benchmark at about 5% injected rows
  (flagged or corrected 99.4%, no clean row flagged or altered, 29.7 rows per 1,000
  flagged); `validation/run_all.R` now regenerates ten tables, all identical.
* `validation/blind_audit/` (new): protocol and scripts for a blind audit of the
  pipeline on real data (stratified sample, two independent annotators, kappa, miss
  rate with intervals, population estimate); tested on synthetic data only.
* `THRESHOLDS.md` says explicitly that the defaults are reference values: the
  threshold sweep is flat, so the benchmark is insensitive to them.

## Citation
* The package now has a Zenodo DOI (concept DOI 10.5281/zenodo.23077702) in
  `CITATION.cff`, `inst/CITATION` and the README.

# sleepcleanr 1.4.9

Documentation and validation release. No change to the package code, the cleaning
logic, any threshold or any computed number.

## Documentation
* README: new "Status and data availability" section (English and Chinese): the
  study data are not public; the bundled synthetic fixture, the seeded synthetic
  benchmark and two public datasets are. The CRAN claim and two directory badges
  were removed (the package is not on CRAN), and a section on running the tests
  and reporting problems was added.
* `validation/README.md` (new): each headline validation number, the table and
  script it comes from, and whether it needs the (non-public) study data.
* The redundant-channel result is now reported as 80 of 81 corrections improved
  (98.8%). The first analysis (August 2026) read 81 of 88 (92%) because one rule,
  `sleep_awake_swap_3h`, had not yet been guarded (v1.4.3); the validation
  vignettes (English and Chinese) keep both results and say why they differ.

## Validation
* `validation/redundant_channel_check.R` (new) recomputes that comparison from a
  run's `output/corrected_ema_data.rds`: counts, medians, an exact interval and a
  paired test, in total, by origin (algorithmic or manual) and by correction type.

## Repository
* The pre-commit hook also refuses root-level csv/rds/xlsx files and the
  manual_/sber_/real_data_config/fasttrack-style file-name shapes.

# sleepcleanr 1.4.8

Review-loop and figure-clarity release. No change to cleaning logic,
thresholds or any computed number; the real-data run gives the same 85
corrections as 1.4.7.

## Review worksheets show where each row was already handled
* The `[NEW]manual_error_correction_review.csv` and
  `[NEW]manual_unusual_review.csv` worksheets still list every row the rules
  flag, and now carry four extra columns taken from the manual files:
  `in_manual_file`, `review_resolution`, `resolved_at`, `resolved_by`. A row
  that is in no manual file yet has all four empty.
* At the end of a run (after the re-check of the corrected data) the console
  prints, per worksheet: rows not yet in a manual file, pending, legacy (no
  record of who or when), corrected, and handled-but-still-flagged. The summary
  is skipped when manual corrections were not applied.
* A manual row written without a `row_id` is matched to its worksheet row by
  participant and day.

## Fixed
* Manual correction files are read the same way in every R session. In a
  non-UTF-8 locale `read.csv(fileEncoding = "UTF-8")` silently dropped rows;
  the files are now read as raw bytes and decoded as UTF-8 (BOM stripped),
  and invalid input stops with an error instead of truncating.
* The step ledger (Fig 12 / A1) recorded `NA` for the checkforerrors standard
  at every step; it now shows the flag counts.
* Fig 24 crashed on a leftover continuous x scale; Fig 13 no longer clips its
  top; Fig 2 and R25 subtitles no longer overlap or run off the figure.
* Step 11 built the figure index from the wrong folder for tagged runs.
* A1 was listed as "not generated" when it had been.

## Figures explain themselves
* Figures carry their own definitions or standards where a reader needs them,
  and fractional-cup substance values are shown as fractions.
* Every figure missing from a run is listed, with a reason, on the contact
  sheet; Fig 13C (no synthetic benchmark files) and Fig 14 (pending rows have
  no computable sleep duration) now say so instead of "Reason not recorded" or
  "UNEXPECTED".
* An odd number of figures in a tier no longer leaves an unexplained empty
  cell on the contact sheet.

## Documentation
* `interpreting-output` (English and Chinese) restructured: plain-language
  rules, terminology, run and inputs first, collapsible FAQ and exact rules.
* The pkgdown Articles menu separates English and Chinese; every article links
  to its counterpart.
* `validation/external/` documents two external-dataset checks (KAIST,
  Manchester) with their adaptation scripts. Both are feasibility checks, not
  accuracy evaluations: neither dataset has known diary errors.

# sleepcleanr 1.4.7

Robustness and consent release. Fixes found by external-dataset validation and
controlled re-runs; no changes to cleaning logic or thresholds.

## New: explicit manual-corrections gate
* `run_pipeline()` gains `include_manual_corrections = FALSE` (new default):
  an algorithmic-only run — no human-review file touches the data, a
  prominent banner says so, and Step 5 still writes the `[NEW]` review
  worksheets for inspection. `TRUE` restores the legacy behaviour; `"ask"`
  prompts interactively (reporting flagged-record counts) and degrades to
  FALSE non-interactively; `y/yes/n/no` accepted. A dataset can now only be
  modified by a human-review file when the caller asked for it by name.
* `data.require_manual_corrections` guard fixed: the key was documented and
  configured one YAML level too deep (`data.files.`), so the missing-file
  hard stop had been silently inert since 1.4.5. It now lives under `data:`
  and verified to stop correctly.

## Fixed
* `format(<difftime>, "%H:%M")` raised "invalid 'trim' argument" on R >= 4.x
  for hms/difftime timestamp columns; conversion is now manual and
  version-stable (the pipeline runs on R 4.6.0).
* CSV main inputs crashed at Step 1.5 with the cryptic "unknown input format"
  (the field-misentry preprocessor hard-coded `readRDS()`); CSV is now loaded
  by extension, matching the Step-1 loader.
* All-NA interval columns no longer skip contract-placeholder generation
  (`*_mincalc`, `*_checkforerrors`, `*_correctionsmade`), so datasets that
  legitimately lack a field (no naps, no substance data) pass the Step-10
  column-dictionary check.
* Corrected-time review sheets now show the pipeline's actual corrected
  values with real observation dates instead of the 2000-01-01 placeholder
  date (de-identified inputs have no dates; the sber export supplies them).

## External validation
* End-to-end run on an independent real dataset (Baigutanova et al. 2025,
  *Scientific Data*: 49 healthy adults x 4 weeks, 1,372 diary entries,
  24-hour clock times, no separate get-up field): 1,094 valid (79.7%),
  mean TST 7.55 h (healthy-adult literature range), zero errors, zero
  automated corrections — consistent with the source study's pre-release
  AM/PM correction.

# sleepcleanr 1.4.6

Data-first entry, provenance, and figure-hardening release.

## New API: `clean_sleep_diary()`

- One-call entry: `clean_sleep_diary("my.csv")` (also .rds / .xlsx / data.frame)
  with no config file required; column names are inferred and every schema
  inference decision is recorded, never silently guessed.
- `guess_column_mapping()` returns per-column records (user_col, internal_col,
  match_rule, confidence, status, candidate_set); ambiguous ties are never
  silently resolved; absent required fields fail loudly.
- `dry_run = TRUE` previews the mapping and writes only `dry_run_manifest.json`
  (never a cleaned dataset); raw input is never modified.
- Provenance manifest (JSON): input md5 hash as identity, git commit (NULL
  outside a repo), UTC timestamp, environment (R version, platform, package
  versions), full effective config, per-step ledger, output paths.
- `run_pipeline()` gains an optional `data = NULL` argument; default NULL is
  the zero-change backward-compatible path (invariant-tested).

## Validation hardening

- `validation/synthetic/operating_point_sweep.R`: 20-point grid
  (swap 1-5 h x flip 8-14 h) with a predefined selection rule; result: flat
  plateau, defaults (3, 12) validated as an operating point.
- `validation/synthetic/benchmark_table.R`: per-category detection-vs-
  correction table with precision / FAR / false-correction columns; fixes the
  control-row miscompute in detection_outcomes_v4_current.csv.
- Citation metadata: CITATION.cff, inst/CITATION, .zenodo.json (DOI placeholder).

## Figure robustness

- Review PDF built from saved PNGs (print() of patchwork corrupts on
  non-interactive devices); Fig 13 uses measured table heights so the canvas
  grows instead of tables overflowing; Fig 15 reads Step-6 classification and
  degrades to per-type counts on single-date data; Fig 11/14/16 report skip
  reasons (`.mark_skip()`); missing-figure report (console + CSV + contact
  sheet footer); A1 ledger Step column width fixed.

# sleepcleanr 1.4.5

CRAN resubmission: fixes the Debian check ERROR by replacing the legacy
`US/Pacific` timezone alias (not recognized by lubridate's CCTZ on Debian)
with the canonical IANA name `America/Los_Angeles` in the timestamp parser
(`R/timestamp_parse.R` and the legacy `inst/scripts/process_timestamp_
emadatarelease_cyra.R` copy). Also drops the stray `inst/doc/.gitkeep`
hidden file from the build, adds `VALIDATION_REPORT.md` to `.Rbuildignore`,
and updates the README codecov (301) and stargazers (404) badge links.

# sleepcleanr 1.4.4

Adds the silent-error audit disposition layer: Dataset B now carries a
per-row `audit_disposition` roll-up column (none/keep/keep_flagged/
corrected_manual/set_na/mixed) sourced from a private field-level ledger
(`audit_dispositions.csv`, gitignored), with hard consistency guards linking
value-changing dispositions to the manual-corrections file. NA writes in
`sleep_metric_duration_corrections` are now honored as explicit original-value
removal (set_na). Field-misentry check now resolves the SOL column from config
(MM:SS-era export compatibility).

# sleepcleanr 1.4.3

Fixes a correction rule flagged by the redundant-channel validation on real
data (Channel B, 2026-08-12/13).

## Fixed

* **`sleep_awake_swap_3h` guard**: the swap now only fires when `bed <= awake`.
  Previously, swapping when the old awake time preceded bed put the new sleep
  time before bed, worsening the (bed→sleep) SOL gap; validation measured this
  as a real negative effect (7/10 corrected rows moved farther from
  self-reported SOL). Real-data rerun after the guard: 10 → 4 swap rows, all
  order-valid, 3/4 closer to self-report. Guarded rows are left uncorrected
  and picked up by the downstream temporal-order check for human review.

# sleepcleanr 1.4.2

Adds the calibrated synthetic-error-injection benchmark harness to the
tracked repo (`validation/synthetic/`). No cleaning logic changed.

## New

* **Benchmark harness**: `generate_clean_data.R` (structurally-pure and
  population-realistic synthetic data), `error_catalog.yaml` (12-category
  error taxonomy with provenance tags), `inject_errors.R`
  (participant-clustered injector with ground-truth logging),
  `evaluate_fcr.R` / `evaluate_detection.R` (false-alteration and
  per-category detection/recall evaluators).
* **First-pass results** (`validation/synthetic/SYNTHETIC_BENCHMARK_RESULTS.md`):
  0/10,000 false alterations on structurally-clean synthetic input;
  population-stratified flag-rate gradient (0.0% healthy_adult to 7.7%
  insomnia_like); per-category detection results across 12 injected-error
  types. This harness is what found and verified the two bugs fixed in
  v1.4.1 (field-misentry silent misrepair, missing human-review CSVs).
* **README**: Validation section's benchmark row corrected from "planned"
  to "first pass done", linking to the results doc.

## Not yet done

Full recall/specificity/PPV-curve treatment with cluster-bootstrap CIs,
multiverse analysis (needs a prerequisite refactor: the 3-hour
adjacent-swap threshold and cross-participant MAD constants are currently
hardcoded, not configurable), leave-one-out ablation, and downstream
sleep-metric sensitivity analysis. See `benchmark-design.md`.

---

# sleepcleanr 1.4.1

Bug-fix release. No cleaning logic changed outside the two items below.

## Bug fixes

* **SOL/WASO high-risk duration-reinterpretation flag (`checkforerrors_processing.R`,
  Part A4).** Synthetic benchmark testing (n=400/class) found `field_misentry_sol` /
  `field_misentry_waso` (clock-time text typed into a duration field) were silently
  misrepaired 95.8% / 96.0% of the time: `process_interval.R`'s `MM:SS` / `dd:00`
  reinterpretation heuristic turns the misentry into a small, plausible-looking number,
  and the downstream `sol_duration_for_review_status` / `waso_duration_for_metrics_status`
  checks (`calculate_sleep_time_end.R`) only ever flag values that are too *large*, never
  too *small* -- so nothing catches it. New Part A4 block flags any row whose
  `_correctionsmade` note matches the `MM:SS`/`dd:00` reinterpretation pattern and routes
  it to human review. Reduces SOL silent misrepair to 3.5% (14/400 -- a disclosed residual
  blind spot for "01:XX"-shaped values that leave no reinterpretation trace) and WASO to
  0% (0/400). Verified 0/10,000 new false positives on clean synthetic data and 0/10,000
  unrelated-field false alterations, both unchanged from pre-patch.

* **`generate_correction_files.R` now actually writes the human-review CSVs (Section 13).**
  The `write.csv()` calls for `[NEW]manual_error_correction_review.csv` and
  `[NEW]manual_unusual_review.csv` were commented out, and `run_pipeline()` immediately
  `rm()`'d the in-memory result afterward -- so neither file was ever produced, even
  though the pipeline's own log unconditionally printed "Files saved: ...". Human
  reviewers had nothing to review. Fixed; verified non-empty/expected output on a full
  real n=280 pipeline run and confirmed no collision with the Step 6 input filenames
  (`manual_error_corrections.csv` / `manual_unusual_corrections.csv`).

---

# sleepcleanr 1.4.0

Delivery release. **No cleaning logic changed.** Run-to-run figures are
identical to 1.3.9: Clean 1,908 / Unusual 31 / Equal 903 / Corrected 81 /
mean TST 7.71 h / mean SOL 28.8 min.

## New

* **`finalize_columns()` now runs as Step 10 of `run_pipeline()`.** Previously
  it had to be called by hand, so a plain `run_pipeline()` produced no Dataset A
  or B at all. Pass `finalize = FALSE` for the old behaviour. It runs after
  `final_summary()` on purpose: it only selects and renames columns, so a
  failure there leaves the cleaning run and every reported number intact.

* **`inst/extdata/column_dictionary.csv`** is the single source of truth for the
  delivered columns -- whitelist, rename mapping and data dictionary in one
  table. Adding a column means editing one CSV row.

* **Dataset A (36 columns)** and **Dataset B (15 columns)**. B carries `row_id`
  so `A ⋈ B` on `(pid, day_num, row_id)` cannot multiply rows; `pid + day_num`
  alone is not unique.

* **`record_status`** replaces `data_category` in Dataset A. Six levels, not the
  five originally planned: `reasonable_unusual` records were reviewed and
  accepted by a human, and that is not the same claim as `unusual`. An unmapped
  level stops the build rather than shipping a blank.

* **`waso_computed_minutes`** (`getup - final awakening`, converted from hours to
  minutes). Not a substitute for `waso_selfreport_minutes`: on real data
  (n = 1,723 paired) the marginal distributions nearly coincide -- both median
  10 min, both Q3 20 min -- but night-level correlation is r = 0.013. They are
  two variables, not two measurements of one quantity.

* **`verify_reference_fidelity.R`** -- the fidelity check deferred in 1.3. It
  pins each of the 8 metric formulas to its stated definition and records, per
  metric, whether it has been compared against the 2026-05-19 baseline. Four are
  identical; four deviate, all deliberately and all documented. Previously
  "has anyone actually checked this formula?" had no answer anywhere in the
  repo, which is how the sleep-onset deviation survived three months.

* **CI now runs the standalone verification scripts.** `R CMD check` executes
  `tests/testthat/` only and never touched `verify_*.R`, so nothing enforced
  them on push. `verify_reference_fidelity.R` runs with `--strict`: a metric
  with no recorded comparison fails the build.

## Fixes

* **Affect-layer columns are now reserved, not dropped.** `pos_affect`,
  `neg_affect`, `stress_today_pm` and `copestress_today_pm` are declared as
  `status = reserved` in the dictionary. When a corrected dataset carries them,
  `finalize_columns()` passes them through untouched; when it does not (the
  current real data), no placeholder is fabricated. They exist so a future
  dataset with the EMA affect items can be finalised without a breaking change.

* **Export guard.** `finalize_columns()` stops the run if any of the 14 signed
  minute metrics (`tst_minutes`, `sol_computed_minutes`, `sleepperiod_minutes`,
  `waso_*`, exercise minutes, ...) is negative in an analysable row
  (`record_status` neither `error` nor `not_reported`). `not_reported`
  (`skipped_na`) rows are whole missing nights; their negative fragments are
  arithmetic noise and are excluded, mirroring analyst filters.

* **Delivery is CI-verified.** `verify_delivery_wiring.R` checks the delivered
  files against the dictionary (exact column contract, finalize wiring,
  live guard) and joins `.github/workflows/R-CMD-check.yaml`; it defers
  gracefully when no `output/` exists in a checkout. `verify_reference_fidelity.R`
  runs in `--strict` mode (currently 16/16) and `verify_finalize_columns.R`
  (41/41). Full testthat suite 190 passing.

* **Development branch `v1.3-s3` deleted** (local and remote) and its trigger
  removed from the CI workflow. Phase 2 (analytics) and Phase 3 (methods
  paper) are paused; this release is the Phase 1 delivery gate.

* `row_id 8502` -- a manual correction fixed the awakening timestamp but left
  the get-up timestamp that the AM/PM normaliser had already shifted by 12 h,
  producing a WASO of -716 minutes. Corrected via the existing
  `column_to_correct_2` mechanism; no code changed.

* `.gitignore` -- backups such as `manual_error_corrections.csv.bak_20260808`
  were untracked rather than ignored, because the existing rules matched exact
  filenames and no suffixed copy. Those files hold participant identifiers.
  Now covered by `*.bak*` and `manual_*.csv.*`.

## Known limitations

* `correction_type` records only the algorithmic action and is not rewritten
  when a later manual correction overrides it. On the 16 rows with
  `has_correction == "both"` it may name a rule whose effect is no longer
  present. Noted in the dictionary; see open issues S6.

* `calculate_sleep_time_vars_end()` writes `output/corrected_ema_data.rds` as a
  side effect, so calling it from a working directory that holds real output
  overwrites that output. See open issues S8.

* The AM/PM normaliser decides *which* timestamp carries the error by looking at
  one pair only, without cross-checking the other two. On the three affected
  records a human overruled it twice, correctly both times. Assessed and
  deliberately not changed: three records, all either flagged or already
  corrected. See open issues S7.

# sleepcleanr 1.3.3

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

# sleepcleanr 1.3.0 (in development)

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

# sleepcleanr 1.2.0

* Per-step flag ledger (`log_step()`, `flag_standards.R`) with
  `output/step_flag_ledger.csv`.
* Figure 12 rebuilt as a three-panel step-by-flag table.
* `flag_severity` moved out of the visualisation layer into Step 7, which now
  emits the four public contract columns.
* `main_csv` made optional; data integrity audit added.
* `R CMD check`: 0 errors, 0 warnings, 3 acceptable notes. GitHub Actions green.

# sleepcleanr 1.4.4

Adds the silent-error audit disposition layer: Dataset B now carries a
per-row `audit_disposition` roll-up column (none/keep/keep_flagged/
corrected_manual/set_na/mixed) sourced from a private field-level ledger
(`audit_dispositions.csv`, gitignored), with hard consistency guards linking
value-changing dispositions to the manual-corrections file. NA writes in
`sleep_metric_duration_corrections` are now honored as explicit original-value
removal (set_na). Field-misentry check now resolves the SOL column from config
(MM:SS-era export compatibility).
