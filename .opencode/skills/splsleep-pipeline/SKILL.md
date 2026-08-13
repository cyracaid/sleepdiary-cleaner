# splsleep-pipeline Skill

<!-- AUTO:SKILL_FACTS_START -->

**Version:** 1.4.3
**Pipeline steps:** 10

| Step | Label | Description |
|------|-------|-------------|
| 1 | Load data | .rds/.csv auto-detected; schema validated; optional supplementary file merged |
| 1.5 | Field-misentry check | SOL/WASO clock-time vs duration-field misentry detection on raw data |
| 2-4 | Parse & normalize (S3 chain) | Parse timestamps → parse intervals → normalize sequence |
| 5 | Classify records | Generate manual review CSVs for human approval |
| 5.75 | Second-review consensus | Apply second-review checklist consensus |
| 6-7 | Correct & compute metrics (S3 chain) | Manual + duration corrections; TST/SOL/WASO/SE metrics; has_correction enum |
| 8 | Auto-detect remaining issues | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED flag classification |
| 8.5 | Cross-participant consistency check | Global consistency audit across participants |
| 9 | Generate diagnostic figures | 24 figures + figure_index.png contact sheet + RUN_INFO.txt |
| 10 | Build delivered datasets | finalize_columns() selects/renames to Dataset A/B per column dictionary |

**Delivered columns (36, from column dictionary):**
- `pid`
- `day_num`
- `row_id`
- `bedtime_selfreport_ts`
- `sleeponset_selfreport_ts`
- `awakening_selfreport_ts`
- `getup_selfreport_ts`
- `tst_minutes`
- `sol_computed_minutes`
- `se_percent`
- `tib_minutes`
- `sleepperiod_minutes`
- `waso_computed_minutes`
- `waso_avg_bout_selfreport_minutes`
- `sol_selfreport_minutes`
- `waso_selfreport_minutes`
- `num_waso_bouts_selfreport`
- `nap_selfreport_totalminutes`
- `exercise_light_minutes`
- `exercise_moderate_minutes`
- `exercise_vigorous_minutes`
- `exercise_strength_minutes`
- `has_correction`
- `is_error`
- `error_type`
- `is_unusual`
- `unusual_type`
- `is_reasonable_unusual`
- `record_status`
- `flag_severity`
- `needs_review`
- `caffeine_num`
- `alcohol_num`
- `nicotine_doses`
- `cannabis_doses`
- `StartDate`

**Runtime dependencies:** 20 packages in Imports (`renv::install()` covers all)

<!-- AUTO:SKILL_FACTS_END -->

## Overview

Pipeline: raw timestamps → parse → correct → metrics → detect → visualize (see the auto-generated step table above).
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

## Repo

https://github.com/cyracaid/sleepdiary-cleaner
