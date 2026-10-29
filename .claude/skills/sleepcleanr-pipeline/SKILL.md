---
name: sleepcleanr-pipeline
description: Run, review and maintain the sleepcleanr sleep EMA diary cleaning pipeline (R package, repository sleepdiary-cleaner). Use for run_pipeline(), manual correction files, review_status.csv and the review verdict, config YAML, figures, and any work on this repository's R/ or inst/scripts. Read the Safety Rules section before touching real data.
---

# sleepcleanr-pipeline Skill

<!-- AUTO:SKILL_FACTS_START -->

**Version:** 1.7.2
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

**Delivered columns (39, from column dictionary):**
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
- `sol_selfreport_raw`
- `sol_selfreport_ambiguous`
- `waso_selfreport_raw`
- `waso_selfreport_ambiguous`

**Runtime dependencies:** 14 packages in Imports (`renv::install()` covers all)

<!-- AUTO:SKILL_FACTS_END -->

## Safety Rules (read first)

The pipeline runs on real participant data. These rules come from the
project's local `AGENTS.md`, which is gitignored and therefore missing from
git worktrees and fresh clones; this section is the copy agents can always see.

Without the user's explicit permission in this conversation, do not:

- `git add` (any staging), commit, push, tag, release or deploy;
- run the pipeline on real data (`run_pipeline()`, `run.sh`, any
  `real_data_config*.yaml`), or run the full test suite (one test file is fine);
- edit `R/` or `inst/scripts/`: show the diff first, write it after approval;
- `R CMD build` / `devtools::build()`;
- overwrite or delete `output/`, `latest_visualization*/`, or any `*.csv` /
  `*.rds` data file.

Always:

- run anything that writes outputs in a temporary directory, never with
  `project_dir` pointing into the repository;
- treat a new file whose name looks like real data (`manual_*`, `fasttrack_*`,
  `disambiguation_*`, `tiered_*`, `timegap_*`, `real_data_config*`, `audit_*`,
  `second_review*`, `sber_*`, `deidentified_*`, `cleaned_*`,
  `*.provenance.json`, backups such as `*.bak`) and is not covered by
  `.gitignore` as a possible leak: stop, report, wait;
- keep backups of real files outside the repository;
- on any unexpected overwrite or leak: stop, report, wait. Do not fix it on
  your own.

## Quick Start

```r
renv::install("cyracaid/sleepdiary-cleaner")
library(sleepcleanr)
run_synthetic_demo(project_dir = tempfile())   # bundled synthetic data
```

For your own data:
```r
file.copy(system.file("config_template.yaml", package = "sleepcleanr"), "my_study.yaml")
# Edit my_study.yaml: data.tag, data.files.main, column_mapping
run_pipeline(config = "my_study.yaml")
```

`data.tag` (`real` / `synth` / `unknown`) says what the data is and decides
where figures go (only `real` goes under `output/`). It is never guessed: if it
is not set and the run makes figures, an interactive session asks once
(r / s / n) and a non-interactive run stops with an error. Runs with
`skip_visualization = TRUE` do not need it.

## Human-Review Corrections (opt-in)

`run_pipeline()` applies human-review files only when asked:

```r
run_pipeline(config = "my_study.yaml", include_manual_corrections = TRUE)
```

- `FALSE` (default): algorithmic-only run; a banner says no human corrections
  were applied.
- `TRUE`: applies the files configured under `data.files.manual_*` and
  `second_review`. If one is missing, an interactive session asks whether to
  continue without it; a non-interactive run warns and continues, unless the
  config sets `data.require_manual_corrections: true`, which makes it stop.
- `"ask"`: asks y / n once when the run starts. A non-interactive session
  cannot answer, so the run stops there with an error.

Step 5 writes the review worksheets `[NEW]manual_error_correction_review.csv`
and `[NEW]manual_unusual_review.csv` to the **project root** (not `output/`).
After Step 8.5 the error worksheet is rewritten as a status table. Templates
for every review file are in `templates/`; the cycle is described in
`vignettes/interpreting-output.Rmd`.

## Writing Manual Correction Rows

Each row is matched by `pid` + `day_num`; the instruction is applied to the
first data row of that day. Rows are applied in file order, so two rows for the
same day both apply: a repeated `Plus 12 hours` shifts the time twice.

How a row in `manual_error_corrections.csv` is read:

| The row has | It is handled as | What is read |
|---|---|---|
| `column_to_correct` **and** `correct_value` | column/value row | the column/value pairs; `solution_humanidentified` is read **only** for "undo correction" and the switch phrases below |
| only `solution_humanidentified` | text row | the phrases in the table below |
| nothing | skipped | — |

Column names must be full names: `time_bed_corrected`, `time_sleep_corrected`,
`time_awake_corrected`, `time_getup_corrected` (several separated by commas).
A short name such as `time_bed` is skipped.

`correct_value` / `correct_value_2` (and `correction_value` / `_2` in the
unusual file):

| Write | Effect |
|---|---|
| `Same day 10:00:00 AM` (or `Same day 22:30`) | keep the date, set the clock time |
| `Minus 12 hours` / `Plus 12 hours` | shift the named column(s) by 12 h |
| `10:00` or `10:00:00` | set the clock time |
| `2022-01-15 06:00:00` (or `2022-01-15 06:00`) | set date and time |

