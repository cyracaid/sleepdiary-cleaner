# SPL Sleep Data Pipeline — Architecture Guide

## Overview

An R pipeline that cleans EMA sleep diary data and produces 30 diagnostic figures (14 QC + 16 research). The pipeline has 10 steps (1, 1.5, 2–4, 5, 5.75, 6–7, 8, 8.5, 9, 10 — source of truth: `inst/steps.yaml`), from raw CSV/RDS loading through final column finalization. Human correction feedback is applied via CSV files at steps 5–7. The entry point is `00_MAIN_entry.R`; run `run_pipeline()` (installed package) or `source("00_MAIN_entry.R")` (development).

Classification categories (TIMESTAMP_ISSUE / DURATION_ISSUE / AMOUNT_FLAG / NEEDS_REVIEW) are **data-type labels, not exclusion criteria** — no data is removed based on category membership.

---

## Pipeline Flow

```
raw data (RDS + CSV)
    │
    ▼
[1] LOAD ───────────────────────────── 00_MAIN_entry.R
    │  Merge RDS (processed EMA vars) and CSV (start date, WASO counts).
    │  Uses row-order alignment (not keyed join — ensure CSV row order matches RDS).
    │  Columns added: StartDate, num_waso (→ num_waso_am), num_waso_estimate_am
    │  Output: df (intermediate, row count = study-dependent)
    │
    ▼
[1.5] CROSS-PARTICIPANT FIELD-MISENTRY ─ cross_participant_field_misentry_check.R
    │  Detects SOL/WASO values that exactly match timestamps from other fields.
    │  Output: cross_participant_field_misentries.csv
    │
    ▼
[2] TIMESTAMP PARSE ────────────────── process_timestamp_emadatarelease_cyra.R
    │  Convert "7:30 PM" → POSIXct datetime per variable.
    │  Detects AM/PM confusion, 24h format, hour > 24.
    │  Adds *_checkforerrors flag columns for downstream detection.
    │  Variables: time_bed_am, time_sleep_am, time_awake_am, time_getup_am,
    │             caffeinetoday_PM, alcoholtoday_PM, nicotine_amount_pm, cannabis_amount_pm
    │  Output: ema_data_release_timeproc (all previous columns + *_hhmm_ampm + *_checkforerrors)
    │
    ▼
[3] INTERVAL PARSE ─────────────────── process_interval.R
    │  Convert "00:30", "90", ".5" → numeric minutes.
    │  Handles missing colons, decimal hours, swapped HH:MM.
    │  Variables: SOL, WASO, nap, exercise (4 levels: Light, Moderate, Vigorous, Strength)
    │  Output: ema_data_release_timeproc (updated with *_mincalc, *_checkforerrors, *_correctionsmade)
    │
    ▼
[4] SEQUENCE NORMALIZE ─────────────── normalize_sleep_time_sequence.R
    │  Applies decision tree to auto-correct common timestamp swaps:
    │    • ≥12h gap between sequential times → add/subtract 12h (AM/PM fix)
    │    • <3h temporal order violation → swap adjacent pair (e.g. bed↔sleep)
    │  Output: ema_data_release_timecalc (time_*_corrected columns, adjustment flags)
    │
    ▼
[5] GENERATE REVIEW FILES ──────────── generate_correction_files.R
    │  Classifies every record into error / unusual / equal_time / skipped_na / clean
    │  based on temporal reasonability thresholds.
    │  Generates CSV templates (written to disk with [NEW] prefix):
    │    • [NEW]manual_error_correction_review.csv  — records needing time-value fixes
    │    • [NEW]manual_unusual_review.csv           — records needing classification review
    │  After human review, rename to strip the [NEW] prefix and use
    │  as input for step 6: manual_error_corrections.csv / manual_unusual_corrections.csv
    │
    ▼
[5.5] HUMAN REVIEW ────────────────── manual
    │  Review [NEW] CSVs from step 5; populate and rename to strip [NEW] prefix.
    │
    ▼
[5.75] SECOND-REVIEW CONSENSUS ─────── apply_second_review.R
    │  Reads second_review_checklist.csv (13 rows, all consensus_reached).
    │  Write-only: dispatches each row to target CSV (anti-join idempotent),
    │  verifies manual_error_corrections.csv / manual_nap_exercise_corrections.csv
    │  entries exist. Placed between 5 and 6 so corrections land in same run.
    │
    ▼
[6] APPLY CORRECTIONS ──────────────── error_unusual_sleep_time_corrections.R
    │  Reads reviewed CSVs and applies fixes (see Human Review Guide below).
    │  Correction cases (check order):
    │    CASE1 (skip):   all fields empty — skip row
    │    CASE2 (text):   natural-language solution (undo, AM/PM, swap, ±12h, …)
    │    CASE3 (column): exact column + value replacement (priority over CASE2)
    │    CASE4 (other):  unprocessable — emit warning
    │  Recalculates time differences, re-classifies.
    │  Flags "reasonable unusual" records (human-approved unusual patterns).
    │  Output: corrected_ema_data (the canonical analysis-ready dataframe)
    │
    ▼
[6.5] APPLY DURATION CORRECTIONS ───── apply_nap_exercise_corrections.R
    │                                    apply_sleep_metric_duration_corrections.R
    │                                    apply_metric_review_acceptances.R
    │  Nap/exercise numeric duration fixes; SOL/WASO MM:SS vs HH:MM fixes;
    │  marks rows human-accepted to suppress future flags.
    │  Inputs: manual_nap_exercise_corrections.csv,
    │          manual_sleep_metric_duration_corrections.csv,
    │          manual_metric_review_acceptances.csv
    │  Output: corrected_ema_data (+ human_metric_review_status)
    │
    ▼
[7] COMPUTE METRICS ────────────────── calculate_sleep_time_end.R
    │  Calculates from corrected timestamps:
    │    • SOL = minutes from bedtime to sleep onset  (0 means bed==sleep)
    │    • Sleep period = duration from sleep onset to final wake-up
    │    • WASO bout avg = average waking-after-sleep-onset interruption length
    │    • Time in bed = total minutes spent in bed
    │    • TST = total sleep time (sleep period minus WASO)
    │    • Sleep efficiency = TST / time-in-bed × 100
    │  Output: corrected_ema_data (updated with self_diffcalc_* columns)
    │
    ▼
[8] AUTO ERROR DETECTION ───────────── checkforerrors_processing.R
    │  Three parallel passes → unified review flag:
    │    PART A — parse-time *_checkforerrors flags (excludes exercise/nap/substance-timestamp)
    │    PART B — temporal error/unusual from step 6 (imports existing error_type/unusual_type)
    │    PART C — sleep metric extremes (SOL<0, SE<0, SE>100%, TST/TIB=0, TST/TIB>1)
    │    PART C2 — suppresses ALL flag types for human-accepted rows
    │              (reads human_metric_review_status + manual_metric_review_acceptances.csv)
    │    PART D — creates checkforerrors_df (remaining flagged records for review)
    │  Also detects substance input anomalies from raw CSV (6 types —
    │    see Key Design Decisions).
    │  Outputs:
    │    checkforerrors_processed    — main data with needs_review_flag + auto_error_desc
    │    checkforerrors_summary      — one-row-per-participant flag counts and category assignment
    │    substance_decimal_anomalies — reference table of input oddities (global env)
    │
    ▼
[8.5] CROSS-PARTICIPANT GLOBAL ─────── cross_participant_global_check.R
    │  Per-participant baselines (median + MAD); flags days where
    │  SOL/WASO/exercise deviates ≥5 MAD from own norm.
    │  Outputs: cross_participant_flagged_rows.csv, cross_participant_suspicious_slices.csv
    │
    ▼
[8.75] HUMAN REVIEW ────────────────── manual
    │  Review checkforerrors_df + cross_participant CSVs; re-run steps 5-8
    │  (skipping manual review) to fold decisions into final check.
    │
    ▼
[9] VISUALIZE ──────────────────────── sleep_visualization.R
     Figures 1-12:  corrected_ema_data (post-correction final data)
     Figures 13-18: checkforerrors_processed (pre-correction auto-detection flags)
     Figures 19-24: checkforerrors_summary + corrected_ema_data
```

