# Arbitrator Brief — splsleep v1.4 Implementation Plan

> You are the ARBITRATOR. Below is the full project state. Your job: review the two-agent debate, resolve the deadlocks, and produce a clear, ordered execution plan. Do NOT write code. Produce decisions with rationale.

---

## 1. Project Background

**splsleep** is an R pipeline that cleans longitudinal sleep diary EMA data (13,990 records, 9 sequential steps). GitHub: `cyracaid/sleepdiary-cleaner`. v1.2.0 is stable on main (0 ERROR, 0 WARNING, CI green).

Pipeline flow:
```
Step 1: Load RDS + CSV → merge
Step 2: Parse timestamps ("7:30 PM" → POSIXct)
Step 3: Parse intervals ("00:30", "90" → numeric minutes)
Step 4: Normalize sleep time sequence (AM/PM fix, time swap)
Step 5: Generate review CSV files for human review
Step 6: Apply manual corrections from reviewed CSVs
Step 7: Calculate sleep metrics (TST, SOL, SE, WASO)
Step 8: Auto-detect errors (substance anomalies, review flags)
Step 9: Generate 24 diagnostic figures
```

---

## 2. What's Been Done (Current State)

### v1.2.0 (tagged, stable)
- Full 9-step pipeline runs on 13,990 records
- R CMD CHECK: 0 ERROR, 0 WARNING
- 35 testthat tests passing
- GitHub Actions CI green
- Full R package structure (DESCRIPTION, NAMESPACE, renv.lock)
- `SCHEMA.md`, `THRESHOLDS.md`, bilingual README
- Figure 1-24 generated (Figure 1 is currently a geom_tile dashboard, not a true flow diagram)

### Recently fixed (not yet tagged)
- **NULL Bug 1** (`sleep_visualization.R:115`): `sleep_duration_h = NA` was classified as "Normal range" by `flag_duration_extreme`. Fixed by adding `is.na()` check first.
- **NULL Bug 2** (`calculate_sleep_time_end.R:158`): Division by zero (try-sleep = 0) produced `Inf` sleep efficiency, breaking plot axes. Fixed with `ifelse(denominator > 0, ..., NA_real_)`.

### Decision document produced (awaiting review)
- `manual_inputs/column_review_2026-08-05.md`: Full column inventory across all 9 pipeline steps. 137+ columns classified into 11 categories. Sections A-I propose ~35 columns for `cleaned_data_final`. 6 open questions (Q1-Q6) await user decisions.

### v1.3-s3 branch (PAUSED)
- S3 generic architecture + `run_cleaning_chain()` written but paused per meeting decision. Focus shifted to v1.4 deliverables.

### User's stated goal
> "other people can use it to do science" — the pipeline output must be understandable and usable by researchers who have never seen the code.

---

## 3. What v1.4 Must Achieve

Three questions the pipeline currently cannot answer:
1. "Which columns do I analyze?" — 100+ columns, no guide
2. "Was this record modified? How?" — must piece together 4 separate flag columns
3. "What happened at each pipeline step?" — Figure 1 is a geom_tile, not a flow diagram

**v1.4 minimum scope (4 items):**
1. Column cleanup → `cleaned_data_final` (~30 essential cols) + `cleaned_data_full` (all cols)
2. `has_correction` column → one glance to know if a record was touched
3. Figure 1 redesign → true flow diagram with per-step counts and percentages
4. `column_map.csv` + data dictionary → column-to-source mapping

---

## 4. Two-Agent Debate — Positions and Arguments

### Decision A: `has_correction` — Boolean vs Enum, and Where to Put It

**PROPONENT (position A3):**
- Place in `finalize_columns()` wrapper at pipeline end (after Step 8, before Step 9)
- Single boolean: `has_correction = corrected | manually_corrected`
- Rationale: one-liner, clean separation of correction logic from output formatting. Keeps Step 7 (pure metric computation) clean.

