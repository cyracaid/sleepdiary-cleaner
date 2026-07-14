# Sleep EMA Data Cleaning Pipeline — Architecture

## Overview
Raw EMA sleep diary data → timestamp parsing → error detection → manual corrections (CSV) → sleep metric calculation → auto-flagging → diagnostic figures. All human review decisions are stored in CSVs that the pipeline reads at the appropriate step.

## Pipeline Steps

### Prerequisites
- R ≥ 4.2 with required packages (see `DESCRIPTION`)
- Raw EMA data files (RDS + CSV format)

### Quick Start
```r
# Install the pipeline package
install.packages("splsleep_1.0.0.tar.gz", repos = NULL)

# Load and run (uses built-in default configuration)
library(splsleep)
run_pipeline()
```

### Adapting to a New Dataset
The pipeline is fully configurable via a YAML configuration file:

```r
# Step 1: Generate a configuration template
library(splsleep)
file.copy(system.file("config_default.yaml", package = "splsleep"),
          "my_study_config.yaml")

# Step 2: Edit my_study_config.yaml
#   - column_mapping:      map your dataset's column names to pipeline variables
#   - classification:      adjust thresholds (SOL, SE, TST/TIB, flag severity)
#   - timestamp.format:    specify your time format (AM/PM, 24h, etc.)

# Step 3: Run with your configuration
run_pipeline(config = "my_study_config.yaml")
```

### Shell Entry Point
```bash
bash run.sh
```

### Step 1: Load Data
- **Script**: `00_MAIN_entry.R` (inline)
- **Input**: `deidentified_intervalvars_forCD_111325.rds`, `sber_ema_anon_20260227.csv`
- **Output**: `df` (merged, with StartDate, num_waso_am, num_waso_estimate_am)

### Step 1.5: Cross-Participant Field-Misentry Check
- **Script**: `cross_participant_field_misentry_check.R`
- **Output**: `cross_participant_field_misentries.csv`
- **What**: Detects SOL/WASO values that exactly match timestamps from other fields (wrong-field entries)

### Step 2: Process Timestamps
- **Script**: `process_timestamp_emadatarelease_cyra.R`
- **Input**: Raw timestamp strings (e.g., "7:30 PM")
- **Output**: `ema_data_release_timeproc` with parsed POSIXct columns + `_checkforerrors` flags
- **What**: AM/PM detection, 12/24h formats, missing separators

### Step 3: Process Interval Durations
- **Script**: `process_interval.R`
- **Input**: Duration strings (e.g., "00:30", "90", ".5")
- **Output**: Numeric minutes for SOL, WASO, nap, exercise (Light/Moderate/Vigorous/Strength)
- **What**: Parses HH:MM, decimal hours, MM:SS. Creates `_checkforerrors` flags for suspicious formats

### Step 4: Normalize Sleep Time Sequence
- **Script**: `normalize_sleep_time_sequence.R`
- **Input**: Parsed timestamps (may have AM/PM errors, order swaps)
- **Output**: `ema_data_release_timecalc` with corrected timestamps + `is_priority_adjusted`, `minor_order_error`
- **What**: Decision-tree fixes for AM/PM confusion, minor order errors, midnight wraparound

### Step 5: Classify Records & Generate Review Files
- **Script**: `generate_correction_files.R`
- **Input**: Normalized timestamps + durations
- **Output**: Error/unusual/equal-time classifications; review CSVs for human annotators
- **What**: Compares bed→sleep→awake→getup differences against thresholds. Generates `[NEW]manual_error_correction_review.csv` for human review

### Step 5.5: Human manual review
Review output CSVs from previous step, make corrections or determine whether to keep flagged data

### Step 5.75: Apply Second-Review Consensus
- **Script**: `apply_second_review.R`
- **Input**: `second_review_checklist.csv` (13 rows, all `consensus_reached`)
- **Output**: Appends to `manual_metric_review_acceptances.csv` (anti-join idempotent); verifies manual_error_corrections.csv and manual_nap_exercise_corrections.csv entries exist
- **What**: Write-only step. Dispatches each checklist row to the appropriate CSV based on `target_csv`. Placed between Step 5 and Step 6 so corrections routed to `manual_error_corrections.csv` take effect in the same run.

### Step 6: Apply Manual Corrections & Recalculate
- **Script**: `error_unusual_sleep_time_corrections.R` (function: `apply_manual_corrections_and_recalculate`)
- **Input CSVs**:
  - `manual_error_corrections.csv` — sleep timestamp corrections (order errors, AM/PM fixes)
  - `manual_unusual_corrections.csv` — accepted unusual patterns (insomnia, delayed phase)
- **Output**: `corrected_ema_data` (timestamps fixed, metrics recalculated, error/unusual flags set)
- **What**: Reads human decisions, applies timestamp replacements/swaps, recalculates all time differences, re-classifies corrected records

