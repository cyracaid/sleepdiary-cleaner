# SPL Sleep — EMA Sleep Diary Data Cleaning Pipeline

> **[English](#english) · [中文](#中文)**

---

<a name="english"></a>

# English Version

SPL Sleep is a reproducible, auditable R pipeline for cleaning sleep EMA (ecological momentary assessment) diary data. It parses raw bedtime/sleep/awake/get-up timestamps, detects and corrects temporal and duration errors through a transparent human-in-the-loop workflow (every correction stored in a re-readable CSV), computes standard sleep metrics (TST, SOL, WASO, SE), validates self-reported durations, and generates diagnostic and research-ready figures. A schema-validated YAML config maps the pipeline to your dataset without touching code; detection thresholds and their rationale are documented in THRESHOLDS.md, and the input contract in SCHEMA.md.

**v1.4.0 (current)** — delivery release, 190+ tests, R CMD CHECK 0 ERROR / 0 WARNING. Adds `finalize_columns()` as Step 10, the column dictionary as single source of truth, reserved affect-layer columns, an export guard against negative signed minutes, and CI-verified delivery wiring. Installable via `renv::install("cyracaid/sleepdiary-cleaner")`. See [releases](https://github.com/cyracaid/sleepdiary-cleaner/releases) for full changelog.

## Phase status

* **Phase 1 — delivery pipeline (v1.4.0): complete.** Cleaning logic is frozen;
  this is the CLI release of the reproducible cleaning pipeline.
* **Phase 2 — analytics** and **Phase 3 — methods paper: paused.** Deliberately
  deferred while Phase 1 is reviewed by the study team.

## Features

- **9-step pipeline**: raw data → timestamp parsing → interval processing → temporal correction → duration correction → metric computation → auto-detection → cross-participant consistency → visualization
- **Manual correction CSV workflow**: human review decisions stored in CSVs, re-read on each pipeline run
- **Configurable thresholds**: SOL/SE/TST-TIB flag thresholds, timestamp format, column names — all set in a YAML config file
- **Checkpoint reporter**: per-step clean/error/unusual/corrected counts printed and saved to CSV
- **Diagnostic figures**: organized into `pipeline_cleaning/` (QC, pipeline flow, correction impact) and `research_ready/` (sleep metrics, substance use, perception)
- **R package**: `library(splsleep); run_pipeline()` — installable, versioned, dependency-managed
- **Correction traceability**: `has_correction` enum column (none / algorithmic / manual / both) plus per-step audit ledger
- **Column mapping**: `adapt_columns()` maps your dataset's column names to pipeline internals via YAML config — no code changes
- **190+ tests**: covering correction engine, classification thresholds, auto-detection logic, config validation, and the finalize/guard delivery contract

## Pipeline Architecture

```
Raw Data ──→ Step 1: Load Data ──→ Step 2: Parse Timestamps ──→ Step 3: Parse Intervals ──→ Step 4: Normalize Sequence
                                                                                                      │
                                                                                                      ▼
                                                                                             Step 5: Classify Records
                                                                                             (generates review CSVs)
                                                                                                      │
                                                                                             Step 5.75: Second Review
                                                                                                      │
                                                                                             Step 6: Apply Manual Corrections
                                                                                             (reads manual_error_corrections.csv)
                                                                                                      │
                                                                                             Step 6.5: Apply Duration Corrections
                                                                                             (nap, exercise, SOL/WASO corrections)
                                                                                                      │
                                                                                             Step 7: Compute Sleep Metrics
                                                                                             (TST, SOL, WASO, SE, TIB)
                                                                                                      │
                                                                                             Step 8: Auto-Detect Remaining
                                                                                             (TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED)
                                                                                                      │
                                                                                             Step 8.5: Cross-Participant Check
                                                                                                      │
                                                                                              Step 9: Generate Figures
```

### Classification Systems

| System | Source | Categories |
|--------|--------|------------|
| `data_category` | Step 6 (temporal) | clean, error, unusual, equal_time_ok, skipped_na |
| `has_correction` | Step 7 (traceability) | none, algorithmic, manual, both |
| `flag_severity` | Step 7 (metrics) | Clean, Minor (1 flag), Major (2+ flags) |
| `checkforerrors_summary` | Step 8 (auto-detect) | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG, CLEAN |

### Figures

| Folder | Content |
|--------|---------|
| `pipeline_cleaning/` | Pipeline flow diagram, data quality dashboard, flag composition, per-participant flag rate, step flag ledger |
| `research_ready/` | Correction impact (before/after delta), sleep variable distributions, perception bias, substance use, sleep regularity, correlation matrix |

## Quick Start

### Prerequisites

- R ≥ 4.2
- Raw EMA data files (RDS + CSV format with sleep diary timestamps)

### Install and Run

```r
# Install from GitHub
renv::install("cyracaid/sleepdiary-cleaner")

# Load and run
library(splsleep)
run_pipeline()
```

### Using with Your Own Dataset

The pipeline is fully configurable via a YAML configuration file. This lets you map your dataset's column names to pipeline variables and adjust thresholds without modifying any R code.

```r
# Step 1: Copy the configuration template
library(splsleep)
file.copy(system.file("config_template.yaml", package = "splsleep"),
          "my_study.yaml")
```

**Step 2: Edit `my_study.yaml`**

The file starts with the only two things you must change:

```yaml
data:
  files:
    main: "your_data.rds"        # Your sleep diary file (.rds or .csv)
    extra: ""                    # Leave empty unless StartDate lives in a separate file
```

Three common scenarios:
- **Everything in one file** (most datasets): `main: "my_data.rds"`, `extra: ""`
- **Data split across two files**: `main: "ema_vars.rds"`, `extra: "dates.csv"`
- **Your data is a CSV**: `main: "my_data.csv"`, `extra: ""` — the `.csv` extension is auto-detected

The config file has additional optional sections for column mapping and thresholds:

#### Column Mapping
Map your dataset's column names to the pipeline's internal variables:

```yaml
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

#### Thresholds
Adjust detection sensitivity for your study population:

```yaml
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

#### Timestamp Format
Specify how your timestamps are stored:

```yaml
timestamp:
  input_format: "hh:mm AM/PM"   # or "HH:MM", "HH:MM:SS"
  ampm:
    enabled: true
    pm_keywords: ["PM", "pm"]
```

**Step 3: Run with your configuration**

```r
run_pipeline(config = "my_study_config.yaml")
```

All pipeline scripts automatically read the config; no R code changes needed.

## How the Pipeline Treats Your Data (Non-Destructive Model)

**The pipeline never deletes a record.** Cleaning means *adding labels and corrected columns*, not removing rows. The number of records in `corrected_ema_data` always equals the number of records you put in.

```
Input:  N raw records
Output: N records, each with additional classification columns
        (data_category, flag_severity) and corrected-value columns
        (time_*_corrected). Raw columns are preserved untouched.
```

What this means for you:

- **Nothing is lost.** Raw timestamps (`time_bed_am_hhmm_ampm`, etc.) stay in the data. Corrected versions are added as new columns (`time_bed_corrected`), so every correction is auditable against the original value.
- **Every record is labelled, not removed.** Records that fail validation are tagged (`data_category = "error"` or `"unusual"`) but remain in the dataset. You decide later whether to include or exclude them in analysis.
- **"Final Clean Dataset" is a recommended analysis subset, not a physically separate file.** It is the records where `data_category` is `clean` or `equal_time_ok`. You can filter to it anytime:

```r
clean_data <- corrected_ema_data[corrected_ema_data$data_category %in% c("clean", "equal_time_ok"), ]
```

**One exception:** records with all four sleep-event timestamps missing (`data_category = "skipped_na"`) remain in the file, but their TST/SOL/WASO metrics are `NA` — there is no way to compute sleep metrics from missing timestamps. They are usable for compliance/attrition analysis (e.g., "how many days did each participant complete?") but not for sleep-metric analysis.

| Record type | Stays in data? | Has sleep metrics? | Suitable for sleep analysis? |
|-------------|:--------------:|:------------------:|:----------------------------:|
| clean / equal_time_ok | Yes | Yes | **Yes** (recommended) |
| error / unusual (flagged) | Yes | Yes | With caution — researcher decides |
| skipped_na (missing timestamps) | Yes | No (NA) | No — compliance analysis only |

## Data Format (Text Only — Templates Provided)

**This repository contains no raw participant data, no real identifiers, and no actual study responses.** All CSV files containing participant data are excluded via `.gitignore` and purged from git history.

Template CSV files with synthetic data are in [`templates/`](templates/). Copy these to create your own correction files.

### Input Data Structure (Text Description)

#### Main Sleep Diary Data (RDS format)

| Column group | Variables | Description |
|---|---|---|
| Identifiers | pid, day_num, row_id, participant | Participant and record IDs |
| Date | StartDate | Calendar date of the EMA session |
| Raw timestamps (HH:MM) | time_bed_am_hhmm, time_sleep_am_hhmm, time_awake_am_hhmm, time_getup_am_hhmm | Self-reported bed/sleep/awake/getup clock times |
| Raw timestamps (AM/PM) | time_bed_am_ampm, time_sleep_am_ampm, time_awake_am_ampm, time_getup_am_ampm | AM/PM indicator for each timestamp |
| Raw durations | duration_totalmin_sol_estimate_am, duration_totalmin_waso_estimate_am | Self-reported SOL and WASO in minutes |
| Nap/Exercise | duration_totalmin_napstoday_PM, exercise_PM_totalmin_[Light\|Moderate\|Vigorous\|Strength] | Self-reported nap and exercise durations |
| Substance use | caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1, alcoholtoday_PM_NumAlcoholicDrinks_1, nicotine_amount_pm_doses, cannabis_amount_pm_doses | Self-reported substance use |
| WASO count | num_waso_estimate_am, num_waso_am | Number of wake bouts |

### Manual Correction CSV Templates

| Template File | Live File | Purpose |
|---|---|---|
| `templates/template_manual_error_corrections.csv` | `manual_error_corrections.csv` | Timestamp corrections (AM/PM, order) |
| `templates/template_manual_unusual_corrections.csv` | `manual_unusual_corrections.csv` | Accepted unusual patterns |
| `templates/template_manual_nap_exercise_corrections.csv` | `manual_nap_exercise_corrections.csv` | Nap/exercise duration corrections |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO metric corrections |
| `templates/template_manual_metric_review_acceptances.csv` | `manual_metric_review_acceptances.csv` | Human-accepted metric flags |
| `templates/template_second_review_checklist.csv` | `second_review_checklist.csv` | Second-person verification decisions |

Each template uses synthetic data. See the template files for column-level descriptions.

### Output

| File | Contents |
|------|----------|
| `output/correction_status_final.csv` | Per-run summary: n_total, tst, sol, error/corrected/flag counts |
| `output/appendix_step_ledger.csv` | Per-step flag tracking ledger |
| `output/flagged_records_self_reported.csv` | Records flagged as SELF_REPORTED_FLAG |
| `latest_visualization_*/figure_index.png` | Contact-sheet index of all generated figures |
| `latest_visualization_*/RUN_INFO.txt` | Run provenance: dataset tag, version, git commit, file sources. **Overwritten every run.** |
| `output/verification/real_n13990/`, `verification/synth_n280/` | Stable, never-overwritten verification artifacts (S3-vs-legacy snapshots, Bland-Altman plots, threshold validation, audit reports) — see `verification_run_dir()` in `R/config.R` |

#### Full Output Directory Structure

```
output/                                        <- REAL data (gitignored, never committed)
├── cleaned_data_final.{csv,rds}                <- Delivered dataset A
├── cleaned_data_prepostcorrection.{csv,rds}    <- Delivered dataset B
├── cleaned_data_full.rds                       <- Full-column archive (not delivered)
├── corrected_ema_data.rds                      <- Cleaning intermediate (feeds visualization)
├── correction_status.csv                       <- Draft/intermediate run report
├── correction_status_final.csv                 <- Final run summary (read this one)
├── appendix_step_ledger.csv
├── audit_integrity_report.csv
├── flagged_records_self_reported.csv
├── column_dictionary_gaps.csv
├── step_flag_ledger.csv
│
├── latest_visualization_real_n<rows>/          <- Most recent REAL-data figure run.
│   │                                              Overwritten every run -- no history.
│   ├── RUN_INFO.txt                            <- Provenance for THIS run only
│   ├── figure_index.png
│   ├── flag_distribution.csv
│   ├── pipeline_cleaning/                      <- Cleaning diagnostics
│   └── research_ready/                         <- Publication-ready figures
│
└── verification/real_n<rows>/                  <- STABLE, never overwritten or wiped.
    ├── VERIFICATION_<date>.md                  <- S3-vs-legacy snapshot report
    ├── snapshot_old.rds / snapshot_s3.rds       <- Comparison snapshots
    ├── bland_altman_sol.png / _waso.png        <- Regenerated every real-data run
    └── threshold_validation.csv                <- Regenerated every real-data run

                                                <- Below: project root, NOT inside output/
latest_visualization_synth_n<rows>/             <- Most recent SYNTHETIC test figure run.
├── RUN_INFO.txt                                   Tag reads 'synth' -- not real data.
├── figure_index.png
├── flag_distribution.csv
├── pipeline_cleaning/
└── research_ready/

verification/synth_n<rows>/                     <- STABLE synth verification artifacts,
├── snapshot_old.rds / snapshot_s3.rds             same structure as verification/real_n<rows>/
├── bland_altman_sol.png / _waso.png
└── threshold_validation.csv
```

Key rules this structure encodes:

- **`latest_visualization_<tag>_n<rows>/` is "latest", not "history".** It is deleted and rebuilt from scratch on every `run_visualization()` call. Nothing inside it survives a rerun except by accident.
- **`verification/<tag>_n<rows>/` is a sibling, not a child, of the figure directory above** (`verification_run_dir()` in `R/config.R`). It is never touched by the wipe, so no special preserve logic is needed anywhere.
- **Location, not just the name, signals real vs. synthetic.** Real-tagged output only ever lands under `output/` (gitignored). Synthetic and `unknown`-tagged output are routed outside `output/` by default — see `figure_run_dir()` in `R/config.R`. A run tagged `unknown` (its data source could not be identified from config) is treated the same as `synth`, never as `real`.
- **Being outside `output/` does not mean git-tracked.** `.gitignore`'s `latest_visualization*/` and the anchored `/verification/` rule both catch these directories regardless of location.

## Agent Skill

**Location**: `.opencode/skills/splsleep-pipeline/SKILL.md`

The skill enables AI assistants to understand the pipeline architecture, run the pipeline, interpret checkpoint reports, add manual corrections, and diagnose issues.

Registered in `opencode.jsonc`:

```json
{
  "skills": {
    "splsleep-pipeline": {
      "description": "Run and maintain the sleep EMA diary data cleaning pipeline",
      "triggers": ["splsleep", "sleep pipeline", "sleep EMA", "run_pipeline"]
    }
  }
}
```

## How to Read the Pipeline Output

After `run_pipeline()` finishes, two CSV files tell you everything. Here is how to read them.

---

### 1. `output/correction_status_final.csv` — The Run Summary (Open This First)

One row per pipeline run. It answers: *"did the cleaning work as expected?"*

**How to open it:**

```r
read.csv("output/correction_status_final.csv")
```

**What each column means and what to check:**

| Column | It tells you... | Check this |
|--------|----------------|------------|
| `n_total` | Total records in your data | Must equal your input row count. If smaller, records were dropped somewhere. |
| `tst_mean_h` | Mean total sleep time in hours | 6.0–8.5 h is normal for most adult studies. If < 5 or > 10, something is off with the timestamp parsing or the study population is unusual. |
| `sol_mean_min` | Mean sleep onset latency in minutes | 10–45 min is normal. If > 60, either the population has high insomnia or AM/PM confusion was not fully corrected. |
| `n_clean` | Records that passed every check | Should be stable across runs (same data = same count). |
| `n_error` | Records with impossible temporal order (e.g., getup before bedtime) | Should be < 1% of total. If > 5%, review the survey design or data collection. |
| `n_corrected` | Records manually corrected via your CSV files | Should match the number of rows in your `manual_error_corrections.csv`. |
| `n_corrected` jump from 0 to 71 to 81 across B→C→D checkpoints | 71 = timestamp corrections, +10 = duration corrections | The jump at the right step is expected. |
| `timestamp_issue` | Timestamps that could not be parsed into a valid time | 0 is normal. > 0 means some participants entered non-standard time formats. |
| `duration_issue` | Sleep metrics (SOL, SE, TST) outside configured thresholds | Small numbers are normal (e.g., 10 out of 280). If very large, your thresholds may be too strict or the data has quality problems. |
| `amount_flag` | Substance-use entries with unusual values (e.g., text, 3-digit numbers) | Should be 0 or very low. Automatic text-to-number conversion handles "three" → 3. |
| `self_reported_flag` | Records where self-reported SOL/WASO disagrees with the computed value | Indicates perception bias. Check Figure 20 (SOL Perception Bias) to see the pattern. |

**Real example (synthetic data):**

```
  n_total tst_mean_h sol_mean_min n_clean n_error n_corrected duration_issue
    N      ~7.5       ~30          ...     0       ...          0-10
```

Interpretation: 280 records, mean TST 6.94 h (normal), mean SOL 31.4 min (normal). 10 duration issues (plausible). No errors (synthetic data was well-formed).

**Stability rule:** Run twice on the same data → every number must be identical. If not, something is non-deterministic.

---

### 2. `output/step_flag_ledger.csv` — The Per-Step Flag Tracker (Open Second)

One row per step × per standard × per category. It answers: *"at which step did which flag appear, and did it persist?"*

**How to open it:**

```r
ledger <- read.csv("output/step_flag_ledger.csv")

# Only rows with actual numbers (skip NA = not yet computed)
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

#### What each "standard" is

The ledger uses 5 independent evaluation systems. Each one becomes meaningful only after the step that computes it:

| Standard | First step with numbers | What it evaluates | Key categories |
|----------|:----------------------:|-------------------|----------------|
| `field_misentry` | 1.5 | Whether a duration estimate (SOL, WASO) exactly matches a timestamp — may indicate "typed in wrong box" | `none`, `SOL=time_sleep`, `SOL=time_bed`, `WASO=time_awake`, `WASO=time_getup` |
| `data_category` | 4 | Temporal order and plausibility of the bed → sleep → awake → getup sequence | `clean`, `error`, `unusual`, `equal_time_ok`, `skipped_na` |
| `flag_severity` | 7 | How many derived-metric flags (low SE, high SOL, high WASO) each record triggered | `Clean`, `Minor (1 flag)`, `Major (2+ flags)` |
| `duration_extreme` | 7 | Total sleep time outside physiologically plausible bounds | `OK`, `Too short (< 3 h)`, `Too long (> 12 h)` |
| `checkforerrors` | 8 | Summary of all auto-detection flags assembled in Step 8 | `TIMESTAMP_ISSUE`, `DURATION_ISSUE`, `AMOUNT_FLAG`, `SELF_REPORTED_FLAG` |

**Conceptual rule:** Standards are computed once and never re-computed. If a standard's counts change after its first computation step, something is wrong.

#### How to validate each standard

**a. `data_category` — must be frozen from Step 6 onward**

Run this:
```r
ledger %>%
  filter(standard == "data_category", !is.na(count)) %>%
  select(step_id, label, category, count)
```

You should see: Steps 6, 6.5, 7, 8, 8.5 all have **identical** numbers for every category (`equal_time_ok`, `skipped_na`, `clean`, `error`, `unusual`). Step 8 (Auto-detect) does NOT reclassify records — it only summarizes.

**Arithmetic check:** `equal_time_ok + skipped_na = n_total`

**b. `flag_severity` — must be frozen from Step 7 onward**

Run this:
```r
ledger %>%
  filter(standard == "flag_severity", !is.na(count)) %>%
  select(step_id, label, category, count)
```

Steps 7, 8, 8.5 must have **identical** Clean / Minor / Major counts. Severity is computed once in Step 7.

**Arithmetic check:** `Clean + Minor + Major = n_total - skipped_na`

**c. `field_misentry` — cross-field contamination check**

If any category other than `none` has `count > 0`, the participant may have typed a duration into a time field or vice versa. This is flagged at Step 1.5 and recorded through every subsequent step.

**d. `duration_extreme` — implausible sleep durations**

From Step 7 onward: `Too short (< 3 h)` + `Too long (> 12 h)` should sum to < 5% of `n_total`. If higher, review whether participant instructions or data collection need adjustment.

**e. `checkforerrors` — auto-detection flags (Step 8 only)**

This standard is populated only at Step 8. It summarizes:
- `TIMESTAMP_ISSUE`: timestamps that could not be parsed
- `DURATION_ISSUE`: metrics outside configured thresholds
- `AMOUNT_FLAG`: anomalous substance-use entries
- `SELF_REPORTED_FLAG`: self-reported vs computed value mismatch

#### Example (synthetic demo data)

```
  Step 4 (Normalize sequence):       data_category: equal_time_ok=266, skipped_na=14
  Step 6 (Manual corrections):       data_category: equal_time_ok=266, skipped_na=14  (unchanged)
  Step 7 (Compute metrics):          data_category: equal_time_ok=266, skipped_na=14  (unchanged)
                                     flag_severity: Clean=251, Minor=28, Major=1
                                     duration_extreme: OK=262, Too short=1, Too long=0
  Step 8 (Auto-detect):              data_category + flag_severity + duration_extreme = unchanged from Step 7
  Step 8.5 (Cross-participant):      same as Step 8
```

The numbers do not change after they are first computed. This is the signature of a stable pipeline.

---

### 3. Regression Check (compare against a previous run)

`output/correction_status_old.csv` is not written by any pipeline script — you create it yourself, as a saved baseline, before rerunning:

```r
# BEFORE rerunning the pipeline (e.g. after a code change you want to check
# for regressions): save the current output as your baseline.
file.copy("output/correction_status_final.csv", "output/correction_status_old.csv",
          overwrite = TRUE)

# ... rerun the pipeline here ...

# AFTER rerunning: compare against the baseline you just saved.
old <- read.csv("output/correction_status_old.csv")
new <- read.csv("output/correction_status_final.csv")

# These must be identical if the input data has not changed
identical(old$tst_mean_h, new$tst_mean_h)
identical(old$sol_mean_min, new$sol_mean_min)
identical(old$n_clean, new$n_clean)
identical(old$n_corrected, new$n_corrected)
```

If they differ and the input data did not change, the pipeline output has changed. Investigate.

---

### 4. Quick Reference Card (print this)

| Check | What to run | Pass if |
|-------|-------------|---------|
| Pipeline finished | `file.exists("output/correction_status_final.csv")` | `TRUE` |
| Reasonable TST | `tst_mean_h` between 6–8.5 | Yes |
| Reasonable SOL | `sol_mean_min` between 10–45 | Yes |
| Few errors | `n_error < 0.01 * n_total` | Yes |
| data_category stable | Counts identical across Steps 6–8.5 | Yes |
| flag_severity stable | Counts identical across Steps 7–8.5 | Yes |
| All records accounted | `equal_time_ok + skipped_na = n_total` | Yes |
| Deterministic | Same input → same output every time | Yes |

---

### 5. How to Read the Figures

Figures are saved in a directory named `latest_visualization_<tag>_n<rows>/` (e.g. `output/latest_visualization_real_n13990/`) that is **overwritten on each run — no history kept**; `RUN_INFO.txt` inside it records only the most recent run's provenance (data source, package version, git commit). A `figure_index.png` contact sheet shows all figures at a glance. Snapshot comparisons, Bland-Altman plots, and other verification artifacts that DO need to survive across runs live separately, in `verification_run_dir()`'s stable location (e.g. `output/verification/real_n13990/`), never inside the overwritten figure directory.

#### Publication Figures (for your Methods section)

Two publication-ready figures answer the reviewer questions: *"How did the cleaning pipeline work?"* and *"What effect did it have on the data?"* — without requiring the reader to inspect source code.

| Figure | File | What it shows |
|--------|------|---------------|
| **Figure 1 — Pipeline Flow** | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | Vertical flow diagram: raw records → parsed → algo-corrected → manual-corrected → final valid. Each stage with count and % of total. Right panel: breakdown by classification (clean, error, unusual, not reported, equal time). |
| **Figure 2 — Correction Impact** | `research_ready/02_Correction_Impact.png` | Three panels: **A/B** = delta lollipops showing only modified records for TST and SOL (sorted by magnitude). **C** = identity scatter plot with unchanged records as faint gray backdrop, modified records in orange/blue. Below: Before/After summary table (mean, SD). |

Both figures read all numbers directly from `corrected_ema_data` — no hardcoded values. Percentages use the raw record count as the denominator. Generated automatically by `run_pipeline()`.

| Step | Figure | Look at this | It should look like this | If not? |
|:----:|--------|-------------|--------------------------|---------|
| 1 | **01 Final Data Quality Dashboard** `pipeline_cleaning/` | The TST / SOL / WASO / SE histograms (top row) | Bell-shaped curves. No spikes at 0 or extreme values. | Large spike at 0 = missing data or parsing failure. Spike at max = threshold too loose. |
| 2 | **12 Pipeline Correction Progress** `pipeline_cleaning/` | The grouped bar chart showing Clean / Error / Corrected across the 5 checkpoints (A–E) | Corrected bar appears ONLY at C (Step 6.5) and stays flat after that. | Corrected bar before C = correction logic triggered too early. Corrected bar changes after C = instability. |
| 3 | **18 Auto-Detected Dashboard** `pipeline_cleaning/` | The flag counts (TIMESTAMP_ISSUE, DURATION_ISSUE, etc.) | Numbers match what you saw in `correction_status_final.csv`. TIMESTAMP_ISSUE is 0 or very low. | Mismatch = the auto-detection output is not aligned with the run summary. Investigate. |
| 4 | **02 Distribution Sleep Variables** `research_ready/` | The four histograms (TST, SOL, WASO, SE) | TST peaks 6–8 h. SOL is right-skewed (mostly 10–45). WASO < 60 min. SE peaks > 85%. | TST peak < 5 h = study population may have short sleep or timestamps are off. SOL flat or bimodal = possible AM/PM confusion not fully resolved. |
| 5 | **19 Unified Quality Status** `research_ready/` | The pie or bar chart of Clean / Minor / Major / Error / Unusual | Most records are Clean or Minor. Error + Unusual < 5% of total. | High Error + Unusual = review the manual correction CSVs. Something systematic may have been missed. |

**If all 5 pass, the pipeline output is valid.** If any fail, go to Part B to diagnose.

---

#### Part B: Complete Figure Reference

##### Figures 01–06: Data Quality and Distributions

| Figure | Section | What it shows | Detailed interpretation |
|--------|---------|---------------|------------------------|
| **01 Final Data Quality Dashboard** | `pipeline_cleaning/` | Multi-panel dashboard with TST, SOL, WASO, SE distributions + records per participant | **Distributions** (top row, 4 histograms): Each should be a plausible bell or right-skewed curve. TST centered ~6–8 h. SOL right-skewed (most < 45 min). WASO right-skewed (most < 60 min). SE left-skewed (most > 85%). **Records per participant** (bottom row): Bar heights should be roughly equal (similar data from each participant). A very tall bar means one participant has many more records than others — may indicate duplicate entries. |
| **02 Distribution Sleep Variables** | `research_ready/` | Same 4 histograms as Figure 01 but in publication-ready layout | Same interpretation as Figure 01 upper row. This figure is for use in reports and presentations. |
| **03 Sleep Duration Distribution** | `research_ready/` | Histogram of TST alone | Peak should be between 360 and 480 min (6–8 h). Values below 180 min (< 3 h) or above 720 min (> 12 h) should be rare or flagged by the pipeline. |
| **04 Sleep Duration vs Time in Bed** | `research_ready/` | Scatter plot: TIB (x-axis) vs TST (y-axis) | Points should cluster along the diagonal (TST ≤ TIB). Points far below the diagonal = high WASO (lots of wake time). Points on the diagonal = WASO near zero. Outliers with TST > TIB are flagged as impossible (error). |
| **04B SOL vs Sleep Duration** | `research_ready/` | Scatter plot: SOL (x-axis) vs TST (y-axis) | Weak negative correlation is expected: higher SOL → slightly less TST. A flat or positive slope suggests an AM/PM confusion pattern (SOL values are not real). |
| **05 Variability Sleep Variables** | `research_ready/` | Boxplots of TST, SOL, WASO, SE per participant (or grouped) | Shows between-participant variability. Each box should have reasonable width. Very wide boxes = high day-to-day variability in that participant. Very narrow boxes = possible duplicate or non-varying data. |

##### Figures 07–12: Pipeline Progress and Classification

| Figure | Section | What it shows | Detailed interpretation |
|--------|---------|---------------|------------------------|
| **07 Flag Composition Stacked** | `pipeline_cleaning/` | Stacked bar chart of flag types at each pipeline step | The proportion of TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG should decrease or stay flat as corrections are applied. If a flag type increases after Step 6 (Manual corrections), the correction logic may have introduced new errors. |
| **08 Sleep Duration by Category** | `pipeline_cleaning/` | Boxplot of TST grouped by `data_category` (clean, error, unusual, equal_time_ok, skipped_na) | Clean and equal_time_ok records should show similar TST distributions. Error records should show extreme TST values (very short or very long). If clean and error distributions overlap completely, the error classification may be too strict. |
| **09 Bedtime vs Getup Distribution** | `pipeline_cleaning/` | Clock-plot (circular) showing bed and getup times | Bedtime should cluster around 22:00–01:00 (10 PM–1 AM). Getup around 06:00–09:00 (6 AM–9 AM). Points outside these ranges may indicate AM/PM errors (e.g., bedtime recorded as 13:00 = 1 PM instead of 1 AM) or shift-work schedules. |
| **10 Extreme Sleep Duration** | `pipeline_cleaning/` | Scatter or bar plot of records with extreme TST (< 3 h or > 12 h) | Each extreme record should have a clear explanation: missing data, AM/PM error, or genuine short/long sleep. If many records are extreme, review the threshold. |
| **12 Pipeline Correction Progress** | `pipeline_cleaning/` | Grouped bar chart at Checkpoints A–E showing Clean, Error, Unusual, Equal Time, Corrected counts | **This is the most important figure for pipeline validation.** The Corrected bar should first appear at Checkpoint C (Step 6.5) and stay at the same height through E. If Corrected increases between C and E, the correction logic applied corrections after the "corrections" step — a bug. If Clean decreases after B, corrections removed the wrong flag from some records. |
| **—** | | | *Figure 11 was removed (free-y axis comparison was misleading).* |

##### Figures 13–18: Auto-Detection and Error Patterns

| Figure | Section | What it shows | Detailed interpretation |
|--------|---------|---------------|------------------------|
| **13 Error Category Distribution** | `pipeline_cleaning/` | Bar chart of error types (order_error, bed_sleep_diff_error, awake_getup_diff_error, sleep_awake_24h_error) | Shows which temporal errors are most common. `order_error` (bed > sleep > awake > getup violated) should be the rarest — it means a record's timestamps cannot be arranged in chronological order at all. `bed_sleep_diff_error` (difference > 7 h) may indicate the participant reports "time to bed" and "time to sleep" inconsistently. If any error type dominates (> 50% of errors), review that specific survey question. |
| **14 Sleep Duration Pre-Correction** | `pipeline_cleaning/` | Distribution of TST BEFORE manual corrections are applied | Compare with Figure 03 (post-correction). If pre-correction has more extreme values, the corrections are working as expected. If pre- and post-correction look identical, the manual correction CSVs may not have been read correctly. |
| **15 Error Timeline** | `pipeline_cleaning/` | Error records plotted over time (study day on x-axis) | Errors should be randomly distributed across study days. If errors cluster on specific days (e.g., Day 1 only), participants may have had trouble starting the survey. If errors cluster late in the study, participant fatigue may be affecting data quality. |
| **16 Common Error Patterns** | `pipeline_cleaning/` | Most frequent combinations of error types per participant | Some participants may have multiple errors of different types. If a participant has both `order_error` and `bed_sleep_diff_error`, their data entry pattern is problematic — consider excluding them or reviewing their training. |
| **17 Top Participants Flags** | `pipeline_cleaning/` | Bar chart: participants with the most total flags | One participant with many more flags than others = investigate their raw data. They may have not understood the survey, or their sleep pattern is genuinely unusual. Evenly distributed flags across participants = good. |
| **18 Auto-Detected Dashboard** | `pipeline_cleaning/` | Dashboard of all flags from Step 8: TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG | TIMESTAMP_ISSUE should be 0 or very low (unparseable timestamps). DURATION_ISSUE flags records outside configured metric thresholds — compare with `correction_status_final.csv` to verify the count matches. SELF_REPORTED_FLAG indicates a disconnect between what the participant estimated and what the timestamps compute. Cross-reference with Figure 20. |

##### Figure 19: Unified Classification Summary

| Figure | Section | What it shows | Detailed interpretation |
|--------|---------|---------------|------------------------|
| **19 Unified Quality Status** | `research_ready/` | Pie chart or bar of final classification: Clean, Minor, Major, Error, Unusual | This is your final quality summary. Most records should be Clean or Minor. Error + Unusual should be a small fraction (< 5%). If Error + Unusual is large, the data collection protocol or correction CSV workflow may need adjustment. |

##### Figures 20–20B: Perception Bias

| Figure | Section | What it shows | Detailed interpretation |
|--------|---------|---------------|------------------------|
| **20 SOL Perception Bias** | `research_ready/` | Bland-Altman plot: self-reported SOL vs computed SOL | **X-axis:** mean of self-reported and computed SOL. **Y-axis:** computed minus self-reported. **This plot answers:** "Do participants accurately estimate their sleep onset latency?" If the horizontal bias line is near 0 (y ≈ 0), self-report is accurate. If the bias line is above 0, participants overestimate their SOL (they think it took longer than it did). If below 0, they underestimate. The dotted lines are 95% limits of agreement — 95% of differences should fall between them. If many points fall outside, the disagreement is large. |
| **20B WASO Perception Bias** | `research_ready/` | Bland-Altman plot: self-reported WASO vs computed WASO | Same interpretation as Figure 20 but for wake-after-sleep-onset. Note: WASO has no "computed" equivalent in EMA data (both values come from self-report). This figure compares two different processing paths for the same self-report, so it measures consistency, not accuracy. |

##### Figures 21–24: Substance Use

| Figure | Section | What it shows | Detailed interpretation |
|--------|---------|---------------|------------------------|
| **21 Substance Use Availability** | `research_ready/` | Bar chart or table showing how many records have non-NA values for each substance (caffeine, alcohol, nicotine, cannabis) | High availability (most records have a value) = good compliance. Low availability for a specific substance = participants may have skipped that question, or it was added late to the survey. |
| **22 Substance Use Distribution** | `research_ready/` | Combined distribution plots for all four substances | Caffeine should show the widest range (0–5+ drinks). Alcohol typically 0–3. Nicotine and cannabis use depends on study population. Spikes at 888 or 999 = filler codes (handled by the pipeline). |
| **23 Caffeine Consumption** | `research_ready/` | Histogram or bar chart of caffeine drinks per day | Most values should be 0–5. Values of 0 should be common (not everyone drinks caffeine every day). A value of exactly 1 or 2 is typical. Values > 10 may be energy drinks or data-entry errors. |
| **24 Alcohol Consumption** | `research_ready/` | Histogram or bar chart of alcoholic drinks per day | Most values should be 0–3. Daily alcohol > 5 drinks may indicate heavy drinking (depends on study population) or data-entry errors. |

##### Figures R25–R27: Research Summary

| Figure | Section | What it shows | Detailed interpretation |
|--------|---------|---------------|------------------------|
| **R25 Sleep Regularity** | `research_ready/` | Side-by-side comparison of weekday vs weekend: TST, bedtime, getup | A small difference is normal (30–60 min later bedtime on weekends). A difference > 2 h suggests social jetlag or shift work. This figure is useful for characterizing the study population's sleep patterns. |
| **R26 Sleep Composition (TIB Breakdown)** | `research_ready/` | Stacked bar: TIB = TST + SOL + WASO for each participant | TST should be the largest segment for most participants. If a participant has WASO > TST, their sleep is highly fragmented — worth noting as an exclusion criterion or covariate. |
| **R27 Sleep Metrics Correlation Matrix** | `research_ready/` | Correlation heatmap of all sleep metrics | Expected: TST ↔ SE = positive (more sleep = higher efficiency). SOL ↔ SE = negative (longer latency = lower efficiency). WASO ↔ SE = negative (more wake = lower efficiency). If correlations are weak or in the wrong direction, the data may have measurement issues. |

---

#### Summary Checklist

```
Part A (3 min): 01 → 12 → 18 → 02 → 19
   All 5 pass? → Output is valid.
   Any fail?   → Go to Part B for detailed diagnosis.

Part B — Use the table above to find the specific figure that failed
and read its detailed interpretation.
```

---

## Step Flag Ledger (detailed reference)

After every pipeline run, `step_flag_ledger.csv` records which flags were set at each step. Each row answers: *"at this step, using this standard, how many records fell into this category?"*

### Column Layout

| Column | What it is |
|--------|-----------|
| `step_id` | Pipeline step number |
| `label` | Human-readable step name |
| `n_total` | Total records in the pipeline at this point |
| `standard` | The evaluation system being tracked (see below) |
| `category` | The specific category within that standard |
| `count` | Number of records in this category (NA = not yet computed at this step) |
| `n_corrected` | Records manually corrected at this step |

### The Five Standards

The ledger tracks **five independent evaluation systems**, each applied across the pipeline. A standard only produces actual counts starting from the step where the pipeline first has enough information to compute it — before that step, its `count` is NA.

| Standard | First step with counts | Categories | What it evaluates |
|----------|:----------------------:|-----------|-------------------|
| `field_misentry` | 1.5 | none, SOL=time\_sleep, SOL=time\_bed, WASO=time\_awake, WASO=time\_getup | Whether a self-reported SOL or WASO duration exactly matches a timestamp field, suggesting the participant typed in the wrong box |
| `data_category` | 4 | clean, error, unusual, equal\_time\_ok, reasonable\_unusual, skipped\_na | Temporal order and reasonability of the bed → sleep → awake → getup sequence |
| `flag_severity` | 7 | Clean, Minor (1 flag), Major (2+ flags) | Severity of derived metric flags: poor efficiency (SE < 70%), high SOL (> 1 h), high WASO (> 1.5 h) |
| `duration_extreme` | 7 | OK, Too short (< 3 h), Too long (> 12 h) | Total sleep time outside physiologically plausible bounds |
| `checkforerrors` | 8 | CLEAN, TIMESTAMP\_ISSUE, DURATION\_ISSUE, AMOUNT\_FLAG, SELF\_REPORTED\_FLAG | Summary of all auto-detection flags assembled in Step 8 |

### How to Read It — Validation Rules

1. **`field_misentry`** is recorded at every step but populated from Step 1.5 onward. If any `SOL=time_bed` or `WASO=time_getup` rows have `count > 0`, the field-misentry check identified potential cross-field contamination.

2. **`data_category`** — from Step 6 onward, the numbers must be **stable** (Step 8 does not reclassify records):
   ```
   equal_time_ok + skipped_na = n_total
   ```

3. **`flag_severity`** — from Step 7 onward, the numbers must be **identical across Steps 7, 8, and 8.5** (severity is computed once in Step 7, never re-calculated):
   ```
   Clean + Minor + Major = n_total - skipped_na
   ```

4. **`duration_extreme`** — from Step 7 onward, stays constant. `Too short (< 3 h)` + `Too long (> 12 h)` should be a small fraction of total records (< 5%).

5. **`checkforerrors`** — populated at Step 8. TIMESTAMP\_ISSUE counts timestamps that could not be parsed; DURATION\_ISSUE flags metrics outside configured thresholds; AMOUNT\_FLAG flags anomalous substance-use entries; SELF\_REPORTED\_FLAG flags records where the participant's self-reported duration disagrees with the computed value.

### Example (synthetic data, 280 rows)

```
Step 7 (Compute metrics):
  data_category:    equal_time_ok = 266, skipped_na = 14        266 + 14 = 280 ✓
  flag_severity:    Clean = 251, Minor = 28, Major = 1         251 + 28 + 1 = 266 = 280 - 14 ✓
  duration_extreme: OK = 262, Too short = 1, Too long = 0
  field_misentry:   none = 266                                   (no misentries detected)
```

## Testing Coverage

The pipeline includes 76+ testthat tests across multiple areas:

| Test File | Coverage |
|-----------|----------|
| `test-normalize.R` | 15 tests: AM/PM correction, minor order errors, midnight crossing, edge cases |
| `test-interval.R` | 2 tests: colon edge cases ("00:000", "000:45") |
| `test-pipeline.R` | 3 tests: end-to-end on synthetic data, config loading, column adaptation |
| `test-sleep-diary.R` | 11 tests: S3 construction, validation, coercion, generics, contract assertion, provenance |
| `test-flag-standards.R` | 6 tests: flag evaluators for field misentry, data category, duration extreme, flag severity |

Run tests with: `testthat::test_package("splsleep")`

Snapshot verification (`inst/verification/`) confirms the S3 chain produces bit-identical output to the legacy pipeline on all 95 columns.

## Renv Reproducibility

```r
renv::restore()
```

## License

MIT

---

<a name="中文"></a>

# 中文版本

自动化的睡眠 EMA 日记数据清洗管线：解析原始就寝/入睡/醒来/起床时间戳，检测并修正时序和时长错误，计算睡眠指标（TST、SOL、WASO、SE），验证自报时长，生成诊断与科研图表。

**v1.4.0（当前版本）** — 交付版本，190+ 个测试，R CMD CHECK 0 ERROR / 0 WARNING。通过 `renv::install("cyracaid/sleepdiary-cleaner")` 安装。

## 功能特性

- **9 步管线**：原始数据 → 时间戳解析 → 区间处理 → 时序修正 → 时长修正 → 指标计算 → 自动检测 → 跨被试检查 → 可视化
- **人工修正 CSV 工作流**：审阅决策存储在 CSV 中，每次运行自动读取
- **可配置阈值**：SOL/SE/TST-TIB 标记阈值、时间戳格式、列名 — 全部通过 YAML 配置
- **检查点报告器**：每步的 clean/error/unusual/corrected 计数自动打印并保存为 CSV
- **诊断图表**：分为 `pipeline_cleaning/`（质控、管线流程、修正影响）和 `research_ready/`（睡眠指标、物质使用、知觉偏差）
- **R 包**：`library(splsleep); run_pipeline()` — 可安装、版本化
- **修正追溯**：`has_correction` enum 列（none / algorithmic / manual / both）+ 每步审计账本
- **列映射**：`adapt_columns()` 通过 YAML 配置映射数据集列名 — 无需修改代码
- **68 个测试**：覆盖修正引擎、分类阈值、自动检测逻辑、配置验证

## 管线架构

```
原始数据 ──→ Step 1: 加载数据 ──→ Step 2: 解析时间戳 ──→ Step 3: 解析区间 ──→ Step 4: 序列标准化
                                                                                    │
                                                                                    ▼
                                                                           Step 5: 分类记录（生成审阅 CSV）
                                                                                    │
                                                                           Step 5.75: Second Review
                                                                                    │
                                                                           Step 6: 应用人工修正（读取 manual_error_corrections.csv）
                                                                                    │
                                                                           Step 6.5: 应用时长修正
                                                                                    │
                                                                           Step 7: 计算睡眠指标（TST/SOL/WASO/SE）
                                                                                    │
                                                                           Step 8: 自动检测
                                                                                    │
                                                                           Step 8.5: 跨被试检查
                                                                                    │
                                                                            Step 9: 生成图表
```

### 分类体系

| 系统 | 来源 | 类别 |
|------|------|------|
| `data_category` | Step 6（时序） | clean, error, unusual, equal_time_ok, skipped_na |
| `has_correction` | Step 7（追溯） | none, algorithmic, manual, both |
| `flag_severity` | Step 7（指标） | Clean, Minor（1 标记）, Major（2+ 标记） |
| `checkforerrors_summary` | Step 8（自动） | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG, CLEAN |

## 快速开始

### 安装运行

```r
# 从 GitHub 安装
renv::install("cyracaid/sleepdiary-cleaner")
library(splsleep)
run_pipeline()
```

### 适配新数据集

```r
# 复制配置模板
file.copy(system.file("config_template.yaml", package = "splsleep"), "my_study.yaml")

# 编辑 my_study.yaml → 设置数据文件路径，可选映射列名、调阈值

# 运行
run_pipeline(config = "my_study.yaml")
```

## 数据说明（纯文字，无真实数据）

### 管线如何处理你的数据（非破坏性模型）

**管线从不删除任何记录。** 清洗的意思是*打标记 + 增加修正列*，不是删行。`corrected_ema_data` 的行数永远等于你输入的行数。

```
输入：N 条原始记录
输出：N 条记录，每条多了分类列（data_category, flag_severity）
     和修正列（time_*_corrected）。原始列原样保留。
```

- **什么都不丢。** 原始时间戳（`time_bed_am_hhmm_ampm` 等）留在数据里，修正版新增为 `time_bed_corrected` 列——每条修正都能和原值对照。
- **每条记录被打标记，不是被删除。** 验证失败的记录标上 `data_category = "error"` 或 `"unusual"`，但仍然在数据集里。你之后自己决定分析时是否包含它们。
- **"最终干净数据集"是推荐的分析子集，不是一个物理上独立的文件。** 它 = `data_category` 为 `clean` 或 `equal_time_ok` 的记录。随时可以这样筛选：

```r
clean_data <- corrected_ema_data[corrected_ema_data$data_category %in% c("clean", "equal_time_ok"), ]
```

**一个例外：** 四个睡眠时间戳全部缺失的记录（`data_category = "skipped_na"`）保留在文件里，但 TST/SOL/WASO 指标是 `NA`——时间戳缺失无法计算睡眠指标。它们可用于依从性/流失分析（如"每个被试完成了多少天"），但不能用于睡眠指标分析。

| 记录类型 | 还在数据里？ | 有睡眠指标？ | 适合睡眠分析？ |
|---------|:---:|:---:|:---:|
| clean / equal_time_ok | 是 | 是 | **是**（推荐） |
| error / unusual（被标记）| 是 | 是 | 谨慎——研究者决定 |
| skipped_na（时间戳缺失）| 是 | 否（NA） | 否——仅依从性分析 |

**本仓库不含任何原始参与者数据。** 所有真实数据 CSV 已从 git 历史彻底清除。

模板文件（含假数据）在 [`templates/`](templates/)，展示列结构。

### 主要输入数据

| 列组 | 变量 | 说明 |
|------|------|------|
| 标识符 | pid, day_num, row_id | 参与者/记录 ID |
| 日期 | StartDate | EMA 会话日期 |
| 原始时间戳 | time_bed_am_hhmm (+ampm), time_sleep_am, time_awake_am, time_getup_am | 自报就寝/入睡/醒来/起床 |
| 原始时长 | duration_totalmin_sol_estimate_am, waso_estimate_am | SOL/WASO（分钟） |
| 小睡/运动 | duration_totalmin_napstoday_PM, exercise_PM_totalmin_* | 小睡和运动时长 |
| 物质使用 | caffeinetoday_PM_*, alcoholtoday_PM_*, nicotine_*, cannabis_* | 自报物质使用 |
| WASO 次数 | num_waso_estimate_am | 醒来次数 |

### 人工修正 CSV 模板

| 模板 | 对应文件 | 用途 |
|------|---------|------|
| `templates/template_manual_error_corrections.csv` | `manual_error_corrections.csv` | 时间戳修正 |
| `templates/template_manual_unusual_corrections.csv` | `manual_unusual_corrections.csv` | 异常模式接受 |
| `templates/template_manual_nap_exercise_corrections.csv` | `manual_nap_exercise_corrections.csv` | 小睡/运动时长修正 |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO 修正 |
| `templates/template_manual_metric_review_acceptances.csv` | `manual_metric_review_acceptances.csv` | 人工接受标记 |
| `templates/template_second_review_checklist.csv` | `second_review_checklist.csv` | 二次验证 |

### 输出

| 文件 | 内容 |
|------|------|
| `output/correction_status_final.csv` | 单次运行摘要：总行数、TST、SOL、各类别计数 |
| `output/appendix_step_ledger.csv` | 每步标记追踪账本 |
| `output/flagged_records_self_reported.csv` | SELF_REPORTED_FLAG 记录 |
| `latest_visualization_*/figure_index.png` | 全部生成图表的缩略图索引 |
| `latest_visualization_*/RUN_INFO.txt` | 运行溯源：数据集标签、版本、git commit、文件来源。**每次运行都会被覆盖。** |
| `output/verification/real_n13990/`、`verification/synth_n280/` | 稳定、不会被覆盖的校验产物（S3 与旧管线快照对比、Bland-Altman 图、阈值校验、审计报告）——见 `R/config.R` 中的 `verification_run_dir()` |

#### 完整 output 目录结构

```
output/                                        ← 真实数据（gitignored，从不提交）
├── cleaned_data_final.{csv,rds}                ← 交付数据集 A
├── cleaned_data_prepostcorrection.{csv,rds}    ← 交付数据集 B
├── cleaned_data_full.rds                       ← 全字段存档（非交付物）
├── corrected_ema_data.rds                      ← 清洗中间产物（图的输入）
├── correction_status.csv                       ← 中间态运行报告
├── correction_status_final.csv                 ← 最终运行摘要（看这个）
├── appendix_step_ledger.csv
├── audit_integrity_report.csv
├── flagged_records_self_reported.csv
├── column_dictionary_gaps.csv
├── step_flag_ledger.csv
│
├── latest_visualization_real_n<行数>/          ← 最近一次真实数据可视化。
│   │                                              每次运行都会被整个覆盖——不保留历史。
│   ├── RUN_INFO.txt                            ← 仅记录这一次运行的溯源信息
│   ├── figure_index.png
│   ├── flag_distribution.csv
│   ├── pipeline_cleaning/                      ← 清洗诊断图
│   └── research_ready/                         ← 可发表图
│
└── verification/real_n<行数>/                  ← 稳定，不会被覆盖或清空。
    ├── VERIFICATION_<日期>.md                  ← S3 与旧管线快照对比报告
    ├── snapshot_old.rds / snapshot_s3.rds       ← 对比快照
    ├── bland_altman_sol.png / _waso.png        ← 每次真实数据运行都会重新生成
    └── threshold_validation.csv                ← 每次真实数据运行都会重新生成

                                                ← 以下：项目根目录，不在 output/ 内
latest_visualization_synth_n<行数>/             ← 最近一次合成测试数据可视化。
├── RUN_INFO.txt                                   tag 显示 'synth'——不是真实数据
├── figure_index.png
├── flag_distribution.csv
├── pipeline_cleaning/
└── research_ready/

verification/synth_n<行数>/                     ← 稳定的合成数据校验产物，
├── snapshot_old.rds / snapshot_s3.rds             结构与 verification/real_n<行数>/ 一致
├── bland_altman_sol.png / _waso.png
└── threshold_validation.csv
```

这套结构背后的规则：

- **`latest_visualization_<tag>_n<行数>/` 是"最新"语义，不是"历史"语义。** 每次调用 `run_visualization()` 都会被整个删除重建，里面的东西除非意外，否则不会跨次运行留存。
- **`verification/<tag>_n<行数>/` 是图目录的兄弟目录，不是子目录**（`R/config.R` 中的 `verification_run_dir()`）。它从不被 wipe 逻辑碰到，因此不需要任何特殊的保留逻辑。
- **区分真实/合成数据靠的不只是命名，还有位置。** 打上 real 标签的输出只会落在 `output/` 下（gitignored）。synth 和 `unknown`（配置里读不到数据来源，无法判断）标签的输出默认都路由到 `output/` 之外——见 `R/config.R` 中的 `figure_run_dir()`。`unknown` 会被当作 `synth` 处理，绝不会被当作 `real`。
- **不在 `output/` 里不等于会被 git 追踪。** `.gitignore` 里的 `latest_visualization*/` 和带锚点的 `/verification/` 规则，不管目录在哪个位置都会命中。

## 如何读懂管线输出

`run_pipeline()` 跑完后，CSV 文件和图表目录会告诉你一切。

---

### 1. `output/correction_status_final.csv` — 运行摘要（先看这个）

每行一次运行。回答"清洗是否按预期工作？"

```r
read.csv("output/correction_status_final.csv")
```

| 列 | 含义 | 检查标准 |
|----|------|---------|
| `n_total` | 总记录数 | 必须等于输入行数 |
| `tst_mean_h` | 平均 TST（小时） | 成人研究 6.0–8.5 h 正常。若 < 5 或 > 10，时间戳解析或研究人群异常 |
| `sol_mean_min` | 平均 SOL（分钟） | 10–45 min 正常。若 > 60，AM/PM 混淆未完全修正或失眠率高 |
| `n_clean` | 通过所有检查的记录 | 同数据多次运行应完全相同 |
| `n_error` | 时序不可能的记录 | 应 < 总记录 1%。若 > 5%，审查调查设计 |
| `n_corrected` | 通过人工 CSV 修正的记录 | 应与 `manual_error_corrections.csv` 行数匹配 |
| `timestamp_issue` | 无法解析的时间戳 | 应为 0 |
| `duration_issue` | 超出阈值的指标 | 少量正常 |
| `amount_flag` | 物质使用异常值 | 应为 0 或极低 |
| `self_reported_flag` | 自报 vs 计算 SOL/WASO 不一致 | 表示知觉偏差，见图 20 |

**稳定性规则：** 同一数据跑两次，所有数字必须完全相同。

---

### 2. `output/appendix_step_ledger.csv` — 每步标记追踪

每行 = 一步 × 一个标准 × 一个类别。回答"哪个标记在哪一步出现、是否保持稳定？"

```r
ledger <- read.csv("output/appendix_step_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

#### 5 个评估标准

| 标准 | 首次有数字的步骤 | 评估什么 | 关键类别 |
|------|:--:|------|------|
| `field_misentry` | 1.5 | 时长是否误填为时间戳 | none, SOL=time_sleep, SOL=time_bed |
| `data_category` | 4 | bed→sleep→awake→getup 时序是否合理 | clean, error, unusual, equal_time_ok, skipped_na |
| `flag_severity` | 7 | 指标超阈值数量 | Clean, Minor, Major |
| `duration_extreme` | 7 | 睡眠时长是否超出合理范围 | OK, Too short (<3h), Too long (>12h) |
| `checkforerrors` | 8 | 自动检测摘要 | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG |

**核心规则：** 每个标准只计算一次，后续步骤不重新分类。如果某个标准的计数在其首次计算步骤之后发生变化 → 有 bug。

#### 验证方法

- **`data_category`** — Step 6 起冻结。Steps 6/6.5/7/8/8.5 各类别计数必须完全相同。`equal_time_ok + skipped_na = n_total`
- **`flag_severity`** — Step 7 起冻结。`Clean + Minor + Major = n_total - skipped_na`
- **`duration_extreme`** — Too short + Too long 应 < n_total 的 5%
- **`checkforerrors`** — 仅在 Step 8 有数据

#### 示例

```
  Step 4: data_category: equal_time_ok=266, skipped_na=14
  Step 6: data_category: equal_time_ok=266, skipped_na=14  (不变)
  Step 7: flag_severity: Clean=251, Minor=28, Major=1
          duration_extreme: OK=262, Too short=1, Too long=0
  Step 8: 同上 (不变)
```

数字在首次计算后不再变化——这是管线稳定的标志。

---

### 3. 回归检查（对比上次运行）

`output/correction_status_old.csv` 不是任何管线脚本自动生成的——需要你在重跑前自己另存一份作为基线：

```r
# 重跑管线之前（比如改了代码想检查有没有回归）：把当前结果存成基线
file.copy("output/correction_status_final.csv", "output/correction_status_old.csv",
          overwrite = TRUE)

# ……在此重跑管线……

# 重跑之后：和刚才存的基线对比
old <- read.csv("output/correction_status_old.csv")
new <- read.csv("output/correction_status_final.csv")
identical(old$tst_mean_h, new$tst_mean_h)
identical(old$sol_mean_min, new$sol_mean_min)
identical(old$n_clean, new$n_clean)
```

输入数据没变但结果不同 → 管线输出改变了，需调查。

---

### 4. 快速检查卡

| 检查项 | 如何验证 | 通过条件 |
|--------|---------|---------|
| 管线完成 | `file.exists("output/correction_status_final.csv")` | TRUE |
| TST 合理 | `tst_mean_h` 6–8.5 | 是 |
| SOL 合理 | `sol_mean_min` 10–45 | 是 |
| 错误少 | `n_error < 0.01 × n_total` | 是 |
| data_category 稳定 | Steps 6–8.5 计数相同 | 是 |
| flag_severity 稳定 | Steps 7–8.5 计数相同 | 是 |
| 记录数一致 | `equal_time_ok + skipped_na = n_total` | 是 |
| 确定性 | 相同输入 → 相同输出 | 是 |

---

### 5. 如何看图

图保存在名为 `latest_visualization_<tag>_n<行数>/` 的目录中（如 `output/latest_visualization_real_n13990/`），**每次运行都会被覆盖——不保留历史版本**；目录内的 `RUN_INFO.txt` 只记录最近一次运行的溯源信息（数据来源、包版本、git commit）。`figure_index.png` 是一张所有图的缩略索引。需要跨次运行留存的校验产物（快照对比、Bland-Altman 图等）单独存放，位置由 `verification_run_dir()` 决定（如 `output/verification/real_n13990/`），从不放在会被覆盖的图目录内部。

#### 论文用图

| 图 | 文件 | 展示内容 |
|----|------|---------|
| **Figure 1 — 管线流程** | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | 垂直流程图：原始 → 解析 → 算法修正 → 人工修正 → 最终有效。每步含计数和百分比 |
| **Figure 2 — 修正影响** | `research_ready/02_Correction_Impact.png` | 三面板：TST/SOL 变化棒棒糖图 + 身份散点图 + Before/After 汇总表 |

#### 5 张必看检查图

| 步骤 | 图 | 看什么 | 正常外观 | 如果不正常？ |
|:--:|----|--------|---------|---------|
| 1 | **01 Pipeline Flow** `pipeline_cleaning/` | 各类别计数和百分比 | 大部分 Clean / Not Reported，Error < 1% | Error 过多 = 修正 CSV 未正确应用 |
| 2 | **12 Pipeline Correction Progress** `pipeline_cleaning/` | 5 个检查点的 Clean/Error/Corrected 柱状图 | Corrected 柱仅在 C 首次出现后保持平直 | Corrected 在 C 之后变化 = 不稳定 |
| 3 | **02 Distribution Sleep Variables** `research_ready/` | TST/SOL/WASO/SE 四个直方图 | TST 峰值 6–8h，SOL 右偏，WASO < 60min，SE 峰值 > 85% | TST 峰值 < 5h = 解析可能有问题 |
| 4 | **02 Correction Impact** `research_ready/` | 棒棒糖图 + 散点图 | 绝大多数点在 identity line 上，只有几条被修正的记录偏离 | 如果大量记录偏离 = 算法修正范围过大 |
| 5 | **19 Unified Quality Status** `pipeline_cleaning/` | Clean/Minor/Major 分类 | 大部分 Clean 或 Minor，Error + Unusual < 5% | 高 Error/Unusual = 审查人工修正 CSV |

**5 张全过 → 管线输出有效。** 任何一张不过 → 看详细图诊断。

## 许可证

MIT