**SKEPTIC (counter):**
- Boolean is lossy: `corrected` (algorithmic fix, Step 4) and `manually_corrected` (human override, Step 6) are **orthogonal** dimensions. Boolean destroys the distinction — a researcher asking "how many were auto-corrected vs human-reviewed" loses the signal.
- Proposal: enum column: `"none"` / `"algorithmic"` / `"manual"` / `"both"`
- Also warns: if `has_correction` is placed in `finalize_columns()` but the column WHITELIST hardcodes ~30 columns, and the user wants to change the whitelist, they might accidentally drop `has_correction`. The function must self-check.
- Concern about partial pipeline runs: if someone runs only Steps 1-6 (for manual review iteration), they'd see `has_correction` but zero sleep metrics — giving a false sense of completeness.

**SKEPTIC also raises a naming concern:**
- `correction_type` already exists (Step 4) as a string describing WHAT algorithmic fix was applied ("sleep_reduce_12h_loop", "bed_sleep_swap_3h", etc.). Adding a new column that ALSO describes correction type creates naming confusion. The existing column tracks algorithmic fix *mechanism*, not the *fact* of correction.

---

### Decision B: Dual-File Output — How and When

**PROPONENT (position B1):**
- `finalize_columns()` wrapper function in `00_MAIN_entry.R`
- Hardcoded `essential_cols` vector → `cleaned_data_final`
- Full dataset → `cleaned_data_full`
- Write both CSVs to disk
- Insert between Steps 8 and 9 (so Step 9 visualization still has full data)

**SKEPTIC (counter):**
- Hardcoded whitelist WILL go stale. Pipeline creates columns in 8+ locations across 6+ source files. Adding one column mid-pipeline → whitelist silently drops it → downstream paper breaks.
- Proposes: whitelist + automatic gap detection. `setdiff(names(data), whitelist)` → if non-empty, WARN loudly. Don't fail the pipeline, but make the gap visible.
- `column_map.csv` has the same maintenance problem. Proposes: maintain a descriptions table (col name + description + source step), auto-generate the map at pipeline end, warn about unmapped columns.
- The magic number "30": the 30-column count leaves zero slack. Should be derived from actual usage, not a target. The column review doc (Sections A-I) proposes ~35 columns — should that be the baseline?
- No config infrastructure exists in this project (no YAML, no JSON schema). Adding config just for a whitelist is over-engineering.

---

### Decision C: Figure 1 — DiagrammeR vs ggplot2 vs grid

**PROPONENT (position C2 — ggplot2):**
- Geom_rect for stage boxes, geom_segment for arrows, geom_text for counts
- Zero new dependencies — everything already loaded (`ggplot2`, `dplyr`, `tidyr`)
- Inherits existing theme
- Provided a full code sketch for a vertical flow diagram

**SKEPTIC (counter — kills DiagrammeR):**
- DiagrammeR requires system-level dependencies: V8 (JavaScript engine via libv8), Graphviz (`libgv`), librsvg2. This project has zero system dependencies currently. A new lab member cloning the repo would spend 2+ hours on environment setup.
- No `renv.lock` (verified), no Dockerfile, no CI `SystemRequirements` field.
- DiagrammeR PNG export chain is fragile.

**SKEPTIC (also attacks ggplot2 approach on a foundational issue):**
- A true flow diagram requires per-step row counts: "how many records were at Step 2? How many were corrected at Step 4? How many were manually fixed at Step 6?"
- These counts do NOT currently exist. The pipeline tracks internal state but doesn't export step-level record counts.
- To build a flow diagram, you'd need a `summarise_pipeline()` function that counts records at each decision point. This IS achievable without modifying pipeline logic — it reads the final dataframe's flag columns.
- The Vertex: BOTH approaches (DiagrammeR and ggplot2) need this count infrastructure first. Without it, the diagram is arbitrary.

**SKEPTIC raises a target question:**
- What's the rendering target? PNG for paper? Interactive HTML? Both have different requirements.
- If counts are for README, a markdown table is simpler than any visualization library.