### Step 6.5: Apply Manual Duration Corrections
- **Scripts** (3 sub-steps):
  1. `apply_nap_exercise_corrections.R` — nap/exercise numeric duration corrections
  2. `apply_sleep_metric_duration_corrections.R` — SOL/WASO metric corrections (MM:SS vs HH:MM)
  3. `apply_metric_review_acceptances.R` — marks rows as human-accepted to suppress future flags
- **Input CSVs**:
  - `manual_nap_exercise_corrections.csv`
  - `manual_sleep_metric_duration_corrections.csv`
  - `manual_metric_review_acceptances.csv`
- **Output**: `corrected_ema_data` with corrected _mincalc values + `human_metric_review_status` set

### Step 7: Calculate Derived Sleep Variables
- **Script**: `calculate_sleep_time_end.R` (function: `calculate_sleep_time_vars_end`)
- **Output**: `corrected_ema_data` + columns: SOL (min), TST (min), TIB (min), SE (%), sleep_onset_timestamp, waso_bout_avg
- **What**: Computes actual sleep metrics used in analysis. Self-diffcalc audit trail

### Step 8: Auto-Detect Remaining Errors
- **Script**: `checkforerrors_processing.R`
- **Parts**:
  - **A**: Collects existing `_checkforerrors` flags from timestamp parsing (steps 2-3)
  - **B**: Imports temporal error_type/unusual_type from step 6
  - **C**: Validates computed sleep metrics (SOL, SE, TST/TIB ratio) against thresholds
  - **C2**: **Suppresses flags for human-accepted rows** (reads `human_metric_review_status` + `manual_metric_review_acceptances.csv`)
  - **D**: Creates `checkforerrors_df` (all remaining flagged records for review)
- **Output**: `checkforerrors_df` (auto-detected issues after human acceptances applied); substance-use anomaly flags
- **Three-level classification**: TIMESTAMP_ISSUE / DURATION_ISSUE / AMOUNT_FLAG / SELF_REPORTED_FLAG / CLEAN

### Step 8.5: Cross-Participant Global Consistency Check
- **Script**: `cross_participant_global_check.R`
- **Output**: `cross_participant_flagged_rows.csv`, `cross_participant_suspicious_slices.csv`
- **What**: Computes per-participant baselines (median + MAD). Flags days where SOL/WASO/exercise deviates ≥5 MAD from own norm

### Step 8.75: Human manual review
Review: `checkforerrors_df`, `cross_participant_flagged_rows.csv`, `cross_participant_suspicious_slices.csv`
Review output CSVs from previous step, make corrections or determine whether to keep flagged data

### Rerun steps 5 through 8 (skipping manual review) to incorporate all manual review into final algorithm checking

