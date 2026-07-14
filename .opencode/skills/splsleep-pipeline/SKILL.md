# splsleep-pipeline Skill

Automate the cleaning of sleep EMA diary data using the splsleep R package. This skill helps an AI agent understand, run, and maintain the data cleaning pipeline.

## Overview

The splsleep pipeline processes raw EMA sleep diary data (bedtime, sleep time, awake time, get-up time, SOL, WASO, substance use) through 9 sequential steps that parse, validate, correct, and visualize the data.

**Input:** Raw EMA CSV + RDS files with participant sleep diary records.
**Output:** Cleaned dataset + 27 QC visualization PNGs + correction reports.

## Pipeline Steps

```
Step 1-4:  Parse timestamps & intervals    (process_timestamp, process_interval)
Step 5:    Classify records                 (error_unusual classification)
Step 5.75: Second review                    (apply_second_review)
Step 6:    Fix timestamp errors             (error_unusual_sleep_time_corrections)
Step 6.5:  Fix nap/exercise durations       (apply_nap_exercise_corrections)
Step 7:    Compute sleep metrics            (TST, SOL, WASO, SE)
Step 8:    Auto-detect remaining issues     (checkforerrors_processing)
Step 8.5:  Cross-participant consistency    (cross_participant_global_check)
Step 9:    Generate visualizations          (sleep_visualization.R)
```

## Key Files

| File | Purpose |
|------|---------|
| `00_MAIN_entry.R` | Main orchestration (`run_pipeline()` function) |
| `00a_setup.R` | Data loading and validation |
| `process_timestamp_emadatarelease_cyra.R` | Parse raw HH:MM AM/PM timestamps |
| `process_interval.R` | Parse HH:MM duration strings |
| `normalize_sleep_time_sequence.R` | Fix AM/PM misassignment in timestamps |
| `calculate_sleep_time_end.R` | Compute TST, SOL, WASO, SE metrics |
| `error_unusual_sleep_time_corrections.R` | Core classification + timestamp correction |
| `generate_correction_files.R` | Create manual correction CSV templates |
| `apply_second_review.R` | Second-pass review after initial classification |
| `apply_nap_exercise_corrections.R` | Fix self-reported nap/exercise durations |
| `apply_sleep_metric_duration_corrections.R` | Fix SOL/WASO duration entries |
| `apply_metric_review_acceptances.R` | Apply human-reviewed metric acceptances |
| `checkforerrors_processing.R` | Auto-detection of remaining issues (3 parts: A/B/C) |
| `cross_participant_global_check.R` | Per-participant baseline deviation check |
| `cross_participant_field_misentry_check.R` | Detect field mis-entry (e.g., SOL=time_bed) |
| `sleep_visualization.R` | Generate 27 QC figures |
| `report_correction_status.R` | Checkpoint reporter + final summary |
| `audit_review_propagation.R` | Audit manual review propagation |
| `generate_ai_review_csvs.R` | Generate AI-assisted review CSVs |
| `run.sh` | Shell entry point (installs package + runs pipeline) |
| `DESCRIPTION` | R package metadata |
| `R/pipeline.R` | Package-exported `run_pipeline()` function |

## Data Files

| File | Format | Description |
|------|--------|-------------|
| `deidentified_intervalvars_forCD_111325.rds` | RDS | Main sleep diary data (processed intervals) |
| `sber_ema_anon_20260227.csv` | CSV | Raw EMA responses with substance use |
| `manual_error_corrections.csv` | CSV | Manual error corrections (Step 6 input) |
| `manual_unusual_corrections.csv` | CSV | Manual unusual value corrections |
| `manual_nap_exercise_corrections.csv` | CSV | Manual nap/exercise duration corrections |
| `manual_sleep_metric_duration_corrections.csv` | CSV | Manual SOL/WASO duration corrections |
| `manual_metric_review_acceptances.csv` | CSV | Human-accepted metric anomalies (suppress from NEEDS_REVIEW) |
| `second_review_checklist.csv` | CSV | Second-review decisions |

## Output

| Path | Contents |
|------|----------|
| `output/correction_status.csv` | Checkpoint snapshots per run (A-E) |
| `output/correction_status_final.csv` | Cross-checkpoint delta summaries |
| `output/flagged_records_self_reported.csv` | SELF-REPORTED FLAG records |
| `latest_visualization/` | All PNGs from latest run |
| `latest_visualization/pipeline_cleaning/` | Pipeline progress & QC figures |
| `latest_visualization/research_ready/` | Sleep metrics & substance use figures |

## Figure Catalog

