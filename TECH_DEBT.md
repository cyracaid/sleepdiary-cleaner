# Technical Debt — splsleep v1.4.0

Tracked code-quality items that are intentionally deferred to a future release.
Each entry states what the debt is, why it exists, and when it should be resolved.

---

## 1. Root and inst/scripts/ script duplication — RESOLVED as design (2026-08-12)

**Status: NOT debt.** The dual copies exist by design, not accident:

- `run_pipeline()` → `system.file("scripts")` → `inst/scripts/` copy
- `source("00_MAIN_entry.R")` → `getwd()` → repo-root copy

`test-script-copies-in-sync.R` enforces byte-identical copies and fails on any new divergence (`KNOWN_DIVERGENT` deliberately empty). Historical note: on 2026-08-05 five scripts (apply_metric_review_acceptances, apply_nap_exercise_corrections, apply_second_review, apply_sleep_metric_duration_corrections, calculate_sleep_time_end) diverged — inst/scripts read paths via cfg_get() while root hardcoded filenames; default config hid the difference until `data.files.*` was overridden. Commit 80c7e657. When refactoring, edit both copies and re-run the sync test.

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

**What:** The step adapters `step_process_timestamps()` and `step_process_intervals()` call the original scripts via `.load_script()` → `sys.source()`. The wrapper-first strategy (v1.3.0) intended that after snapshot verification, these bodies would be internalised into `R/steps.R`, eliminating the filesystem `source()` hit.

**Current state:** The adapters still call the original scripts. The snapshot test (v1.3.0) proved bit-identical output, so internalisation is safe.

**Why this debt exists:** The snapshot verification was completed in the same session as the S3 class implementation. Internalising the script bodies was deferred to a follow-up to avoid mixing structural changes with logic migration.

**Resolution plan (v1.4.0):**
1. Copy the body of `process_timestamp()` into `step_process_timestamps()` in `R/steps.R`.
2. Copy the body of `process_interval()` into `step_process_intervals()` in `R/steps.R`.
3. Remove `.load_script()` calls for these two adapters.
4. Re-run `verify_v1_3_snapshot.R` to confirm output unchanged.
5. The `inst/scripts/` copies are retained for steps 5/8/9 which still `source()` them.

**Last updated:** 2026-07-28 (v1.3.1)

---

## 3. cfg_get() global-environment fallback

**What:** Several `inst/scripts/` files call `cfg_get()` without passing the `cfg` parameter. They rely on the `.GlobalEnv$pipeline_config` fallback, which now emits a deprecation warning in v1.3.1.

**Files affected:** `sleep_visualization.R`, `checkforerrors_processing.R`, `cross_participant_field_misentry_check.R`, `apply_sleep_metric_duration_corrections.R`, `apply_nap_exercise_corrections.R`, `apply_metric_review_acceptances.R`, `apply_second_review.R`, `00_MAIN_entry.R`

**Why this debt exists:** These scripts are `source()`-d into `run_pipeline()` with `local = TRUE`, so they execute in the calling environment where `pipeline_config` is available. Passing `cfg` explicitly would require changing every script's function signatures.

**Resolution plan (v1.4.0):** When these scripts are migrated away from `source()` (see item 1), their functions will accept `cfg` as an explicit parameter.

**Last updated:** 2026-07-28 (v1.3.1)
