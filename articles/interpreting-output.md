# Reading the Output and the Review Loop

[中文版
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output-zh.md)
· [Figures F01-F37
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference.md)

After
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
finishes, two CSV files tell you everything. This page explains how to
read them, how to run the manual-review loop until it converges, and how
to regression-check a run against the previous one.

The figures have their own page: **[Figure
Reference](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference.md)**
explains what every figure means, which folder it lands in, and which
ones to put in a paper. Section numbers below (§1-§7) refer to this
page; “figure reference §N” points at the other one.

Contents

- [Terminology and definitions](#s-terms)
  - [Sleep metrics](#s-terms-1)
  - [Record classification: `data_category`](#s-terms-2)
  - [Metric flags: `flag_severity`](#s-terms-3)
  - [“Standard”](#s-terms-4)
- [1. Running the pipeline](#s-1)
- [2. Manual input files](#s-2)
  - [2.1 Sample and template files](#s-2-1)
  - [2.2 Files the pipeline writes to the project root](#s-2-2)
- [3. The manual-review cycle (plain language)](#s-3)
- [4. `output/correction_status_final.csv` — The Run Summary (Open This
  First)](#s-4)
- [5. `output/step_flag_ledger.csv` — The Per-Step Flag Tracker (Open
  Second)](#s-5)
  - [5.1 Column layout](#s-5-1)
- [6. Regression Check (compare against a previous run)](#s-6)
- [7. Quick Reference Card](#s-7)
- [Figures F01-F37 — separate
  page](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference.md)

## Terminology and definitions

Every term the tables and figures use is defined here once.

### Sleep metrics

| Term | Meaning |
|----|----|
| **TIB** | Time in Bed — from lying down to getting up |
| **SOL** | Sleep Onset Latency — from lying down to actually falling asleep |
| **TST** | Total Sleep Time — time actually asleep |
| **WASO** | Wake After Sleep Onset — time awake during the night after first falling asleep |
| **SE** | Sleep Efficiency — the percentage of time in bed actually spent asleep |

They are tied together by an identity that holds throughout the figures:
`TIB = TST + SOL + WASO`, and `SE = TST / TIB`.

### Record classification: `data_category`

This describes the shape of a record’s *timestamps*. Every record falls
into exactly one class. The classes are checked in the priority order
below — the first match wins.

| Priority | Class | Rule | What happens to it |
|:--:|----|----|----|
| 1 | `skipped_na` | any of the four corrected timestamps (bed, sleep, awake, getup) is missing | left out of the order checks |
| 2 | `error` | the order is broken (not `bed ≤ sleep ≤ awake ≤ getup`); or `sleep = awake` (zero-length sleep); or a bed→sleep or awake→getup gap is longer than 7 h; or sleep→awake spans more than 24 h | always reviewed, and fixed once confirmed |
| 3 | `equal_time_ok` | order intact, and bed = sleep and/or awake = getup (difference under 0.01 h, about 36 seconds) | counts as valid; never queued for review |
| 4 | `unusual` | order intact and not equal-time, but a bed→sleep or awake→getup gap longer than 3 h | reviewed; usually kept as reported |
| 5 | `clean` | none of the above | nothing to do |
| — | `reasonable_unusual` | an `unusual` record that a human looked at and accepted | counted separately so the human judgement is not lost |

- **Equal Time is not an error.** Reporting “went to bed” and “fell
  asleep” (or “woke up” and “got up”) as the same clock time is a
  common, harmless way to fill in a diary. It is tracked as
  `bed_sleep_equal`, `awake_getup_equal` or `both_equal`
  (`equal_time_type`).
- **`sleep = awake` is always an error.** A night with zero sleep is a
  broken record, not a benign habit, so it can never be Equal Time.
- **The 0.01 h tolerance** only absorbs floating-point rounding; it does
  not hide real differences.
- **Sanity check:** the six classes add up to `n_total` (used by the
  ledger, §5). The rules live in `R/flag_standards.R`.

### Metric flags: `flag_severity`

This counts how many derived-metric problems a record triggers: sleep
efficiency below 70%, sleep onset latency above 1 h, and wake after
sleep onset above 1.5 h (defaults; set under
`classification.flag_severity.*`). `Clean` = 0 flags, `Minor` = 1 flag,
`Major` = 2 or more.

It is a **different system** from `data_category`: a record can be
`clean` in `data_category` and `Major` in `flag_severity` (order fine,
computed metrics extreme). The three classes add up to `n_total`.

### “Standard”

In the ledger (§5), a *standard* is one of the five evaluation systems —
`field_misentry`, `data_category`, `flag_severity`, `duration_extreme`,
`checkforerrors`. Each is computed once at a fixed pipeline step and
never recomputed.

## 1. Running the pipeline

Prepare the inputs first (§2), then run:

``` r
library(sleepcleanr)
run_pipeline(config = "my_study.yaml", include_manual_corrections = TRUE)  # full run
run_pipeline(config = "my_study.yaml", skip_visualization = TRUE)          # cleaning only, no figures
```

| Argument | What it does |
|----|----|
| `config` | Path to your config YAML (copy `inst/config_template.yaml` and edit the `data` section). |
| `include_manual_corrections` | **Default `FALSE`.** With `FALSE` the run is algorithmic-only: every human-review CSV is treated as absent, and a banner says no human corrections were applied. Set `TRUE` to apply the manual-correction files named in the config. It is off by default so a dataset can never be modified silently by review files left in the working directory. |
| `skip_visualization` | `TRUE` skips the figures (Steps 9 and F05). |
| `finalize` | Default `TRUE`: writes the delivered datasets (Step 10). `FALSE` stops after cleaning. |

**Say what the data is: `data.tag` in the config.** `real` (participant
data; figures go under `output/`, which is gitignored) or `synth`
(synthetic or test data; figures go outside `output/`). The pipeline
never guesses it. If it is not set and the run makes figures, an
interactive session asks once when the run starts (`r` / `s` / `n` to
stop), for that run only; a non-interactive run (`Rscript`, CI,
knitting) stops with an error that says what to add. Runs with
`skip_visualization = TRUE` do not need it. `RUN_INFO.txt` and
`output/review_runs.csv` record the tag and whether it came from the
config or from the prompt.

**`include_manual_corrections` is an argument, not a YAML setting.**
Writing it in the config file has no effect; it must be in the call. The
YAML only says *where* each human-review file is
(`data.files.manual_error`, …). Two things follow:

- **If a run prints `No corrections file found () — skipping`** for the
  nap/exercise, sleep-metric-duration and metric-acceptance steps, the
  empty `()` means the path was blanked on purpose: the run was
  algorithmic-only (`include_manual_corrections = FALSE`, the default).
  It is not a missing or misspelled file. Rerun with
  `include_manual_corrections = TRUE` to apply them.
- **The default changed in version 1.4.7.** Earlier versions applied the
  manual files in the config without being asked. After upgrading, the
  same call `run_pipeline(config = "my_study.yaml")` no longer applies
  them. Add `include_manual_corrections = TRUE` to reproduce an earlier
  full run.

Step 5 writes the `[NEW]` review worksheets in both modes.

From a shell you can also run `inst/scripts/run.sh` (installs the
package if missing, then runs
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
with the default config).

**Before a run:** the input data file (`data.files.main`, `.rds` or
`.csv`) and the manual CSVs of §2 must exist in the working directory;
the config YAML points at each. The `00a_setup` check reports exactly
which files are missing instead of failing silently.

**Advanced — reproducible human-review chain (fasttrack audit).** After
a pipeline run, the candidate-detection → review → rebuild chain is
scripted end to end with md5 integrity checks (repository checkout
only):

``` r
source("validation/reproduce_fasttrack_chain.R")   # derive → disambiguate →
                                                  # promote → rebuild; verifies
                                                  # byte-identical outputs
```

## 2. Manual input files

The pipeline reads up to seven human-review CSV files from the working
directory (paths configured under `data.files.*` in the config YAML;
`inst/scripts/00a_setup.R` checks for their presence at startup and
reports missing files). Each file is a REAL participant-data file — keep
it out of git and out of release builds (`.gitignore` + `.Rbuildignore`
cover them all).

| CSV (config key) | Consumed at | Why it exists | Created by |
|----|----|----|----|
| `second_review_checklist.csv` | Step 4.75 (`apply_second_review`) | Locks the second-review consensus for records that were previously reviewed, before corrections are applied | Started by hand; `apply_second_review` appends routed rows |
| `manual_error_corrections.csv` | Step 6 (`step_apply_corrections`) | Human correction decisions for records classified `error` | Step 5 writes `[NEW]manual_error_correction_review.csv`; reviewers fill `new_value_*` and it is saved under this name |
| `manual_unusual_corrections.csv` | Step 6 (`step_apply_corrections`) | Human decisions for records classified `unusual` | Step 5 writes `[NEW]manual_unusual_review.csv`; same review-fill flow |
| `manual_nap_exercise_corrections.csv` | Step 6.5 (`apply_nap_exercise_corrections`) | Corrections to nap and exercise durations | Hand-created; `apply_second_review` may append |
| `manual_sleep_metric_duration_corrections.csv` | Step 6.5 (`apply_sleep_metric_duration_corrections`) | Fixes internal inconsistencies in derived sleep durations | Hand-created |
| `manual_metric_review_acceptances.csv` | Step 6.5 (`apply_metric_review_acceptances`) | Manual accept/reject decisions for computed sleep metrics (TST, SOL, WASO, SE) | Hand-created; `apply_second_review` may append |
| `audit_dispositions.csv` | After Step 9 (`audit_data_integrity`) | Audit ledger recording the disposition of every changed record, for reversibility | Written by the pipeline itself |

**Audit ledger path:** the private audit ledger is optional. Name it in
the config as `data.files.audit_dispositions` (empty by default:
inactive, and `audit_disposition` is `"none"` for every row). If you
name a file that does not exist, the run stops rather than silently
writing `"none"`. The consistency check against the manual
metric-duration corrections uses the same file the run applied
(`data.files.manual_metric_duration`).

**Format:** each file is a plain CSV; the error/unusual files carry
`pid, day_num, row_id, variable, old_value_hhmm, old_value_ampm, new_value_hhmm, new_value_ampm, correction_type, confidence, reviewer_notes`
(the `[NEW]` review files from Step 5 are pre-filled with diagnostics —
fill the `new_value_*` and `reviewer_notes` columns). Column templates
live in `templates/template_*.csv`; `inst/extdata/stub_*.csv` are
shipped in the package as header-only format examples (no real data).

### 2.1 Sample and template files

You do not have to start from a blank file. Templates and virtual sample
data are provided:

| What | Where | Notes |
|----|----|----|
| Header-only stubs of the six review CSVs | `inst/extdata/stub_*.csv` (installed with the package) | `stub_error_corrections.csv`, `stub_unusual_corrections.csv`, `stub_nap_exercise.csv`, `stub_metric_duration.csv`, `stub_metric_accept.csv`, `stub_second_review.csv` — correct columns, no rows, no real data |
| Audit dispositions template | `inst/extdata/template_audit_dispositions.csv` | header only |
| Filled-in example templates | `templates/template_*.csv` in the GitHub repository | fictional example rows (e.g. participant 1001); **not** included in the installed package |
| Virtual sample dataset | `inst/extdata/synthetic_sleep_data.rds` and `synthetic_ema_data.csv` | 280 virtual diary rows, no real participants |
| Config for the virtual dataset | `inst/extdata/synthetic_config.yaml` | shows how to map column names for a new dataset |
| Column dictionary | `inst/extdata/column_dictionary.csv` | describes the delivered columns |

To find an installed file from R:

``` r
system.file("extdata", "stub_error_corrections.csv", package = "sleepcleanr")
```

Copy a stub to your working directory under the name your config
expects, then fill it in.

### 2.2 Files the pipeline writes to the project root

Besides `output/`, a run writes several working files **into the project
root** (the directory you passed as `project_dir`). They are
intermediate files for the review cycle, not final results. All of them
contain real participant rows — do not commit them.

| File | Written at | What it is | What to do with it |
|----|----|----|----|
| `[NEW]manual_error_correction_review.csv` | Step 5, **rewritten after Step 8.5** | One status table: every `error` record from Step 5 (same rows as `error_df_pre`) plus every record that became an error only after the corrections. Each row says what happened to it (`status_after_corrections`), whether it is in a manual file (`in_manual_file`), its category before and after the corrections, and its Step 8 flags. Ordered so the rows that still need a person come first. Reviewer columns are blank | Read `status_after_corrections`; act on the `..._still_fails` and `new_after_corrections` rows |
| `[NEW]manual_unusual_review.csv` | Step 5 | Same, for `unusual` records | Fill it in, save as `manual_unusual_corrections.csv` |
| `review_status.csv` | After Step 8.5, overwritten every run | **The one table to read.** Every row of both Step 5 worksheets, plus every record that became an error after the corrections, with one `review_state` (`needs_review`, `not_incorporated`, `incorporated`) and the rule that put it there (`review_state_reason`). `needs_review` rows come first | Act on the `needs_review` rows; the run prints whether the review is DONE by your rule (“Review states and the done rule” below) |
| `manual_error_correction_updated.csv` | Step 6 | The record of the corrections applied: **your** `manual_error_corrections.csv` after the pipeline incorporated it, with the `manually_corrected` column marking which rows were really used. Your own file is never edited; this is the pipeline’s copy | Compare with your input. A row you filled in but that is not marked `TRUE` was not applied — find out why. It is a record, not a new worklist |
| `reasonable_unusual_records.csv` | Step 6 | The `unusual` rows you marked “reasonable unusual record” (odd but plausible, left as is) | A record of what was accepted |
| `cross_participant_flagged_rows.csv` | Step 8.5 | Days whose SOL or WASO is far from that participant’s **own** median (for example 5–30 min on most days, 400 min on one) | Review as a possible entry error |
| `cross_participant_suspicious_slices.csv` | Step 8.5 | All days of the participants in the file above | Context: is the day a one-off or the participant’s usual pattern? |
| `cross_participant_field_misentries.csv` | Step 8.5 | Rows where the SOL or WASO number looks like it was typed into another time field | Review as a possible mis-entered field |

## 3. The manual-review cycle (plain language)

**Common question:** “the manual CSVs — are they generated by asking an
AI over and over, or by the pipeline itself? What decides that a record
needs a human?”

The answer: **the pipeline decides, by deterministic rules — no AI, no
randomness.** Every run of Step 5 re-classifies every record and writes
two “please review these” files. Humans (or AI as an assistant) only
ever fill in *what the correct value should be*. The cycle works like
this:

    Step 5: classify ALL records → write [NEW]manual_error_correction_review.csv
                                     and [NEW]manual_unusual_review.csv
       ↓
    Human review: fill in `column_to_correct` + `correct_value` (+ notes)
       ↓
    Remove the [NEW] prefix → save as manual_error_corrections.csv /
                                manual_unusual_corrections.csv
       ↓
    NEXT pipeline run: Step 6 applies your corrections, re-derives everything
       ↓
    Step 5 lists every record the rules flag on the data BEFORE corrections, so
       rows you already handled are listed again. Four columns tell you where
       (if anywhere) each row was handled; the run ends with a summary. Loop until
       no row is unhandled and none is still a problem (see "How to know you are done").

**What puts a record on the review pile (the exact rules, in priority
order):**

The hour limits below are the defaults. You can change each one under
`classification.step5` in your config (see [Input data and
configuration](https://cyracaid.github.io/sleepdiary-cleaner/articles/column-mapping.md));
every run prints the values it used and saves them in
`output/effective_rules.csv`. Where these defaults come from: the Step 5
limits are recorded in the project’s March 2026 logic document, and the
code has used the same values since the first release (July 2026) until
they became configuration. To reproduce the study’s results, keep the
defaults. All thresholds, with their rationale, are on the
[Thresholds](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.html)
page.

*ERROR — physically impossible, must be fixed
(`generate_correction_files.R:315`):* 1. `sleep_awake_equal_error` —
sleep time == awake time (a zero-length sleep period; the record is
fundamentally broken) 2. `order_error` — the bed → sleep → awake → getup
sequence is violated (e.g. get-up before bed) 3. `bed_sleep_diff_error`
— bed and sleep more than 7 h apart (nobody takes 7 hours to fall
asleep) 4. `awake_getup_diff_error` — more than 7 h between waking and
getting up 5. `sleep_awake_24h_error` — computed sleep period longer
than 24 h

*UNUSUAL — suspicious but possible, worth a look (`:393`):* 1.
`sleep_awake_suspicious` — total sleep \< 3 h or \> 15 h 2.
`bed_sleep_suspicious` — sleep onset latency \> 3 h 3.
`awake_getup_suspicious` — lying awake in bed \> 3 h before rising 4.
`multiple_suspicious` — several of the above at once

*Final label priority:* `error` \> `equal_time` \> `unusual` \>
`normal`. Equal-time records get a label but **never enter the review
files** — they are benign (see the Terminology section).

**What is inside a `[NEW]` review file** (columns, in order):

| Column group | Columns | Meaning |
|----|----|----|
| Identity | `pid`, `day_num`, `row_id` | Which participant, which day, which row |
| Raw entries | `time_bed/sleep/awake/getup_am_hhmm_ampm` | What the participant typed (unchanged) |
| Parsed times | `time_bed/sleep/awake/getup_corrected` | Pipeline’s current best guess |
| Diffs | `bed_sleep_diff_h`, `sleep_awake_diff_h`, `awake_getup_diff_h`, `reasonable_temporal_order` | The numbers the rules above fired on |
| Machine verdict | `error_type`, `corrected`, `correction_type` | Which rule fired; whether the algorithm already fixed it |
| **Human fills in** | `problem_humanidentified`, `solution_humanidentified`, `column_to_correct`, `correct_value`, `manually_corrected` | Blank columns — write which column is wrong, what the right value is, and whether you fixed it |
| **Status** (added after the corrections) | `source`, `status_after_corrections`, `category_before_corrections`, `category_after_corrections`, `step8_flags_after_corrections` | Where the row came from and what happened to it (see below). Step 8 flags are reported separately and do not change the status |
| **Where it was handled** (added by the pipeline) | `in_manual_file`, `review_resolution`, `resolved_at`, `resolved_by` | Copied from the matching row of your manual file. All four empty means nobody has handled this record yet |

**How to read the status table.** Step 5 first writes every record the
rules flag on the data *before* corrections. After Steps 6–8.5 the
pipeline rewrites `[NEW]manual_error_correction_review.csv` as one table
in which no row is dropped. `status_after_corrections` is one of:

| `status_after_corrections` | Meaning |
|----|----|
| `not_in_manual_file_still_fails` | Not in any manual file and not clean after the corrections — to do |
| `in_manual_file_still_fails` | In a manual file, but still not clean — the correction did not work |
| `new_after_corrections` | Not on the Step 5 list; became an error only after the corrections |
| `not_in_manual_file_now_passes` | Not in a manual file; the rules fixed it |
| `in_manual_file_now_passes` | In a manual file and now clean |

“Clean” means the final category is `clean`, `equal_time_ok` or
`reasonable_unusual`. The pipeline reports; it does not decide when a
row is finished. `step8_flags_after_corrections` shows any Step 8 flag
on the row (for example a long SOL) and you decide whether that counts
as a problem. Rows are ordered so that the ones that still need a person
come first, in the same order every run. The four columns
`in_manual_file`, `review_resolution`, `resolved_at`, `resolved_by`
still say where a row was handled:

| What you see | Meaning |
|----|----|
| all four empty | never handled — to do |
| `corrected` with `resolved_by` | handled and recorded |
| `resolution_unknown_legacy` / `legacy` | handled, but nobody recorded who or when (you can fill that in) |
| `flagged_unresolved`, or `resolved_by` = `pending` | waiting for confirmation |

At the end of each run the pipeline prints how many rows of each
worksheet are in each state, and how many handled rows are **still a
problem after the automatic re-check** (still an error, or still
flagged). Corrected records can still fail that re-check, so that last
number matters. When the review counts as done is **your** rule, written
in the config, not something the pipeline decides (see “Review states
and the done rule” below). On the real study data this ended with 75
error + 37 unusual human-verified corrections (see the Methods section,
Stage 5).

**Review states and the done rule.** `review_status.csv` (project root)
puts every row of *both* worksheets, plus every record that became an
error after the corrections, into exactly one `review_state`. Which
state a row gets is decided only by the rules below and by the `review:`
block of your config; the pipeline applies them and never changes them
during a run.

| `review_state` | Rule (first that applies) |
|----|----|
| `needs_review` | became an error after the corrections; or marked pending (`flagged_unresolved` / `resolved_by` = `pending`) in the manual file; or still fails the re-check; or has a time missing after the corrections, so the order cannot be re-checked (unless it is in a manual file and `review.missing_times_ok_after_manual: true`); or — only if `review.step8_flags_need_review: true` — has a Step 8 flag |
| `incorporated` | a manual decision for it was applied in this run, and it passes the re-check |
| `not_incorporated` | no manual decision changed it in this run, and it passes the re-check (the rules fixed it, or manual corrections were not applied) |

`review_state_reason` names the rule for each row. The review is
**DONE** when the number of `needs_review` rows is at most
`review.done_when.max_needs_review` (default `0`). Every run prints the
verdict;
[`review_verdict()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/review_verdict.md)
returns it, and `review.fail_if_not_done: true` stops the run with an
error, after every output is written, when it is NOT DONE (useful in
CI). In an algorithmic-only run nothing can be `incorporated`, and the
printout says so.

Each run also adds one line to `output/review_runs.csv` (one file for
all runs; no new file per run): content hashes of the data, the manual
files and the config, the hash of `review_status.csv`, the three counts
and the verdict. After deleting and rebuilding an environment, compare
the last two lines to see whether the inputs or the result changed; the
run prints that comparison. `Rscript validation/reproducibility.R`
checks that the same input gives identical outputs in new directories
and new R processes.

**Where the validated numbers come from (historical, 1.6.x era):** a
controlled re-run (2026-09-29) showed exactly what the manual
corrections do to the final dataset: without them, 1,719 records have
computable total sleep time and 61 remain in the `error` class; with
them, 1,729 records are valid (+10 net), 85 records carry a manual
correction, and only 3 records remain errors. The 11 unlocked records
were `error`-class rows whose corrected timestamps made TST computable
(293–590 min); one extreme record (TST = 10 min) was correctly retired
by its correction.

**Current as of 1.7.1** (records confirmed 2026-10-29): the delivered
error count is **0** – the three records whose reviewers wrote
undo-then-reapply instructions (2854/13, 6985/7, 6985/12) now have both
steps executed and pass; the review loop converges (Review DONE: 100/100
incorporated, 0 needs_review); 85 records carry human corrections; 46
ambiguous self-reported durations are delivered with their raw text and
a flag (`sol/waso_selfreport_ambiguous/raw`, see the question table in
the output-files article).

## 4. `output/correction_status_final.csv` — The Run Summary (Open This First)

One row per pipeline run. It answers: *“did the cleaning work as
expected?”*

``` r
read.csv("output/correction_status_final.csv")
```

| Column | It tells you… | Check this |
|----|----|----|
| `n_total` | Total records in your data | Must equal your input row count. If smaller, records were dropped somewhere. |
| `run_id`, `timestamp` | When the run was made (`YYYYMMDD_HHMM` and full time) | Rows are appended, so each run adds one row; use these to tell runs apart. |
| `checkpoint_first`, `checkpoint_last` | Which two checkpoints `*_first` and `*_last` below were read at (see the box after this table) | Usually `A` and `E`. |
| `tst_mean_h` | Mean total sleep time in hours | 6.0–8.5 h is normal for most adult studies. If \< 5 or \> 10, something is off with the timestamp parsing or the study population is unusual. |
| `sol_mean_min` | Mean sleep onset latency in minutes | 10–45 min is normal. If \> 60, either the population has high insomnia or AM/PM confusion was not fully corrected. |
| `n_clean_first`, `n_clean_last`, `delta_clean` | Records that passed every check at the first and at the last checkpoint; `delta_clean = n_clean_last - n_clean_first` | `n_clean_last` should be stable across runs (same data = same count). `delta_clean` \> 0 means cleaning made records clean. |
| `n_error_first`, `n_error_last`, `delta_error` | Records with impossible temporal order (e.g., getup before bedtime) at the first and at the last checkpoint; `delta_error = n_error_last - n_error_first` | Judge `n_error_last` (what is left after cleaning): should be \< 1% of total; if \> 5%, review the survey design or data collection. `n_error_first` is before cleaning and is expected to be higher. `delta_error` \< 0 means errors were removed. |
| `n_corrected` | Records manually corrected via your CSV files | Should match the number of rows in your `manual_error_corrections.csv`. |
| `timestamp_issue` | Timestamps that could not be parsed into a valid time | 0 is normal. \> 0 means some participants entered non-standard time formats. |
| `duration_issue` | Sleep metrics (SOL, SE, TST) outside configured thresholds | Small numbers are normal. If very large, your thresholds may be too strict or the data has quality problems. |
| `amount_flag` | Substance-use entries with unusual values | Should be 0 or very low. |
| `self_reported_flag` | Records where self-reported SOL/WASO disagrees with the computed value | Indicates perception bias. Check F24 (SOL Perception Bias) in the [figure reference](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference.md). |

**What `first` and `last` mean.** Both are snapshots taken inside the
*same* run, not two runs and not the first and last row of the data. The
pipeline counts the records in each class (`data_category`) at five
checkpoints:

| ID  | Taken after                                     |
|-----|-------------------------------------------------|
| `A` | Step 4 (auto-normalize: rule-based corrections) |
| `B` | Step 6 (timestamp corrections)                  |
| `C` | Step 6.5 (duration corrections)                 |
| `D` | Step 7 (metrics computed)                       |
| `E` | Step 8 (auto-detection, the end of the run)     |

`*_first` is the first checkpoint at which records have been classified
(normally `A`), `*_last` is the final checkpoint (normally `E`), and the
two used are written in `checkpoint_first` and `checkpoint_last`.
`delta_*` is `last - first`. Read the `last` values for the state of the
data you will analyse, and the `delta` values for what the cleaning did.

**Stability rule:** Run twice on the same data → every number must be
identical. If not, something is non-deterministic.

**A note on SOL:** `sol_mean_min` above is the **raw SOL duration**.
This is a different quantity from the “SOL perception bias” checked by
F24 (the gap between self-reported and computed SOL, in figure reference
§5) — the two use different reference numbers (10–45 min here vs. 15/60
min there) because they measure different things. Don’t read one against
the other.

## 5. `output/step_flag_ledger.csv` — The Per-Step Flag Tracker (Open Second)

One row per step × per standard × per category. It answers: *“at which
step did which flag appear, and did it persist?”*

``` r
ledger <- read.csv("output/step_flag_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

Each row answers: *“at this step, using this standard, how many records
fell into this category?”*

### 5.1 Column layout

| Column | What it is |
|----|----|
| `step_id` | Pipeline step number |
| `label` | Human-readable step name |
| `n_total` | Total records in the pipeline at this point |
| `standard` | The evaluation system being tracked (see below) |
| `category` | The specific category within that standard |
| `count` | Number of records in this category (NA = not yet computed at this step) |
| `n_corrected` | Records manually corrected at this step |

The ledger uses 5 independent evaluation systems:

| Standard | First step with numbers | What it evaluates | Key categories |
|----|:--:|----|----|
| `field_misentry` | 1.5 | Whether a duration estimate (SOL, WASO) exactly matches a timestamp — may indicate “typed in wrong box” | `none`, `SOL=time_sleep`, `SOL=time_bed`, `WASO=time_awake`, `WASO=time_getup` |
| `data_category` | 4 | Temporal order and plausibility of the bed → sleep → awake → getup sequence | `clean`, `error`, `unusual`, `equal_time_ok`, `skipped_na` |
| `flag_severity` | 7 | How many derived-metric flags (low SE, high SOL, high WASO) each record triggered | `Clean`, `Minor (1 flag)`, `Major (2+ flags)` |
| `duration_extreme` | 7 | Total sleep time outside physiologically plausible bounds | `OK`, `Too short (< 3 h)`, `Too long (> 12 h)` |
| `checkforerrors` | 8 | Summary of all auto-detection flags assembled in Step 8 | `TIMESTAMP_ISSUE`, `DURATION_ISSUE`, `AMOUNT_FLAG`, `SELF_REPORTED_FLAG` |

**Conceptual rule:** Standards are computed once and never re-computed.
If a standard’s counts change after its first computation step,
something is wrong.

**Validation rules:**

1.  `field_misentry` — populated from Step 1.5 onward. Any
    `SOL=time_bed` or `WASO=time_getup` with `count > 0` = potential
    cross-field contamination.
2.  `data_category` — from Step 6 onward the numbers must be **stable**:
    `clean + unusual + reasonable_unusual + equal_time_ok + error + skipped_na = n_total`.
3.  `flag_severity` — from Step 7 onward identical across Steps 7, 8,
    8.5: `Clean + Minor + Major = n_total`.
4.  `duration_extreme` — `Too short + Too long` should be \< 5% of
    `n_total`.
5.  `checkforerrors` — populated at Step 8 only.

**Example (synthetic data, 280 rows):**

    Step 7 (Compute metrics):
      data_category:    equal_time_ok = 266, skipped_na = 14        266 + 14 = 280 ✓
      flag_severity:    Clean = 251, Minor = 28, Major = 1         251 + 28 + 1 = 280 - 14 ✓
      duration_extreme: OK = 262, Too short = 1, Too long = 0

## 6. Regression Check (compare against a previous run)

`output/correction_status_old.csv` is not written by any pipeline script
— you create it yourself as a saved baseline before rerunning:

``` r
# BEFORE rerunning: save the current output as your baseline.
file.copy("output/correction_status_final.csv", "output/correction_status_old.csv",
          overwrite = TRUE)
# ... rerun the pipeline here ...
# AFTER rerunning: compare against the baseline.
old <- read.csv("output/correction_status_old.csv")
new <- read.csv("output/correction_status_final.csv")
identical(old$tst_mean_h, new$tst_mean_h)
identical(old$sol_mean_min, new$sol_mean_min)
identical(old$n_clean_last, new$n_clean_last)
```

If they differ and the input data did not change, the pipeline output
has changed. Investigate.

## 7. Quick Reference Card

| Check | What to run | Pass if |
|----|----|----|
| Pipeline finished | `file.exists("output/correction_status_final.csv")` | `TRUE` |
| Reasonable TST | `tst_mean_h` between 6–8.5 | Yes |
| Reasonable SOL (raw duration, not perception bias) | `sol_mean_min` between 10–45 | Yes |
| Few errors | `n_error_last < 0.01 * n_total` | Yes |
| data_category stable | Counts identical across Steps 6–8.5 | Yes |
| flag_severity stable | Counts identical across Steps 7–8.5 | Yes |
| All records accounted | `clean + unusual + reasonable_unusual + equal_time_ok + error + skipped_na = n_total` | Yes |
| Deterministic | Same input → same output every time | Yes |

## Next

The 37 figures the pipeline draws are documented one by one in the
**[Figure
Reference](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference.md)**:
what each part means, the rule it is built from, what healthy data look
like, and a paper-ready caption.