---

## Classification System

### Data Categories (step 6)

```
data_category:
  has_na                → "skipped_na"
  bed_sleep_equal | awake_getup_equal → "equal_time_ok"
  is_error              → "error"
  is_unusual            → "unusual"
  otherwise             → "clean"

error_type (priority order):
  1. order_error            — temporal sequence broken (bed < sleep < awake < getup)
  2. bed_sleep_diff_error   — |bed_to_sleep| > 7 hours
  3. awake_getup_diff_error — |awake_to_getup| > 7 hours
  4. sleep_awake_24h_error  — |sleep_to_awake| > 24 hours
  5. multiple_errors        — multiple violations

unusual_type:
  - sleep_awake_suspicious  — sleep-to-awake < 3h or > 15h
  - bed_sleep_suspicious    — bed-to-sleep > 3h
  - awake_getup_suspicious  — awake-to-getup > 3h
  - multiple_suspicious

equal_time_type:
  - bed_sleep_equal / awake_getup_equal / both_equal
```

### Review Flag Categories (step 8)

| Label | Meaning | Source |
|-------|---------|--------|
| `TIMESTAMP_ISSUE` | Clock-time format errors | Step 2 parse flags (bed/sleep/awake/getup) |
| `DURATION_ISSUE` | Interval/duration format errors | Step 3 parse flags (SOL, WASO) |
| `AMOUNT_FLAG` | Substance input structural anomaly | Step 8 sections 1a-1c |
| `SELF_REPORTED_FLAG` | Diary-based metric anomaly (manual inspection) | Step 8 Part C (SOL, SE, TST/TIB) |
| `CLEAN` | No issues | — |
| `CLEAN (Manually Fixed)` | Corrected in step 6 | — |

