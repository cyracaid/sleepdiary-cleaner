# SPL Sleep — EMA Sleep Diary Data Cleaning Pipeline

Automated pipeline for cleaning sleep EMA diary data. Parses raw bedtime/sleep/awake/getup timestamps, detects and corrects temporal and duration errors, computes sleep metrics (TST, SOL, WASO, SE), validates self-reported durations, and generates 27 QC visualizations.

## Features

- **9-step pipeline**: raw data → timestamp parsing → interval processing → temporal correction → duration correction → metric computation → auto-detection → cross-participant consistency → visualization
- **Manual correction CSV workflow**: human review decisions stored in CSVs, re-read on each pipeline run
- **Configurable thresholds**: SOL/SE/TST-TIB flag thresholds, timestamp format, column names — all set in a YAML config file
- **Checkpoint reporter**: per-step clean/error/unusual/corrected counts printed and saved to CSV
- **27 diagnostic figures**: organized into `pipeline_cleaning/` (QC) and `research_ready/` (sleep metrics, substance use)
- **R package**: `library(splsleep); run_pipeline()` — installable, versioned, dependency-managed
- **Agent skill**: AI assistants can understand and maintain the pipeline via `.agents/skills/splsleep-pipeline/SKILL.md`

## Pipeline Architecture

```
Raw Data ──→ Step 1: Load Data ──→ Step 2: Parse Timestamps ──→ Step 3: Parse Intervals ──→ Step 4: Normalize Sequence
                                                                                                      │
                                                                                                      ▼
                                                                                             Step 5: Classify Records
                                                                                             (generates review CSVs)
                                                                                                      │
                                                                                             Step 5.75: Second Review
                                                                                                      │
                                                                                             Step 6: Apply Manual Corrections
                                                                                             (reads manual_error_corrections.csv)
                                                                                                      │
                                                                                             Step 6.5: Apply Duration Corrections
                                                                                             (nap, exercise, SOL/WASO corrections)
                                                                                                      │
                                                                                             Step 7: Compute Sleep Metrics
                                                                                             (TST, SOL, WASO, SE, TIB)
                                                                                                      │
                                                                                             Step 8: Auto-Detect Remaining
                                                                                             (TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED)
                                                                                                      │
                                                                                             Step 8.5: Cross-Participant Check
                                                                                                      │
                                                                                             Step 9: Generate 27 Figures
```

### Classification Systems

| System | Source | Categories |
|--------|--------|------------|
| `data_category` | Step 5 (temporal) | clean, error, unusual, equal_time_ok, skipped_na |
| `flag_severity` | Step 7 (metrics) | Clean, Minor (1 flag), Major (2+ flags) |
| `checkforerrors_summary` | Step 8 (auto-detect) | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG, CLEAN |

### Figures

| Folder | Count | Content |
|--------|-------|---------|
| `pipeline_cleaning/` | 9 | Pipeline progress, data quality dashboard, flag composition, per-participant flag rate |
| `research_ready/` | 15 | Sleep variable distributions, perception bias, substance use, sleep regularity, correlation matrix |

## Quick Start

### Prerequisites

- R ≥ 4.2
- Raw EMA data files (RDS + CSV format with sleep diary timestamps)

### Install and Run

```r
# Install the package
install.packages("splsleep_1.0.0.tar.gz", repos = NULL)

# Load and run (uses built-in default configuration)
library(splsleep)
run_pipeline()
```

Or from the command line:

```bash
bash run.sh
```

### Using with Your Own Dataset

The pipeline is fully configurable via a YAML configuration file. This lets you map your dataset's column names to pipeline variables and adjust thresholds without modifying any R code.

```r
# Step 1: Generate a configuration template
library(splsleep)
file.copy(system.file("config_default.yaml", package = "splsleep"),
          "my_study_config.yaml")
```

**Step 2: Edit `my_study_config.yaml`**

The config file has three key sections:

