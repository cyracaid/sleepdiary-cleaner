<div id="main" class="col-md-9" role="main">

# Column Mapping, Config & Data Format

sleepcleanr is fully configurable via a YAML configuration file: map
your dataset’s column names to pipeline internals and adjust thresholds
without modifying any R code.

<div id="cb1" class="sourceCode">

``` r
library(sleepcleanr)
```

</div>

<div class="section level2">

## Terminology

Two sleep-diary metric abbreviations appear in the column mapping and
threshold tables below: **SOL** (Sleep Onset Latency) and **WASO** (Wake
After Sleep Onset).

</div>

<div class="section level2">

## Install and run

<div id="cb2" class="sourceCode">

``` r
# Install from GitHub
renv::install("cyracaid/sleepdiary-cleaner")

# Load and run
library(sleepcleanr)
run_pipeline()
```

</div>

</div>

<div class="section level2">

## Using with your own dataset

The pipeline is fully configurable via a YAML configuration file. This
lets you map your dataset’s column names to pipeline variables and
adjust thresholds without modifying any R code.

<div id="cb3" class="sourceCode">

``` r
# Step 1: Copy the configuration template
library(sleepcleanr)
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
```

</div>

**Step 2: Edit `my_study.yaml`**

The file starts with the only two things you must change:

<div id="cb4" class="sourceCode">

``` yaml
data:
  files:
    main: "your_data.rds"        # Your sleep diary file (.rds or .csv)
    extra: ""                    # Leave empty unless StartDate lives in a separate file
```

</div>

Three common scenarios: - **Everything in one file** (most datasets):
`main: "my_data.rds"`, `extra: ""` - **Data split across two files**:
`main: "ema_vars.rds"`, `extra: "dates.csv"` - **Your data is a CSV**:
`main: "my_data.csv"`, `extra: ""` — the `.csv` extension is
auto-detected

<div class="section level3">

### Column Mapping

Map your dataset’s column names to the pipeline’s internal variables:

<div id="cb5" class="sourceCode">

``` yaml
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

</div>

</div>

<div class="section level3">

### Thresholds

Adjust detection sensitivity for your study population:

<div id="cb6" class="sourceCode">

``` yaml
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

</div>

Threshold rationale lives in `THRESHOLDS.md` — defaults are deliberately
lenient for healthy-adult samples; revisit for clinical populations.

</div>

<div class="section level3">

### Timestamp Format

<div id="cb7" class="sourceCode">

``` yaml
timestamp:
  input_format: "hh:mm AM/PM"   # or "HH:MM", "HH:MM:SS"
  ampm:
    enabled: true
    pm_keywords: ["PM", "pm"]
```

</div>

**Step 3: Run with your configuration**

<div id="cb8" class="sourceCode">

``` r
run_pipeline(config = "my_study_config.yaml")
```

</div>

All pipeline scripts automatically read the config; no R code changes
needed.

</div>

</div>

<div class="section level2">

## Input data structure

**This repository contains no raw participant data.** All CSV files with
participant data are gitignored. Templates with synthetic data live in
`templates/`.

| Column group           | Variables                                                                                                                                           | Description                                     |
|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| Identifiers            | pid, day\_num, row\_id, participant                                                                                                                 | Participant and record IDs                      |
| Date                   | StartDate                                                                                                                                           | Calendar date of the EMA session                |
| Raw timestamps (HH:MM) | time\_bed\_am\_hhmm, time\_sleep\_am\_hhmm, time\_awake\_am\_hhmm, time\_getup\_am\_hhmm                                                            | Self-reported bed/sleep/awake/getup clock times |
| Raw timestamps (AM/PM) | time\_bed\_am\_ampm, time\_sleep\_am\_ampm, time\_awake\_am\_ampm, time\_getup\_am\_ampm                                                            | AM/PM indicator for each timestamp              |
| Raw durations          | duration\_totalmin\_sol\_estimate\_am, duration\_totalmin\_waso\_estimate\_am                                                                       | Self-reported SOL and WASO in minutes           |
| Nap/Exercise           | duration\_totalmin\_napstoday\_PM, exercise\_PM\_totalmin\_\[Light\|Moderate\|Vigorous\|Strength\]                                                  | Self-reported nap and exercise durations        |
| Substance use          | caffeinetoday\_PM\_NumCaffeinatedDrinksSnacks\_1, alcoholtoday\_PM\_NumAlcoholicDrinks\_1, nicotine\_amount\_pm\_doses, cannabis\_amount\_pm\_doses | Self-reported substance use                     |
| WASO count             | num\_waso\_estimate\_am, num\_waso\_am                                                                                                              | Number of wake bouts                            |

</div>

<div class="section level2">

## Manual correction CSV templates

| Template File                                                     | Live File                                      | Purpose                              |
|-------------------------------------------------------------------|------------------------------------------------|--------------------------------------|
| `templates/template_manual_error_corrections.csv`                 | `manual_error_corrections.csv`                 | Timestamp corrections (AM/PM, order) |
| `templates/template_manual_unusual_corrections.csv`               | `manual_unusual_corrections.csv`               | Accepted unusual patterns            |
| `templates/template_manual_nap_exercise_corrections.csv`          | `manual_nap_exercise_corrections.csv`          | Nap/exercise duration corrections    |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO metric corrections          |
| `templates/template_manual_metric_review_acceptances.csv`         | `manual_metric_review_acceptances.csv`         | Human-accepted metric flags          |
| `templates/template_second_review_checklist.csv`                  | `second_review_checklist.csv`                  | Second-person verification decisions |

</div>

<div class="section level2">

## Output

| File                                                           | Contents                                                         |
|----------------------------------------------------------------|------------------------------------------------------------------|
| `output/correction_status_final.csv`                           | Per-run summary: n\_total, tst, sol, error/corrected/flag counts |
| `output/appendix_step_ledger.csv`                              | Per-step flag tracking ledger                                    |
| `output/flagged_records_self_reported.csv`                     | Records flagged as SELF\_REPORTED\_FLAG                          |
| `latest_visualization_*/figure_index.png`                      | Contact-sheet index of all generated figures                     |
| `output/verification/real_n13990/`, `verification/synth_n280/` | Stable, never-overwritten verification artifacts                 |

Key rules the output structure encodes: -
`latest_visualization_<tag>_n<rows>/` is “latest”, not “history” — wiped
on every visualization run. - `verification/<tag>_n<rows>/` is a sibling
that is never touched by the wipe. - Real-tagged output only ever lands
under `output/` (gitignored); synthetic output routes outside `output/`.

</div>

</div>
