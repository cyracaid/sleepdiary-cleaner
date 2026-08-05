# Work Log — 2026-08-05

**Project:** splsleep (Sleep EMA Diary Data Cleaning Pipeline)

---

## Meeting Notes

### Core Goal: Make the Cleaning Pipeline Understandable & Reusable by Others

> The pipeline itself is functional (v1.2.0). Work going forward focuses on **"Methods section writable, reviewer-comprehensible, third-party reusable."** No new pipeline features — only explainability and deliverability.

---

### 1. Current Pipeline Status

| Metric | Value |
|--------|-------|
| Total Records | 13,990 |
| Clean | 1,908 |
| Error | 7 |
| Unusual | 31 |
| Equal Time | 902 |
| Skipped NA | 11,142 |
| Manual Corrections | 81 (Step 6: 71 + Step 6.5: 10) |
| Mean TST | 7.71h ± 1.27 |
| Mean SOL | 28.8min ± 36.4 |
| flag_severity Minor (1 flag) | 318 |
| flag_severity Major (2+ flags) | 9 |

**Problem:** These numbers are currently unclear in the figures. Pipeline categories (algorithmic correction vs. manual correction vs. reviewed-but-unchanged) are muddled in Figure 1 and unusable for writing the Methods:

> "We need to be able to say: out of X total records, how many were algorithmically corrected, how many were manually corrected, how many auto-detected errors were removed, how many were reviewed but not changed, how many were untouched."

---

### 2. Figure Overhaul — Two Figure Sets

#### Figure Set 1: Pipeline Overview (Flow Diagram)

**Current:** Figure 1 uses `geom_tile` with fixed coordinates + manual arrows — not a true flow diagram. Branch arrows don't align properly.

**Goal:** A left-to-right standard flow diagram. Reviewers should understand the entire pipeline without reading code.

**Required Categories (show count and % of raw total):**

| Category | Meaning | Color |
|----------|---------|:--:|
| Raw records | Total input records | — |
| Auto-detected errors removed | Irreparable errors removed from analysis | 🔴 Red |
| Algorithmically corrected | Auto-fixed by algorithm (AM/PM flip, time swap, etc.) | 🟠 Orange |
| Manually corrected | Human corrected via manual CSV input | 🔵 Blue |
| Reviewed, unchanged | Review file generated, human reviewed, decided no change | 🩶 Gray |
| No issues / clean | Never flagged, passed clean through | 🟢 Green |
| Final analysis dataset | Records entering final analysis | — |

> **Key distinctions:**
> - "Auto-detected errors removed" = data detected as irreparable, removed from analysis
> - "Algorithmically corrected" = algorithm auto-fixed values (AM/PM flip, timestamp swap)
> - "Manually corrected" = human wrote corrections into manual CSV
> - "Reviewed, unchanged" = review file generated, human looked, decided no change needed

**Implementation:** DiagrammeR preferred; ggplot2 with precise coordinate layout as fallback.

#### Figure Set 2: Effect of Cleaning (Before/After)

**Purpose:** Visually demonstrate "what changed and by how much."

**Panel A — TST Distribution:**
- Before cleaning vs. after cleaning: boxplot / violin / density overlay
- Annotated with Median / Mean / SD

**Panel B — SOL Distribution:**
- Same design as Panel A

**Panel C — Per-record Changes:**
- Scatter plot: raw value → final value (identity line)
- Color by correction type (algorithmic / manual / unchanged)
- This panel proves that only corrected observations moved

**Summary Table:**

| Metric | Before | After | Δ |
|--------|--------|-------|-----|
| Mean TST | | | |
| SD TST | | | |
| Mean SOL | | | |
| SD SOL | | | |

---

### 3. Figure 18 Problem

**Current issue:** `07_Auto_Detected.png` (original Figure 18) is unclear — what does the "issue breakdown" actually show? Reviewers can't interpret it.

**Needed:** Break down by specific issue type (TIMESTAMP_ISSUE / DURATION_ISSUE / AMOUNT_FLAG / NEEDS_REVIEW / SELF-REPORTED_FLAG), with clear counts and explanations for each flag type.

---

### 4. data_category Column

**Decision:** The `data_category` column is not helpful to end users and should be removed from final output. It is an internal process label.

**Keep:** `flag_severity` (Minor / Major / Clean) — this is computed at Step 7 from SOL/SE/WASO thresholds and has explanatory value for the paper.

---

### 5. Output Column Name Cleanup (One of the Most Important Tasks This Week)

**Current problem:** The cleaned dataframe has hundreds of columns, most of which are intermediate process columns. Researchers receiving the data have no way to know which are "final conclusions" vs. "intermediate steps."

**Goal:** Final output (CSV/RDS) should contain only meaningful, reusable columns. Rest should be preserved but not as primary output.

**Core columns to retain:**