---

## 5. Additional Issues the Skeptic Raised (not disputed by Proponent)

### 5.1 `correction_type` naming collision
- Step 4 already has `correction_type` (algorithmic fix mechanism string: "sleep_reduce_12h_loop", etc.)
- Adding a new column also about correction creates ambiguity
- Suggestion: new column should be called something else — e.g., `correction_source`, `record_status`, or `modification_type`

### 5.2 Column whitelist maintenance
- 6+ source files, 8+ column creation locations, ~50 columns across steps
- Any change mid-pipeline can add a column silently
- Automatic gap detection is the minimum viable safeguard

### 5.3 `column_map.csv` must be auto-generated
- Manual maintenance = guaranteed staleness
- Approach: maintain descriptions table once, auto-generate map at pipeline end, warn unmapped

### 5.4 Figure 1 depends on a counting function that doesn't exist
- `summarise_pipeline()` must precede Figure 1 implementation
- This function reads `corrected_ema_data` columns (`data_category`, `corrected`, `manually_corrected`, `is_error`, `is_unusual`) and produces per-decision-point counts
- Does NOT require modifying pipeline steps — all information is already in the final dataframe

---

## 6. Open User Decisions (from column_review_2026-08-05.md)

These 6 questions are awaiting the user's input. The arbitrator should weigh in on each:

| Q# | Question | Options |
|----|----------|---------|
| Q1 | `self_diffcalc_sleepefficiency_percent` is named "percent" but stores 0-1 fraction. Rename? | A: Rename to `_fraction` / B: Keep, document |
| Q2 | `data_category` removed from final. What replaces it? | A: Nothing, use existing booleans / B: Rename to `record_status` / C: New `record_status` column |
| Q3 | viz-layer flag columns (`flag_severity`, `flag_duration_extreme`, etc.) — promote to final? | A: Only `flag_severity` / B: All / C: None (stay in full) |
| Q4 | Column names are very long. Shorten? (`self_diffcalc_totalsleeptime_minutes` → `tst_minutes`) | A: Keep / B: Short in final, long in full / C: All short |
| Q5 | `has_correction` — new unified column vs keep existing separate columns? | A: New + keep old / B: New, drop old / C: Don't add new |
| Q6 | Hundreds of passive EMA columns (mood, stress, context…) from source RDS | A: Keep all in full / B: Only confirmed-useful |

---

## 7. Your Task as Arbitrator

Read the two-agent debate (Section 4), consider the open user questions (Section 6), and produce:

### 7.1 Resolution for each decision

| Decision | Your Verdict | Rationale |
|----------|-------------|-----------|
| A: `has_correction` — boolean or enum? | | |
| A: `has_correction` — where to place it? | | |
| B: Dual-file output — how to implement? | | |
| B: Column whitelist — how to prevent staleness? | | |
| B: column_map.csv — how to maintain? | | |
| C: Figure 1 — which library? | | |
| C: Figure 1 — what prerequisite work is needed? | | |

### 7.2 Ruling on open user questions (Q1-Q6)

For each Q, pick the option you recommend and explain why.

### 7.3 Ordered execution plan

List the exact steps, in order, that should be executed to reach v1.4. Each step should have:
- What it produces
- What it depends on
- Estimated complexity (trivial / small / medium)
- Whether it can be done in parallel with other steps

### 7.4 Risks and mitigations

What could go wrong with this plan? What guardrails should exist?

---

## Constraints (non-negotiable)

1. Do NOT modify existing pipeline logic (the 9-step functions)
2. Do NOT delete columns arbitrarily — full version always preserved
3. Column selection decisions are ultimately the user's — provide recommendations, not commands
4. Zero new system-level dependencies (no Graphviz, no V8, etc.)
5. "other people can use it to do science" is the standard for every decision
6. The user has a meeting coming up where they need to show new figures and clear counts