Note: `SELF_REPORTED_FLAG` was previously named `NEEDS_REVIEW`; relabeled 2026-07-14 to clarify these are diary-based metric anomalies, not data errors.

---

## Column Naming Convention

| Layer | Pattern | Purpose | Modifiable |
|-------|---------|---------|------------|
| 1 — Raw | `*_am_hhmm_ampm` | Original AM/PM data | Never |
| 2 → 4 | `*_corrected` | Baseline normalized (step 4), then overwritten with post-correction value (step 6) | Replaced in place |
| 3 — Working | `*_manual` | Correction target during step 6 processing | **Only** modifiable column |

Layers 2 and 4 are the same physical column. Step 4 writes the auto-normalized timestamp; step 6 overwrites it if a manual correction was applied.

---

## Key Design Decisions

### Substance Detection: Input Structure, Not Behavior
The original system flagged records as `BEHAVIORAL` when values exceeded thresholds (caffeine>4, alcohol>3, nicotine>=1). These 10 records were false positives — high values reflecting real participant variability.

The current system detects only **input-entry structural anomalies**:
- Non-numeric text (e.g., "Had three black coffees" → auto-fixed to 3)
- Negative values
- Filler codes (888, 999, 777)
- Excessive value (≥100) — too many for a single-day self-report
- Repeated digits (111, 222) — unlikely genuine values
- Suspicious decimal precision (≥2 decimal places)

These are flagged as `AMOUNT_FLAG` and recorded in `substance_decimal_anomalies` (accessible via `View(substance_decimal_anomalies)` in R Studio). Only the text entry case is auto-corrected; all others are flagged for manual review.

### Part B: Import, Don't Recompute
Step 8 Part B originally re-ran `difftime()` calculations already done in steps 5-6. It was replaced with a 6-line import that reads the existing `error_type` / `unusual_type` columns. Temporal label format uses `[Temporal] Error: <type>` and `[Temporal] Unusual: <type>` to support Figure 16's regex pattern matching.

