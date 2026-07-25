# Pipeline Integration Work Log — 2026-05-18

## Objective
Consolidate and simplify the SPL sleep data-cleaning pipeline: eliminate redundancy, replace RED/YELLOW/BEHAVIORAL classification with data-type labels, remove duplicate code, shift substance value detection from behavioral thresholds to input-structure anomaly detection. Add comprehensive English annotations for non-programmer team members across the entire pipeline.

---

## Core Changes

### 1. Detection Philosophy Shift: Behavioral Thresholds → Input Structure Anomalies

**What was done**: Substance column (caffeine, alcohol, nicotine) anomaly detection switched from "value exceeds behavioral threshold" to "value has an input-structure problem."

**How it was implemented**:
- Removed `add_val_flag()` (hardcoded `caffeine>4 → BEHAVIORAL`, `alcohol>3 → BEHAVIORAL`, `nicotine>=1 → BEHAVIORAL`)
- Replaced with `detect_input_anomaly()`, detecting 6 purely structural issues: `non_numeric_entry` (text), `negative_value` (negatives), `filler_value` (888/999/777), `excessive_digits` (≥100), `repeated_digits` (111/222), `suspicious_decimal` (≥2 decimal places)
- Added `fix_substance_text()` to read raw CSV and auto-fix text entries via a word-to-number table (one→1 ... ten→10)
- Added `build_input_anomalies()` to read raw CSV and construct `substance_decimal_anomalies` reference table (flag-only, no modification except text)
- Used `assign(..., envir = .GlobalEnv)` to persist the table across the pipeline environment (visible in R Studio)

| Old System | New System |
|------------|------------|
| `caffeine>4, alcohol>3, nicotine>=1` flagged as "BEHAVIORAL" | Not flagged — high values are real variability, not errors |
| 11 flagged records (including 1 text) | 3 flagged records (structural anomalies only) |
| False positives: 10 threshold-based (normal highs mislabeled) | False positives: 0 — all are genuine input-structure problems |

### 2. `substance_decimal_anomalies` Final Result (3 Records Only)
| # | Type | Detail | Value Modified? |
|---|------|--------|:---:|
| 1 | `non_numeric_entry` | caffeine "Had three black coffees" → extracted three → 3 | ✅ Fixed |
| 2 | `possible_decimal_slip` | caffeine 0.3 (pid=90023) | ❌ Flagged only |
| 3 | `suspicious_decimal` | alcohol 1.25 (pid=90042) | ❌ Flagged only |

### 3. Old Behavioral Threshold Records: All Unflagged
Records previously flagged as BEHAVIORAL (caffeine=5×4, alcohol=4-6×4, nicotine=2/3×2) are now CLEAN. These values remain in the data — they are no longer treated as anomalies.

### 4. Classification Rename + Part B Replacement

**What was done**:
- Labels: `SERIOUS_RED_LINE` → `TIMESTAMP_ISSUE`, `UNUSUAL_VALUE` → `DURATION_ISSUE`, `BEHAVIORAL` → `AMOUNT_FLAG`, new `NEEDS_REVIEW`
- Part B entirely removed and rewritten

**How it was implemented**:
- Part B originally re-ran `difftime()` to recompute bed→sleep and sleep→awake differences for temporal error detection
- Replaced with direct import from `corrected_ema_data`'s existing `error_type`/`unusual_type` columns — 6 lines replacing ~65
- Label format: `[Temporal] Error: order_error` and `[Temporal] Unusual: sleep_awake_suspicious` to match Figure 16's regex
- `checkforerrors_processing.R` Assertion Report title: "REVIEW NECESSITY REPORT" → "FLAG DISTRIBUTION REPORT"
- `sleep_visualization.R` Figures 13/19/23-24 labels and color mappings updated in sync

### 5. Code Duplication Removal

**What was done**:
- `error_unusual_sleep_time_corrections.R`: Deleted L1255-1283 duplicate block; merged two swap functions
- `sleep_visualization.R`: Renamed function to avoid confusion
- `00_MAIN_entry.R`: `source()` calls moved into pipeline unified environment

**How it was implemented**:
- Deleted block (L1255-1283) was an exact copy of L1232-1253's `column_to_adjust_2` handler, differing only in using inline `switch()` instead of `corrected_to_manual_col()`
- `process_swap_operations_case3` + `process_swap_operations` merged into single `process_swap_operations(data, row_idx, solution_text, pattern_set = "case3"/"case2")`
- `sleep_visualization.R`'s `calculate_sleep_time_vars` (local classification subset helper) renamed to `apply_sleep_metrics` to avoid confusion with pipeline main function `calculate_sleep_time_vars_end`

