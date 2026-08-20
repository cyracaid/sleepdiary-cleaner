# Interpreting the Pipeline Output

After
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
finishes, two CSV files tell you everything. This vignette explains how
to read them, how to regression-check against a previous run, and how to
read the figures.

``` r
library(sleepcleanr)
```

## 1. `output/correction_status_final.csv` — The Run Summary (Open This First)

One row per pipeline run. It answers: *“did the cleaning work as
expected?”*

``` r
read.csv("output/correction_status_final.csv")
```

| Column               | It tells you…                                                          | Check this                                                                                                                                    |
|----------------------|------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `n_total`            | Total records in your data                                             | Must equal your input row count. If smaller, records were dropped somewhere.                                                                  |
| `tst_mean_h`         | Mean total sleep time in hours                                         | 6.0–8.5 h is normal for most adult studies. If \< 5 or \> 10, something is off with the timestamp parsing or the study population is unusual. |
| `sol_mean_min`       | Mean sleep onset latency in minutes                                    | 10–45 min is normal. If \> 60, either the population has high insomnia or AM/PM confusion was not fully corrected.                            |
| `n_clean`            | Records that passed every check                                        | Should be stable across runs (same data = same count).                                                                                        |
| `n_error`            | Records with impossible temporal order (e.g., getup before bedtime)    | Should be \< 1% of total. If \> 5%, review the survey design or data collection.                                                              |
| `n_corrected`        | Records manually corrected via your CSV files                          | Should match the number of rows in your `manual_error_corrections.csv`.                                                                       |
| `timestamp_issue`    | Timestamps that could not be parsed into a valid time                  | 0 is normal. \> 0 means some participants entered non-standard time formats.                                                                  |
| `duration_issue`     | Sleep metrics (SOL, SE, TST) outside configured thresholds             | Small numbers are normal. If very large, your thresholds may be too strict or the data has quality problems.                                  |
| `amount_flag`        | Substance-use entries with unusual values                              | Should be 0 or very low.                                                                                                                      |
| `self_reported_flag` | Records where self-reported SOL/WASO disagrees with the computed value | Indicates perception bias. Check Figure 20 (SOL Perception Bias).                                                                             |

**Stability rule:** Run twice on the same data → every number must be
identical. If not, something is non-deterministic.

## 2. `output/step_flag_ledger.csv` — The Per-Step Flag Tracker (Open Second)

One row per step × per standard × per category. It answers: *“at which
step did which flag appear, and did it persist?”*

``` r
ledger <- read.csv("output/step_flag_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

Each row answers: *“at this step, using this standard, how many records
fell into this category?”*

### Column layout

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
    `equal_time_ok + skipped_na = n_total`.
3.  `flag_severity` — from Step 7 onward identical across Steps 7, 8,
    8.5: `Clean + Minor + Major = n_total - skipped_na`.
4.  `duration_extreme` — `Too short + Too long` should be \< 5% of
    `n_total`.
5.  `checkforerrors` — populated at Step 8 only.

**Example (synthetic data, 280 rows):**

    Step 7 (Compute metrics):
      data_category:    equal_time_ok = 266, skipped_na = 14        266 + 14 = 280 ✓
      flag_severity:    Clean = 251, Minor = 28, Major = 1         251 + 28 + 1 = 280 - 14 ✓
      duration_extreme: OK = 262, Too short = 1, Too long = 0

## 3. Regression Check (compare against a previous run)

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
identical(old$n_clean, new$n_clean)
```

If they differ and the input data did not change, the pipeline output
has changed. Investigate.

## 4. Quick Reference Card

| Check                 | What to run                                         | Pass if |
|-----------------------|-----------------------------------------------------|---------|
| Pipeline finished     | `file.exists("output/correction_status_final.csv")` | `TRUE`  |
| Reasonable TST        | `tst_mean_h` between 6–8.5                          | Yes     |
| Reasonable SOL        | `sol_mean_min` between 10–45                        | Yes     |
| Few errors            | `n_error < 0.01 * n_total`                          | Yes     |
| data_category stable  | Counts identical across Steps 6–8.5                 | Yes     |
| flag_severity stable  | Counts identical across Steps 7–8.5                 | Yes     |
| All records accounted | `equal_time_ok + skipped_na = n_total`              | Yes     |
| Deterministic         | Same input → same output every time                 | Yes     |

## 5. How to Read the Figures

Figures are saved to `latest_visualization_<tag>_n<rows>/` (overwritten
each run — no history). A `figure_index.png` contact sheet shows all
figures at a glance. Stable verification artifacts (snapshots,
Bland-Altman plots, threshold validation) live separately in
`output/verification/<tag>/`.

**Publication figures (for a Methods section):**

| Figure                           | File                                             | What it shows                                                                                                          |
|----------------------------------|--------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| **Figure 1 — Pipeline Flow**     | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | Vertical flow diagram: raw → parsed → algo-corrected → manual-corrected → final valid, with counts and % at each stage |
| **Figure 2 — Correction Impact** | `research_ready/02_Correction_Impact.png`        | A/B delta lollipops (only modified records, TST & SOL) + identity scatter + before/after summary table                 |

**Five must-check figures:**

| Step | Figure                              | Should look like                                                   | If not?                                   |
|:----:|-------------------------------------|--------------------------------------------------------------------|-------------------------------------------|
|  1   | **01 Final Data Quality Dashboard** | Bell-shaped TST/SOL/WASO/SE histograms, no spikes at 0 or extremes | Spike at 0 = missing data/parsing failure |
|  2   | **12 Pipeline Correction Progress** | Corrected bar appears ONLY at C (Step 6.5), flat after             | Change after C = instability              |
|  3   | **18 Auto-Detected Dashboard**      | Flag counts match `correction_status_final.csv`                    | Mismatch = misalignment                   |
|  4   | **02 Distribution Sleep Variables** | TST peaks 6–8 h, SOL right-skewed, WASO \< 60, SE \> 85%           | SOL flat/bimodal = AM/PM confusion        |
|  5   | **19 Unified Quality Status**       | Most records Clean/Minor; Error+Unusual \< 5%                      | High = review manual CSVs                 |