### Step 9: Generate Figures
- **Script**: `sleep_visualization.R`
- **Output**: 27 PNG figures in `latest_visualization/`
  - **pipeline_cleaning/** (9 figs): Pipeline progress & QC (e.g., Data Quality Dashboard, Flag Composition, Pipeline Progress, Per-Participant Flag Rate)
  - **research_ready/** (15 figs): Sleep analysis figures (e.g., Sleep Variable Distributions, Perception Bias, Substance Use, Sleep Regularity, Sleep Composition, Correlation Matrix)
- **Note**: Excluding auto-detection figures (13-18) when no issues are found

### After running pipeline
Examine visualizations in `latest_visualization/` (master directory) or organized into `pipeline_cleaning/` and `research_ready/` subfolders.

## Classification Systems

### data_category (Step 5 — temporal classification)
- `clean` — no temporal issues detected
- `error` — temporal ordering impossible to auto-fix (e.g., getup before bed)
- `unusual` — plausible but unusual pattern
- `equal_time_ok` — bed == getup (auto-accepted)
- `skipped_na` — no sleep data recorded
- `reasonable_unusual` — unusual but within acceptable bounds

### flag_severity (Step 7 — computed metric flags)
- **Clean** — 0 flags
- **Minor issues (1 flag)** — exactly 1 flag from {SE < 70%, SOL > 1h, WASO > 1.5h}
- **Major issues (2+ flags)** — 2+ of the same flags

### checkforerrors_summary (Step 8 — auto-detection)
- `TIMESTAMP_ISSUE` — clock-time format errors
- `DURATION_ISSUE` — interval/format errors
- `AMOUNT_FLAG` — substance input anomalies
- `SELF_REPORTED_FLAG` — self-reported SOL/WASO metric anomalies (not data errors)
- `CLEAN` — no issues
- `CLEAN (Manually Fixed)` — had issues, corrected in Step 6

## Manual Input CSV Files

| File | Step Read | Purpose |
|------|-----------|---------|
| `manual_error_corrections.csv` | 6 | Sleep timestamp corrections (order, AM/PM) |
| `manual_unusual_corrections.csv` | 6 | Accepted unusual patterns |
| `manual_nap_exercise_corrections.csv` | 6.5 | Nap/exercise duration corrections |
| `manual_sleep_metric_duration_corrections.csv` | 6.5 | SOL/WASO MM:SS→min corrections |
| `manual_metric_review_acceptances.csv` | 6.5/8 | Human-accepted metric flags |
| `second_review_checklist.csv` | 5.75 | Second-person verification of 13 single-annotator decisions |

## Output Files

| Path | Contents |
|------|----------|
| `output/correction_status.csv` | Run history of checkpoint snapshots (A through E) |
| `output/correction_status_final.csv` | Cross-checkpoint comparison (start vs end per run) |
| `output/flagged_records_self_reported.csv` | Records flagged as SELF_REPORTED_FLAG with details |
| `latest_visualization/` | All PNGs from latest run |
| `latest_visualization/pipeline_cleaning/` | Pipeline progress & quality control figures |
| `latest_visualization/research_ready/` | Sleep metrics, perception bias, substance use |

## Data Flow
```
RDS + CSV ──→ Step 1 ──→ Step 2 ──→ Step 3 ──→ Step 4 ──→ Step 5 (review CSVs)
                                                              ↓
                                   manual_error_corrections.csv
                                   manual_unusual_corrections.csv
                                   second_review_checklist.csv
                                                              ↓
                              Step 5.75 ──→ manual_metric_review_acceptances.csv (append)
                                                              ↓
                              Step 6 ──→ Step 6.5 ──→ Step 7 ──→ Step 8 ──→ Step 8.5 ──→ Step 9
                                           ↑                        ↑
                              nap_exercise_corrections    manual_metric_review_acceptances
                              sleep_metric_corrections    human_metric_review_status
```

## R Package

The pipeline is packaged as an R package (`splsleep`):
- **Install**: `devtools::install(".", dependencies = TRUE)` or from tarball
- **Run**: `library(splsleep); run_pipeline()`
- **Lockfile**: `renv.lock` — `renv::restore()` to reproduce R environment
- **Entry script**: `run.sh` auto-installs the package then calls `run_pipeline()`

## Key Code Fixes (2026-06-23)
1. `checkforerrors_processing.R` Part C2: now **always reads** `manual_metric_review_acceptances.csv` (previously skipped when Path 1 found matches). Suppresses **ALL** flag types for accepted rows (previously only SOL:excessive).
2. `apply_nap_exercise_corrections.R`: fixed `isTRUE()` bug — CSV reads `manually_corrected` as character `"TRUE"` not logical TRUE. Now uses `tolower() %in% c("true","verified_recode")`. Also fixed NA exclusion path for `do_not_use` rows.
3. `error_unusual_sleep_time_corrections.R` (line 739): `apply_time_instruction_case3()` only accepts relative instruction format `"Same day HH:MM:SS AM/PM"`, not absolute datetimes.

## Key Updates (2026-07-14)
1. **NEEDS_REVIEW relabeled** to `SELF_REPORTED_FLAG` to clarify these are diary-based metric anomalies, not data errors.
2. **Figure count** expanded from 24 to 27: added Pipeline Progress (replacing pie chart), Per-Participant Flag Rate, Sleep Regularity, Sleep Composition, and Correlation Matrix.
3. **Figure organization** split into `pipeline_cleaning/` and `research_ready/` subfolders within `latest_visualization/`.
4. **Checkpoint reporter** (`report_correction_status.R`) inserted into pipeline — prints and saves per-step clean/error/unusual/corrected counts.
5. **R package** created (`splsleep`) with `DESCRIPTION`, `NAMESPACE`, exported `run_pipeline()`, and `renv.lock` for environment reproducibility.
6. **Agent skill** created (`.agents/skills/splsleep-pipeline/SKILL.md`) so AI assistants can understand and maintain the pipeline.
7. **Figure 7 annotation** now shows flag thresholds (SE < 70%, SOL > 1h, WASO > 1.5h) and Minor/Major counts directly on the plot.
8. **final_summary** updated to skip checkpoint A (no data_category yet) and compare B→E for meaningful deltas.

## File Locations
- Pipeline code: `/splsleep/` (root)
- Review CSVs: `/splsleep/` (active), `/splsleep/archive_intermediate_review_csvs/` (archived intermediate files)
- Outputs: `/splsleep/output/` (CSV reports), `/splsleep/latest_visualization/` (figures)
- Worklog: `/splsleep/worklog/weekly_plan_2026-07-13.md`
- Audit script: `/splsleep/audit_review_propagation.R` (cross-references review CSVs vs pipeline inputs)
