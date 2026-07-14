# Second-Review Integration — Worklog

**Date:** 2026-07-09
**Project:** splsleep (sleep EMA diary data pipeline)

---

## 2026-07-09 — Second-Review Consensus Integration & Pipeline Automation

### Summary
Integrated 13 second-review checklist decisions into pipeline-input CSVs. Created 3 new automation scripts: `apply_second_review.R` (Step 5.75), `00a_setup.R` (environment check), `run.sh` (one-command runner). Migrated hardcoded pid=4024 fix from `00_MAIN_entry.R` to `manual_nap_exercise_corrections.csv`. Batch-annotated remaining 16 single-reviewer rows in `metrics_ai_review.csv` with `(two reviewer consensus)`. Pipeline now has 10 steps with explicit routing via `target_csv` column.

---

### Phase A: Second-Review Checklist Routing

**Goal:** Implement the third-agent verification of 13 rows from `second_review_checklist.csv`.

#### Decision Table

| Decision Type | Count | target_csv | Action |
|--------------|-------|------------|--------|
| confirmed_not_error_do_not_correct | 11 | `manual_metric_review_acceptances` | Append via anti-join |
| correction (6985 day8 awake→getup) | 1 | `manual_error_corrections` | Verify-only (already hand-entered) |
| recode (10009 day9 nap 675→75) | 1 | `manual_nap_exercise_corrections` | Verify-only (already hand-entered) |

#### Why Step 5.75, Not Step 6 or Step 6.5

Placed between Step 5 and Step 6 so that corrections routed to `manual_error_corrections.csv` (e.g., pid=6985 day8 awake→getup fix) are read by `error_unusual_sleep_time_corrections.R` in the **same** pipeline run. If placed after Step 6, those corrections would be invisible until the next run.

#### Routing Mechanism

Added `target_csv` column to `second_review_checklist.csv` — an explicit routing column rather than text-inference from `decision_type` or `pipeline_status_before_review`. Also renamed `current_status` → `pipeline_status_before_review` for clarity.

---

### Phase B: Automation Scripts Created

| Script | Step | Purpose |
|--------|------|---------|
| `apply_second_review.R` | 5.75 | Write-only consensus applicator: reads checklist → 3-route dispatch via anti-join |
| `00a_setup.R` | (pre-pipeline) | Auto-detects R packages via regex scanning of `library()`/`require()` calls; verifies all 8 required input files exist |
| `run.sh` | (runner) | `set -euo pipefail` → `00a_setup.R` → `00_MAIN_entry.R` |

#### `apply_second_review.R` Design
- Helper `append_with_antijoin()`: reads existing CSV → anti-join on (pid, day_num, row_id) → appends only non-duplicate rows
- Route A (`manual_metric_review_acceptances`): actually appends rows with `source = "second_review"` and `date_added`
- Route B (`manual_error_corrections`): verify-only — prints expected rows for operator confirmation
- Route C (`manual_nap_exercise_corrections`): verify-only — same pattern

---

### Phase C: Hardcoded Fix Migration

Removed the hardcoded line from `00_MAIN_entry.R` line 72:
```r
# Before:
ema_data_release_timeproc$exercisetoday_PM_totalmin_Moderate[3992] <- "01:30"

# After:
# NOTE: pid=4024 hardcoded fix was migrated to manual_nap_exercise_corrections.csv
```

Added to `manual_nap_exercise_corrections.csv`:
`pid=4024, day=3, row=3992, variable=exercisetoday_PM_totalmin_Moderate, corrected_mincalc=90`

Uses `verified_recode` (not `TRUE`) in the `manually_corrected` column to distinguish from human-review entries.

---

### Phase D: Batch Annotation of 16 Single-Reviewer Rows

All 16 remaining rows in `metrics_ai_review.csv` without `(two reviewer consensus)` annotation were batch-updated. These are interval-trust boundary cases (SOL=0, awake=getup, or low SOL values) structurally identical to the 46 already dual-consensus rows. All had `human_decision = confirmed_not_error_do_not_correct` from single-reviewer pass. Batch annotation brings the file to 62/62 rows annotated.

#### Breakdown of the 16 rows

| Pattern | Count | PIDs |
|---------|-------|------|
| SOL=0 | 4 | 2714 d12, 2835 d5, 4481 d7, 6374 d13 |
| awake=getup | 4 | 2835 d5/d12, 3200 d2, 6374 d13 |
| SOL 5–120 (other boundary) | 8 | 1036 d11, 3200 d7, 6143 d1, 6032 d10, 6805 d9, 7078 d5, 9696 d3, 10929 d2, 11419 d10, 11863 d14 |

---

### Phase E: Three-Agent Cross-Validation

Three subagents independently reviewed the changes:

| Agent | Focus | Findings |
|-------|-------|----------|
| Pipeline integrity | Step numbering, source dependencies | Step 5.75 position correct; all source() targets verified |
| CSV cross-reference | Checklist → target CSV consistency | All 13 checklist rows accounted for; anti-join keys unique; `verified_recode` correctly used |
| Documentation audit | `pipeline_architecture.md` vs code | 10 of 11 claims verified; only discrepancy was 24 figures claimed (actual: 20 when C2 suppresses all flags) |

---

### Files Modified

| File | Change |
|------|--------|
| `00_MAIN_entry.R` | Added Step 5.75 (source apply_second_review.R); removed hardcoded line 72 fix; updated step count to 10 |
| `metrics_ai_review.csv` | 16 rows batch-annotated with `(two reviewer consensus)` → 62/62 complete |
| `second_review_checklist.csv` | Added `target_csv` column; renamed `current_status` → `pipeline_status_before_review` |
| `manual_nap_exercise_corrections.csv` | Added pid=4024 entry (migrated from hardcoded fix) |
| `pipeline_architecture.md` | Added Step 5.75 to step table, data flow diagram, and CSV table |

### Files Created

| File | Size | Purpose |
|------|------|---------|
| `apply_second_review.R` | ~80 lines | Step 5.75 — write-only consensus applicator |
| `00a_setup.R` | ~55 lines | Pre-pipeline environment check |
| `run.sh` | ~8 lines | One-command bash runner |

### Final Inventory

| File | Status | Details |
|------|--------|---------|
| `second_review_checklist.csv` | ✅ 13 rows, all consensus_reached, with target_csv | |
| `apply_second_review.R` | ✅ Created | Anti-join idempotent, 3-route dispatch |
| `00a_setup.R` | ✅ Created | Auto-install packages, verify input files |
| `run.sh` | ✅ Created | set -euo pipefail |
| `metrics_ai_review.csv` | ✅ 62/62 annotated | |
| `manual_nap_exercise_corrections.csv` | ✅ 12 rows (pid=4024 added) | |
| `00_MAIN_entry.R` | ✅ Step 5.75 inserted, hardcoded fix removed | |
| `pipeline_architecture.md` | ✅ Updated | |
| Pipeline steps | **10 steps** (1, 1.5, 2, 3, 4, 5, **5.75**, 6, 6.5, 7, 8, 8.5, 9) | |
