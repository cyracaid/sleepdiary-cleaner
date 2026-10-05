<div id="main" class="col-md-9" role="main">

# Interpreting the Pipeline Output

[中文版
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output-zh.md)

After `run_pipeline()` finishes, two CSV files tell you everything. This
vignette explains how to read them, how to regression-check against a
previous run, and how to read the figures.

Sections 1–3 cover running the pipeline and the manual input files; 4–7
cover the two output CSVs, the regression check and the quick reference
card; 8–9 cover the figures.

Contents

-   [Terminology and definitions](#s-terms)
    -   [Sleep metrics](#s-terms-1)
    -   [Record classification: `data_category`](#s-terms-2)
    -   [Metric flags: `flag_severity`](#s-terms-3)
    -   [“Standard”](#s-terms-4)
-   [1. Running the pipeline](#s-1)
-   [2. Manual input files](#s-2)
    -   [2.1 Sample and template files](#s-2-1)
-   [3. The manual-review cycle (plain language)](#s-3)
-   [4. `output/correction_status_final.csv` — The Run Summary (Open
    This First)](#s-4)
-   [5. `output/step_flag_ledger.csv` — The Per-Step Flag Tracker (Open
    Second)](#s-5)
    -   [5.1 Column layout](#s-5-1)
-   [6. Regression Check (compare against a previous run)](#s-6)
-   [7. Quick Reference Card](#s-7)
-   [8. How to Read the Figures](#s-8)
-   [9. Figure-by-Figure Reference](#s-9)
    -   [9.1 Figure Index](#s-9-1)
    -   [9.2 Pipeline-cleaning figure cards (`pipeline_cleaning/`) (15
        figures)](#s-9-2)
        -   [01 · Pipeline Record Flow](#01-pipeline-record-flow)
        -   [06 · Sleep Duration
            Post-Correction](#06-sleep-duration-post-correction)
        -   [07 · Flag Composition
            Stacked](#07-flag-composition-stacked)
        -   [10 · Extreme Sleep Durations](#10-extreme-sleep-durations)
        -   [13 · Error Category
            Distribution](#13-error-category-distribution)
        -   [13B · Adjacent Timestamp
            Gaps](#13b-adjacent-timestamp-gaps)
        -   [13C · Detection Outcomes
            Heatmap](#13c-detection-outcomes-heatmap)
        -   [13D · Threshold vs Measurement
            Noise](#13d-threshold-vs-measurement-noise)
        -   [14 · Sleep Duration
            Pre-Correction](#14-sleep-duration-pre-correction)
        -   [15 · Error Timeline](#15-error-timeline)
        -   [16 · Common Error Patterns](#16-common-error-patterns)
        -   [17 · Top Participants by Flag
            Rate](#17-top-participants-by-flag-rate)
        -   [18 · Auto-Detected Dashboard](#18-auto-detected-dashboard)
        -   [A1 · Step Flag Ledger](#a1-step-flag-ledger)
        -   [P26 · Participants Worth a Second
            Look](#p26-participants-worth-a-second-look)
    -   [9.3 Research-ready figure cards (`research_ready/`) (16
        figures)](#s-9-3)
        -   [02 · Correction Impact](#02-correction-impact)
        -   [02B · Distribution of Sleep
            Variables](#02b-distribution-of-sleep-variables)
        -   [03 · TST Distribution](#03-tst-distribution)
        -   [04 · Sleep Duration vs Time in
            Bed](#04-sleep-duration-vs-time-in-bed)
        -   [04B · SOL vs Sleep Duration](#04b-sol-vs-sleep-duration)
        -   [05 · Variability of Sleep
            Variables](#05-variability-of-sleep-variables)
        -   [09 · Bedtime vs Get-up
            Distribution](#09-bedtime-vs-get-up-distribution)
        -   [20 · SOL Perception Bias](#20-sol-perception-bias)
        -   [20B · WASO Perception Bias](#20b-waso-perception-bias)
        -   [21 · Substance Use
            Availability](#21-substance-use-availability)
        -   [22 · Substance Use Value
            Distribution](#22-substance-use-value-distribution)
        -   [23 · Caffeine Consumption](#23-caffeine-consumption)
        -   [24 · Alcohol Consumption](#24-alcohol-consumption)
        -   [R25 · Sleep Regularity — Weekday vs
            Weekend](#r25-sleep-regularity--weekday-vs-weekend)
        -   [R26 · Sleep Composition — TIB
            Breakdown](#r26-sleep-composition--tib-breakdown)
        -   [R27 · Sleep Metrics Correlation
            Matrix](#r27-sleep-metrics-correlation-matrix)

<div class="section level2">

## Terminology and definitions

Every term the tables and figures use is defined here once.

<div class="section level3">

### Sleep metrics

| Term     | Meaning                                                                         |
|----------|---------------------------------------------------------------------------------|
| **TIB**  | Time in Bed — from lying down to getting up                                     |
| **SOL**  | Sleep Onset Latency — from lying down to actually falling asleep                |
| **TST**  | Total Sleep Time — time actually asleep                                         |
| **WASO** | Wake After Sleep Onset — time awake during the night after first falling asleep |
| **SE**   | Sleep Efficiency — the percentage of time in bed actually spent asleep          |

They are tied together by an identity that holds throughout the figures:
`TIB = TST + SOL + WASO`, and `SE = TST / TIB`.

</div>

<div class="section level3">

### Record classification: `data_category`

This describes the shape of a record’s *timestamps*. Every record falls
into exactly one class. The classes are checked in the priority order
below — the first match wins.

| Priority | Class                | Rule                                                                                                                                                                                       | What happens to it                                    |
|:--------:|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
|    1     | `skipped_na`         | any of the four corrected timestamps (bed, sleep, awake, getup) is missing                                                                                                                 | left out of the order checks                          |
|    2     | `error`              | the order is broken (not `bed ≤ sleep ≤ awake ≤ getup`); or `sleep = awake` (zero-length sleep); or a bed→sleep or awake→getup gap is longer than 7 h; or sleep→awake spans more than 24 h | always reviewed, and fixed once confirmed             |
|    3     | `equal_time_ok`      | order intact, and bed = sleep and/or awake = getup (difference under 0.01 h, about 36 seconds)                                                                                             | counts as valid; never queued for review              |
|    4     | `unusual`            | order intact and not equal-time, but a bed→sleep or awake→getup gap longer than 3 h                                                                                                        | reviewed; usually kept as reported                    |
|    5     | `clean`              | none of the above                                                                                                                                                                          | nothing to do                                         |
|    —     | `reasonable_unusual` | an `unusual` record that a human looked at and accepted                                                                                                                                    | counted separately so the human judgement is not lost |

-   **Equal Time is not an error.** Reporting “went to bed” and “fell
    asleep” (or “woke up” and “got up”) as the same clock time is a
    common, harmless way to fill in a diary. It is tracked as
    `bed_sleep_equal`, `awake_getup_equal` or `both_equal`
    (`equal_time_type`).
-   **`sleep = awake` is always an error.** A night with zero sleep is a
    broken record, not a benign habit, so it can never be Equal Time.
-   **The 0.01 h tolerance** only absorbs floating-point rounding; it
    does not hide real differences.
-   **Sanity check:** the six classes add up to `n_total` (used by the
    ledger, §5). The rules live in `R/flag_standards.R`.

</div>

<div class="section level3">

### Metric flags: `flag_severity`

This counts how many derived-metric problems a record triggers: sleep
efficiency below 70%, sleep onset latency above 1 h, and wake after
sleep onset above 1.5 h (defaults; set under
`classification.flag_severity.*`). `Clean` = 0 flags, `Minor` = 1 flag,
`Major` = 2 or more.

It is a **different system** from `data_category`: a record can be
`clean` in `data_category` and `Major` in `flag_severity` (order fine,
computed metrics extreme). The three classes add up to `n_total`.

</div>

<div class="section level3">

### “Standard”

In the ledger (§5), a *standard* is one of the five evaluation systems —
`field_misentry`, `data_category`, `flag_severity`, `duration_extreme`,
`checkforerrors`. Each is computed once at a fixed pipeline step and
never recomputed.

</div>

</div>

<div class="section level2">

## 1. Running the pipeline

Prepare the inputs first (§2), then run:

<div id="cb1" class="sourceCode">

``` r
library(sleepcleanr)
run_pipeline(config = "my_study.yaml", include_manual_corrections = TRUE)  # full run
run_pipeline(config = "my_study.yaml", skip_visualization = TRUE)          # cleaning only, no figures
```

</div>

| Argument                     | What it does                                                                                                                                                                                                                                                                                                                                          |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `config`                     | Path to your config YAML (copy `inst/config_template.yaml` and edit the `data` section).                                                                                                                                                                                                                                                              |
| `include_manual_corrections` | **Default `FALSE`.** With `FALSE` the run is algorithmic-only: every human-review CSV is treated as absent, and a banner says no human corrections were applied. Set `TRUE` to apply the manual-correction files named in the config. It is off by default so a dataset can never be modified silently by review files left in the working directory. |
| `skip_visualization`         | `TRUE` skips the figures (Steps 9 and 11).                                                                                                                                                                                                                                                                                                            |
| `finalize`                   | Default `TRUE`: writes the delivered datasets (Step 10). `FALSE` stops after cleaning.                                                                                                                                                                                                                                                                |

From a shell you can also run `inst/scripts/run.sh` (installs the
package if missing, then runs `run_pipeline()` with the default config).

**Before a run:** the input data file (`data.files.main`, `.rds` or
`.csv`) and the manual CSVs of §2 must exist in the working directory;
the config YAML points at each. The `00a_setup` check reports exactly
which files are missing instead of failing silently.

**Advanced — reproducible human-review chain (fasttrack audit).** After
a pipeline run, the candidate-detection → review → rebuild chain is
scripted end to end with md5 integrity checks (repository checkout
only):

<div id="cb2" class="sourceCode">

``` r
source("validation/reproduce_fasttrack_chain.R")   # derive → disambiguate →
                                                  # promote → rebuild; verifies
                                                  # byte-identical outputs
```

</div>

</div>

<div class="section level2">

## 2. Manual input files

The pipeline reads up to seven human-review CSV files from the working
directory (paths configured under `data.files.*` in the config YAML;
`inst/scripts/00a_setup.R` checks for their presence at startup and
reports missing files). Each file is a REAL participant-data file — keep
it out of git and out of release builds (`.gitignore` + `.Rbuildignore`
cover them all).

| CSV (config key)                               | Consumed at                                          | Why it exists                                                                                               | Created by                                                                                                            |
|------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| `second_review_checklist.csv`                  | Step 4.75 (`apply_second_review`)                    | Locks the second-review consensus for records that were previously reviewed, before corrections are applied | Started by hand; `apply_second_review` appends routed rows                                                            |
| `manual_error_corrections.csv`                 | Step 6 (`step_apply_corrections`)                    | Human correction decisions for records classified `error`                                                   | Step 5 writes `[NEW]manual_error_correction_review.csv`; reviewers fill `new_value_*` and it is saved under this name |
| `manual_unusual_corrections.csv`               | Step 6 (`step_apply_corrections`)                    | Human decisions for records classified `unusual`                                                            | Step 5 writes `[NEW]manual_unusual_review.csv`; same review-fill flow                                                 |
| `manual_nap_exercise_corrections.csv`          | Step 6.5 (`apply_nap_exercise_corrections`)          | Corrections to nap and exercise durations                                                                   | Hand-created; `apply_second_review` may append                                                                        |
| `manual_sleep_metric_duration_corrections.csv` | Step 6.5 (`apply_sleep_metric_duration_corrections`) | Fixes internal inconsistencies in derived sleep durations                                                   | Hand-created                                                                                                          |
| `manual_metric_review_acceptances.csv`         | Step 6.5 (`apply_metric_review_acceptances`)         | Manual accept/reject decisions for computed sleep metrics (TST, SOL, WASO, SE)                              | Hand-created; `apply_second_review` may append                                                                        |
| `audit_dispositions.csv`                       | After Step 9 (`audit_data_integrity`)                | Audit ledger recording the disposition of every changed record, for reversibility                           | Written by the pipeline itself                                                                                        |

**Format:** each file is a plain CSV; the error/unusual files carry
`pid, day_num, row_id, variable, old_value_hhmm, old_value_ampm, new_value_hhmm, new_value_ampm, correction_type, confidence, reviewer_notes`
(the `[NEW]` review files from Step 5 are pre-filled with diagnostics —
fill the `new_value_*` and `reviewer_notes` columns). Column templates
live in `templates/template_*.csv`; `inst/extdata/stub_*.csv` are
shipped in the package as header-only format examples (no real data).

<div class="section level3">

### 2.1 Sample and template files

You do not have to start from a blank file. Templates and virtual sample
data are provided:

| What                                     | Where                                                                | Notes                                                                                                                                                                                                          |
|------------------------------------------|----------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Header-only stubs of the six review CSVs | `inst/extdata/stub_*.csv` (installed with the package)               | `stub_error_corrections.csv`, `stub_unusual_corrections.csv`, `stub_nap_exercise.csv`, `stub_metric_duration.csv`, `stub_metric_accept.csv`, `stub_second_review.csv` — correct columns, no rows, no real data |
| Audit dispositions template              | `inst/extdata/template_audit_dispositions.csv`                       | header only                                                                                                                                                                                                    |
| Filled-in example templates              | `templates/template_*.csv` in the GitHub repository                  | fictional example rows (e.g. participant 1001); **not** included in the installed package                                                                                                                      |
| Virtual sample dataset                   | `inst/extdata/synthetic_sleep_data.rds` and `synthetic_ema_data.csv` | 280 virtual diary rows, no real participants                                                                                                                                                                   |
| Config for the virtual dataset           | `inst/extdata/synthetic_config.yaml`                                 | shows how to map column names for a new dataset                                                                                                                                                                |
| Column dictionary                        | `inst/extdata/column_dictionary.csv`                                 | describes the delivered columns                                                                                                                                                                                |

To find an installed file from R:

<div id="cb3" class="sourceCode">

``` r
system.file("extdata", "stub_error_corrections.csv", package = "sleepcleanr")
```

</div>

Copy a stub to your working directory under the name your config
expects, then fill it in.

</div>

</div>

<div class="section level2">

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
`sleep_awake_suspicious` — total sleep &lt; 3 h or &gt; 15 h 2.
`bed_sleep_suspicious` — sleep onset latency &gt; 3 h 3.
`awake_getup_suspicious` — lying awake in bed &gt; 3 h before rising 4.
`multiple_suspicious` — several of the above at once

*Final label priority:* `error` &gt; `equal_time` &gt; `unusual` &gt;
`normal`. Equal-time records get a label but **never enter the review
files** — they are benign (see the Terminology section).

**What is inside a `[NEW]` review file** (columns, in order):

| Column group                                     | Columns                                                                                                           | Meaning                                                                                                   |
|--------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| Identity                                         | `pid`, `day_num`, `row_id`                                                                                        | Which participant, which day, which row                                                                   |
| Raw entries                                      | `time_bed/sleep/awake/getup_am_hhmm_ampm`                                                                         | What the participant typed (unchanged)                                                                    |
| Parsed times                                     | `time_bed/sleep/awake/getup_corrected`                                                                            | Pipeline’s current best guess                                                                             |
| Diffs                                            | `bed_sleep_diff_h`, `sleep_awake_diff_h`, `awake_getup_diff_h`, `reasonable_temporal_order`                       | The numbers the rules above fired on                                                                      |
| Machine verdict                                  | `error_type`, `corrected`, `correction_type`                                                                      | Which rule fired; whether the algorithm already fixed it                                                  |
| **Human fills in**                               | `problem_humanidentified`, `solution_humanidentified`, `column_to_correct`, `correct_value`, `manually_corrected` | Blank columns — write which column is wrong, what the right value is, and whether you fixed it            |
| **Where it was handled** (added by the pipeline) | `in_manual_file`, `review_resolution`, `resolved_at`, `resolved_by`                                               | Copied from the matching row of your manual file. All four empty means nobody has handled this record yet |

**How to know you are done.** The `[NEW]` files always list every record
the rules flag on the data as it stands *before* corrections, so they do
not shrink to empty. Read the four added columns instead:

| What you see                                       | Meaning                                                         |
|----------------------------------------------------|-----------------------------------------------------------------|
| all four empty                                     | never handled — to do                                           |
| `corrected` with `resolved_by`                     | handled and recorded                                            |
| `resolution_unknown_legacy` / `legacy`             | handled, but nobody recorded who or when (you can fill that in) |
| `flagged_unresolved`, or `resolved_by` = `pending` | waiting for confirmation                                        |

At the end of each run the pipeline prints how many rows of each
worksheet are in each state, and how many handled rows are **still a
problem after the automatic re-check** (still an error, or still
flagged). Corrected records can still fail that re-check, so that last
number matters. You are done when no row is unhandled or pending and
none is still a problem. On the real study data this ended with 75 error
+ 37 unusual human-verified corrections (see the Methods section, Stage
5).

**Where the validated numbers come from:** a controlled re-run
(2026-09-29) showed exactly what the manual corrections do to the final
dataset: without them, 1,719 records have computable total sleep time
and 61 remain in the `error` class; with them, 1,729 records are valid
(+10 net), 85 records carry a manual correction, and only 3 records
remain errors. The 11 unlocked records were `error`-class rows whose
corrected timestamps made TST computable (293–590 min); one extreme
record (TST = 10 min) was correctly retired by its correction.

</div>

<div class="section level2">

## 4. `output/correction_status_final.csv` — The Run Summary (Open This First)

One row per pipeline run. It answers: *“did the cleaning work as
expected?”*

<div id="cb5" class="sourceCode">

``` r
read.csv("output/correction_status_final.csv")
```

</div>

| Column               | It tells you…                                                          | Check this                                                                                                                                        |
|----------------------|------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `n_total`            | Total records in your data                                             | Must equal your input row count. If smaller, records were dropped somewhere.                                                                      |
| `tst_mean_h`         | Mean total sleep time in hours                                         | 6.0–8.5 h is normal for most adult studies. If &lt; 5 or &gt; 10, something is off with the timestamp parsing or the study population is unusual. |
| `sol_mean_min`       | Mean sleep onset latency in minutes                                    | 10–45 min is normal. If &gt; 60, either the population has high insomnia or AM/PM confusion was not fully corrected.                              |
| `n_clean`            | Records that passed every check                                        | Should be stable across runs (same data = same count).                                                                                            |
| `n_error`            | Records with impossible temporal order (e.g., getup before bedtime)    | Should be &lt; 1% of total. If &gt; 5%, review the survey design or data collection.                                                              |
| `n_corrected`        | Records manually corrected via your CSV files                          | Should match the number of rows in your `manual_error_corrections.csv`.                                                                           |
| `timestamp_issue`    | Timestamps that could not be parsed into a valid time                  | 0 is normal. &gt; 0 means some participants entered non-standard time formats.                                                                    |
| `duration_issue`     | Sleep metrics (SOL, SE, TST) outside configured thresholds             | Small numbers are normal. If very large, your thresholds may be too strict or the data has quality problems.                                      |
| `amount_flag`        | Substance-use entries with unusual values                              | Should be 0 or very low.                                                                                                                          |
| `self_reported_flag` | Records where self-reported SOL/WASO disagrees with the computed value | Indicates perception bias. Check Figure 20 (SOL Perception Bias).                                                                                 |

**Stability rule:** Run twice on the same data → every number must be
identical. If not, something is non-deterministic.

**A note on SOL:** `sol_mean_min` above is the **raw SOL duration**.
This is a different quantity from the “SOL perception bias” checked by
Figure 20 (the gap between self-reported and computed SOL, in §9.3) —
the two use different reference numbers (10–45 min here vs. 15/60 min
there) because they measure different things. Don’t read one against the
other.

</div>

<div class="section level2">

## 5. `output/step_flag_ledger.csv` — The Per-Step Flag Tracker (Open Second)

One row per step × per standard × per category. It answers: *“at which
step did which flag appear, and did it persist?”*

<div id="cb6" class="sourceCode">

``` r
ledger <- read.csv("output/step_flag_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

</div>

Each row answers: *“at this step, using this standard, how many records
fell into this category?”*

<div class="section level3">

### 5.1 Column layout

| Column        | What it is                                                              |
|---------------|-------------------------------------------------------------------------|
| `step_id`     | Pipeline step number                                                    |
| `label`       | Human-readable step name                                                |
| `n_total`     | Total records in the pipeline at this point                             |
| `standard`    | The evaluation system being tracked (see below)                         |
| `category`    | The specific category within that standard                              |
| `count`       | Number of records in this category (NA = not yet computed at this step) |
| `n_corrected` | Records manually corrected at this step                                 |

The ledger uses 5 independent evaluation systems:

| Standard           | First step with numbers | What it evaluates                                                                                       | Key categories                                                                 |
|--------------------|:-----------------------:|---------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `field_misentry`   |           1.5           | Whether a duration estimate (SOL, WASO) exactly matches a timestamp — may indicate “typed in wrong box” | `none`, `SOL=time_sleep`, `SOL=time_bed`, `WASO=time_awake`, `WASO=time_getup` |
| `data_category`    |            4            | Temporal order and plausibility of the bed → sleep → awake → getup sequence                             | `clean`, `error`, `unusual`, `equal_time_ok`, `skipped_na`                     |
| `flag_severity`    |            7            | How many derived-metric flags (low SE, high SOL, high WASO) each record triggered                       | `Clean`, `Minor (1 flag)`, `Major (2+ flags)`                                  |
| `duration_extreme` |            7            | Total sleep time outside physiologically plausible bounds                                               | `OK`, `Too short (< 3 h)`, `Too long (> 12 h)`                                 |
| `checkforerrors`   |            8            | Summary of all auto-detection flags assembled in Step 8                                                 | `TIMESTAMP_ISSUE`, `DURATION_ISSUE`, `AMOUNT_FLAG`, `SELF_REPORTED_FLAG`       |

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
4.  `duration_extreme` — `Too short + Too long` should be &lt; 5% of
    `n_total`.
5.  `checkforerrors` — populated at Step 8 only.

**Example (synthetic data, 280 rows):**

    Step 7 (Compute metrics):
      data_category:    equal_time_ok = 266, skipped_na = 14        266 + 14 = 280 ✓
      flag_severity:    Clean = 251, Minor = 28, Major = 1         251 + 28 + 1 = 280 - 14 ✓
      duration_extreme: OK = 262, Too short = 1, Too long = 0

</div>

</div>

<div class="section level2">

## 6. Regression Check (compare against a previous run)

`output/correction_status_old.csv` is not written by any pipeline script
— you create it yourself as a saved baseline before rerunning:

<div id="cb8" class="sourceCode">

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
identical(old$n_clean, new$n_clean)
```

</div>

If they differ and the input data did not change, the pipeline output
has changed. Investigate.

</div>

<div class="section level2">

## 7. Quick Reference Card

| Check                                              | What to run                                                                           | Pass if |
|----------------------------------------------------|---------------------------------------------------------------------------------------|---------|
| Pipeline finished                                  | `file.exists("output/correction_status_final.csv")`                                   | `TRUE`  |
| Reasonable TST                                     | `tst_mean_h` between 6–8.5                                                            | Yes     |
| Reasonable SOL (raw duration, not perception bias) | `sol_mean_min` between 10–45                                                          | Yes     |
| Few errors                                         | `n_error < 0.01 * n_total`                                                            | Yes     |
| data\_category stable                              | Counts identical across Steps 6–8.5                                                   | Yes     |
| flag\_severity stable                              | Counts identical across Steps 7–8.5                                                   | Yes     |
| All records accounted                              | `clean + unusual + reasonable_unusual + equal_time_ok + error + skipped_na = n_total` | Yes     |
| Deterministic                                      | Same input → same output every time                                                   | Yes     |

</div>

<div class="section level2">

## 8. How to Read the Figures

Figures are saved to `latest_visualization_<tag>_n<rows>/` (overwritten
each run — no history). A `figure_index.png` contact sheet shows all
figures at a glance; if any figure could not be generated, a red
“FIGURE(S) NOT GENERATED THIS RUN” block at the very **top** of the
sheet lists each one with its reason. Stable verification artifacts
(snapshots, Bland-Altman plots, threshold validation) live separately in
`output/verification/<tag>/`.

**New to these figures?** Start with the `figure_index.png` contact
sheet for an overview, then work through the five “must-check” figures
below in order — together they are a sleep-quality QC pass in miniature.
Every figure number here (e.g. “01”, “13D”) matches a heading in §9.2 or
§9.3 you can jump to directly for the full explanation. The folder split
(`pipeline_cleaning/` = QC/audit figures, `research_ready/` = built for
a paper) only matters once you’re deciding what to put in a manuscript —
for just checking your data, ignore it and go by figure number.

**Publication figures (for a Methods section):**

| Figure                           | File                                             | What it shows                                                                                                          |
|----------------------------------|--------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| **Figure 1 — Pipeline Flow**     | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | Vertical flow diagram: raw → parsed → algo-corrected → manual-corrected → final valid, with counts and % at each stage |
| **Figure 2 — Correction Impact** | `research_ready/02_Correction_Impact.png`        | A/B delta lollipops (only modified records, TST & SOL) + identity scatter + before/after summary table                 |

**Five must-check figures:**

| Step | Figure (card)                                  | Should look like                                                      | If not?                                                                 |
|:----:|------------------------------------------------|-----------------------------------------------------------------------|-------------------------------------------------------------------------|
|  1   | **01 Pipeline Record Flow** (§9.2)             | Flow narrows gently; Clean dominates; Error + Unusual small (&lt; 5%) | Spike at 0 or huge Error/Unusual share → parsing/AM-PM failure upstream |
|  2   | **A1 Step Flag Ledger** (§9.2)                 | Corrected bar appears ONLY at Step 6.5, flat after                    | Change after Step 6.5 = instability                                     |
|  3   | **18 Auto-Detected Dashboard** (§9.2)          | Flag counts match `correction_status_final.csv`                       | Mismatch = misalignment                                                 |
|  4   | **02B Distribution of Sleep Variables** (§9.3) | TST peaks 6–8 h, SOL right-skewed, WASO &lt; 60, SE &gt; 85%          | SOL flat/bimodal = AM/PM confusion                                      |
|  5   | **13 Error Category Distribution** (§9.2)      | Most records Clean/Minor; Error+Unusual &lt; 5%                       | High = review manual CSVs                                               |

</div>

<div class="section level2">

## 9. Figure-by-Figure Reference

Every figure the pipeline produces is documented as a self-contained
card below: what each part means, the exact rules it is built from, what
healthy data look like, what anomalies mean, and a paper-ready caption.
Figures land in `latest_visualization_<tag>_n<rows>/pipeline_cleaning/`
(diagnostic) and `.../research_ready/` (publication).

<div class="section level3">

### 9.1 Figure Index

| \#      | File                                                      | Paper use     | Code source                     | Card                                                                                      | Last checked |
|---------|-----------------------------------------------------------|---------------|---------------------------------|-------------------------------------------------------------------------------------------|--------------|
| **01**  | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png`          | Methods Fig 1 | `sleep_visualization.R:862`     | [§9.2 · Pipeline Record Flow](#01-pipeline-record-flow)                                   | 2026-09-25   |
| **02**  | `research_ready/02_Correction_Impact.png`                 | Methods Fig 2 | `sleep_visualization.R:1013`    | [§9.3 · Correction Impact](#02-correction-impact)                                         | 2026-09-25   |
| **02B** | `research_ready/02B_Distribution_Sleep_Variables.png`     | Results       | `sleep_visualization.R:1057`    | [§9.3 · Distribution of Sleep Variables](#02b-distribution-of-sleep-variables)            | 2026-09-25   |
| **03**  | `research_ready/03_Sleep_Duration_Distribution.png`       | Results       | `sleep_visualization.R:1108`    | [§9.3 · TST Distribution](#03-tst-distribution)                                           | 2026-09-25   |
| **04**  | `research_ready/04_Sleep_Duration_vs_Time_in_Bed.png`     | Results       | `sleep_visualization.R:1163`    | [§9.3 · Sleep Duration vs Time in Bed](#04-sleep-duration-vs-time-in-bed)                 | 2026-09-25   |
| **04B** | `research_ready/04B_SOL_vs_Sleep_Duration.png`            | Results       | `sleep_visualization.R:1215`    | [§9.3 · SOL vs Sleep Duration](#04b-sol-vs-sleep-duration)                                | 2026-09-25   |
| **05**  | `research_ready/05_Variability_Sleep_Variables.png`       | Results       | `sleep_visualization.R:1265`    | [§9.3 · Variability of Sleep Variables](#05-variability-of-sleep-variables)               | 2026-09-25   |
| **06**  | `pipeline_cleaning/06_Sleep_Duration_Post_Correction.png` | Supplement    | `sleep_visualization.R:1339`    | [§9.2 · Sleep Duration Post-Correction](#06-sleep-duration-post-correction)               | 2026-09-25   |
| **07**  | `pipeline_cleaning/07_Flag_Composition_Stacked.png`       | Supplement    | `sleep_visualization.R:1404`    | [§9.2 · Flag Composition Stacked](#07-flag-composition-stacked)                           | 2026-09-25   |
| **09**  | `research_ready/09_Bedtime_vs_Getup_Distribution.png`     | Results       | `sleep_visualization.R:1458`    | [§9.3 · Bedtime vs Get-up Distribution](#09-bedtime-vs-get-up-distribution)               | 2026-09-25   |
| **10**  | `pipeline_cleaning/10_Extreme_Sleep_Duration.png`         | Supplement    | `sleep_visualization.R:1514`    | [§9.2 · Extreme Sleep Durations](#10-extreme-sleep-durations)                             | 2026-09-25   |
| **13**  | `pipeline_cleaning/13_Error_Category_Distribution.png`    | Supplement    | `sleep_visualization.R:1794`    | [§9.2 · Error Category Distribution](#13-error-category-distribution)                     | 2026-09-25   |
| **13B** | `pipeline_cleaning/13B_Adjacent_Timestamp_Gaps.png`       | Supplement    | `sleep_visualization.R:1877`    | [§9.2 · Adjacent Timestamp Gaps](#13b-adjacent-timestamp-gaps)                            | 2026-09-25   |
| **13C** | `pipeline_cleaning/13C_Detection_Outcomes_Heatmap.png`    | Supplement    | `sleep_visualization.R:1936`    | [§9.2 · Detection Outcomes Heatmap](#13c-detection-outcomes-heatmap)                      | 2026-09-25   |
| **13D** | `pipeline_cleaning/13D_Threshold_vs_Noise_Ratio.png`      | Supplement    | `sleep_visualization.R:1980`    | [§9.2 · Threshold vs Measurement Noise](#13d-threshold-vs-measurement-noise)              | 2026-09-25   |
| **14**  | `pipeline_cleaning/14_Sleep_Duration_Pre_Correction.png`  | Supplement    | `sleep_visualization.R:2051`    | [§9.2 · Sleep Duration Pre-Correction](#14-sleep-duration-pre-correction)                 | 2026-09-30   |
| **15**  | `pipeline_cleaning/15_Error_Timeline.png`                 | Supplement    | `sleep_visualization.R:2137`    | [§9.2 · Error Timeline](#15-error-timeline)                                               | 2026-09-30   |
| **16**  | `pipeline_cleaning/16_Common_Error_Patterns.png`          | Supplement    | `sleep_visualization.R:2228`    | [§9.2 · Common Error Patterns](#16-common-error-patterns)                                 | 2026-09-30   |
| **17**  | `pipeline_cleaning/17_Top_Participants_Flags.png`         | Supplement    | `sleep_visualization.R:2307`    | [§9.2 · Top Participants by Flag Rate](#17-top-participants-by-flag-rate)                 | 2026-09-25   |
| **18**  | `pipeline_cleaning/18_Auto_Detected_Dashboard.png`        | Supplement    | `sleep_visualization.R:2409`    | [§9.2 · Auto-Detected Dashboard](#18-auto-detected-dashboard)                             | 2026-09-25   |
| **20**  | `research_ready/20_SOL_Perception_Bias.png`               | Results       | `sleep_visualization.R:2637`    | [§9.3 · SOL Perception Bias](#20-sol-perception-bias)                                     | 2026-09-25   |
| **20B** | `research_ready/20B_WASO_Perception_Bias.png`             | Results       | `sleep_visualization.R:2695`    | [§9.3 · WASO Perception Bias](#20b-waso-perception-bias)                                  | 2026-09-25   |
| **21**  | `research_ready/21_Substance_Use_Availability.png`        | Supplement    | `sleep_visualization.R:2767`    | [§9.3 · Substance Use Availability](#21-substance-use-availability)                       | 2026-09-25   |
| **22**  | `research_ready/22_Substance_Use_Distribution.png`        | Supplement    | `sleep_visualization.R:2870`    | [§9.3 · Substance Use Value Distribution](#22-substance-use-value-distribution)           | 2026-09-25   |
| **23**  | `research_ready/23_Caffeine_Consumption.png`              | Supplement    | `sleep_visualization.R:2944`    | [§9.3 · Caffeine Consumption](#23-caffeine-consumption)                                   | 2026-09-25   |
| **24**  | `research_ready/24_Alcohol_Consumption.png`               | Supplement    | `sleep_visualization.R:2979`    | [§9.3 · Alcohol Consumption](#24-alcohol-consumption)                                     | 2026-09-25   |
| **A1**  | `pipeline_cleaning/A1_Step_Flag_Ledger.png`               | Supplement    | `figure12_step_flag_table.R:15` | [§9.2 · Step Flag Ledger](#a1-step-flag-ledger)                                           | 2026-09-25   |
| **P26** | `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png`      | Supplement    | `sleep_visualization.R:2579`    | [§9.2 · Participants Worth a Second Look](#p26-participants-worth-a-second-look)          | 2026-09-25   |
| **R25** | `research_ready/R25_Sleep_Regularity_Weekday_Weekend.png` | Results       | `sleep_visualization.R:3043`    | [§9.3 · Sleep Regularity — Weekday vs Weekend](#r25-sleep-regularity--weekday-vs-weekend) | 2026-09-25   |
| **R26** | `research_ready/R26_Sleep_Composition_TIB_Breakdown.png`  | Results       | `sleep_visualization.R:3096`    | [§9.3 · Sleep Composition — TIB Breakdown](#r26-sleep-composition--tib-breakdown)         | 2026-09-25   |
| **R27** | `research_ready/R27_Sleep_Metrics_Correlation_Matrix.png` | Results       | `sleep_visualization.R:3125`    | [§9.3 · Sleep Metrics Correlation Matrix](#r27-sleep-metrics-correlation-matrix)          | 2026-09-25   |

`11` (flag co-occurrence) is skipped whenever fewer than two flag
columns have complete data, and the reason is printed on the red block
at the top of `figure_index.png`. `14`, `15` and `16` are generated
whenever there is something to plot (cards below); when a run has
nothing to show (e.g. the review queue is empty because everything was
already reviewed), the skip reason says so explicitly.

> **For reference only.** The suggestions below are a starting point,
> not a rule; which figures to use depends on your paper’s story and the
> journal’s limits.

**Choosing figures for the paper — a recommendation.** The “Paper use”
column above is a default suggestion, not a verdict. For a
Methods/Results structure the pipeline supports, this split works well:

-   **Methods, main text (2 figures).** 01 (Pipeline Record Flow) —
    shows what the pipeline IS: stages, counts, and the final
    classification breakdown. 02 (Correction Impact) — shows what
    cleaning DID: non-destructive, only confirmed input errors modified.
    These two answer the reviewer’s first two questions (“what did you
    do?” and “how invasive was it?”) with no clutter.
-   **Results, main text (pick 3–5).** 03 (TST distribution) as the
    data-quality anchor; 20/20B (perception bias) if
    subjective-vs-computed agreement is part of your story; R25 (weekday
    vs weekend) or R26 (TIB composition) if timing regularity /
    composition matters; R27 (correlation matrix) if you reference
    metric interrelationships. Resist putting more than five in the main
    text — the rest reads better as supplement.
-   **Supplement (everything else).** All `pipeline_cleaning/` figures
    (13, 13B, 13C, 13D, 17, 18, A1, P26, 06, 07, 10) form the audit
    trail: put them in a supplement titled “Data quality and cleaning
    audit” and cite the set collectively from Methods with one sentence
    (“see Supplement S1 for the full audit trail”). The substance
    figures (21–24) belong with whatever substance-use analysis the
    paper reports, or supplement if none.

A minimal working set if page limits are tight: **01 + 02 in Methods, 03
+ 20 + R27 in Results, the supplement section for the audit trail.**
Captions for every one of these are ready in §9.2 and §9.3 below, at the
end of each figure’s card.

</div>

<div class="section level3">

### 9.2 Pipeline-cleaning figure cards (`pipeline_cleaning/`)

<div class="section level4">

#### 01 · Pipeline Record Flow

**File** `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` — generated at
`sleep_visualization.R:862`

**Paper use** Methods Fig 1

**What each part means** Vertical flow of 5 stages, each
self-describing: Raw Load (all diary entries) → Parsed (entries with
timestamps) → Auto-Corrected (AM/PM + order fixes) → Manual-Corrected
(human review fixes) → Final Valid (usable for analysis). Each box =
record count + % of total; two correction stages also show participant
counts.

The right-side annotation classifies every final record into one of five
classes:

| Class              | Meaning                                                                                                                                                             |
|--------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Not Reported       | Any of bed / sleep / awake / getup time is missing                                                                                                                  |
| Error (Reviewed)   | Order broken (not `bed ≤ sleep ≤ awake ≤ getup`), `sleep = awake`, a gap &gt; 7 h, or a sleep span &gt; 24 h — reviewed and fixed                                   |
| Equal Time         | `bed == sleep` and/or `awake == getup` (difference &lt; 0.01 h, about 36 s) with the order intact — a benign diary habit. (`sleep == awake` is an ERROR, not this.) |
| Unusual (Accepted) | Order intact but a gap &gt; 3 h (bed→sleep or awake→getup) — odd but possible, reviewed and kept as-is                                                              |
| Clean              | Order intact, no gap &gt; 3 h                                                                                                                                       |

The figure prints these standards next to each class (first match wins,
in the order above), so the diagram can be read without this page.
Bottom text = % of raw records entering analysis.

**Healthy look** The flow narrows gently from raw to valid. Clean is the
biggest class in the side annotation, and Error + Unusual together stay
under about 5%. The two correction stages show small counts — only
genuinely broken records were fixed; everything else stays as reported.

**Anomaly →** A large Error/Unusual share usually means AM/PM confusion
or a parsing problem upstream, not thousands of truly bad nights.
Near-zero correction counts on data you know contains errors mean the
detector missed rows.

**Precise rules**

-   **What is counted.** One row per raw diary entry (13,990 in the real
    run). The five boxes are successive stages: everything loaded, then
    entries that have timestamps, then entries fixed by rules (AM/PM and
    order fixes), then entries fixed by a human, then entries usable for
    analysis. Every percentage is out of the raw total.
-   **How the side list is made.** Every final record gets exactly one
    class, checked top to bottom: not reported, error, equal time,
    unusual, clean. The first match wins. The exact rules are in the
    Terminology section, and the figure prints them next to each class.
-   **The bottom line** (“x% of raw records enter analysis”) is the
    share of raw entries that have all four timestamps and therefore
    computed sleep metrics.
-   **Participants with a correction** counts participants who have at
    least one corrected record, out of all participants.

**FAQ**

Why isn’t Equal Time classified as an error?

A zero sleep latency (or getting up the moment you wake) is a plausible
thing to report. The pipeline keeps `error` for records that are
impossible as written: a broken order, or zero sleep.

What if both pairs are equal (bed = sleep and awake = getup)?

It is still `equal_time_ok`, recorded as `both_equal`.

What does 0.01 h mean for a reviewer?

Two timestamps that differ by less than about 36 seconds count as the
same. The tolerance only absorbs floating-point rounding; it does not
hide real differences.

Why are almost 80% of the records “Not Reported”? Is that a problem?

It means those rows are missing at least one of the four times (for
example, the diary was not completed that day). The pipeline never
guesses a missing time. Whether it is a problem depends on your study
design and expected response rate — compare it with what you expected.

Only 3 records are “Error (Reviewed)”, but Figure 2 shows 77 corrected
records. Which is right?

Both. Figure 1 classifies the FINAL data: errors that were fixed are no
longer errors, so only 3 remain in that class. Figure 2 counts the
records that were changed along the way.

**Paper caption**

> **Figure 01.** Flow diagram tracing all raw diary entries through the
> five pipeline stages (raw load, timestamp parsing, algorithmic
> correction, manual correction, final valid output), with record counts
> and percentages at each stage. The side annotation reports the final
> record classification (clean, unusual accepted, error reviewed,
> equal-time benign, not-reported) and the proportion of participants
> who received at least one correction. TST = total sleep time; SOL =
> sleep onset latency.

</div>

<div class="section level4">

#### 06 · Sleep Duration Post-Correction

**File** `pipeline_cleaning/06_Sleep_Duration_Post_Correction.png` —
generated at `sleep_visualization.R:1339`

**Paper use** Supplement

**What each part means** Density curves of final sleep duration by
record class (Clean / Unusual / Manually Corrected / Error) after Steps
5–6.5. WHAT THIS ANSWERS: did the human corrections distort the overall
sleep-duration distribution? (The corrected class’s curve should overlap
the clean curve.)

**Healthy look** One smooth peak around 6–8 hours, with nothing piled up
at 0 or beyond 12 hours — the shape of normal night sleep. It also shows
the human corrections did not distort the overall distribution.

**Anomaly →** A flat or two-humped curve means 12-hour and 24-hour time
formats survived parsing; a spike at 0 means missing or zero-duration
records slipped through.

**Precise rules**

-   **What is drawn.** A smoothed curve of the final `sleep_duration_h`
    (TST in hours) for each record class: Clean, Unusual, Manually
    Corrected and Error. Each curve is scaled to its own area, so
    compare shapes, not heights; the subtitle lists how many records
    each curve rests on.
-   **Who is included.** Only records with a computed sleep duration,
    and only those four classes. A record that was manually corrected is
    shown as Manually Corrected, whatever its original class.
-   **What it is for.** To check that human corrections did not distort
    the overall distribution: compare with Figure 14, which shows the
    same kind of curve before any manual correction.

**FAQ**

Why are there far fewer records here than the “usable for analysis”
count in Figure 1?

Figure 6 draws only the Clean, Unusual, Manually Corrected and Error
classes. Equal Time records (benign) and Not Reported records (no
computed duration) are not in it.

Why does the Unusual curve look different from the Clean one?

Unusual records were picked by a rule about odd gaps, so they are not a
random sample. They need not look like the Clean records, and looking
different is not evidence that they are wrong.

The Manually Corrected curve has extra bumps at the very short and very
long ends. Is that a problem?

Manually corrected records were chosen because they were broken, so
extreme durations are over-represented among them. It is worth opening
those records one by one, but the bumps alone do not mean the
corrections are wrong.

**Paper caption**

> **Figure 06.** Density of final total sleep time (TST, hours) after
> all manual corrections were applied. Unimodal distributions centered
> on 6–8 h indicate healthy sleep durations; spikes at zero or &gt; 12 h
> indicate residual parsing artifacts.

</div>

<div class="section level4">

#### 07 · Flag Composition Stacked

**File** `pipeline_cleaning/07_Flag_Composition_Stacked.png` — generated
at `sleep_visualization.R:1404`

**Paper use** Supplement

**What each part means** Stacked histogram: x = sleep duration (h), y =
number of records in that range, fill = `flag_severity` (see
Terminology, above) under a legend titled “Data Quality”. Shows whether
quality problems cluster at extreme durations.

| Fill color | Meaning         |
|------------|-----------------|
| Clean      | 0 metric flags  |
| Minor      | 1 metric flag   |
| Major      | 2+ metric flags |

Not to be confused with `data_category` — a different classification
system (see the Terminology section).

**Healthy look** In every duration bin the green (Clean) part is the
biggest. Orange and red slivers (records with flagged metrics) appear
mainly at the extremes — under about 3 h and over about 12 h — and at 0.
That is expected: extreme durations are exactly what trip the
sleep-efficiency, onset-latency and wake-time thresholds.

**Anomaly →** A wide orange/red band across the middle durations means a
systematic parsing problem, not a handful of extreme records.

**Precise rules**

-   **What the colours mean.** The fill is `flag_severity`, not
    `data_category`: Clean (no metric flag), Minor (1 flag), Major (2 or
    more). A flag is one of: sleep efficiency below 70%, sleep onset
    latency above 1 h, wake after sleep onset above 1.5 h (set under
    `classification.flag_severity.*`).
-   **What the bars are.** Each bar counts the records whose sleep
    duration falls in that range; the colours split each bar by
    severity.
-   **What is cut off.** The x axis shows 0 to 16 h, and records with a
    duration of 0 or 20 h and above are left out.
-   **The box in the corner** repeats the thresholds and the counts of
    Minor and Major records, so the figure can be read without this
    page.

**FAQ**

So this is about computed-metric flags, not timestamp errors?

Correct. Figure 13 is about timestamp and format problems; Figure 7
shows how many metric flags occur at each sleep duration. They are two
different systems (`flag_severity` versus `data_category`).

Why do the coloured slivers sit at the extremes?

Very short or very long sleep is exactly what tends to push sleep
efficiency, onset latency or night waking past their thresholds, so
flags naturally gather there. A flag there is a prompt to look, not a
verdict.

Can I change the thresholds?

Yes, under `classification.flag_severity.*` in the config. The figure’s
corner box reads the current values, so it stays correct.

**Paper caption**

> **Figure 07.** Stacked histogram of final sleep duration (hours), with
> bars colored by flag severity: Clean (no metric flags), Minor (one
> flag), Major (two or more flags from {SE &lt; 70%, SOL &gt; 1 h, WASO
> &gt; 1.5 h}). Shows whether quality problems concentrate at extreme
> durations.

</div>

<div class="section level4">

#### 10 · Extreme Sleep Durations

**File** `pipeline_cleaning/10_Extreme_Sleep_Duration.png` — generated
at `sleep_visualization.R:1514`

**Paper use** Supplement

**What each part means** Scatter: x = TST (h), y = sleep efficiency (%),
restricted to extreme durations (&lt; 4 h or &gt; 10 h).

| Encoding        | Meaning                              |
|-----------------|--------------------------------------|
| Color           | Data quality                         |
| Shape           | Short vs long sleeper                |
| Horizontal line | SE = 85% (poor-efficiency threshold) |

**Healthy look** The extremes are a small scatter of points. Short-sleep
points (triangles) mostly sit at moderate sleep efficiency (roughly
60–95%) and long-sleep points (circles) at high efficiency, so these
look like plausible unusual nights rather than arithmetic artefacts.

**Anomaly →** Many short-sleep points below 85% efficiency could be real
insomnia or a measurement problem — look at those records one by one.
Points sitting exactly at TST = 0 or 24 h point to a parsing failure.

**Precise rules**

-   **What is shown.** Only the extremes: records with TST under 4 h
    (triangles, “short”) or over 10 h (circles, “long”). Everything in
    between is left out. Colour is the data-quality class.
-   **The dashed line** at sleep efficiency 85% is a reading aid taken
    from the clinical rule of thumb. The pipeline’s own flag uses 70%
    (`poor_efficiency_threshold_pct`), so a point can sit below 85%
    without being flagged.
-   **Two sets of cut-offs.** 4 h and 10 h are this figure’s own display
    cut-offs. They are looser than the pipeline’s `duration_extreme`
    limits (under 3 h, over 12 h), which are a separate check.

**FAQ**

Where do 4 h and 10 h come from?

They are display cut-offs chosen to show the tails of the distribution.
They are not the pipeline’s physiological limits (`duration_extreme`:
under 3 h and over 12 h); do not mix the two.

Does a point below the 85% line mean the record is bad?

No. The line is a reference for reading the plot. A low efficiency with
a short duration may be a real poor night, a measurement problem, or a
diary entry that needs checking — the figure cannot tell which.

Why are there so few points?

Only records outside the 4–10 h range are drawn, and most nights fall
inside it. Few points is the expected, healthy picture.

**Paper caption**

> **Figure 10.** Scatter of total sleep time (TST, hours) versus sleep
> efficiency (SE, %) restricted to extreme durations (&lt; 4 h short,
> &gt; 10 h long). Point shape encodes short vs long sleep; point color
> encodes record quality. The horizontal line marks the SE = 85%
> poor-efficiency threshold.

</div>

<div class="section level4">

#### 13 · Error Category Distribution

**File** `pipeline_cleaning/13_Error_Category_Distribution.png` —
generated at `sleep_visualization.R:1794`

**Paper use** Supplement

**What each part means** Bar chart of auto-detection error/review
categories with counts and % labels. Categories mirror `auto_error_desc`
prefixes (Temporal / Metrics / Amount / Interval / Timestamp).

**Healthy look** One or two categories dominate (usually Metric
Threshold or Temporal), and every category is small in absolute terms —
the review queue is short and concentrated in a few causes.

**Anomaly →** Large Timestamp Format or Interval Format bars mean
participants entered times in non-standard ways in bulk; check the
parsing rules before reviewing records one by one.

**Precise rules**

-   **What the bars count.** Records flagged by the automatic check in
    Step 8, before any manual correction, grouped by the kind of
    problem. The kind comes from the prefix of the check’s message:
    `[Temporal]` temporal issues, `[Metrics]` metric thresholds,
    `[Amount]` amount/input flags, `[Interval]` interval format,
    `[Timestamp]` timestamp format; anything else is “Other”.
-   **The subtitle** lists the metric rules feeding the Metric Threshold
    group: SOL above 120 min, sleep efficiency below 0 or above 100%,
    TST/TIB ratio below 0.5.
-   **The two tables** under the bars explain the categories: the first
    lists each category with a severity and a plain description; the
    second counts records by their check result (for example
    SELF\_REPORTED\_FLAG, CLEAN).

**FAQ**

Why is it called “pre-correction”?

It answers “what did the raw data contain that needed attention?” — the
load the pipeline had to absorb. Figure 18 shows what is still flagged
afterwards.

Does a record in a bar mean the record is wrong?

No. It means the automatic check wanted a human to look. Many flagged
records are self-report-versus-computed disagreements that the pipeline
deliberately keeps as data.

Why is one bar so much taller than the others?

Usually one rule (here the metric thresholds) catches many records at
once. A single dominant bar means a single common cause; check that
cause first.

What is “Other Issue”?

It collects flagged records whose check message does not begin with one
of the five known prefixes. In practice these are usually records
flagged by the duration-reinterpretation check (message prefix
`[DurationReinterp]`): an SOL or WASO value that might have been typed
in the wrong format (for example minutes:seconds instead of
hours:minutes).

**Paper caption**

> **Figure 13.** Bar chart of records flagged by the post-correction
> auto-detection pass, grouped into six review classes derived from the
> flag description: temporal issues, metric issues, amount/input flags,
> interval format errors, timestamp format errors, and other. Counts are
> pre-correction — they show the burden the pipeline had to absorb.

</div>

<div class="section level4">

#### 13B · Adjacent Timestamp Gaps

**File** `pipeline_cleaning/13B_Adjacent_Timestamp_Gaps.png` — generated
at `sleep_visualization.R:1877`

**Paper use** Supplement

**What each part means** Histogram of gap hours between adjacent diary
events (bed→sleep, sleep→awake, awake→getup), **pre-correction raw
times**. Negative gap = the later event’s clock time precedes the
earlier one. Vertical reference line at 0.

**Healthy look** Most gaps fall between +0.5 and +2 hours — positive
means the events are in the expected order. A small negative tail is
normal: a negative gap means the later event has an earlier clock time,
the signature of an order error or a 12-hour AM/PM slip.

**Anomaly →** A large negative mass means widespread order errors that
the normalizer will flip; two clusters near ±12 h point to a
12-hour-dial AM/PM habit.

**Precise rules**

-   **What a gap is.** For each of three neighbouring pairs — bed to
    sleep, sleep to awake, awake to getup — the gap is the later time
    minus the earlier time, in hours. It is computed on the raw
    (decoded) times, before any correction.
-   **A negative gap** means the later event has an earlier clock time
    than the earlier one (for example awake at 01:00 but asleep at 23:00
    in the same row). That is the raw signature of an order error or a
    12-hour AM/PM slip.
-   **The red band** marks gaps of −3 to −6 h, the range that defines
    the “AM/PM decode or field-swap candidate” definition used in the
    validation work; the count in the band is printed on it.
-   **How to read the shape.** A negative mass of roughly −1 to −3 h
    points to order swaps (repaired by the swap step); two clusters near
    ±12 h point to PM times typed as AM (repaired by the 12-hour flip).

**FAQ**

Why is this drawn before correction?

Because it shows what the raw entries looked like. After correction the
negative gaps are mostly gone, so the picture would hide the problem the
pipeline solved.

Why are the three panels on different axes?

Each pair has its own typical size: bed→sleep and awake→getup gaps are
usually under an hour or two, while sleep→awake is a whole night (about
6–10 h). Each panel is scaled to its own data.

Does a count in the red band mean that many records are wrong?

Not exactly. It counts records whose raw gap falls in that range and
therefore look like AM/PM or swap candidates. Some are real long gaps;
the rules and the review decide which are errors.

**Paper caption**

> **Figure 13B.** Histogram of the time gap (hours) between adjacent
> diary events (bed→sleep, sleep→awake, awake→getup) computed from raw,
> pre-correction timestamps. Negative gaps indicate the later event’s
> clock time precedes the earlier one, the signature of order errors and
> 12 h AM/PM dial habits.

</div>

<div class="section level4">

#### 13C · Detection Outcomes Heatmap

**File** `pipeline_cleaning/13C_Detection_Outcomes_Heatmap.png` —
generated at `sleep_visualization.R:1936`

**Paper use** Supplement

**What each part means** A heatmap from the synthetic error-injection
benchmark. Each row is an error type that was injected into clean
records on purpose. Each column is what the pipeline did with it:
`CORRECT` (fixed correctly), `FLAGGED_UNRESOLVED` (caught and handed to
a human, not fixed), `MISREPAIRED` (fixed wrongly), `MISSED` (not
detected), `NO_MATCH`. Each cell is the percentage of that error type’s
rows with that outcome. The subtitle gives the number of injected rows
and categories.

**Healthy look** For each row, almost all of the colour sits in
`CORRECT` or `FLAGGED_UNRESOLVED` — the error was either fixed correctly
or caught and sent to a human — and `MISREPAIRED`, `MISSED` and
`NO_MATCH` stay near 0. Some error types are only ever flagged and never
auto-fixed (for example wrong-field entries); that is by design, because
the pipeline flags what it cannot fix safely instead of guessing.

**Anomaly →** Colour in `MISREPAIRED` means the automatic fix was wrong
— worse than leaving the record alone. Colour in `MISSED` means the
error was not detected at all.

**Precise rules**

-   **Where the data come from.** The synthetic error-injection
    benchmark
    (`validation/synthetic/results/detection_outcomes_v4_current.csv`):
    known errors were injected into clean data, and the pipeline was run
    on the result. Because the right answer is known, each outcome can
    be labelled.
-   **What a cell is.** For an injected error type, `n` is the number of
    injected rows; a cell is `count / n × 100`. Each row therefore adds
    up to about 100%.
-   **The five outcomes.** `CORRECT` fixed correctly;
    `FLAGGED_UNRESOLVED` caught and handed to a human without a fix;
    `MISREPAIRED` fixed wrongly; `MISSED` not detected; `NO_MATCH` the
    injected row could not be matched one-to-one to a row in the
    pipeline output.
-   **If the file is missing** from the working directory, the figure is
    skipped and the reason appears at the top of the figure index.

**FAQ**

Why does a synthetic-injection figure belong in a QC folder?

It is the evidence that the detection numbers mean something: the
detector is checked against known ground truth, whereas on real data the
“correct” answer is unknowable.

Is FLAGGED\_UNRESOLVED a failure?

No. It means the pipeline noticed the problem but did not want to guess
a fix, so it left the decision to a person. For some error types (for
example values typed into the wrong field) that is the intended
behaviour.

Which colour would worry me most?

MISREPAIRED. A wrong automatic fix is worse than leaving the record
alone, because it changes data without anyone noticing. MISSED is the
second: the error stays in the data undetected.

Does this say how many errors my real data have?

No. It is a test on synthetic data with errors put in on purpose. It
tells you how reliable each detector is, not how many errors your own
data contain.

**Paper caption**

> **Figure 13C.** Heatmap from the synthetic benchmark in which known
> errors were injected into clean records. Rows are injected error
> types; columns are pipeline outcomes (correctly fixed, flagged for
> review, misrepaired, missed); each cell is the percentage of that
> error type’s rows with that outcome.

</div>

<div class="section level4">

#### 13D · Threshold vs Measurement Noise

**File** `pipeline_cleaning/13D_Threshold_vs_Noise_Ratio.png` —
generated at `sleep_visualization.R:1980`

**Paper use** Supplement

**What each part means** Horizontal bars, one for each cleaning
threshold that can be checked against a self-report (the SOL and WASO
thresholds; thresholds with no self-report counterpart, such as sleep
efficiency, are left out and the subtitle says how many). Bar length =
threshold ÷ measurement noise, where the noise is the half-width of the
95% Bland-Altman limits of agreement between the self-reported value and
the value the pipeline computes from the timestamps. Dashed lines mark
2× (borderline) and 3× (safe).

**Healthy look** Bars at 3× or longer: the threshold is well above the
normal disagreement between self-report and computed values, so a record
flagged by it is unlikely to be flagged by measurement noise alone.
Between 2× and 3× is borderline.

**Anomaly →** A bar shorter than 2× means the threshold sits inside the
typical measurement disagreement: records it flags may be flagged by
noise alone, so treat that flag as a prompt to look, not as evidence of
an error — and consider raising the threshold.

**Precise rules**

-   **What each bar is.** A cleaning threshold divided by the
    measurement noise. Only thresholds that can be checked against a
    self-report are drawn (the SOL and WASO thresholds); the subtitle
    says how many others were left out, such as sleep efficiency.
-   **What “noise” means.** The self-reported value and the value the
    pipeline computes from the timestamps never agree exactly. Their
    typical disagreement is the half-width of the 95% Bland-Altman
    limits of agreement; that is the noise.
-   **How it is graded.** At least 5× conservative, at least 3× safe, at
    least 2× borderline, under 2× inside the noise. The dashed lines are
    at 2× and 3×.
-   **Live numbers.** It is computed from this run’s data by
    `validate_thresholds()` (`R/bland_altman.R`), not from the synthetic
    benchmark.

**FAQ**

Why compare thresholds to noise at all?

A threshold smaller than the measurement noise detects nothing real — it
would flag pure noise. This figure shows how far above the noise each
threshold sits.

A bar is under 2×. Must I change the threshold?

Not necessarily. It means records flagged by that threshold may be
flagged by noise alone, so treat those flags as prompts to look rather
than as evidence of error. Raising the threshold is one option; keeping
it and reviewing the flagged records is another.

Why are sleep efficiency and TST/TIB not shown?

They have no self-reported counterpart to compare with, so the noise
cannot be estimated. The subtitle says how many thresholds were left
out.

**Paper caption**

> **Figure 13D.** Each cleaning threshold divided by the Bland-Altman
> measurement noise (half-width of the 95% limits of agreement between
> self-reported and computed values). Dashed lines mark 2× (borderline)
> and 3× (safe).

</div>

<div class="section level4">

#### 14 · Sleep Duration Pre-Correction

**File** `pipeline_cleaning/14_Sleep_Duration_Pre_Correction.png` —
generated at `sleep_visualization.R:2051`

**Paper use** Supplement

**What each part means** Two overlaid density curves of sleep duration:
green = a sample (up to 5,000) of records with no auto-detection flag;
red = records the algorithm flagged for review. Pre-correction view:
algorithm only, no manual corrections. The subtitle gives both sample
sizes.

**Healthy look** The flagged (red) curve is broader or shifted — that is
why those records were flagged — and it rests on far fewer records than
the clean (green) curve.

**Anomaly →** Flagged and clean curves that look identical mean the
flags are unrelated to duration; they come from timestamp or format
rules.

**Precise rules**

-   **Two groups.** Green is a random sample (up to 5,000) of records
    with no automatic flag. Red is every record the automatic check
    flagged that has a usable sleep duration.
-   **Before any manual fix.** This uses the algorithm’s flags only;
    manual corrections are not applied, so the curve shows what the
    automatic check saw.
-   **Compare with Figure 6,** which shows the same kind of curve after
    human review.

**FAQ**

Why is the green group only a sample?

There are far more unflagged records than flagged ones; drawing up to
5,000 keeps the curve readable without changing its shape. The subtitle
gives both sample sizes.

Is it a problem that the two curves look alike?

Not necessarily, but it tells you the flags are not driven by sleep
duration — they come from timestamp or format rules instead.

When is this figure not produced?

When no flagged record has a usable sleep duration. The top of the
figure index then says so.

**Paper caption**

> **Figure 14.** Density of sleep duration (hours) for records without
> auto-detection flags (green, random sample of up to 5,000) and records
> flagged for review (red), before any manual correction.

</div>

<div class="section level4">

#### 15 · Error Timeline

**File** `pipeline_cleaning/15_Error_Timeline.png` — generated at
`sleep_visualization.R:2137`

**Paper use** Supplement

**What each part means** Stacked columns, one per month, counting
records that carry a temporal classification from Step 5/6:
`order_error` (error) and the three “suspicious gap” types
(`bed_sleep_suspicious`, `sleep_awake_suspicious`,
`awake_getup_suspicious`). Counted per month because there are only a
few dozen such records in total; a per-day area chart would draw slanted
blocks between isolated dates.

**Healthy look** Small counts spread across the study period, with no
single month dominating — the unusual patterns are occasional, not tied
to one period.

**Anomaly →** A spike in one month points to a protocol change or a
data-collection disruption; a cluster at the start points to a learning
curve or unclear instructions.

**Precise rules**

-   **Which records.** Records that carry a temporal classification: an
    order error (`order_error`) or one of three “suspicious gap” types
    (bed→sleep, sleep→awake, awake→getup). Each needs a bed timestamp so
    it can be placed on the calendar.
-   **Why monthly.** There are only a few dozen such records in total. A
    daily area chart would draw slanted blocks between isolated days and
    suggest a trend that is not there, so the figure counts per month.
-   **Data source.** `corrected_ema_data`, where the classification
    lives. `clean_df` is the earlier frame from before the
    classification, so it does not have these columns.
-   **A flag is not a verdict.** Most of these records were reviewed and
    kept as reported (see Figure 2).

**FAQ**

What would a spike in one month mean?

It suggests something changed around then — a protocol change, a
technical problem, or a wave of new participants. Look at which pattern
type the spike consists of and at the participants involved.

Why are the columns different colours?

Each colour is a pattern type: `order_error`, `bed_sleep_suspicious`,
`sleep_awake_suspicious`, `awake_getup_suspicious`. The legend under the
plot names them.

Records of mine have no date. Are they missing from the plot?

Yes. A record without a bed timestamp cannot be placed on the calendar,
so it is not drawn.

**Paper caption**

> **Figure 15.** Number of records per month with a temporal-order error
> or a suspicious-gap pattern (Step 6 classification), by pattern type.

</div>

<div class="section level4">

#### 16 · Common Error Patterns

**File** `pipeline_cleaning/16_Common_Error_Patterns.png` — generated at
`sleep_visualization.R:2228`

**Paper use** Supplement

**What each part means** Horizontal bars ranking the specific patterns
found in the auto-detection review queue: temporal order error, unusual
sleep pattern, SOL / sleep-efficiency / TST-TIB metric abnormal, **SOL
exceeds bed-to-sleep window**, WASO estimate inconsistent,
interval-format and timestamp-parse issues. A final bar, **“Other /
unclassified”**, counts queued records that match none of the named
patterns, so a reader can see what share the named patterns do not
explain.

**Healthy look** A few named patterns cover most of the queue, and
“Other / unclassified” is small — the detector’s reasons are well
described.

**Anomaly →** A large “Other / unclassified” bar means some detection
rule has no matching label in this figure.

**Precise rules**

-   **What is ranked.** The queue of records the automatic check
    flagged, sorted by the specific pattern found in its message:
    temporal order error, unusual sleep pattern, SOL / sleep-efficiency
    / TST-TIB metric abnormal, SOL exceeds the bed-to-sleep window, WASO
    estimate inconsistent, interval-format and timestamp-parse issues.
-   **“Other / unclassified”.** Flagged records that match none of the
    named patterns. The bar is always drawn last, so you can see what
    share the named patterns do not explain.
-   **When it is skipped.** If every flagged record is “Other /
    unclassified”, or there is nothing in the queue (for example because
    everything was already reviewed), the figure is not drawn and the
    reason is listed at the top of the figure index.

**FAQ**

What does “SOL exceeds bed-to-sleep window” mean?

The self-reported time to fall asleep is longer than the time between
the bedtime and sleep-onset timestamps, plus a small tolerance
(`window_tolerance_minutes`, 15 min by default). The two reports
contradict each other, so a person should look.

Is a large “Other / unclassified” bar bad?

It is a signal about this figure, not about your data: the detector
raised reasons that this figure has no label for. It is worth finding
out what they are.

Is this the same as Figure 13?

They draw on the same flagged records but group them differently. Figure
13 groups by the kind of check; Figure 16 names the specific pattern
inside each message.

**Paper caption**

> **Figure 16.** Most common automatically detected patterns among
> records in the review queue; the last bar collects records that match
> no named pattern.

</div>

<div class="section level4">

#### 17 · Top Participants by Flag Rate

**File** `pipeline_cleaning/17_Top_Participants_Flags.png` — generated
at `sleep_visualization.R:2307`

**Paper use** Supplement

**What each part means** Bar chart: top 15 participants by
algorithm-flagged record RATE (flags ÷ days), with PID labels.

**Healthy look** Rates are modest (under about 30%) and no single
participant stands far above the rest — flags are spread thinly, not
concentrated in one person’s diary.

**Anomaly →** One participant above about 60% usually means a habit (for
example always entering times on a 12-hour dial) or a recurring format
mistake; open their raw entries and look at the pattern.

**Precise rules**

-   **What the rate is.** For each participant, the number of records
    flagged by the automatic check divided by the number of diary days
    that participant has. The 15 highest rates are shown, each labelled
    with `flags / days`.
-   **Why a rate, not a count.** Participants are observed for different
    lengths of time. Five flags in 75 days (7%) is not the same as five
    flags in 5 days (100%).
-   **What it is for.** To find people whose diaries are worth a look.
    The figure does not say the records are wrong.

**FAQ**

Why is the bar height a percentage but the label shows two numbers?

The height is the rate in percent; the label repeats it with the raw
`flags/days` so you can see how much data it rests on. A high rate on
few days is weaker evidence than a moderate rate on many.

Is the top participant a problem?

Not automatically. A high rate usually means a habit (for example always
entering times on a 12-hour dial) or a recurring format mistake. Open
that person’s raw entries and look at the pattern before deciding
anything.

How is this different from Figure P26?

Figure 17 ranks by automatic-check flags (algorithm only, before manual
review). Figure P26 ranks by the final metric flags (`flag_severity`) of
the corrected data.

**Paper caption**

> **Figure 17.** The 15 participants with the highest auto-detected flag
> rate (flags per observed diary day), not raw flag counts, so
> participants with few diary days are not overrepresented.

</div>

<div class="section level4">

#### 18 · Auto-Detected Dashboard

**File** `pipeline_cleaning/18_Auto_Detected_Dashboard.png` — generated
at `sleep_visualization.R:2409`

**Paper use** Supplement

**What each part means** Left text panel “Key Metrics”: three numbers,
each with its name under it — auto-detected (needs human review),
manually corrected (human-reviewed and fixed), and total records. Right:
pie of review\_source classes (Temporal Issues / Metrics Issues /
Amount/Input Flags / Interval Format Errors / Timestamp Format Errors /
Other).

**Healthy look** Flagged records are far fewer than total records; the
largest slice is usually Temporal or Metrics issues; the numbers match
`correction_status_final.csv`.

**Anomaly →** Numbers that disagree with the CSV mean the ledger and
table pipeline are out of sync; a large Amount/Input slice points to a
substance-use coding problem.

**Precise rules**

-   **Left panel.** Three headline numbers, each named under it: records
    the algorithm flagged (needs human review), records already fixed by
    a human, and the total number of records.
-   **Right panel.** A pie of the flagged records by review source:
    Temporal, Metrics, Amount/Input, Interval Format, Timestamp Format,
    Other. Each slice shows its count and share.
-   **A consistency check.** The numbers should match
    `correction_status_final.csv`; the console also checks that no
    corrected record is still flagged.

**FAQ**

Why is the flagged number not zero after all the manual work?

The flagged number is the open queue: records the automatic check
flagged that have been neither corrected nor accepted by a reviewer. It
reaches zero only when every flagged record has been dealt with. The
“already corrected” number next to it counts the ones a person fixed.

What should I do if a slice is large?

Open the matching card: a large Metrics slice points to Figure 13D (are
the thresholds above the noise?), a large Amount/Input slice points to
the substance-use coding (Figures 22–24), a large Temporal slice points
to Figures 13B and 15.

Why is there a pie when pies are hard to read?

It has only a handful of slices and its job is to show one dominant
source at a glance. For exact numbers use the counts printed on the
slices or Figure 13.

**Paper caption**

> **Figure 18.** Key metrics panel (total records, flagged records,
> manually corrected records) alongside a stacked bar of the six
> review-source classes. Counts must match
> `correction_status_final.csv`.

</div>

<div class="section level4">

#### A1 · Step Flag Ledger

**File** `pipeline_cleaning/A1_Step_Flag_Ledger.png` — generated at
`figure12_step_flag_table.R:15`

**Paper use** Supplement

**What each part means** Grid table: one row per pipeline step; columns
are N (records in the run), DC:error / DC:unusual (`data_category`, Step
5), SEV:Minor / SEV:Major (`flag_severity`, Step 7), CFE:flag
(`checkforerrors`, Step 8), MISentry (`field_misentry`, Step 1.5),
Corrected and Suppressed. A grey “—” means “not computable yet at that
step”; the first number in a column is where it is generated. The key
under the table spells out every abbreviation, and the numbers are
centered under their headers. Read it like the CSV ledger (§5) rendered
as a figure.

**Healthy look** Each column’s counts first appear at the step that
computes it and then stay constant. From Step 6 on, the six
`data_category` counts add up to `n_total`, and the three
`flag_severity` counts add up to `n_total` from Step 7 on.

**Anomaly →** Counts that change after the step that first computed them
mean the pipeline is unstable (see the validation rules in §5).

**Precise rules**

-   **One row per pipeline step.** The columns are the five evaluation
    systems, each computed once at a fixed step: `DC` (`data_category`,
    Step 5), `SEV` (`flag_severity`, Step 7), `CFE` (`checkforerrors`,
    Step 8), `MISentry` (`field_misentry`, Step 1.5), plus Corrected and
    Suppressed.
-   **A dash means “not computable yet”.** The first number in a column
    is where it is generated; after that the counts should stay put.
-   **The two identities worth checking.** From Step 6 on, the six
    `data_category` counts add up to the number of records; from Step 7
    on, the three `flag_severity` counts do too. The rule list is in §5.

**FAQ**

Why do the numbers stay the same in the later rows?

Each standard is computed once and never recomputed. If a number changes
after the step that first produced it, something in the pipeline is
unstable.

What is the difference between Corrected and Suppressed?

Corrected counts records whose data were changed. Suppressed counts
flags a human reviewed and accepted, so they no longer need attention
but the data were not changed.

What does the CFE:flag column count, and why is it not the same as
Figure 13?

From Step 8 on it counts the records in each outcome of the automatic
check’s summary (for example SELF\_REPORTED\_FLAG), which is the same
table behind `correction_status_final.csv`. That summary is built before
a person’s accepted rows are withdrawn, so it still counts them (85 in
the real run), and it classifies the duration-reinterpretation flags as
clean (39). Figure 13 counts the open queue instead, which is why it
shows 226 where this column shows 272. Steps before 8 show a dash
because the check has not run yet.

Where is the same information as a file?

`output/step_flag_ledger.csv` (see §5). This figure is that table drawn
as a picture.

**Paper caption**

> **Figure A1.** Per-step × per-standard × per-category record counts
> for the five evaluation systems (field mis-entry, data category, flag
> severity, duration extreme, check-for-errors). Each standard is
> computed once at a fixed pipeline step; counts must remain constant
> thereafter.

</div>

<div class="section level4">

#### P26 · Participants Worth a Second Look

**File** `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png` —
generated at `sleep_visualization.R:2579`

**Paper use** Supplement

**What each part means** A table (not a bar chart) of the 20
participants with the highest flagged-record rate — participant ID,
total records, and the Clean / Minor / Major percentages — for manual
review prioritization; rows at 20% flagged or more are tinted orange,
50% or more red. The figure’s subtitle defines Minor (1 flag) and Major
(2+ flags) with the current thresholds.

**Healthy look** A short list, and no participant far above the rest.

**Anomaly →** A long list means a systemic issue affecting many
participants, not individual behavior.

**Precise rules**

-   **Who is listed.** The 20 participants with the highest share of
    their own records flagged by `flag_severity` (Minor plus Major). The
    share is 100% minus the Clean percentage.
-   **The colours.** Rows at 20% flagged or more are tinted orange, 50%
    or more red. In a healthy dataset no row is tinted.
-   **Not a quality verdict.** A flag marks a record that differs from
    an automatic expectation, including self-report-versus-computed
    disagreements that the pipeline keeps on purpose.

**FAQ**

A participant has a high flag rate. Is their data wrong?

Not necessarily. The list says whose records are worth checking first;
the verdict comes from looking at the records, not from this table.

Why is nobody coloured in my figure?

Colours start at 20% flagged. If every participant is below that, the
table is working as intended — there is no one who stands out.

How is this different from Figure 17?

Figure 17 ranks by the automatic check’s flags before manual review;
this table ranks by the final metric flags (`flag_severity`) of the
corrected data.

**Paper caption**

> **Figure P26.** Ranked table of participants by flagged-record rate,
> for manual review prioritization. A high rate flags records worth
> hand-checking; it is not a verdict that the data are wrong.

</div>

</div>

<div class="section level3">

### 9.3 Research-ready figure cards (`research_ready/`)

<div class="section level4">

#### 02 · Correction Impact

**File** `research_ready/02_Correction_Impact.png` — generated at
`sleep_visualization.R:1013`

**Paper use** Methods Fig 2

**Purpose** An audit of how much, and in which direction, corrections
changed the data. It answers “how invasive was the cleaning?” — the
figure’s subtitle says so and explains how to read each panel.

**What each part means** 4 panels: (A) TST delta lollipops — one row per
modified record, x = ΔTST (min); (B) same layout for SOL; (C) identity
scatter of TST-before vs TST-after (all records); (D) summary table of
TST/SOL mean ± SD before vs after. Caption states how many of how many
records were modified.

| Mark                              | Meaning                                                                     |
|-----------------------------------|-----------------------------------------------------------------------------|
| ● Orange                          | Algorithmic correction                                                      |
| ● Blue                            | Manual correction                                                           |
| ● Gray, 3% opacity (panel C only) | Unchanged record — an almost invisible backdrop behind the corrected points |
| Dotted diagonal (panel C)         | 1:1 “no change” reference line                                              |

**When nothing was corrected** If no record was changed (a clean
dataset, or the manual-correction files were not applied), panels A–C
would be empty, so the figure shows one sentence — “No record was
changed by a correction in this run (none needed, or the
manual-correction files were not applied)” — plus the before/after
table, whose rows are then identical.

**Healthy look** Most points sit on the dotted diagonal, the bars in the
top panels are short and cluster near 0, and the before/after means in
the table are close. That means the cleaning was non-destructive: it
changed a few records, not the data as a whole.

**Anomaly →** Very long bars or a large share of corrected rows mean
corrections are changing real data, not just fixing entry errors; a
clear shift in the before/after means calls for asking why so much was
“fixed”.

**Precise rules**

-   **Who is counted as “modified”.** Each record has a status: `manual`
    if a human correction touched it, otherwise `algorithmic` if a rule
    changed it, otherwise `none`. A record is never both; manual wins.
-   **What the top panels plot.** Only modified records, one row each,
    sorted by the size of the change. ΔTST = TST after − TST before
    (minutes), ΔSOL likewise. A negative bar means the correction
    shortened the value.
-   **What “before” means.** The “before” values are recomputed from the
    raw parsed timestamps (TST = awake − sleep − WASO, SOL = sleep −
    bed); the “after” values are the pipeline’s final numbers.
-   **The scatter** plots before (x) against after (y) for all records.
    Unchanged records are drawn almost transparent, so they form a faint
    band on the diagonal behind the few coloured modified points.
-   **The table** gives the mean and SD of TST and SOL before and after;
    the caption says how many of how many records were modified.

**FAQ**

Why does most of the data sit on the diagonal?

Corrections are non-destructive by design: only confirmed input errors
are fixed (about 0.6% of records in the real run). Differences between
self-report and computed values are kept as data, not smoothed away.

Can a faint point sit far from the diagonal?

Unchanged records should sit on the diagonal. A faint point off it means
the “before” value (recomputed from the raw timestamps) and the “after”
value (the pipeline’s final number) differ for a record that was not
marked as corrected. The figure cannot say why; open that record.

Why do so many corrected records show exactly ±720 minutes?

720 minutes is 12 hours. An AM/PM flip changes a clock time by exactly
12 hours, which moves the derived duration by 12 hours too, so AM/PM
fixes stack up at the same length.

Does a big bar mean the correction was wrong?

No. A big change usually means a big input error was fixed, such as a
12-hour slip. Whether a correction was right is decided in review, not
by this figure; the figure shows how large the changes were.

Why is the table there?

It gives a one-glance answer to “did the averages move?”. If the before
and after means are close, the cleaning did not shift the data as a
whole.

**Paper caption**

> **Figure 02.** (A) Lollipop plot of the change in total sleep time
> (ΔTST, minutes) for each modified record, colored by correction type
> (orange = algorithmic, blue = manual). (B) Same for sleep onset
> latency (ΔSOL). (C) Identity scatter of TST before vs after
> correction; unchanged records are shown at 3% opacity as a gray
> backdrop. (D) Summary table of TST and SOL means (± SD) before and
> after correction. Corrections are non-destructive: only confirmed
> input errors were modified.

</div>

<div class="section level4">

#### 02B · Distribution of Sleep Variables

**File** `research_ready/02B_Distribution_Sleep_Variables.png` —
generated at `sleep_visualization.R:1057`

**Paper use** Results

**What each part means** Histograms + density curves for key sleep
metrics (TST, SOL, WASO, SE) on the **final corrected** data.

**Healthy look** TST peaks at 6–8 h, SOL is right-skewed (most people
fall asleep within 10–45 min, a few take much longer), WASO stays under
about 60 min, and sleep efficiency sits above 85%. These are the shapes
normal sleep diaries produce.

**Anomaly →** A flat or two-humped SOL suggests AM/PM confusion left
uncorrected; sleep efficiency piled up at exactly 100% suggests many
“slept all night” entries that deserve a look.

**Precise rules**

-   **What is drawn.** Five small panels, one per metric: sleep
    duration, time in bed, WASO, SOL and sleep efficiency, from the
    final corrected data. Each panel has its own axis (the panels are
    not comparable in scale).
-   **Bars and curve.** The green bars are a histogram (40 bins); the
    red curve is a smoothed version of the same data. Both are on a
    density scale, so the area is 1 in each panel.
-   **Units.** Durations are in hours and sleep efficiency is in
    percent, as in the other figures.

**FAQ**

Why do the panels have different x axes?

Each metric has its own natural scale — hours for durations, percent for
efficiency — so each panel is scaled to its own data. Do not compare the
horizontal widths across panels.

SOL has a small negative part. Is that an error?

A negative SOL means the sleep time is earlier than the bed time in a
record. It is rare; these records are examined by the order checks. A
few negative values on the left edge are worth a glance, but a few
points do not change the picture.

Why does sleep efficiency pile up at 100%?

Sleep efficiency is capped by its definition: it cannot exceed 100%, and
many nights with no waking and no delay come out at or near 100%. A tall
spike at exactly 100% is common; it is worth a look only if it is very
large.

How is this different from Figure 5?

Figure 2B shows the shape of each distribution (how common each value
is). Figure 5 shows the spread in a violin-and-box form, which makes the
median and the spread easier to compare at a glance.

**Paper caption**

> **Figure 02B.** Histograms with density curves for total sleep time
> (TST), sleep onset latency (SOL), wake after sleep onset (WASO), and
> sleep efficiency (SE) on the final corrected data.

</div>

<div class="section level4">

#### 03 · TST Distribution

**File** `research_ready/03_Sleep_Duration_Distribution.png` — generated
at `sleep_visualization.R:1108`

**Paper use** Results

**What each part means** Histogram + density of total sleep time (TST —
see Terminology, above).

| Mark                 | Meaning                              |
|----------------------|--------------------------------------|
| ● Red smooth curve   | Density estimate                     |
| ● Blue solid line    | Mean (labeled with its hour value)   |
| ● Orange dashed line | Median (labeled with its hour value) |

The legend under the plot, titled “Line shown”, names each line.

TST here is the *enhanced* definition: `TST = TIB − SOL − WASO` — not
the raw clock-time difference between two timestamps.

**Healthy look** One peak centered at 6–8 h, with the mean and median
close together. A single symmetric peak is what a healthy sample looks
like.

**Anomaly →** Mean well above median means a long right tail of very
long sleepers; a spike at 0 means zero-duration records.

**Precise rules**

-   **What TST is here.** The enhanced definition: sleep period minus
    wake after sleep onset, `TST = TIB − SOL − WASO` (stored as
    `sleep_duration_h`). It is not the raw difference between two clock
    times.
-   **The lines.** Blue solid = mean, orange dashed = median, red =
    smoothed density; the legend “Line shown” names them and the two
    values are printed in it.
-   **Skew.** For sleep data the mean is usually a little above the
    median because of the long-sleeper tail.
-   **`n`** in the corner is the number of records with a computed TST.

**FAQ**

Why two distribution figures (02B and 03)?

02B is a five-metric dashboard in small panels. Figure 03 isolates TST
and marks the mean and median, which is the usual first figure for a
paper.

Why is TST not just the time between falling asleep and waking?

Because nights often include time awake after first falling asleep. The
pipeline subtracts that wake time (WASO), so TST counts only time
actually asleep.

My mean and median are far apart. What does that mean?

A gap means the distribution is skewed: a tail of very long (or very
short) sleepers pulls the mean away from the median. Look at which side
of the histogram has the tail, and at Figures 10 and 06.

Do the curves include the records that were manually corrected?

Yes. This is the final corrected data, so corrected records count at
their corrected values.

**Paper caption**

> **Figure 03.** Histogram and density of TST (hours) with the mean
> (blue) and median (orange) marked. TST is computed as the sleep period
> minus WASO (TST = TIB − SOL − WASO).

</div>

<div class="section level4">

#### 04 · Sleep Duration vs Time in Bed

**File** `research_ready/04_Sleep_Duration_vs_Time_in_Bed.png` —
generated at `sleep_visualization.R:1163`

**Paper use** Results

**What each part means** Scatter of TIME IN BED (from getting into bed
to getting out) vs SLEEP DURATION (time actually asleep = TIB − SOL −
WASO). Black line = linear trend; the gray band around it = that trend’s
uncertainty range. Dashed diagonal = the impossible line TST == TIB.

**Healthy look** Points hug the dotted 1:1 line and spread out at longer
time in bed (people stay in bed awake); no point has TST above time in
bed, which would be impossible.

**Anomaly →** Points above the line (TST &gt; TIB) mean a duration
arithmetic error, such as WASO not being subtracted; a shapeless cloud
means TIB and TST are decoupled, which usually points to a parsing
problem.

**Precise rules**

-   **What is plotted.** Time in bed (x) against total sleep time (y)
    for records with a time in bed under 24 h and a TST between 0 and
    20 h. Colour is the data-quality class.
-   **The impossible line.** The dashed diagonal is TST = TIB. Since TST
    = TIB − SOL − WASO, no valid point can be above it.
-   **The trend line** is an ordinary straight-line fit with its
    uncertainty band; the subtitle prints the correlation `r`.
-   **The view** is cut to 0–16 h on both axes for readability; the
    statistics use all points in range.

**FAQ**

What does a point above the dashed line mean?

It would mean more sleep than time in bed, which cannot happen. It
indicates a duration arithmetic problem, for example WASO not being
subtracted. There should be no such points in healthy data.

Why does the cloud spread out at long time in bed?

People who stay in bed longer are often awake for part of it, so sleep
does not grow as fast as time in bed. That is a normal spread, not
noise.

I can see a few points above the dashed line. What should I do?

They are impossible as recorded (more sleep than time in bed), usually
because of a parsing slip or a timestamp problem. Find them by filtering
for `sleep_duration_h > time_in_bed_h` in the data and check those
records by hand.

Why are some axes cut at 16 hours?

To keep the plot readable. A few extreme points lie beyond the view but
are still in the statistics.

**Paper caption**

> **Figure 04.** Scatter of TST (hours) by time in bed (TIB, hours) with
> a smoothed trend and identity reference line. Because TST ≤ TIB by
> construction, points above the identity line are physically
> impossible.

</div>

<div class="section level4">

#### 04B · SOL vs Sleep Duration

**File** `research_ready/04B_SOL_vs_Sleep_Duration.png` — generated at
`sleep_visualization.R:1215`

**Paper use** Results

**What each part means** Scatter of SOL (how long it took to fall asleep
after getting into bed) vs TST. Each dot = one diary night. Black line =
linear trend; gray band = trend’s uncertainty range. Red dotted vertical
at SOL = 1 h (reference, labeled). SOL &gt; 3 h filtered out for
clarity.

**Healthy look** A negative relationship — a longer time to fall asleep
goes with less sleep; most points have SOL under 1 hour; the quality
colors are mixed evenly rather than clustered.

**Anomaly →** A cluster of Error/Unusual colors at high SOL suggests a
sleep-onset mis-entry pattern; a vertical stripe at SOL = 0 is
zero-latency reporting (equal-time entries).

**Precise rules**

-   **What is plotted.** Sleep onset latency (x, in hours) against total
    sleep time (y) for records with SOL between 0 and 3 h. Colour is the
    data-quality class.
-   **The red dotted line** marks SOL = 1 h, the pipeline’s “long onset
    latency” metric flag.
-   **The trend line** is an ordinary straight-line fit with its
    uncertainty band.
-   **The 3 h cut** only keeps the plot readable; it is a display
    choice, not a pipeline rule.

**FAQ**

Why is SOL capped at 3 h here when other figures use different numbers?

Several different numbers are in play and they do different jobs: 3 h is
this figure’s display cut-off; 1 h is the `flag_severity` threshold (the
red dotted line); and Figure 13’s metric check flags SOL above 120 min.
They are separate on purpose.

What is the vertical stripe at SOL = 0?

Participants who report no delay before falling asleep (or who typed the
same time for bed and sleep). Those entries are the equal-time reports
described in the Terminology section.

The trend is almost flat. Is that wrong?

Not necessarily. In many samples the link between how long it takes to
fall asleep and how long you sleep is weak. The gray band shows how
uncertain the slope is.

**Paper caption**

> **Figure 04B.** Scatter of SOL (hours, restricted to ≤ 3 h for
> readability) by TST (hours), colored by flag severity. The negative
> association (long onset latency, shorter sleep) is the expected
> clinical pattern.

</div>

<div class="section level4">

#### 05 · Variability of Sleep Variables

**File** `research_ready/05_Variability_Sleep_Variables.png` — generated
at `sleep_visualization.R:1265`

**Paper use** Results

**What each part means** Violin plots + inner boxplots, one per sleep
variable, **free Y axis per panel**. Shows distribution shape and
spread.

**Healthy look** TST violins are roughly symmetric; SOL and WASO are
right-skewed (many small values, a few large); no panel is dominated by
isolated spikes.

**Anomaly →** A violin with two lobes means two behaviors are mixed (for
example weekday vs weekend, or a 12-hour-dial habit); a wide, flat
violin means noisy measurement.

**Precise rules**

-   **What is drawn.** One violin per metric (sleep duration, time in
    bed, WASO, SOL, sleep efficiency), with a small box inside showing
    the median and middle half of the data. Each panel has its own
    vertical axis.
-   **How to read a violin.** The width at each height is how many
    records have that value; a wide part means many records, a thin part
    means few.
-   **The box** shows the median (line) and the middle 50% of values;
    outliers are not drawn separately, because the violin already shows
    the tails.

**FAQ**

What is the difference between the violin and the box inside it?

The violin shows the whole shape of the distribution; the box inside
gives two numbers to compare at a glance: the median and the middle half
of the data.

A violin has two bulges. What does that mean?

Two groups of behaviour are mixed together — for example weekday versus
weekend, or a mix of 12-hour and 24-hour time entries. Check Figure R25
or the parsing before trusting a single summary number.

Why is there a long thin line at the top or bottom?

A few extreme records stretch the range. The thin line is those tails;
they are worth checking in Figure 10.

**Paper caption**

> **Figure 05.** Violin plots with overlaid boxplots for each sleep
> variable; each panel uses its own y-axis scale, so panels are compared
> by distribution shape, not absolute values.

</div>

<div class="section level4">

#### 09 · Bedtime vs Get-up Distribution

**File** `research_ready/09_Bedtime_vs_Getup_Distribution.png` —
generated at `sleep_visualization.R:1458`

**Paper use** Results

**What each part means** Two density curves over hour-of-day (0–24):
bedtime distribution vs get-up distribution (final corrected times).

**Healthy look** Bedtime peaks around 22:00–00:00 and get-up around
06:00–08:00, and the two curves overlap little — the usual day/night
pattern.

**Anomaly →** A bedtime peak after 02:00 means a delayed-sleep group or
a PM/AM decoding error; a get-up peak before 04:00 means evening times
were parsed as morning.

**Precise rules**

-   **What is drawn.** Two smoothed curves of the clock hour (0–24):
    bedtime (green) and get-up time (orange), from the corrected
    timestamps.
-   **The wrap-around.** The axis runs from 0 to 24 h, so bedtimes
    around midnight are split: the part before midnight is at the right
    end and the part after midnight is at the left end.
-   **Who is included.** Records that have both a bed time and a get-up
    time.

**FAQ**

Why does the bedtime curve appear at both ends of the plot?

Because the axis is clock time from 0 to 24 h. A bedtime of 23:30 lies
at the right end and a bedtime of 00:30 lies at the left end, so one
evening peak is drawn as two pieces.

What would a bedtime peak in the small hours mean?

Either a genuinely delayed sleep group, or an AM/PM decoding error that
turned an evening time into a morning time. Compare with Figure 13B.

Is this the same as the weekday/weekend figure?

No. This figure pools all days; Figure R25 splits by weekday and
weekend.

**Paper caption**

> **Figure 09.** Density of bedtime and get-up clock hours (corrected
> times) across the day. Peak separation (evening bedtimes, morning
> get-ups) is the healthy circadian signature.

</div>

<div class="section level4">

#### 20 · SOL Perception Bias

**File** `research_ready/20_SOL_Perception_Bias.png` — generated at
`sleep_visualization.R:2637`

**Paper use** Results

**Note:** this figure measures something *different* from the SOL
duration range in the quick reference card (10–45 minutes). It measures
the *gap* between two independent SOL estimates, not the length of SOL
itself.

**What each part means** Histogram of the absolute bias, printed in the
figure’s bottom-right caption as
`bias = |computed SOL − self-reported SOL|` (minutes). Two reference
lines, each now labeled with its basis: **orange dashed at 15 min** =
small mismatch (close to the pipeline’s 15-min window tolerance,
`classification.metric_validation.sol.window_tolerance_minutes`); **red
dashed at 60 min** = large mismatch — a DISPLAY reference, not a
pipeline rule; cases beyond it are worth a manual look.

**Healthy look** Most of the mass is near 0 with a small tail, and the
mean bias is under about 30 min: self-reported and computed onset
latency mostly agree.

**Anomaly →** A large systematic shift (mean far above 0) means
participants misjudge how long they take to fall asleep; two humps mean
a subset of participants is using the field differently.

**Precise rules**

-   **The two SOL values.** Objective SOL is computed from the corrected
    times, `time_sleep_corrected − time_bed_corrected`, in minutes.
    Subjective SOL is what the participant reported in
    `duration_totalmin_sol_estimate_am`.
    `bias = |objective − subjective|`.
-   **Who is included.** Only records where both values exist.
-   **The view.** The x axis shows 0–200 minutes, so larger differences
    are not drawn (R prints a warning about the removed rows).
-   **The two dashed lines** are reading aids: 15 min is close to the
    pipeline’s 15-min window tolerance; 60 min is a display reference,
    not a rule.

**FAQ**

Is a large bias an error?

Not necessarily. People estimate how long they took to fall asleep
imprecisely, often in round numbers (5, 10, 15, 30 minutes), which is
why the histogram has spikes. The gap is kept as data; the 60-minute
line only marks cases worth a look for a possible input error.

Why do the bars look so spiky?

Self-reports cluster on round numbers. The spikes at multiples of 5 are
a fingerprint of rounding, not noise.

Some differences are not shown. Is data being hidden?

The x axis stops at 200 minutes for readability, so larger differences
are off the chart. They are still in the data; R prints a warning saying
how many rows were left out of the plot.

Which way does the bias go?

The figure shows the absolute difference, so it cannot say whether
people over- or under-report. To see the direction you would compute the
signed difference from the two columns.

**Paper caption**

> **Figure 20.** Histogram of the absolute difference between objective
> SOL (derived from corrected bed and sleep timestamps) and subjective
> SOL (participant’s reported onset latency), in minutes.

</div>

<div class="section level4">

#### 20B · WASO Perception Bias

**File** `research_ready/20B_WASO_Perception_Bias.png` — generated at
`sleep_visualization.R:2695`

**Paper use** Results

**What each part means** Histogram of the absolute difference between
two different quantities: the self-reported nighttime wakefulness (WASO)
and the time the diary shows between the final awakening and getting up
(`getup − awake`). The figure’s caption prints
`bias = |computed − self-reported|` (minutes), with the same 15 min / 60
min reference lines as Figure 20.

**Healthy look** Most of the mass is near 0 with a small tail. Because
the two quantities are different windows, this mostly tells you how
large the gap is between night wakefulness and lingering in bed, not how
well people report.

**Anomaly →** A long tail means many participants have a big gap between
night wakefulness and time in bed after waking. It is informative, not
an error; check the WASO duration corrections only if you suspect an
entry problem.

**Precise rules**

-   **The two values are different things.** Objective here is
    `time_getup_corrected − time_awake_corrected` in minutes — the time
    spent in bed after the final awakening. Subjective is the
    participant’s reported nighttime wakefulness
    (`duration_totalmin_waso_estimate_am`, read when written as
    hours:minutes).
-   **So the gap is not a pure reporting error.** The two numbers cover
    different time windows; the figure’s subtitle says so. The mismatch
    is informative, not something to fix.
-   **Same construction as Figure 20.**
    `bias = |objective − subjective|`, records with both values, x axis
    0–200 min, dashed references at 15 and 60 min.

**FAQ**

Why compare two different things?

The pipeline has no direct second measure of night wakefulness, so the
closest timestamp-based quantity available is the time between final
awakening and getting up. The figure is explicit that the windows
differ; it is an agreement check, not a validation.

Does a large gap here mean the diary is wrong?

No. A participant can be awake for long stretches at night and still get
up quickly, or wake once and linger in bed. Both give a large gap
without any error in either number.

Why are fewer records used than in Figure 20?

Only rows where the self-reported WASO is written as hours:minutes can
be read, so some rows drop out.

**Paper caption**

> **Figure 20B.** Histogram of the absolute difference between computed
> wake-after-sleep-onset and the participant’s self-reported nighttime
> wakefulness, in minutes.

</div>

<div class="section level4">

#### 21 · Substance Use Availability

**File** `research_ready/21_Substance_Use_Availability.png` — generated
at `sleep_visualization.R:2767`

**Paper use** Supplement

**What each part means** Bar chart: % of records with data per substance
(caffeine, alcohol, nicotine, cannabis).

**Healthy look** High availability (over about 80%) for the substances
your study asks about; low availability for the others is an expected
skip pattern (not asked, or not answered).

**Anomaly →** Near-zero availability for a substance you did measure
points to a column-mapping or collection problem.

**Precise rules**

-   **What each bar is.** The percentage of all diary rows that have a
    value for that substance (caffeine, alcohol, nicotine, cannabis).
    The label gives the count, the percentage and the range of reported
    values.
-   **The denominator is every row,** including days with no substance
    entry at all, so the percentages are low for items that were only
    asked on some days or only in the evening survey.
-   **Units.** Caffeine is cups, alcohol is standard drinks, nicotine
    and cannabis are doses.

**FAQ**

Why is caffeine only about 11% while my participants surely drink
coffee?

The percentage is out of all diary rows, and a value exists only where
the substance question was answered. A low percentage therefore usually
reflects how often the question was asked or answered, not how often
people consume the substance.

A substance is at 0%. Is it a mistake?

It means no row has a value in that column. If your study did not ask
about it, that is expected. If it did, suspect the column mapping or the
data export.

What does the range in the label tell me?

The smallest and largest reported values. A very large maximum suggests
a units mix-up; see Figures 22–24.

**Paper caption**

> **Figure 21.** Percentage of records containing data for each
> substance (caffeine, alcohol, nicotine, cannabis), indicating how
> completely each substance domain was reported.

</div>

<div class="section level4">

#### 22 · Substance Use Value Distribution

**File** `research_ready/22_Substance_Use_Distribution.png` — generated
at `sleep_visualization.R:2870`

**Paper use** Supplement

**What each part means** Boxplots (box = middle 50% of reports; line
inside = median) with **gray dots** — each dot = one participant’s
report, jittered sideways so identical values don’t stack into one
point.

**Healthy look** Compact boxes at plausible amounts (caffeine 0–4 cups,
alcohol 0–3 drinks) with few outliers.

**Anomaly →** Extreme outliers usually mean a units problem (drinks vs
servings) and feed the amount flags; a very wide box means non-standard
dosing.

**Precise rules**

-   **What is drawn.** One box per substance that has data: the box is
    the middle half of the reports, the line inside is the median, and
    the gray dots are individual reports spread sideways so identical
    values do not stack into one dot.
-   **Which substances.** Only those with at least one value; substances
    with no data are not drawn.
-   **Units.** Caffeine is cups and alcohol is standard drinks; nicotine
    and cannabis are doses.
-   **Extreme values** feed the amount flags in Step 8.

**FAQ**

Why is the box so flat?

When most people report the same few values (1 or 2 cups, say), the
middle half of the data is narrow. A flat box means most reports agree.

Why are the gray dots in rows?

Reports are whole or round numbers, so many dots share the same height.
The sideways jitter only keeps them from sitting exactly on top of each
other.

A dot is far above the rest. Is it an error?

It is a candidate. A very large value often means a units mix-up (drinks
versus servings) and it triggers an amount flag, but it could also be a
real heavy day. Check the record.

**Paper caption**

> **Figure 22.** Boxplots with jittered points of reported values per
> substance. Units: caffeine = cups, alcohol = standard drinks, nicotine
> and cannabis = doses.

</div>

<div class="section level4">

#### 23 · Caffeine Consumption

**File** `research_ready/23_Caffeine_Consumption.png` — generated at
`sleep_visualization.R:2944`

**Paper use** Supplement

**What each part means** Bar chart, **one bar per distinct reported
value** (0, 1/3, 1/2, 1, 1 1/2, … cups/day — discrete x axis, bars never
overlap), counts + % on top. Fractional answers (half a cup and so on)
are kept exactly as reported and are labeled as fractions; the subtitle
says so. A fractional value with only one record (e.g. 0.3) has a very
short bar, but its count label is still printed.

**Healthy look** Right-skewed, with most reports at 0–1 cups — a few
heavy days, mostly light ones.

**Anomaly →** A spike at implausible values (10 or more) usually means
units confusion (cans vs cups) and feeds `AMOUNT_FLAG`.

**Precise rules**

-   **One bar per distinct reported value,** with no binning, in numeric
    order on a discrete axis, so every value has its own bar and bars
    never overlap. Fractional answers (half a cup, for example) keep
    their own bar and are labelled as fractions.
-   **Unit and column.** Cups per day, from
    `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1`.
-   **Labels.** Each bar shows its count and its share of the
    non-missing reports.
-   **Extreme values** (for example 10 or more) feed `AMOUNT_FLAG` in
    Step 8 and often mean a units mix-up (cups, cans or servings).

**FAQ**

Why does the axis have 1/2, 1 1/2 and 0.3?

Because people answered with fractions and the figure keeps every
reported value. Half a cup and one and a half cups are labelled as
fractions; other values are shown as written in the data (for example
0.3).

A fractional value has a tiny bar. Did it disappear?

No. A value reported by only one or a few records has a very short bar,
but its count is still printed above it.

Why is the most common value 1 cup and not 0?

Only days with a report are counted, and most reports are 1 or 2 cups.
Days on which nobody answered are not zeros; they are missing.

What is a suspicious value?

Anything very large, such as 10 or more cups. It usually means cans or
servings were entered as cups; such records get an amount flag.

**Paper caption**

> **Figure 23.** Count of records by reported caffeine consumption
> (cups/day). Right-skewed with a mode of 0–1 cups is expected; spikes
> at implausible values indicate unit confusion.

</div>

<div class="section level4">

#### 24 · Alcohol Consumption

**File** `research_ready/24_Alcohol_Consumption.png` — generated at
`sleep_visualization.R:2979`

**Paper use** Supplement

**What each part means** Bar chart, one bar per distinct reported value
(drinks/day), same discrete construction as Figure 23; fractional
answers (e.g. 1 1/4 drinks) are kept and labeled as fractions.

**Healthy look** Right-skewed, with most reports at the lowest counts.

**Anomaly →** A spike at high values raises the same units concern as
caffeine; verify how `alcoholtoday_PM` was coded.

**Precise rules**

-   **Same construction as Figure 23.** One bar per distinct reported
    value on a discrete axis, in numeric order; fractional answers are
    kept and labelled as fractions.
-   **Unit and column.** Standard drinks per day, from
    `alcoholtoday_PM_NumAlcoholicDrinks_1`.
-   **Labels.** Each bar shows its count and its share of the
    non-missing reports.
-   **High values** feed `AMOUNT_FLAG` in Step 8; check how the column
    was coded before treating them as real consumption.

**FAQ**

Why is there no bar for zero drinks?

If there is no bar at zero, no record reported zero drinks. A day with
no answer is missing, not zero, and the figure cannot tell a
non-drinking day from a missing one.

Why is the first bar so much taller than the rest?

Most reports are the smallest amount (one drink). The distribution is
right-skewed: many light days, a few heavy ones.

What is a standard drink?

A fixed amount of alcohol used as a unit, so beer, wine and spirits can
be compared. If participants answered in “drinks” without that
definition, treat large values with care.

**Paper caption**

> **Figure 24.** Count of records by reported alcohol consumption
> (standard drinks/day).

</div>

<div class="section level4">

#### R25 · Sleep Regularity — Weekday vs Weekend

**File** `research_ready/R25_Sleep_Regularity_Weekday_Weekend.png` —
generated at `sleep_visualization.R:3043`

**Paper use** Results

**What each part means** Two side-by-side panels — **left = Bedtime,
right = Get-up Time** (bold labels on top) — each a violin + boxplot of
the clock hour split by day type (weekday/weekend, colors).

**Columns used** Bedtime = `time_bed_corrected` (the corrected “went to
bed” timestamp, i.e. `time_bed`); Get-up Time = `time_getup_corrected`
(the corrected “left bed” timestamp, i.e. `time_getup`). Both are
pipeline-produced columns, not raw diary columns. Bedtime hours before
noon are shifted +24, so a y-value above 24 means after midnight
(e.g. 26 = 02:00).

**Healthy look** Weekend bedtimes about 0.5–1 h later and get-up about 1
h later than weekdays; otherwise the shapes are similar — the typical
small weekend shift.

**Anomaly →** Identical weekday and weekend distributions suggest
`day_type` was mis-assigned or dates were stripped; a very large weekend
shift is social jetlag and worth reporting as a finding.

**Precise rules**

-   **Which columns.** Bedtime comes from `time_bed_corrected` and
    get-up time from `time_getup_corrected`. Both are corrected
    timestamps the pipeline creates, not raw diary columns.
-   **Weekday or weekend.** From the calendar day of the bed timestamp:
    Saturday and Sunday are “Weekend”, Monday to Friday are “Weekday”. A
    bedtime after midnight carries the next day’s date.
-   **Hours above 24.** Bedtime hours before noon are shifted by +24, so
    a y value above 24 means after midnight (26 = 02:00).
-   **What is drawn.** A violin plus a box for each day type, separately
    for bedtime and get-up time; the black dot is the median.

**FAQ**

Which day does a bedtime at 02:00 belong to?

The day on the bed timestamp. After the pipeline’s midnight handling, a
bedtime at 02:00 on Sunday carries Sunday’s date, so it counts as a
weekend night; Friday night at 01:00 counts as Saturday.

Does Friday night count as a weekend night?

Only if the bedtime is after midnight, because then it carries
Saturday’s date. A Friday bedtime at 23:30 counts as a weekday. This
follows directly from the rule above and is worth remembering when you
compare to other studies.

Why are the y values above 24?

So that a bedtime just after midnight (for example 01:00) sits next to
23:00 instead of at the bottom of the axis. 25 means 01:00.

What size of weekend shift is normal?

A small shift — up to about one hour later at the weekend — is the usual
pattern. A much larger shift is social jetlag and worth reporting as a
finding.

**Paper caption**

> **Figure R25.** Violin plots with boxplots of bedtime and get-up clock
> hours, split by day type (weekday, Monday–Friday; weekend,
> Saturday–Sunday, derived from the corrected bedtime date). A modest (≤
> 1 h) weekend delay is expected; a large shift indicates social jetlag.

</div>

<div class="section level4">

#### R26 · Sleep Composition — TIB Breakdown

**File** `research_ready/R26_Sleep_Composition_TIB_Breakdown.png` —
generated at `sleep_visualization.R:3096`

**Paper use** Results

**What each part means** Stacked bar of Time in Bed composition; the
figure subtitle defines every abbreviation: TIB = TST (Total Sleep Time
— actually asleep) + SOL (Sleep Onset Latency — falling asleep) + WASO
(Wake After Sleep Onset — awake in the night), as proportions.

**Healthy look** TST is the biggest block (about 80–90% of time in bed);
SOL and WASO are small segments.

**Anomaly →** SOL or WASO taking more than 30% of time in bed means
heavy fragmentation or very long onset latency; a negative leftover
would mean a duration arithmetic bug.

**Precise rules**

-   **What the bar is.** The average share of time in bed spent in each
    of three parts: total sleep time (TST), sleep onset latency (SOL)
    and wake after sleep onset (WASO). For each record the three parts
    are divided by their sum, and those shares are then averaged over
    records.
-   **The identity.** `TIB = TST + SOL + WASO`, so the three segments
    fill the whole bar with no leftover; any tiny gap is rounding.
-   **Who is included.** Records with all three values and a TST above
    0; the subtitle gives the number.

**FAQ**

Is this the average of the pooled minutes or the average of per-record
shares?

The average of per-record shares: each record counts equally, whatever
its length. A pooled version (total minutes of each part over all
records) would give longer nights more weight and could differ slightly.

Why are SOL and WASO so small?

In most nights falling asleep and night waking take little of the time
in bed, so TST dominates. A large SOL or WASO segment means
fragmentation or a slow onset for those records.

Why a single bar instead of a pie?

A bar makes it easy to compare the segments side by side, and small
slices stay readable, which a pie would crowd.

**Paper caption**

> **Figure R26.** Stacked bars decomposing time in bed (TIB) into its
> components: total sleep time (TST), sleep onset latency (SOL), and
> wake after sleep onset (WASO), with TIB = TST + SOL + WASO by
> construction. Healthy composition places TST at 80–90% of TIB.

</div>

<div class="section level4">

#### R27 · Sleep Metrics Correlation Matrix

**File** `research_ready/R27_Sleep_Metrics_Correlation_Matrix.png` —
generated at `sleep_visualization.R:3125`

**Paper use** Results

**What each part means** Corrplot upper-triangle of pairwise Pearson
correlations among TST, SOL, WASO, SE, TIB (final corrected data),
coefficient printed in each cell.

| Color | Meaning              |
|-------|----------------------|
| Red   | Negative correlation |
| Green | Positive correlation |

**Healthy look** The signs match physiology: TST–SE strongly positive,
SOL–SE negative, TST–TIB positive, WASO–SE negative.

**Anomaly →** A wrong sign (for example TST–SE negative) means a metric
definition was altered or units were mixed; a correlation of almost
exactly ±1 between two metrics that are not defined from each other
means they are effectively the same column. (WASO–SE is strongly
negative by construction, because SE is computed from WASO.)

**Precise rules**

-   **What each cell is.** The Pearson correlation between two of TST,
    SOL, WASO, SE and TIB, computed on records where all five are
    present; the subtitle gives the number of records.
-   **The colours.** Red is negative, green is positive, and the colour
    gets stronger the closer the value is to −1 or +1. Only the upper
    triangle is shown; the diagonal is always 1.
-   **Definitional links.** Some pairs are tied by definition:
    `SE = TST / TIB` and `TIB = TST + SOL + WASO`, so their correlations
    are partly built in.

**FAQ**

Why is the TST–SE correlation high?

SE is defined from TST (SE = TST / TIB), so they share information.
Treat high correlations between definitionally linked metrics as
confirmation that the numbers are consistent, not as a new finding.

WASO and SE are almost −1. Is that suspicious?

No. SE is computed from WASO, so a very strong negative link is built
in. A value close to ±1 is only suspicious between two metrics that are
not derived from each other.

What does a sign that is the opposite of what I expect mean?

A metric definition was altered, or units were mixed (minutes versus
hours, for example). Check the columns feeding that metric before
interpreting the figure.

Does correlation tell me about cause?

No. It only says that two metrics move together in these records. It
cannot say why, and it is computed on the records that have all five
values.

**Paper caption**

> **Figure R27.** Upper-triangle corrplot of pairwise Pearson
> correlations among TST, SOL, WASO, SE, and TIB on the final corrected
> data (red = negative, green = positive, coefficient per cell).
> Expected signs: TST–SE positive, SOL–SE negative, TST–TIB positive,
> WASO–SE negative.

</div>

</div>

</div>

</div>