Phrases read in `solution_humanidentified`:

| Phrase | Effect |
|---|---|
| `Undo correction` | restore the four raw times first; the row's other instructions are then applied on top |
| `sleep-awake switch`, `awake-getup switch`, `bed-sleep switch` (also `awake/getup switch`, `perform ... switch`) | swap the two times. Text rows also accept `sleep-awake swap` etc.; column/value rows accept only the `switch` forms. `Swap awake/getup` is not recognised |
| `Bed time AM/PM conversion` (also sleep / awake / getup) | text rows only |
| `Change sleep time into 23:30` | text rows only |
| `Align awake time's hour to getup time's hour` | text rows only |
| `Minus 12 hours` / `Plus 12 hours` | text rows only, and it shifts **all four** times |

**Anything else is skipped**, for example free text such as `Set time_awake
equal to time_getup` or a short column name. Each skipped instruction is
printed as a WARNING during Step 6, and its record is `needs_review` in
`review_status.csv` with the reason "manual instruction not understood and
skipped: ...". `correction_type` is written by the algorithm (Step 4), not by a
person; it never marks a record as manually corrected.

### When a row is still `needs_review` after corrections

1. Read its `review_state_reason` in `review_status.csv`.
2. If the reason says an instruction was not understood, rewrite it in one of
   the forms above. Otherwise look up the row in the manual file: are the
   column names full, and is every value in one of the forms above?
3. Compare the raw times (`time_*_am_hhmm_ampm`) with the corrected times
   (`time_*_corrected`) in `pipeline_results()$corrected_ema_data`: was the
   instruction applied, and is the order bed ≤ sleep ≤ awake ≤ getup?
4. A blank raw time cannot be re-checked: `data_category` is `skipped_na`.
   Whether that counts as done is the user's rule
   (`review.missing_times_ok_after_manual`).
5. Report the cause and the options; let the user change the manual file.

## Review Rules and the End Point

The user, not the agent, defines what counts as done, in the config's
`review:` block (`done_when.max_needs_review`, `step8_flags_need_review`,
`missing_times_ok_after_manual`, `fail_if_not_done`, `suggestions`). An agent
running the pipeline must:

- read the verdict from `review_verdict()` (or the printed `Review DONE /
  NOT DONE` line) and report it as is; never declare the review finished
  on its own judgement, and never edit the `review:` block unless the user
  asks for that change;
- report the three counts of `review_status.csv` (`needs_review`,
  `not_incorporated`, `incorporated`) and list the `needs_review` rows with
  their `review_state_reason` as options for the user;
- treat `ai_label` suggestions as suggestions: a row stays open until a
  person fills in `human_decision`;
- check reproducibility with `Rscript validation/reproducibility.R`.

Step 8 labels a manually corrected record `CLEAN (Manually Fixed)` only when
its Step 8 checks and its `data_category` both pass; otherwise it keeps its
flag, or is `STILL FAILS (Manually Corrected)`, or `NOT CHECKABLE (Manually
Corrected)` when a time is missing.

## Fetching Results

The pipeline writes nothing to the global environment. `pipeline_results()`
returns `corrected_ema_data`, `review_output`, `checkforerrors_summary`,
`pipeline_config`, `review_status` and `review_verdict`; `cleaning_report()`
builds a prevalence report from them.

## Output

| Path | Contents |
|------|----------|
| `review_status.csv` (project root) | Both worksheets in one table; each row `needs_review` / `not_incorporated` / `incorporated` with its reason. Start here |
| `output/review_runs.csv` | One line per run: input/config/result hashes, data tag, counts, verdict |
| `output/effective_rules.csv` | The rules this run used (thresholds, `review.*`), each marked default or your config; also printed at the start of the run |
| `output/manual_corrections_not_applied.csv` | Manual duration rows the interval parser overruled (`manual_corrections.manual_overrides_parser: false`) |
| `output/second_review_rows_skipped.csv` | Second-review rows left out because `pid` / `day_num` is not a number |
| `[NEW]manual_error_correction_review.csv` (project root) | Status table of the Step 5 error list (kept for compatibility; `review_status.csv` supersedes it) |
| `[NEW]manual_unusual_review.csv` (project root) | Step 5 `unusual` records for a person to fill in |
| `manual_error_correction_updated.csv` (project root) | The corrections as applied; `manually_corrected` marks the rows really used |
| `output/cleaned_data_final.*`, `output/cleaned_data_prepostcorrection.*` | Delivered datasets A and B |
| `output/correction_status_final.csv`, `output/appendix_step_ledger.csv` | Per-run summary; per-step flag counts |
| `<figures>/RUN_INFO.txt`, `<figures>/figure_index.png` | Run provenance (incl. data tag and its source); contact sheet of all figures |

`<figures>` is `output/latest_visualization_real_n<rows>/` for `data.tag: real`
and `latest_visualization_<tag>_n<rows>/` in the project root otherwise.

The `[NEW]` prefix is literal. In R, list these files with
`list.files(pattern = "\\[NEW\\]")`; an unescaped `[NEW]*` is a regex
character class and matches nothing.
