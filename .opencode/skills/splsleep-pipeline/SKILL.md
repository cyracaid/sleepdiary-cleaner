# splsleep-pipeline Skill

Automate the cleaning of sleep EMA diary data using the splsleep R package (v1.3.9).

## Overview

9-step pipeline: raw timestamps → parse → correct → metrics → detect → visualize. 
Configurable via YAML — maps your dataset columns without code changes.

**Input:** .rds or .csv sleep diary data
**Output:** Cleaned dataset + diagnostic figures + figure_index.png contact sheet + audit reports

## Quick Start

```r
renv::install("cyracaid/sleepdiary-cleaner")
library(splsleep)
run_pipeline()
```

For your own data:
```r
file.copy(system.file("config_template.yaml", package = "splsleep"), "my_study.yaml")
# Edit my_study.yaml → set data.files.main to your file
run_pipeline(config = "my_study.yaml")
```

## Pipeline Steps

```
Step 1:    Load data (.rds or .csv, auto-detected)
Step 1.5:  Field-misentry check (SOL/WASO vs time columns)
Step 2-4:  Parse timestamps, parse intervals, normalize sequence
Step 5:    Classify records → generate review CSVs
Step 5.75: Second-review consensus
Step 6:    Apply manual corrections (reads manual CSVs)
Step 6.5:  Apply nap/exercise + duration corrections
Step 7:    Compute sleep metrics (TST, SOL, WASO, SE) + has_correction enum
Step 8:    Auto-detect remaining issues (Parts A/B/C)
Step 8.5:  Cross-participant consistency check
Step 9:    Generate diagnostic figures + figure_index.png
```

## Key Columns

| Column | Source | Description |
|--------|--------|-------------|
| `has_correction` | Step 7 | none / algorithmic / manual / both |
| `data_category` | Step 6 | clean / error / unusual / equal_time_ok / skipped_na |
| `flag_severity` | Step 7 | Clean / Minor (1 flag) / Major (2+ flags) |
| `needs_review_flag` | Step 8 | Combined auto-detection flag |
| `auto_error_desc` | Step 8 | All detected issues in text form |

## Config System

- `data.files.main` — your data file (.rds or .csv, auto-detected)
- `data.files.extra` — optional supplementary file (StartDate, WASO counts)
- `column_mapping` — map your column names to pipeline internals
- `classification.*` — adjustable detection thresholds

Template: `inst/config_template.yaml`

## Output

| Path | Contents |
|------|----------|
| `latest_visualization_*/` | All figures + RUN_INFO.txt + figure_index.png |
| `output/correction_status_final.csv` | Per-run summary |
| `output/appendix_step_ledger.csv` | Per-step flag tracking |
| `output/flagged_records_self_reported.csv` | SELF_REPORTED_FLAG records |
| `column_map.csv` | Column source mapping |

## Key Figures

- `01_Pipeline_Flow_Diagram` — record flow with counts and percentages
- `02_Correction_Impact` — delta lollipops + identity scatter + summary table
- `12_Pipeline_Correction_Progress` — checkpoint convergence
- `figure_index.png` — contact sheet of all figures

## Dependencies

All 18 runtime packages in Imports — `renv::install()` installs everything automatically.

## Repo

https://github.com/cyracaid/sleepdiary-cleaner
