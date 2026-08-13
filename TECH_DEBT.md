# Technical Debt — splsleep v1.4.0

Tracked code-quality items that are intentionally deferred to a future release.
Each entry states what the debt is, why it exists, and when it should be resolved.

---

## 1. Root and inst/scripts/ script duplication — RESOLVED as design (2026-08-12)

**Status: NOT debt.** The dual copies exist by design, not accident:

- `run_pipeline()` → `system.file("scripts")` → `inst/scripts/` copy
- `source("00_MAIN_entry.R")` → `getwd()` → repo-root copy

`test-script-copies-in-sync.R` enforces byte-identical copies and fails on any new divergence (`KNOWN_DIVERGENT` deliberately empty). Historical note: on 2026-08-05 five scripts (apply_metric_review_acceptances, apply_nap_exercise_corrections, apply_second_review, apply_sleep_metric_duration_corrections, calculate_sleep_time_end) diverged — inst/scripts read paths via cfg_get() while root hardcoded filenames; default config hid the difference until `data.files.*` was overridden. Commit 80c7e657. When refactoring, edit both copies and re-run the sync test.

**Local gate (2026-08-13):** `inst/hooks/pre-commit` aborts any commit whose staged files touch a dual-maintained script with only one copy updated — installed via `bash inst/hooks/install-hooks.sh`. CI's sync test still runs on push; the hook just catches the drift before the commit exists.

**File index (both locations):**

| File | Root copy | inst/scripts/ copy |
|------|-----------|-------------------|
| `error_unusual_sleep_time_corrections.R` | ✓ | ✓ |
| `checkforerrors_processing.R` | ✓ | ✓ |
| `sleep_visualization.R` | ✓ | ✓ |
| `generate_correction_files.R` | ✓ | ✓ |
| `cross_participant_field_misentry_check.R` | ✓ | ✓ |
| `cross_participant_global_check.R` | ✓ | ✓ |
| `apply_second_review.R` | ✓ | ✓ |
| `apply_nap_exercise_corrections.R` | ✓ | ✓ |
| `apply_sleep_metric_duration_corrections.R` | ✓ | ✓ |
| `apply_metric_review_acceptances.R` | ✓ | ✓ |
| `report_correction_status.R` | ✓ | ✓ |
| `audit_data_integrity.R` | ✓ | ✓ |
| `audit_review_propagation.R` | ✓ | ✓ |
| `generate_ai_review_csvs.R` | ✓ | ✓ |

---

## 2. process_timestamp() and process_interval() exist in both R/steps.R and inst/scripts/

**Status: RESOLVED (2026-08-13, commit 5d0e481).** The two adapter bodies are
internalised: `R/timestamp_parse.R` and `R/interval_parse.R` carry verbatim
copies, and `step_process_timestamps()` / `step_process_intervals()` call them
directly — no `.load_script()` filesystem hit remains for these two adapters.
Snapshot verification (13/13) confirmed bit-identical `corrected_ema_data`.

The `inst/scripts/` copies are **retained by design**: `00_MAIN_entry.R`, the
snapshot verifier and `test-interval.R` still `source()` them. Edit both copies
together; `test-script-copies-in-sync.R` + the pre-commit hook enforce it.

---

## 3. cfg_get() global-environment fallback

**Status: RESOLVED (2026-08-13, commit 53e6fda).** All `cfg_get()` calls now
receive `cfg` explicitly — no `.GlobalEnv$pipeline_config` fallback remains in
pipeline scripts:

- Function scripts (`apply_metric_review_acceptances`, `apply_nap_exercise`,
  `apply_sleep_metric_duration_corrections`) take a `cfg = NULL` parameter.
- Top-level scripts (`cross_participant_field_misentry_check`,
  `checkforerrors_processing`, `sleep_visualization`) read `.pipeline_cfg`
  from the source environment; callers inject it before `source()`.