### Exercise/Nap/Substance Exclusions
`*_checkforerrors` columns for exercise format, nap duration, and substance timestamps are excluded from auto-detection. They produce ~81% false positives without affecting core sleep metrics (SOL, TST, SE, WASO).

---

## File Index

| File | Lines | Role |
|------|-------|------|
| `00_MAIN_entry.R` | 141 | Pipeline orchestrator — single entry point, per-step log_step calls |
| `process_timestamp_emadatarelease_cyra.R` | 168 | Step 2 — Timestamp → POSIXct |
| `process_interval.R` | 284 | Step 3 — Duration string → minutes |
| `normalize_sleep_time_sequence.R` | 198 | Step 4 — Sequence auto-correction |
| `generate_correction_files.R` | 574 | Step 5 — Classification → review CSVs |
| `error_unusual_sleep_time_corrections.R` | 2078 | Step 6 — Correction engine (core) |
| `calculate_sleep_time_end.R` | 139 | Step 7 — Sleep metrics calculation |
| `checkforerrors_processing.R` | 612 | Step 8 — Auto error detection + substance anomaly |
| `sleep_visualization.R` | 2540 | Step 9 — 30 diagnostic figures (14 QC + 16 research) |
| `report_correction_status.R` | 494 | Checkpoint reporter + log_step() per-step slicer (30-dim metrics → step_log.csv) |
| `R/pipeline.R` | 150 | Package entry points: run_pipeline, run_visualization, run_figure_index, etc. |
| `R/config.R` | 128 | Config loader: load_config, config_get, adapt_columns, validate_columns |
| `make_figure_index.R` | 124 | Contact-sheet generator (30-figure thumbnail index) |
| `README_figures_navigation.md` | 57 | Figure navigation: 3-tier triage guide |

---

## Reproducibility

### Requirements
```r
install.packages(c("lubridate", "tidyverse", "stringi", "stringr", "readr",
                   "ggplot2", "patchwork", "scales", "RColorBrewer", "gridExtra"))
```
Note: `checkforerrors_processing.R` has no `library()` calls — it relies on packages loaded by earlier steps. Always run via `00_MAIN_entry.R`, never standalone.

### Dual Script Copies (Root vs inst/scripts/)
Pipeline scripts exist in two physical locations — this is by design, not debt:
- `run_pipeline()` → `system.file("scripts")` → the `inst/scripts/` copy
- `source("00_MAIN_entry.R")` → `getwd()` → the repo-root copy

Both copies must be kept byte-identical by hand; `test-script-copies-in-sync.R` fails if they drift. On 2026-08-05 five scripts (apply_metric_review_acceptances, apply_nap_exercise_corrections, apply_second_review, apply_sleep_metric_duration_corrections, calculate_sleep_time_end) diverged — inst/scripts read paths via cfg_get() while root hardcoded filenames; default config hid the divergence until `data.files.*` was overridden. Commit 80c7e657. When refactoring, edit both copies and re-run the sync test.

### Data Sources
- `<deidentified_ema_vars>.rds` — pre-processed EMA variables from the survey platform (study-specific deidentified export; real filename differs per study)
- `<sber_ema_export>.csv` — raw survey responses (provides StartDate, num_waso, num_waso_estimate_am)

The merge in step 1 uses row-order alignment (`df$StartDate <- full_df$StartDate`), not a keyed join. The CSV row order must exactly match the RDS. This is fragile — if the CSV is regenerated with different sorting, the merge silently corrupts.

### Human Review Guide
Step 5 generates two CSV templates. The human reviewer populates them and renames (removing `[NEW]` prefix) for step 6 to read.

