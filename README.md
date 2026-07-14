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

## Data Format (Text Only — Templates Provided)

**This repository contains no raw participant data, no real identifiers, and no actual study responses.** All CSV files containing participant data are excluded from version control via `.gitignore` and have been purged from git history.

You can find template CSV files in [`templates/`](templates/) showing the expected column structure with synthetic (fake) data values. Copy these to create your own correction files.

### Input Data Structure (Text Description)

#### Main Sleep Diary Data (RDS format)
A pre-processed R data frame with one row per participant per study day. Each row contains:

| Column group | Variables | Description |
|---|---|---|
| Identifiers | pid, day_num, row_id, participant | Participant and record IDs |
| Date | StartDate | Calendar date of the EMA session |
| Raw timestamps (HH:MM) | time_bed_am_hhmm, time_sleep_am_hhmm, time_awake_am_hhmm, time_getup_am_hhmm | Self-reported bed/sleep/awake/getup clock times |
| Raw timestamps (AM/PM) | time_bed_am_ampm, time_sleep_am_ampm, time_awake_am_ampm, time_getup_am_ampm | AM/PM indicator for each timestamp |
| Raw durations | duration_totalmin_sol_estimate_am, duration_totalmin_waso_estimate_am | Self-reported SOL and WASO in minutes |
| Nap/Exercise | duration_totalmin_napstoday_PM, exercise_PM_totalmin_[Light\|Moderate\|Vigorous\|Strength] | Self-reported nap and exercise durations |
| Substance use | caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1, alcoholtoday_PM_NumAlcoholicDrinks_1, nicotine_amount_pm_doses, cannabis_amount_pm_doses | Self-reported substance use |
| WASO count | num_waso_estimate_am, num_waso_am | Number of wake bouts |

#### Raw EMA CSV
A CSV file with the same participant-day structure, containing additional raw response columns from the EMA survey platform. Key columns that supplement the RDS:

| Column | Description |
|---|---|
| StartDate | EMA session start date |
| num_waso, num_waso_estimate_am | WASO bout counts |
| Various substance-use responses | Raw text/numeric inputs |

### Manual Correction CSV Formats (Templates Available)

All manual correction files follow a consistent structure of participant identifier + day number + correction instruction.
**Template files with synthetic data are in [`templates/`](templates/)** — copy them to create your own:

| Template File | Corresponding Live File | Purpose |
|---|---|---|
| `templates/template_manual_error_corrections.csv` | `manual_error_corrections.csv` | Timestamp corrections (AM/PM, order) |
| `templates/template_manual_unusual_corrections.csv` | `manual_unusual_corrections.csv` | Accepted unusual patterns |
| `templates/template_manual_nap_exercise_corrections.csv` | `manual_nap_exercise_corrections.csv` | Nap/exercise duration corrections |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO metric corrections |
| `templates/template_manual_metric_review_acceptances.csv` | `manual_metric_review_acceptances.csv` | Human-accepted metric flags |
| `templates/template_second_review_checklist.csv` | `second_review_checklist.csv` | Second-person verification decisions |

#### Column-by-Column Description

##### `manual_error_corrections.csv`
Contains timestamp corrections entered by human reviewers. Each row specifies:
- **pid, day_num, row_id**: identifies the record
- **variable**: the timestamp variable to correct (e.g., time_bed_am, time_sleep_am)
- **old_value_hhmm, old_value_ampm**: the original value
- **new_value_hhmm, new_value_ampm**: the corrected value
- **correction_type**: type of fix applied (e.g., "order_error", "ampm_fix")
- **confidence**: reviewer confidence level
- **reviewer_notes**: free-text notes

##### `manual_unusual_corrections.csv`
Accepted unusual temporal patterns judged as physiologically plausible:
- **pid, day_num, row_id**: identifies the record
- **unusual_type**: category (e.g., "short_sleep", "delayed_phase")
- **sleep_duration_h**: observed sleep duration
- **notes**: reviewer rationale

##### `manual_nap_exercise_corrections.csv`
Fix duration parsing errors in nap/exercise entries:
- **pid, day_num, row_id**: identifies the record
- **variable**: which duration variable to correct
- **old_value**: original parsed value (string)
- **new_value**: corrected value (numeric minutes)
- **correction_type**: "MMSS_recode" (e.g., "06:30" → 6.5 min) or "decimal_fix"

##### `manual_sleep_metric_duration_corrections.csv`
Fix SOL/WASO duration entries where HH:MM was misinterpreted as MM:SS:
- **pid, day_num, row_id**: identifies the record
- **variable**: "duration_totalmin_sol_estimate_am" or "duration_totalmin_waso_estimate_am"
- **original_mincalc**: value before correction
- **corrected_value**: value after correction
- **mmss_threshold_applied**: whether MM:SS→min conversion was applied

##### `manual_metric_review_acceptances.csv`
Rows where a human reviewer judged the auto-detected flag as acceptable (not an error):
- **pid, day_num, row_id**: identifies the record
- **human_metric_review_status**: "confirmed_not_error_do_not_correct"
- **auto_error_desc**: the original auto-detection description
- **reviewer_id**: who approved it
- **review_date**: when it was approved

##### `second_review_checklist.csv`
Second-person verification of single-annotator decisions:
- **target_csv**: which correction CSV the decision applies to
- **pid, day_num, row_id**: identifies the record
- **original_assessment**: what the first reviewer decided
- **consensus_reached**: TRUE/FALSE
- **final_action**: e.g., "apply_correction", "mark_as_accepted"

### Derived / Output CSV Formats

| File | Contents |
|---|---|
| `output/correction_status.csv` | Run history of checkpoint snapshots (A-E per run). Tracks n_clean, n_error, n_unusual, n_equal_time, n_skipped, n_corrected at each pipeline step |
| `output/correction_status_final.csv` | Per-run summary comparing first meaningful checkpoint (B) to last (E), with deltas |
| `output/flagged_records_self_reported.csv` | Records flagged as SELF_REPORTED_FLAG, with SOL/SE/ratio categories and metric values |

## Renv Reproducibility

The project includes a `renv.lock` file for exact R environment reproduction:

```r
renv::restore()
```

This ensures all package versions match the development environment.

## License

MIT