### 6. Figures 21-24 Restructured

**What was done**: Removed all threshold lines and "behavioral" annotations, replaced with purely descriptive statistics.

**How it was implemented**:
- Figure 21: Changed from "flagged vs clean grouping" to data-availability bar chart (showing response rate per substance)
- Figures 23-24: Removed dashed threshold lines, red fill, behavioral-annotation text; single-color histograms with range/median subtitles

### 7. Full Pipeline English Annotations (8 Files)

**What was done**: Added English annotations to every file for non-programmer team members, explaining data flow, purpose, and output of each step.

**How it was implemented**:
| File | Annotation Focus |
|------|-----------------|
| `00_MAIN_entry.R` | Per-step data flow `INPUT→OUTPUT→WHAT`, pipeline overview |
| `process_timestamp_*.R` | AM/PM parsing heuristics, `*_checkforerrors` column meanings |
| `process_interval.R` | 3 format branches (colon/no-colon/bad colon), guessing strategy |
| `normalize_sleep_time_sequence.R` | Decision tree logic, ≥12h AM/PM adjustment, 3h threshold rationale |
| `generate_correction_files.R` | Meaning and trigger conditions for each classification category |
| `calculate_sleep_time_end.R` | Plain-language definitions of SOL/TST/SE |
| `checkforerrors_processing.R` | Part A/B/C three-channel detection, input anomaly classification |
| `sleep_visualization.R` | Per-figure `WHAT THIS FIGURE SHOWS / INTERPRETATION` |

---

## Final Verification
- Flag Distribution: `TIMESTAMP_ISSUE=0, DURATION_ISSUE=0, AMOUNT_FLAG=2, NEEDS_REVIEW=731, CLEAN=13,204, CLEAN(Manually Fixed)=53`
- `substance_decimal_anomalies` global table visible ✅
- Figure 16 pattern matching: 32 "Unusual sleep pattern" rows correctly displayed ✅
- All 8 files pass R `parse()` ✅
- Pipeline completes, all 24 figures generated ✅

## Not Done (User Decision Pending)
- `error_unusual_sleep_time_corrections.R`: 725-line Chinese doc header preserved (no additional annotations)
- Word-to-number expansion (e.g., twenty→20) not added — currently only one text record exists and is already fixed

---

## 2026-05-19 Follow-up Work

### 1. ARCHITECTURE.md Significant Expansion

- **Pipeline Flow** completed: each step now annotated with intermediate dataframe names (`df → ema_data_release_timeproc → ema_data_release_timecalc → corrected_ema_data`)
- **Human Review Guide**: full column documentation for both manual review CSVs (column-by-column fill instructions, CASE2/CASE3 trigger conditions, reasonable_unusual keyword)
- **Expected Output**: typical flag distribution percentages, plausible sleep metric ranges table (TST / SOL / SE / WASO), key figure sanity-check checklist
- **Error Recovery Table**: 7 common failure modes and their fixes
- **First-Run Bootstrap**: catch-22 (step 5 generates CSVs → step 6 immediately reads them) with placeholder CSV workaround
- **Requirements**: explicit list of 10 R packages and `checkforerrors_processing.R` transitive dependency warning
- **Data Sources Fragility**: step 1 merge uses row-order alignment (not keyed join) — CSV row order must exactly match RDS

### 2. 3 Subagent Review Rounds + 6+ Issues Fixed

| Issue | Severity | Fix |
|-------|----------|-----|
| Intermediate dataframes unnamed | HIGH | Added output names for each step in pipeline flow |
| Step 8 output relationships unclear | MEDIUM | Documented checkforerrors_summary / substance_decimal_anomalies |
| Part C used "etc." in examples | MEDIUM | Listed all specific checks (SOL<0, SE<0, SE>100%, TST/TIB=0, TST/TIB>1) |
| Missing dependency list | MEDIUM | Added Requirements with full package list |
| Data source merge fragility undocumented | MEDIUM | Noted row-order alignment risk |
| "digit length" terminology | LOW | → "Excessive value (≥100)" |
| Missing Human Review Guide / Error Recovery | HIGH | Fully added |
| Duplicate Requirements block | LOW | Removed duplicate from top of document |

### 3. CASE4 CSV Fix

`manual_error_corrections.csv` row for pid=90027 day=8 had the correction text `"Set time_awake equal to time_getup"` incorrectly placed in the `correct_value` column (col 24) instead of `solution_humanidentified` (col 22). This caused the CASE2 handler to miss it, falling through to CASE4 (unprocessable — skipped). Moved to `solution_humanidentified` so CASE2 can now trigger and execute the Awake time align to get up operation.