| Category | Column Pattern | Purpose |
|----------|---------------|---------|
| Raw timestamps | `*_am_hhmm_ampm` | Participant original input (AM/PM format for reference) |
| Parsed timestamps | `time_bed_*` / `time_sleep_*` / `time_awake_*` / `time_getup_*` | Parsed POSIXct time values |
| Duration mincalc | `*_mincalc` | Durations standardized to minutes (SOL/WASO/nap/exercise) |
| Corrected timestamps | `*_corrected` | Final timestamps after normalize + manual correction |
| Derived metrics | `self_diffcalc_*` | Step 7 sleep metrics (TST/SOL/SE/WASO) |
| Contract columns | `sleep_efficiency_pct` / `sol_h` / `waso_h` / `sleep_duration_h` | Step 7 output, used by downstream analysis |
| Correction flag | **NEW:** `has_correction` (TRUE/FALSE) | Whether any correction (algorithmic or manual) was applied |
| Correction type | **NEW:** `correction_type` | "none" / "algorithmic" / "manual" / "both" |
| Flag severity | `flag_severity` | Clean / Minor / Major |

**Principles:**
- **Don't delete columns** — raw process columns preserved but not in primary output; saved in a separate "full intermediate results" file
- **Dual-file output:**
  - `cleaned_data_final.csv/rds` — core analysis columns only (~20–30 columns)
  - `cleaned_data_full.csv/rds` — all columns (for traceability / debugging)
- Document each column's source and purpose in `SCHEMA.md`

---

### 6. Correction Traceability

**Requirement:** Anyone receiving the final data should be able to answer:
> "Was this record changed? Which field was changed? What was the original value?"

**Solution:** Two new columns:
- `has_correction`: BOOL — whether this record was modified by any correction step
- `correction_type`: enum — ("none" / "algorithmic" / "manual" / "both")

Combined with kept `*_corrected` and `*_hhmm_ampm` columns, users can trace original → final values.

---

### 7. This Week's Task List

| # | Task | Priority | Status |
|---|------|:--:|:--:|
| 1 | **Redo Figure 1**: True flow diagram (DiagrammeR), with all category counts + percentages | 🔴 Highest | ⬜ |
| 2 | **New Figure 2**: Before/after TST/SOL distributions + per-record scatter + summary table | 🔴 Highest | ⬜ |
| 3 | **Fix Figure 18**: Break down issue breakdown by flag type | 🔴 Highest | ⬜ |
| 4 | **Remove data_category column**: Drop from final output | 🟡 High | ⬜ |
| 5 | **Output column cleanup**: Define final column set → dual-file output (final + full) | 🟡 High | ⬜ |
| 6 | **Add correction traceability**: `has_correction` + `correction_type` columns | 🟡 High | ⬜ |
| 7 | **Update SCHEMA.md**: Document each column source + purpose + inter-column mapping | 🟢 Medium | ⬜ |

**Constraints:**
- Don't modify pipeline logic
- Don't modify existing functions
- Don't fabricate stats (reuse existing outputs where possible)
- All percentages use raw data total as denominator
- "Show data at next meeting" — ready to present new figures and numbers

---

## 8. NULL Problem Investigation (Executed 2026-08-05)

Audited all 9 pipeline scripts for NULL-related issues. Found **13 items**, 5 need fixing:

### Must Fix

| # | File | Line | Issue | Severity |
|---|------|------|-------|:--:|
| 1 | `sleep_visualization.R` | 115 | `sleep_duration_h = NA` classified as "Normal range" by `flag_duration_extreme` | 🔴 Wrong output |
| 2 | `calculate_sleep_time_end.R` | 158 | TST / TIB division by zero → `sleepefficiency_percent = Inf`, distorts plot axes | 🔴 Wrong output |
| 3 | `sleep_visualization.R` | 463 | `data_category = NA_character_` silently falls into "Other" (not triggered in normal run, lacks defense) | 🟡 Risk |
| 4 | `error_unusual_sleep_time_corrections.R` | 1089 | `ensure_marking_columns()` fills missing `data_category` with bare `NA` (logical), type mismatch | 🟡 Risk |
| 5 | `sleep_visualization.R` | 930 | Figure 8 `exists()` check missing `is.data.frame()` guard | 🟡 Risk |

> **Bug 1 plain English:** You're labeling each record: "Sleep < 3h → 'too short', > 12h → 'too long', otherwise → 'normal'." Then you hit a blank record — the person left it empty. The old code asks "is blank < 3?" — can't answer. "Is blank > 12?" — can't answer. Since neither matched, it says "normal." **Blank got labeled normal. Wrong.** Fix: first ask "is it blank?" — yes → "Missing." Done.
>
> **Bug 2 plain English:** Sleep efficiency = total sleep time ÷ try-sleep duration. Some records have try-sleep = 0 minutes (awake time equals sleep time). 120 ÷ 0 = Inf (infinity). Infinity runs into ggplot and blows up the axis — figure is dead. Fix: check denominator first — if 0 or less, set NA; don't divide.

### Low Priority (No Fix Needed)

| # | Issue | Reason |
|---|-------|--------|
| `checkforerrors_processed <- data.frame()` empty | Downstream `nrow > 0` guard handles it |
| `raw_csv_data <- NULL` when file missing | `is.null()` guard correctly handles |
| `find_duration_columns()` returns NULL | All callers correctly guard |
| `needs_manual_check = NA` bare logical | Extremely low risk |

### Risk Conclusion

