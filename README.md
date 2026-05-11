# EMA Sleep Diary Data Cleaning Pipeline 🛏️📊

**生态瞬时评估睡眠日记数据清洗管道**

A comprehensive R pipeline for cleaning, normalizing, and validating Ecological Momentary Assessment (EMA) sleep diary data. This pipeline processes raw timestamp-based sleep records (bedtime, sleep onset, wake time, get-up time), detects and corrects common data entry errors (AM/PM misclassification, order swaps, format inconsistencies), applies manual corrections, and generates quality-controlled sleep metrics (SOL, TST, SE, WASO) along with publication-ready visualizations.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Pipeline Architecture](#pipeline-architecture)
- [Directory Structure](#directory-structure)
- [How to Run](#how-to-run)
- [Data Sources](#data-sources)
- [Processing Steps](#processing-steps)
- [Error Classification System](#error-classification-system)
- [Output](#output)
- [Development History](#development-history)
- [License](#license)

---

## Overview

### What This Pipeline Does

This pipeline processes EMA sleep diary data collected from mobile surveys where participants report their sleep times (bedtime, sleep onset, wake time, get-up time) along with substance use and exercise information. Raw EMA data often contains:

- **AM/PM misclassifications** — e.g., bedtime reported as "8:00 PM" when it should be "8:00 AM"
- **Order reversals** — e.g., sleep time entered before bedtime
- **Format inconsistencies** — times entered as "23.00", "11;00", "1100", etc.
- **Missing values** — incomplete diary entries
- **Unusual values** — extreme sleep durations, unrealistic intervals

The pipeline automatically detects and corrects these issues, applies human-reviewed manual corrections, and produces a clean, analysis-ready dataset.

### Key Features

- ✅ **Timestamp parsing** — Handles diverse input formats (hh:mm, h.mm, h;mm, hhmm, etc.)
- ✅ **AM/PM auto-correction** — ±12-hour adjustments using decision-tree logic
- ✅ **Order normalization** — Automatically swaps reversed time sequences
- ✅ **Interval processing** — Converts duration strings to numeric minutes
- ✅ **Manual correction system** — Applies human-reviewed corrections with undo support
- ✅ **3-tier error classification** — RED (critical), YELLOW (warning), BEHAVIORAL (lifestyle markers)
- ✅ **22 publication-quality figures** — Quality dashboards, distribution plots, perception bias, substance use
- ✅ **Flag reduction strategy** — Automated reduction of non-actionable flags from ~3,399 to 0

---

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       00_MAIN_entry.R                            │
│                     (Main Pipeline Entry)                        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: Timestamp Processing                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ process_timestamp_emadatarelease_cyra.R                   │    │
│  │ • Parse raw time strings (hhmm + ampm)                    │    │
│  │ • Normalize format to HH:MM AM/PM                         │    │
│  │ • Convert to POSIXct datetime                              │    │
│  │ • Detect AM/PM / 24h conflicts                             │    │
│  │ • Handle 8 time variables (bed/sleep/awake/getup +           │    │
│  │   caffeine/alcohol/nicotine/cannabis)                      │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: Interval Processing                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ process_interval.R                                        │    │
│  │ • Parse duration strings (SOL, WASO, exercise, nap)       │    │
│  │ • Handle diverse formats (dd:dd, dddd, d:dd, :dddd, etc.) │    │
│  │ • Convert to numeric minutes                               │    │
│  │ • Mark records needing manual review                       │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: Sleep Time Sequence Normalization                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ normalize_sleep_time_sequence.R                          │    │
│  │ • Stage 1: ±12h loop adjustments (AM/PM fixes)           │    │
│  │ • Stage 2: Order error correction (<3h threshold swaps)  │    │
│  │ • Stage 3: Clear parse-stage warnings after correction    │    │
│  │ • Record correction type for audit trail                  │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: Manual Correction System                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ error_unusual_sleep_time_corrections.R                   │    │
│  │ • Generate correction CSV templates                      │    │
│  │ • Apply human-reviewed corrections                       │    │
│  │ • Support undo operations                                │    │
│  │ • Handle swap operations (bed↔sleep, awake↔getup)        │    │
│  │ • Classify "reasonable unusual" records for exclusion    │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 5: Sleep Metrics Calculation                               │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ calculate_sleep_time_end.R                               │    │
│  │ • Time in Bed (TIB) = getup - bed                        │    │
│  │ • Sleep Onset Latency (SOL) = sleep - bed                │    │
│  │ • Total Sleep Time (TST) = awake - sleep                 │    │
│  │ • Sleep Efficiency (SE) = TST / TIB                      │    │
│  │ • Wake After Sleep Onset (WASO) = getup - awake         │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 6: Error Detection & Classification                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ checkforerrors_processing.R                             │    │
│  │ • 3-tier severity: RED / YELLOW / BEHAVIORAL            │    │
│  │ • Exclude exercise/nap noise (~81% flag reduction)      │    │
│  │ • Clear stale timestamp warnings after normalization    │    │
│  │ • Generate quality classification report                │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 7: Visualization (22 Figures)                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ sleep_visualization.R                                    │    │
│  │ • Figures 1-12: Core quality metrics                     │    │
│  │ • Figures 13-18: Auto-detection flags                    │    │
│  │ • Figures 19-22: Classification + perception bias +      │    │
│  │   substance use                                          │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
EMA-Sleep-Diary-Data-Cleaning-Pipeline/
│
├── pipeline/                          # 🔧 Core pipeline R scripts
│   ├── 00_MAIN_entry.R                #   Main entry point
│   ├── process_timestamp_emadatarelease_cyra.R  # Timestamp processing
│   ├── process_interval.R             #   Interval/duration processing
│   ├── normalize_sleep_time_sequence.R  # Sleep time normalization
│   ├── generate_correction_files.R    #   Generate manual correction CSVs
│   ├── error_unusual_sleep_time_corrections.R  # Apply manual corrections
│   ├── calculate_sleep_time_end.R     #   Calculate sleep metrics
│   ├── checkforerrors_processing.R    #   Error detection & classification
│   ├── sleep_visualization.R          #   22-figure visualization suite
│   ├── validation_helpers.R           #   Validation utility functions
│   └── test_df_entry.R                #   Unit test (4 cases)
│
├── output/                            # 📈 Output visualizations & reports
│   ├── plots_png/                     #   PNG figures (22+7)
│   ├── plots_pdf/                     #   PDF vector figures
│   └── reports/                       #   Summary reports & analysis
│
└── README.md                          # This file
```

---

## How to Run

### Prerequisites

- R (≥ 4.0) with packages: `lubridate`, `tidyverse`, `dplyr`, `stringi`, `ggplot2`
- Data files (not included in repo — see [Data Sources](#data-sources)):
  - `deidentified_intervalvars_forCD_111325.rds`
  - `sber_ema_anon_20260227.csv`
  - `manual_error_corrections.csv`
  - `manual_unusual_corrections.csv`

### Run the Full Pipeline

```r
# Set working directory to pipeline/
setwd("pipeline/")

# Run the main entry script
source("00_MAIN_entry.R")
```

### Run Tests

```r
source("test_df_entry.R")
# Tests 4 cases: no valid records, multiple 12h loops, missing durations, equal times
```

---

## Data Sources

The pipeline expects the following input files in the working directory:

| File | Description | Source |
|------|-------------|--------|
| `deidentified_intervalvars_forCD_111325.rds` | Deidentified interval variables (RDS format) | EMA database export |
| `sber_ema_anon_20260227.csv` | Anonymized EMA survey responses | EMA database export |
These files are **not included** in the repository — they are IRB-protected data requiring authorized access. Contact the study team for access.

---

## Processing Steps

### Step 1: Timestamp Processing (`process_timestamp_emadatarelease_cyra.R`)

- Parses raw time strings from `*_hhmm` (time) and `*_ampm` (AM/PM) columns
- Handles format variations: `hh:mm`, `h:mm`, `hh.mm`, `hh;mm`, integer hours
- Detects and flags AM/PM conflicts (e.g., 24h format with AM/PM marker)
- Converts to `POSIXct` datetime in `US/Pacific` timezone
- For evening variables (bed, sleep): shifts dates back if hour > 15 (previous calendar day)
- Output columns: `*_hhmm_ampm`, `*_checkforerrors`

### Step 2: Interval Processing (`process_interval.R`)

- Parses duration strings for SOL, WASO, naps, exercise durations
- Branch 1: Correct format `dd:dd` → validates, repairs `dd:00 → 00:dd` (hours-minutes swap)
- Branch 2: No colon → handles 1-5+ digit variations
- Branch 3: Has colon, wrong format → repairs `d:d:dd`, `:dddd`, `ddd:d`, etc.
- Output: `*_mincalc` (numeric minutes), `*_checkforerrors`, `*_correctionsmade`

### Step 3: Normalization (`normalize_sleep_time_sequence.R`)

**Stage 1 — Priority Order Adjustment (±12h loops):**
- Wake-up section: if `getup - awake ≥ 12h`, reduce getup by 12h iteratively
- Sleep section: if `sleep - bed ≥ 12h`, reduce sleep by 12h iteratively
- Records correction type for audit trail

**Stage 2 — Minor Order Error Processing (<3h threshold):**
- Bed > Sleep and difference < 3h → swap (bed-sleep order error)
- Sleep > Awake and difference < 3h → swap (sleep-awake order error)
- Awake > Getup and difference < 3h → swap (awake-getup order error)

**Stage 3 — Clear Stale Warnings:**
- After successful correction, clears `*_checkforerrors` for records with valid `*_corrected` values
- Prevents parse-stage warnings from being misinterpreted as data errors

### Step 4: Manual Corrections (`error_unusual_sleep_time_corrections.R`)

- **Branch A — Manual Unusual Processing**: Pre-identified records needing special handling
  - Undo correction (restore original values)
  - Time adjustments (±12h, specific time change)
  - Swap operations
  - "Reasonable unusual" record identification

- **Branch B — Correction DataFrame Processing**: Column-value mapped corrections
  - Case 1: Skip (no info)
  - Case 2: Solution-based (natural language description)
  - Case 3: Column-value pair (preferred — precise instructions)
  - Case 4: Unprocessable (log warning)

- **Post-Processing**: Update corrected columns, recalculate time differences, detect errors/unusual

### Step 5: Sleep Metrics (`calculate_sleep_time_end.R`)

| Metric | Formula | Unit |
|--------|---------|------|
| Time in Bed (TIB) | `getup - bed` | hours |
| Sleep Onset Latency (SOL) | `sleep - bed` | minutes |
| Total Sleep Time (TST) | `awake - sleep` | hours |
| Sleep Efficiency (SE) | `TST / TIB × 100` | % |
| Wake After Sleep Onset (WASO) | `getup - awake` | minutes |

### Step 6: Error Detection & Classification (`checkforerrors_processing.R`)

Three-tier severity system:

| Tier | Label | Condition | Action |
|------|-------|-----------|--------|
| 🛑 **RED** | SERIOUS_RED_LINE | `red_flags > 0` | Must review |
| ⚠️ **YELLOW** | UNUSUAL_VALUE | `red_flags == 0 & yellow_flags > 0` | Suggest review |
| 🔵 **BEHAVIORAL** | BEHAVIORAL | Substance threshold flags only | Researcher reference |
| ✅ **CLEAN** | CLEAN | No flags | Pass |

Flag exclusion filters:
- **Exercise/nap format checks** excluded (~81% noise reduction: 2,628 → 8 flags)
- **Substance timestamp columns** excluded (contextual, not core sleep metrics)
- **Stale timestamp warnings** cleared after normalization (~771 → 0)

### Step 7: Visualization (`sleep_visualization.R`)

22 figures generated in two groups:

**Core Quality (Figures 1-12):**
- Data quality dashboard, sleep variable distributions, duration distributions
- SOL vs Sleep Duration, Sleep Duration vs Time in Bed
- Variability analysis, pre/post correction comparison
- Flag composition, bedtime/getup distributions, extreme durations

**Auto-Detection & Advanced (Figures 13-22):**
- Error category distribution, error timeline, common error patterns
- Top participants with flags, auto-detected dashboard
- Unified quality status, SOL/WASO perception bias
- Substance use thresholds and distribution

---

## Error Classification System

### Flag Reduction Results (May 7 Optimization)

| Stage | checkforerrors_df | SERIOUS_RED_LINE | UNUSUAL_VALUE | BEHAVIORAL | Needs Review |
|-------|-------------------|------------------|---------------|------------|--------------|
| Original | 4,069 | 771 | 2,628 | — | ~3,399 |
| + Exclude exercise/nap | 1,449 | 751 | 8 | — | ~759 |
| + Normalize clearing | 1,013 | 0 | 8 | — | ~61 |
| + Intelligent classification | 1,013 | **0** | **0** | **8** | **0** |

### Final Status Distribution (13,990 records)

| Status | Count | Percentage |
|--------|-------|------------|
| CLEAN | 13,929 | 99.56% |
| CLEAN (Manually Fixed) | 53 | 0.38% |
| BEHAVIORAL | 8 | 0.06% |
| SERIOUS_RED_LINE | 0 | 0% |
| UNUSUAL_VALUE | 0 | 0% |

### Substance Use Thresholds

| Substance | Threshold | Rationale | Records Exceeding |
|-----------|-----------|-----------|-------------------|
| Caffeine | >4 cups/day | >400mg linked to sleep disruption | 18 (1.2%) |
| Alcohol | >3 drinks/day | Heavy drinking impairs sleep | 4 (3.8%) |
| Nicotine | >1 dose/day | Any use may affect sleep | 0 |
| Cannabis | >1 dose/day | Daily use linked to sleep problems | 0 |

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Dual exclusion (Part A + Part 3) | Preserve audit trail — flags exist but don't trigger review |
| Clear checkforerrors based on `!is.na(*_corrected)` not `corrected == TRUE` | Many records have valid corrected values despite parse warnings, with `corrected == FALSE` |
| BEHAVIORAL category for substance flags | Researcher visibility without triggering review |
| SOL interval → RED, WASO interval → YELLOW | SOL is core metric; WASO is important but secondary |

---

## Output

### Visualization Figures (`output/plots_png/`, `output/plots_pdf/`)

22 publication-quality figures (PNG 300 DPI + PDF vector).

### Reports (`output/reports/`)

- `sleep_analysis_report.html` — Comprehensive HTML report
- Summary statistics, error analysis, unusual records analysis

---

## Development History

### 📅 2025 — Initial Development
- Core timestamp and interval processing functions
- Sensitivity analysis (time swap thresholds, AM/PM correction)
- Validation helpers and test infrastructure
- R Markdown notebook for manual cleaning

### 📅 January 2026 — Decision Tree Logic
- New normalized sleep time processing with decision tree architecture
- Priority order adjustment (±12h loops)
- Minor order error correction (<3h threshold swaps)
- Calculated sleep time variables with correction audit trail

### 📅 March 2026 — Manual Correction System
- Comprehensive manual error/unusual correction system
- Decision tree for correction processing (Branches A-D)
- Reasonable unusual record identification and exclusion
- Methodology draft and documentation

### 📅 April 2026 — Substance Checks & Review Flags
- Substance use threshold checks (caffeine, alcohol, nicotine, cannabis)
- Review flag generation system
- PID search tools for participant identification
- Sleep visualization iteration

### 📅 May 7, 2026 — Automated Flag Reduction (Current Stable)
- Unified main entry point (`00_MAIN_entry.R`)
- 3-tier error classification (RED/YELLOW/BEHAVIORAL)
- 81% noise reduction from exercise/nap format exclusion
- Stale timestamp warning clearing
- Final result: **0 actionable flags**, 99.56% CLEAN
- 22-figure visualization suite

---

### Perception Bias Analysis

The pipeline includes SOL and WASO perception bias analysis (Figures 20, 20B), comparing participants' subjective self-assessments against algorithm-computed objective values. Thresholds: minor = 15 minutes, red-line = 60 minutes.

---

## License

This project is developed for sleep research purposes at the **Stanford Psychophysiology Lab**. The raw EMA sleep diary data is **IRB-protected** and **not included in this repository**. Access to the original data requires IRB approval — please contact the Stanford Psychophysiology Lab for data access permissions.

### Authors

- **Cyra Cai Dong** — Primary author and maintainer
- **Maia ten Brink** — Co-author and methodology contributor