#### Column Mapping
Map your dataset's column names to the pipeline's internal variables:

```yaml
column_mapping:
  identifiers:
    pid: "subject_id"          # your participant ID column
    day_num: "study_day"       # your day number column
  timestamp:
    time_bed_hhmm: "bedtime"   # your bedtime HH:MM column
    time_bed_ampm: "bed_ampm"  # your bedtime AM/PM column
    time_sleep_hhmm: "sleeptime"
    time_sleep_ampm: "sleep_ampm"
  duration:
    sol: "sleep_onset_latency" # your SOL column (minutes)
    waso: "wake_after_onset"   # your WASO column (minutes)
  substance:
    caffeine: "caffeine_cups"
    alcohol: "alcohol_drinks"
```

#### Thresholds
Adjust detection sensitivity for your study population:

```yaml
classification:
  metric_validation:
    sol:
      excessive_minutes: 120   # SOL > 2h → flagged
    se:
      min_valid_percent: 0
      max_valid_percent: 100
    tst_tib_ratio:
      min_ratio: 0.5
      max_ratio: 1.0
  flag_severity:
    poor_efficiency_threshold_pct: 70   # SE < 70% → flag
    high_sol_threshold_hours: 1         # SOL > 1h → flag
    high_waso_threshold_hours: 1.5      # WASO > 1.5h → flag
```

#### Timestamp Format
Specify how your timestamps are stored:

```yaml
timestamp:
  input_format: "hh:mm AM/PM"   # or "HH:MM", "HH:MM:SS"
  ampm:
    enabled: true
    pm_keywords: ["PM", "pm"]
```

**Step 3: Run with your configuration**

```r
run_pipeline(config = "my_study_config.yaml")
```

All pipeline scripts automatically read the config; no R code changes needed.

## Agent Skill

The project includes an AI agent skill for AI-assisted pipeline maintenance:

**Location**: `.agents/skills/splsleep-pipeline/SKILL.md`

The skill enables AI assistants to:
- Understand the pipeline architecture, file structure, and data flow
- Run the pipeline and interpret checkpoint reports
- Add manual corrections and regenerate figures
- Diagnose issues in the cleaning process

To use with opencode or compatible AI tools, the skill is registered in `opencode.jsonc`:

```json
{
  "skills": {
    "splsleep-pipeline": {
      "description": "Run and maintain the sleep EMA diary data cleaning pipeline",
      "triggers": ["splsleep", "sleep pipeline", "sleep EMA", "run_pipeline"]
    }
  }
}
```

## Output Structure

| Path | Contents |
|------|----------|
| `latest_visualization/` | All PNGs from latest pipeline run |
| `latest_visualization/pipeline_cleaning/` | QC and pipeline progress figures |
| `latest_visualization/research_ready/` | Sleep metrics and analysis figures |
| `output/correction_status.csv` | Per-checkpoint snapshots over all runs |
| `output/correction_status_final.csv` | Cross-checkpoint comparisons per run |
| `output/flagged_records_self_reported.csv` | Records flagged as SELF_REPORTED_FLAG |

## Manual Correction CSVs

| File | Step | Purpose |
|------|------|---------|
| `manual_error_corrections.csv` | 6 | Timestamp corrections (AM/PM, order) |
| `manual_unusual_corrections.csv` | 6 | Accepted unusual patterns |
| `manual_nap_exercise_corrections.csv` | 6.5 | Nap/exercise duration corrections |
| `manual_sleep_metric_duration_corrections.csv` | 6.5 | SOL/WASO metric corrections |
| `manual_metric_review_acceptances.csv` | 6.5/8 | Human-accepted metric flags |
| `second_review_checklist.csv` | 5.75 | Second-person verification decisions |

## Renv Reproducibility

The project includes a `renv.lock` file for exact R environment reproduction:

```r
renv::restore()
```

This ensures all package versions match the development environment.

## License

MIT