Current pipeline in normal execution does **not** trigger these errors (Step 4 → Step 6 → Step 9 sequential flow). Risk is in:
- Someone skipping Step 6 in future
- Division by zero in edge-case data
- Someone calling visualization directly without running `recalculate_and_mark_errors()`

---

## 9. Meeting Notes — Missed Items (After Line-by-Line Review)

| # | Missed Item | Supplement |
|---|-------------|------------|
| 1 | **NULL problem** | See §8, investigated, 5 items to fix |
| 2 | **"WE WANT THE DECISION OURSELVES"** | Column list to be human-reviewed and approved. No automated cutting. Approach: generate all columns + classification proposal, you confirm keep/remove |
| 3 | **Column MAP** | Separate output: `column_map.csv` tracking: raw column → process column → final column, so users can trace "where did this value come from" |
| 4 | **Task ordering** | Notes said "take the steps first in column name regulation" — column cleanup should precede or parallel Figures. Clean column names first, then clean figures. Adjusted below |
| 5 | **"DONT DELETED ARBITURARILY"** | Strengthened to iron rule: never delete original columns, only select a subset in a new file. Full version MUST always exist |
| 6 | **"other people can use it to do science"** | Use this as validation criterion for every change |

---

## 10. Revised Weekly Task List (Reordered per Original Notes Intent)

| # | Task | Priority | Depends On |
|---|------|:--:|------|
| 1 | **NULL fixes (2 items)**: NA→Normal range + Inf division by zero | 🔴 Highest | — |
| 2 | **Column cleanup**: List all output columns → classify → human-approved keep list → dual-file output (final + full) + column_map.csv | 🔴 Highest | — |
| 3 | **Add traceability columns**: `has_correction` + `correction_type` | 🔴 Highest | Column cleanup done |
| 4 | **Remove data_category**: Drop from final output | 🟡 High | During column cleanup |
| 5 | **Redo Figure 1**: DiagrammeR true flow diagram, all category counts + percentages | 🔴 Highest | Column cleanup + traceability done |
| 6 | **New Figure 2**: Before/after TST/SOL distributions + per-record scatter + summary table | 🔴 Highest | Column cleanup + traceability done |
| 7 | **Fix Figure 18**: Break down issue breakdown by flag type | 🟡 High | — |
| 8 | **SCHEMA.md + column_map.csv**: Column source/purpose/mapping docs | 🟢 Medium | Column cleanup done |
| 9 | **NULL defensive hardening**: 3 guards (data_category warning + is.data.frame + column init) | 🟢 Medium | — |

**Core Principles:**
1. Column name regulation FIRST
2. WE decide what to keep — no automated cutting
3. DON'T DELETE ARBITRARILY — full version always preserved
4. "other people can use it to do science" as the standard for every decision

---

## 11. Today's Execution Log

### Code Changes Made

| File | Change | Description |
|------|--------|-------------|
| `sleep_visualization.R:115` | Added `is.na(sleep_duration_h) ~ "Missing"` | Fixed NA sleep duration classified as "Normal range" |
| `calculate_sleep_time_end.R:158` | `ifelse(denominator > 0, TST/TIB, NA_real_)` | Fixed division by zero producing Inf |

### Review Output (Code NOT Modified)

| File | Description |
|------|-------------|
| `manual_inputs/column_review_2026-08-05.md` | Full column inventory + classification + 6 decision questions, awaiting review |

### Review Doc Structure

- **Sections A-I**: Final output candidate columns (35-40 cols) → approve/reject each
- **Sections J-O**: Full-only columns (not in final) → approve/reject each
- **Q1-Q6**: 6 naming/structure decisions → choose option

### Task Status Update

| # | Task | Status |
|---|------|:--:|
| 1 | NULL fixes (2 items) | ✅ Done |
| 2 | Column cleanup — column inventory | ✅ Review doc produced, awaiting approval |
| 3-9 | Remaining | ⬜ Blocked on column review |

### Two-Agent Debate Completed (2026-08-05)

Proponent vs Skeptic debated 3 key decisions:
- **A: `has_correction`** — Proponent argued boolean, Skeptic argued enum (preserves algorithmic/manual distinction)
- **B: Dual-file output** — Both agreed on `finalize_columns()`. Skeptic flagged whitelist staleness + column_map maintenance burden
- **C: Figure 1** — Skeptic killed DiagrammeR (system dependencies). Pointed out Figure 1 needs `summarise_pipeline()` counting function first

**Full arbitrator brief archived:** `manual_inputs/arbitrator_brief_2026-08-05.md` (complete context + both agent positions + 6 open decisions Q1-Q6 + constraints)

---

## Notes

- v1.3-s3 S3 architecture work is paused; focus on Figures + column cleanup first
- Detailed Figure design spec from reviewer is archived (see §Figure Overhaul)
- Color requirements: colorblind-friendly, semantically mapped (red=removed, orange=algo-corrected, blue=manual-corrected, gray=reviewed-no-change, green=clean)
- NULL audit complete: 13 findings, 5 need fixing (full report in session)

---

> 2026-08-05 | Next meeting focus: Present new Figures + clear category breakdown
