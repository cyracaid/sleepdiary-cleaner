# sleepcleanr-pipeline Skill

<!-- AUTO:SKILL_FACTS_START -->

**Version:** 1.5.3
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
| 9 | Generate diagnostic figures | 32 figures (16 QC + 16 research) + figure_index.png contact sheet + RUN_INFO.txt |
| 10 | Build delivered datasets | finalize_columns() selects/renames to Dataset A/B per column dictionary |

**Delivered columns (35, from column dictionary):**
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
- `record_status`
- `flag_severity`
- `human_review`
- `caffeine_num`
- `alcohol_num`
- `nicotine_doses`
- `cannabis_doses`
- `StartDate`

**Runtime dependencies:** 13 packages in Imports (`renv::install()` covers all)

<!-- AUTO:SKILL_FACTS_END -->

## Overview

Pipeline: raw timestamps → parse → correct → metrics → detect → visualize (see the auto-generated step table above).
Configurable via YAML — maps your dataset columns without code changes.

**Input:** .rds or .csv sleep diary data
**Output:** Cleaned dataset + diagnostic figures + figure_index.png contact sheet + audit reports

## Quick Start

```r
renv::install("cyracaid/sleepdiary-cleaner")
library(sleepcleanr)
run_pipeline()
```

For your own data:
```r
file.copy(system.file("config_template.yaml", package = "sleepcleanr"), "my_study.yaml")
# Edit my_study.yaml → set data.files.main to your file
run_pipeline(config = "my_study.yaml")
```

## Human-Review Corrections (opt-in)

Since v1.5.0, `run_pipeline()` does **not** apply human-review corrections
by default. Review worksheets are still regenerated under `output/` every
run for human fill-in; to apply completed reviews, opt in explicitly:

```r
run_pipeline(config = "my_study.yaml", include_manual_corrections = TRUE)
```

- `FALSE` (default): algorithmic-only run; a banner states that no human corrections were applied.
- `TRUE`: applies the review files configured under `data.files.manual_*` / `second_review`.
- `"ask"`: prompts interactively; non-interactive sessions degrade to `FALSE`.

Templates for every review file live in `templates/`; the review workflow
is walked through in `vignettes/interpreting-output.Rmd`.

## Fetching Results

The pipeline writes nothing to your global environment. Main results are
kept package-private and retrieved with `pipeline_results()`;
`cleaning_report()` builds a prevalence report from the same results
object. Pass `export_env = globalenv()` to `run_pipeline()` only if the
pre-v1.5.0 behaviour is needed.

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
| `[NEW]manual_error_correction_review.csv` | Step 5 review worksheet: `error` records awaiting human decisions — written to the **project root**, not `output/` |
| `[NEW]manual_unusual_review.csv` | Step 5 review worksheet: `unusual` records — also project root |

The `[NEW]` prefix is literal. In R, list these files with
`list.files(pattern = "\\[NEW\\]")` — an unescaped `[NEW]*` pattern is a
regex character class and matches nothing.

## Key Figures

- `01_Pipeline_Flow_Diagram` — record flow with counts and percentages
- `02_Correction_Impact` — delta lollipops + identity scatter + summary table
- `A1_Step_Flag_Ledger` — per-step flag counts (merges former Fig 12 checkpoint convergence)
- `figure_index.png` — contact sheet of all figures

## Repo

https://github.com/cyracaid/sleepdiary-cleaner
