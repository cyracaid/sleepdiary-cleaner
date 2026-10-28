# Output files

[中文版
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/output-files-zh.md)

## Quick guide: which file answers which question

The pipeline delivers three datasets. Use **A** for analysis, **B** to
see what changed, and the full file when you need a column that A and B
leave out.

| File                                              | Size in the study run    | Use it for                                                                                       |
|---------------------------------------------------|--------------------------|--------------------------------------------------------------------------------------------------|
| **A** `output/cleaned_data_final.csv`             | 13,990 rows × 35 columns | Analysis: times, sleep metrics, and the status columns below                                     |
| **B** `output/cleaned_data_prepostcorrection.csv` | 13,990 × 16              | What changed: the four times before and after correction, `correction_type`, `audit_disposition` |
| Full `output/cleaned_data_full.rds`               | 13,990 × 135             | Everything the pipeline computed, nothing dropped                                                |

| I want to know…                                             | Open                                                       | Column                                                                                                 |
|-------------------------------------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| Was this entry changed, and by what?                        | A or B                                                     | `has_correction`: `none`, `algorithmic`, `manual` or `both`. B also has `correction_type` (which rule) |
| What was typed, and what is it now?                         | B                                                          | `bedtime_precorrection` / `bedtime_postcorrection`, and the same for sleep onset, awakening, get-up    |
| Is it clean, an error, unusual, or not reported?            | A                                                          | `record_status`, `flag_severity` (with `error_type`, `unusual_type`)                                   |
| Did a person look at it, and what came of it?               | A                                                          | `human_review`: `none`, `corrected`, `accepted` or `waiting` (explained below)                         |
| Which Step 5 rows are in which review state after this run? | `[NEW]manual_error_correction_review.csv` (project folder) | `status_after_corrections`, `in_manual_file`                                                           |
| Who resolved a row, and when?                               | The review files you keep                                  | `review_resolution`, `resolved_by`, `resolved_at`                                                      |
| Why was a manual correction not used?                       | `output/manual_corrections_not_applied.csv`                | `reason`                                                                                               |
| Which rules did this run use?                               | `output/effective_rules.csv`                               | `value`, `source`                                                                                      |

`human_review` has one value per row, the first that applies:

| Value       | Meaning                                                                                                                                                                                |
|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `waiting`   | Still flagged for a person (Step 8) and not already accepted by one                                                                                                                    |
| `corrected` | A manual correction was applied                                                                                                                                                        |
| `accepted`  | A person looked and kept it as it is: a “Reasonable unusual record”, or a metric warning marked confirmed-not-error. `record_status` also says `reasonable_unusual` for the first kind |
| `none`      | Nobody had to look, or nobody has yet                                                                                                                                                  |

It reports what the review files say. It does not decide anything.
(`has_correction` still says whether the pipeline or a person changed
the entry.)

A run writes files in three places: the **project folder** (the
`project_dir` you gave), its `output/` folder, and the figure folders.
Files in the project folder are working files for the review; they
contain participant rows and must not be committed. Within each table
the files are listed in the order they are written.

## Project folder (not `output/`)

| File                                      | Written at                       | What it is                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|-------------------------------------------|----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `cross_participant_field_misentries.csv`  | Step 1.5                         | Rows where the SOL or WASO number looks typed into another time field. Written on the raw data                                                                                                                                                                                                                                                                                                                                                   |
| `[NEW]manual_error_correction_review.csv` | Step 5, rewritten after Step 8.5 | One status table: every `error` record from Step 5, plus every record that became an error only after the corrections. Columns `status_after_corrections`, `in_manual_file`, `category_before_corrections`, `category_after_corrections`, `step8_flags_after_corrections`. Rows that still need a person come first. See [Reading the output and the review loop](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output.md) |
| `[NEW]manual_unusual_review.csv`          | Step 5                           | The `unusual` records, with blank reviewer columns                                                                                                                                                                                                                                                                                                                                                                                               |
| `manual_error_correction_updated.csv`     | Step 6                           | The record of the corrections applied: your `manual_error_corrections.csv` as the pipeline incorporated it, with `manually_corrected` marking the rows actually used. Your own file is never edited. Not a worklist                                                                                                                                                                                                                              |
| `reasonable_unusual_records.csv`          | Step 6                           | `unusual` rows you marked “reasonable unusual record” (odd but plausible, left as is)                                                                                                                                                                                                                                                                                                                                                            |
| `cross_participant_flagged_rows.csv`      | Step 8.5                         | Days whose SOL or WASO is far from that participant’s **own** median                                                                                                                                                                                                                                                                                                                                                                             |
| `cross_participant_suspicious_slices.csv` | Step 8.5                         | All days of the participants in the previous file, for context                                                                                                                                                                                                                                                                                                                                                                                   |