### pipeline_cleaning/ (QC & pipeline progress)
- `01_Final_Data_Quality_Dashboard` — data_category pie + key metrics
- `06_Sleep_Duration_Post_Correction` — density by correction status
- `07_Flag_Composition_Stacked` — flag_severity × sleep_duration
- `08_Sleep_Duration_by_Category` — violin by data_category
- `10_Extreme_Sleep_Duration` — extreme values with efficiency
- `11_Flag_Cooccurrence_Heatmap` — flag pair co-occurrence
- `12_Pipeline_Correction_Progress` — checkpoint A→E bar chart
- `19_Unified_Quality_Status` — checkforerrors_summary classification
- `P26_PerParticipant_Flag_Rate` — per-participant Clean/Minor/Major %

### research_ready/ (Sleep analysis)
- `02_Distribution_Sleep_Variables` — TST/SOL/WASO/SE histograms
- `03_Sleep_Duration_Distribution` — TST histogram with stats
- `04_Sleep_Duration_vs_Time_in_Bed` — scatter with correlation
- `04B_SOL_vs_Sleep_Duration` — SOL × TST scatter
- `05_Variability_Sleep_Variables` — violin plots (free_y)
- `09_Bedtime_vs_Getup_Distribution` — circadian patterns
- `20_SOL_Perception_Bias` — subjective vs objective SOL
- `20B_WASO_Perception_Bias` — subjective vs objective WASO
- `21_Substance_Use_Availability`, `22-24` — substance use

### Not generated when auto-detection finds no issues:
- Figures 13-18 (auto-detection detail)

## Classification System

### data_category (from Step 5, temporal classification)
- `clean` — no temporal issues detected
- `error` — temporal ordering impossible to auto-fix (e.g., getup before bed)
- `unusual` — plausible but unusual pattern (e.g., very short sleep)
- `equal_time_ok` — bed == getup (auto-accepted)
- `skipped_na` — no sleep data recorded
- `reasonable_unusual` — unusual but within reasonable bounds

### flag_severity (from corrected metrics, Step 7)
- **Clean** — 0 flags
- **Minor** — 1 flag from {SE < 70%, SOL > 1h, WASO > 1.5h}
- **Major** — 2+ flags from the same set

### checkforerrors_summary (from Step 8 auto-detection)
- `TIMESTAMP_ISSUE` — clock-time format errors
- `DURATION_ISSUE` — interval/format errors
- `AMOUNT_FLAG` — substance input anomalies
- `SELF_REPORTED_FLAG` — SOL/WASO metrics anomalies (NOT data errors)
- `CLEAN` — no issues
- `CLEAN (Manually Fixed)` — had issues, corrected in Step 6

## Key Metrics (current run)
- Total records: 13,990
- Skipped NA (no sleep data): 11,142
- Clean: 1,908 | Error: 7 | Unusual: 31 | Equal Time: 902
- Manually corrected: 82
- SELF-REPORTED FLAG: 72 (61 SOL excessive + 11 TST/TIB very_low)
- Valid metric records: 1,729 | Mean TST: 7.71h | Mean SOL: 28.8min
- TIMESTAMP/DURATION/AMOUNT issues: 0 (all resolved by pipeline)

## Common Tasks

### Run the pipeline (default config)
```r
library(splsleep)
run_pipeline()
```

### Run with custom configuration (new dataset)
```r
# 1. Generate config template
file.copy(system.file("config_default.yaml", package = "splsleep"),
          "my_study_config.yaml")

# 2. Edit my_study_config.yaml:
#    - column_mapping:  map your column names to pipeline variables
#    - classification:  adjust thresholds (SOL, SE, TST/TIB ratio)
#    - timestamp:       input time format

# 3. Run
run_pipeline(config = "my_study_config.yaml")
```

### Shell entry point
```bash
cd /path/to/splsleep
bash run.sh
```

### Run without package install (legacy)
Rscript -e 'splsleep_loaded <- TRUE; source("00_MAIN_entry.R")'

### Regenerate figures only
```r
source("sleep_visualization.R")
```

### Check latest correction status
```r
# From output/correction_status_final.csv
read.csv("output/correction_status_final.csv")
```

### Add a manual correction
1. Add row to `manual_error_corrections.csv` (or other correction CSV)
2. Re-run pipeline
3. Verify in report and Figure 7

### Add a new figure
1. Add code in `sleep_visualization.R`
2. Add `save_png()` with `subdir = "pipeline_cleaning"` or `"research_ready"`
3. Update figure catalog in the script
4. Re-run