#### `[NEW]manual_error_correction_review.csv`
| Column | How to fill |
|--------|-------------|
| `problem_humanidentified` | Describe the issue (free text). Optional but helpful. |
| `solution_humanidentified` | Solution as natural-language text. **CASE2 triggers on this** when column/value are empty. Valid patterns: `"Undo correction"`, `"Bed time AM/PM conversion"`, `"Get up AM/PM conversion"`, `"Awake time align to get up"`, `"Time_change: <column>=<value>"`, `"Plus 12 hours"`, `"Minus 12 hours"`, `"Switch"`. |
| `column_to_correct` / `correct_value` | Exact column name and replacement value. **CASE3 triggers on this** (takes priority over CASE2). Example: `time_bed_corrected` / `2026-01-15 22:30:00`. |
| `manually_corrected_mtb` / `agreement_cd_mtb` | Consensus flags. Set `manually_corrected_mtb=1` and `agreement_cd_mtb=1` for reviewed records. |
| `easiness` / `notes` | Optional: difficulty rating + notes. |

#### `[NEW]manual_unusual_review.csv`
Schema differs from the error CSV:
- `column_to_adjust` / `correction_value` (not `column_to_correct` / `correct_value`)
- `problem_humanidentified` — if the record is actually fine, write `"Reasonable unusual record"` (this exact phrase triggers the reasonable-unusual flag, which sets `is_unusual=FALSE` and `data_category="reasonable_unusual"`)
- `cd_mtb_Consenssus` (not `agreement_cd_mtb`)
- `tier_mtb`, `easiness`, `notes` — optional

#### First-Run Bootstrap (catch-22)
Step 5 generates the `[NEW]*.csv` review files. Step 6 immediately tries to read `manual_error_corrections.csv` / `manual_unusual_corrections.csv`. This means:
1. **First run:** Pipeline will fail at step 6 because the reviewed CSVs don't exist yet.
2. **Workaround:** Create empty placeholder CSVs before the first run:
   ```r
   write.csv(data.frame(), "manual_error_corrections.csv", row.names = FALSE)
   write.csv(data.frame(), "manual_unusual_corrections.csv", row.names = FALSE)
   ```
3. **After generation:** Review the `[NEW]*.csv` files, populate them, rename, re-run.

### Expected Output

**Typical flag distribution (N ≈ 14,000 records):**
```
TIMESTAMP_ISSUE=0   DURATION_ISSUE=0   AMOUNT_FLAG=2    (= 0.01%)
NEEDS_REVIEW=731    CLEAN=13,204       CLEAN(Manually Fixed)=53  (= 94.4%)
```

**Plausible sleep metric ranges to sanity-check figures:**
| Metric | Typical Median | Plausible Range |
|--------|---------------|-----------------|
| TST (total sleep time) | 7.2 hours | 3–12 hours |
| SOL (sleep onset latency) | 15–30 min | 0–120 min |
| Sleep efficiency | 85–95% | 40–100% |
| WASO per bout | 5–15 min | 0–60 min |

**Key figures for data quality check (inspect first):**
- **Figure 2:** Variable distributions should look roughly normal / bell-shaped within plausible ranges
- **Figure 4:** TST vs time-in-bed should cluster near the diagonal (most points within ±2 hours)
- **Figure 11:** Flag co-occurrence heatmap — total absence of flags in clean data is normal
- **Figure 13:** Error category bar should have only a small fraction of records flagged