## `output/`

| File                                          | Written at                                   | What it is                                                                                                                                                                                                                                                                                    |
|-----------------------------------------------|----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `effective_rules.csv`                         | Start of the run                             | Every rule and threshold the run used (key, value, default, whether it comes from the default or from your config, meaning). Compare two runs by comparing this file                                                                                                                          |
| `manual_corrections_not_applied.csv`          | When manual metric-duration rows are applied | Each manual sleep-metric-duration row that was not applied and why (`parser_already_converted_MMSS`, `row_not_marked_manually_corrected`, `column_not_found`, `no_unique_row_match`). Header only when every row was applied                                                                  |
| `second_review_rows_skipped.csv`              | Step 5.75                                    | Second-review rows left out because their `pid` or `day_num` is not a number: file line, `target_csv`, reason. Header only when none                                                                                                                                                          |
| `correction_status.csv`                       | At each checkpoint                           | One row per checkpoint (A–E) with the counts of each record class, mean TST and SOL; rows are added at every run, with a `run_id`                                                                                                                                                             |
| `step_flag_ledger.csv`                        | After Step 9                                 | One row per step × standard × category: how many records fall in each class at that step (logged during the run, written near the end)                                                                                                                                                        |
| `flagged_records_self_reported.csv`           | Step 8                                       | Records flagged `SELF_REPORTED_FLAG` (for example SOL over 120 min)                                                                                                                                                                                                                           |
| `corrected_ema_data.rds`                      | Step 7                                       | The pipeline’s working data after corrections and the sleep metrics, all columns                                                                                                                                                                                                              |
| `audit_integrity_report.csv`                  | After Step 9                                 | Integrity check of the corrected data against the input: rows, columns, untouched variables, duplicates                                                                                                                                                                                       |
| `appendix_step_ledger.csv`                    | Step 9                                       | The full per-step ledger drawn in figure A1                                                                                                                                                                                                                                                   |
| `cleaned_data_final.csv` / `.rds`             | Step 10                                      | **Dataset A**, the analysis-facing columns (driven by the column dictionary)                                                                                                                                                                                                                  |
| `cleaned_data_prepostcorrection.csv` / `.rds` | Step 10                                      | **Dataset B**: before and after values with the audit disposition per row. The disposition comes from the optional private ledger named by `data.files.audit_dispositions` in the config; with no ledger named it is `"none"` for every row, and a named ledger that is missing stops the run |
| `cleaned_data_full.rds`                       | Step 10                                      | Everything, unchanged                                                                                                                                                                                                                                                                         |
| `column_dictionary_gaps.csv`                  | Step 10                                      | Columns in the data that the column dictionary does not describe                                                                                                                                                                                                                              |
| `correction_status_final.csv`                 | End                                          | **The run summary.** One row per run (appended). See [Reading the output and the review loop](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output.html#s-4)                                                                                                            |

## Figure folder `latest_visualization_<tag>_n<rows>/`

Rebuilt from scratch at every visualization run. `<tag>` is the dataset
tag (`real`, `synth`); `n` is the number of input records.

| Item                                    | What it is                                                                 |
|-----------------------------------------|----------------------------------------------------------------------------|
| `pipeline_cleaning/`, `research_ready/` | The diagnostic and publication figures                                     |
| `figure_index.png`                      | Contact sheet of all figures; a red block lists the ones that were skipped |
| `all_figures_review.pdf`                | Every figure, one per page                                                 |
| `figures_not_generated.csv`             | Each figure that was not produced, and why                                 |
| `flag_distribution.csv`                 | One row per entry with its flag counts and details                         |
| `classification_summary.csv`            | Counts per final classification (written only when the run produced one)   |
| `RUN_INFO.txt`                          | When, which tag, how many records, which package version                   |

## Verification folder `verification/<tag>_n<rows>/`

Not wiped when figures are rebuilt: Bland-Altman plots of self-reported
against computed SOL and WASO, `threshold_validation.csv`, saved
snapshots used for the comparison with a previous run, and
`PROVENANCE.txt`.

## Before you rerun

A rerun overwrites these files. To keep a previous result, copy the
whole project folder first and run in the copy.
