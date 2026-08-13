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