### Error Recovery

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Error in readRDS` or `file not found` | Missing data files in working directory | Place the study's deidentified RDS and CSV export files in the working directory |
| `Error in read_csv("manual_error_corrections.csv")` | First run — reviewed CSV doesn't exist yet | Create empty placeholder CSVs (see First-Run Bootstrap above) |
| Figures 13-18 empty | `checkforerrors_processing.R` not run before visualization | Ensure pipeline runs sequentially; step 8 must precede step 9 |
| `object 'checkforerrors_processed' not found` | Running `sleep_visualization.R` standalone | Always run via `00_MAIN_entry.R`; the viz file is not self-contained |
| All records classified CLEAN when errors expected | Manual correction CSVs out of date | Check that `manual_error_corrections.csv` exists and has been populated for known problem records |
| CASE4 warnings in console | A correction instruction doesn't match any known case | Review the record manually; the record will remain uncorrected |

---

## Checkpoint System & Figure 12 (Pipeline Progress)

`report_correction_status.R` captures data state at five pipeline milestones:

| Checkpoint | Location | Description |
|---|---|---|
| **A** | After Step 4 | Post-normalization, pre-classification (no data_category yet) |
| **B** | After Step 6 | After timestamp corrections applied |
| **C** | After Step 6.5 | After nap/exercise duration corrections |
| **D** | After Step 7 | After sleep metrics computed (TST, SOL, WASO, SE) |
| **E** | After Step 8 | After auto-detection (final classification state) |

Each checkpoint logs `n_total, n_clean, n_error, n_unusual, n_equal_time, n_skipped, n_corrected, n_valid, tst_mean_h, sol_mean_min` to `output/correction_status.csv`. After all checkpoints, `final_summary()` compares B→E (skips A — no data_category yet), prints a delta table, saves to `output/correction_status_final.csv`.

**Figure 12** reads `output/correction_status.csv` and visualizes Clean/Error/Unusual/Equal Time/Corrected counts per checkpoint as a grouped bar chart (replaces the former flag_severity pie chart).

---

## Testing Coverage

Unit tests for critical data-transformation logic in `tests/testthat/` (12 files):

| Test file | Scenarios covered |
|---|---|
| `test-normalize.R` | Normal sequence, AM/PM getup/sleep error, minor order swap (< 3h), all-NA row, bed = getup, large-gap out-of-order |
| `test-interval.R` | Malformed colon formats ("00:000" → "00:00", "000:45" → "00:45") |
| `test-pipeline.R` | End-to-end smoke test on synthetic data, config loading, column adaptation |
| `test-script-copies-in-sync.R` | Root vs `inst/scripts/` copies byte-identical (KNOWN_DIVERGENT deliberately empty; guards against silent divergence — see 2026-08-05 incident) |
| others | One per R module (config, flags, figure steps, etc.) |

Run: `Rscript -e 'pkgload::load_all(quiet=TRUE); library(testthat); test_dir("tests/testthat", reporter="summary")'`

---

## Figure Summary

| Figure | Data Source | Content |
|--------|-------------|---------|
| 1 | corrected_ema_data | Data quality dashboard |
| 2 | corrected_ema_data | Sleep variable distributions |
| 3 | corrected_ema_data | TST distribution |
| 4 | corrected_ema_data | TST vs time-in-bed (color by category) |
| 4B | corrected_ema_data | SOL vs TST (color by category) |
| 5 | — | [REMOVED] Violin plots with free scales not comparable across units |
| 6 | corrected_ema_data | Clean vs flagged TST density |
| 7 | corrected_ema_data | Stacked histogram by category |
| 8 | corrected_ema_data | TST violin by category |
| 9 | corrected_ema_data | Bedtime/get-up circular plot |
| 10 | corrected_ema_data | Extreme TST with SE context |
| 11 | corrected_ema_data | Flag co-occurrence heatmap |
| 12 | correction_status.csv | Pipeline correction progress (table with per-step counts + deltas) |
| 13 | checkforerrors_processed | Error category bar + severity table |
| 14 | checkforerrors_processed | Auto-detect: clean vs flagged density |
| 15 | checkforerrors_processed | Error timeline |
| 16 | checkforerrors_processed | Common error patterns |
| 17 | checkforerrors_processed | Top-15 participants by flags |
| 18 | checkforerrors_processed | Auto-detection dashboard |
| 19 | checkforerrors_summary | Final quality status |
| 20 | corrected_ema_data | SOL perception bias (with WASO sub-panel 20B) |
| 21 | corrected_ema_data | Substance data availability |
| 22 | corrected_ema_data | Substance value distributions |
| 23 | corrected_ema_data | Caffeine consumption distribution |
| 24 | corrected_ema_data | Alcohol consumption distribution |