- `apply_second_review` default `checklist_path` moved out of the signature
  arg (lazy evaluation couldn't see caller cfg) → `NULL` + resolve inside.
- `run_visualization()` in `R/pipeline.R` injects `.pipeline_cfg <- env$cfg`
  before sourcing.

Deprecation warnings from the cfg fallback are gone; remaining 24 warnings in
`test-pipeline.R` are pre-existing `mutate()` warnings, unrelated to cfg.

**Last updated:** 2026-08-13

---

## 4. R/steps.R still `.load_script()`s six adapters at runtime

**Status: RESOLVED (2026-08-13, commits 8e70f10/f3a4eb7/4c983a4/c5ae1c3).**
All six adapters internalised into `R/` with verbatim bodies:
`R/normalize_sequence.R`, `R/sleep_time_metrics.R`,
`R/correction_appliers.R`, `R/manual_corrections.R`. `.load_script()` deleted;
the S3 chain has zero filesystem dependency. `test-internalised-in-sync.R`
locks each R/ body to its inst/scripts counterpart (parse+deparse identical);
the snapshot verifier was refactored to `pkgload::load_all` + `rm()` so it
actually exercises the internalised code (13/13 bit-identical).

The `inst/scripts/` copies are **retained by design**: `00_MAIN_entry.R` and
the legacy pipeline still `source()` them. Edit both copies together; the
pre-commit hook + `test-script-copies-in-sync.R` cover the script pair and
`test-internalised-in-sync.R` covers the R/↔script pair.

**Why it existed:** Same historical reason as item 2 — the S3 chain
originally sourced step scripts.

**Cost (paid):** Runtime filesystem dependency; adapter bodies couldn't be
unit-tested from the package; drift between copies was only half-gated.

**Resolution (done):** Verbatim bodies into `R/*.R`, direct calls from
`step_*()`, snapshot-verified bit-identical at each step.

---

## 5. Two parallel pipeline implementations
## 5. Two parallel pipeline implementations

**Status: OPEN (2026-08-13).** `run_pipeline()` (R/pipeline.R, 8 `source()`
calls) and `.run_pipeline_internal()` (00_MAIN_entry.R, 16 `source()` calls)
are separate implementations of the same 10 steps. The packaged entry wraps
the S3 chain; the legacy entry re-sources every step itself.

**Why:** 00_MAIN_entry.R predates the package wrapper and was kept for
back-compat (users `source()` it directly).

**Cost:** Proven by P2: the smoke test caught `.cfg` being used before
assignment in 00_MAIN_entry's Step 1 — a bug that existed since 2cbe1be8
(2026-08-06) because the two paths can drift independently. Every fix must
land in both copies plus the sync gate.

**Resolution options:** (a) make `.run_pipeline_internal()` delegate to the
packaged `run_pipeline()`, keeping 00_MAIN_entry as a thin shim; (b) deprecate
00_MAIN_entry entirely once smoke coverage is strong. Option (a) is lower
risk; the legacy-entry smoke test (2911d06) must stay green either way.

---

## 6. verify_v1_3_snapshot.R carries a local cfg_get() duplicate

**Status: OPEN (2026-08-13).** The snapshot verifier defines its own 3-arg
`cfg_get(key, default, cfg_arg)` (verify_v1_3_snapshot.R:57 + inst/
verification copy) that shadows the package version. `cfg_arg` avoids the
parameter-vs-closure name clash; body logic duplicates R/config.R.

**Why:** The verifier runs standalone (`Rscript verify_v1_3_snapshot.R`)
without the package attached in the same way as the pipeline, and its closure
needs the local `cfg` binding.

**Cost:** Package `cfg_get()` semantics change → verifier version drifts
silently; the sync test only checks the two verifier copies against each
other, not against R/config.R.

**Resolution:** Export `cfg_get` (already exported) and make the verifier
call the package version with explicit `cfg`; delete the local definition.
Requires the verifier to `library(splsleep)` (or `pkgload::load_all`) first —
it already does for other package functions.

---

## 7. error_unusual publishes results via list2env() to .GlobalEnv

**Status: OPEN (2026-08-13).** `error_unusual_sleep_time_corrections.R:2046`
does `list2env(results, envir = .GlobalEnv)`, dumping equal_time_df, error_df,
unusual_df, clean_df, correction_summary (+ reasonable_unusual_df via
assign) into the global environment. The leakage test (2911d06) whitelists
these 5 names as the accepted protocol.

**Why:** Legacy data-passing style: downstream steps (checkforerrors,
visualization) read the dataframes from the global env after the source()
call, mirroring how the whole legacy chain passes data.

**Cost:** Pollutes the global env; any refactor that adds a new result key
silently leaks it unless the whitelist is updated; conflicts with package
namespace hygiene (functions like eval_checkforerrors take the data as
arguments instead).

**Resolution:** Return the list from a function and pass it into downstream
steps explicitly (same direction as items 3/4), or at minimum scope the
names into the source() environment rather than .GlobalEnv. Low priority —
contained and gated by the leakage test.

---

## 8. 35 pre-existing mutate() warnings in test-pipeline.R

**Status: OPEN (2026-08-13).** `run_pipeline` on synthetic data emits dplyr
`mutate()` warnings (name-repair / unknown-column style). Count changed
24 → 35 when the test process locale moved from C to UTF-8
(helper-locale.R), confirming they are encoding-sensitive noise, not
cfg-related.

**Why:** Legacy step scripts use `mutate()` with `:=`/`!!` patterns that
trigger dplyr's name-repair warnings on the synthetic column set.

**Cost:** Hides real warnings in CI output; the warning count is locale-
dependent so it can't be asserted on.

**Resolution:** Either silence deliberately (`suppressWarnings` around the
known-benign mutate in the relevant step, with a comment), or fix the
name-repair root cause (explicit `.name_repair`). Cosmetic; do not block
release work.

**Last updated:** 2026-08-13

---

## 9. calculate_sleep_time_vars_end reads .GlobalEnv$pipeline_config

**Status: OPEN (2026-08-13).** The internalised
`calculate_sleep_time_vars_end()` (R/sleep_time_metrics.R, verbatim from the
script) reads `cfg <- get0("pipeline_config", envir = .GlobalEnv,
ifnotfound = NULL)` and only then computes the `flag_severity` /
`flag_duration_extreme` columns. Called outside a run that assigned
pipeline_config to .GlobalEnv (e.g. run_cleaning_chain standalone), the
two flag columns are silently missing.

**Why kept:** D7 decision during internalisation — changing the signature to
`cfg = NULL` would break the verbatim parity gate across three copies
(R/, inst/scripts, and the legacy entry). It was deliberately deferred.

**Resolution:** Add `cfg = NULL` parameter, resolve via the explicit arg
(apply_* pattern), update all three copies in one commit, extend
test-internalised-in-sync.R if the signature change requires it, and add a
unit test asserting flag_severity appears when cfg is passed.

**Last updated:** 2026-08-13
