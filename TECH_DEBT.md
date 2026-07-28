# Technical Debt — splsleep v1.3.1

Tracked code-quality items that are intentionally deferred to a future release.
Each entry states what the debt is, why it exists, and when it should be resolved.

---

## 1. Duplicate scripts in root and inst/scripts/

**What:** The following files exist in TWO locations with identical content:

| File | Root copy | inst/scripts/ copy | Why duplicated |
|------|-----------|-------------------|----------------|
| `error_unusual_sleep_time_corrections.R` | 2,082 lines | 2,082 lines | Root copy used by legacy run_pipeline(); inst/scripts/ used by S3 chain |
| `checkforerrors_processing.R` | 987 lines | 987 lines | Same reason |
| `sleep_visualization.R` | 2,594 lines | 2,594 lines | Same reason |
| `generate_correction_files.R` | 807 lines | 807 lines | Same reason |
| `cross_participant_field_misentry_check.R` | — | — | Same reason |
| `cross_participant_global_check.R` | 429 lines | 429 lines | Same reason |
| `apply_second_review.R` | — | 98 lines | Same reason |
| `apply_nap_exercise_corrections.R` | — | — | Same reason |
| `apply_sleep_metric_duration_corrections.R` | — | — | Same reason |
| `apply_metric_review_acceptances.R` | — | — | Same reason |
| `report_correction_status.R` | — | — | Same reason |
| `audit_data_integrity.R` | — | — | Same reason |
| `audit_review_propagation.R` | — | — | Same reason |
| `generate_ai_review_csvs.R` | — | — | Same reason |

**Why this debt exists:** The legacy pipeline (`run_pipeline()`) sourced scripts from the project root. When the package was restructured for `R CMD build`, these scripts were copied into `inst/scripts/` while the roots were kept for backward compatibility. The S3 chain reads from `inst/scripts/` via `scripts_dir()`.

**Resolution plan (v1.4.0):**
1. Internalise `process_timestamp()` and `process_interval()` into `R/steps.R` (see item 2).
2. For the remaining scripts, make `inst/scripts/` the single source of truth. The root copies can become thin wrappers that call `source(system.file("scripts/...", package="splsleep"))`.
3. Or: delete all root copies after all callers are migrated to use `scripts_dir()`.

**Last updated:** 2026-07-28 (v1.3.1)

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
