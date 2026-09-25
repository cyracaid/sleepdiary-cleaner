<div id="main" class="col-md-9" role="main">

# Interpreting the Pipeline Output

After `run_pipeline()` finishes, two CSV files tell you everything. This
vignette explains how to read them, how to regression-check against a
previous run, and how to read the figures.

<div id="cb1" class="sourceCode">

``` r
library(sleepcleanr)
```

</div>

<div class="section level2">

## Terminology

Sleep-diary metric abbreviations used throughout this vignette: **SOL**
(Sleep Onset Latency), **TST** (Total Sleep Time), **WASO** (Wake After
Sleep Onset), **SE** (Sleep Efficiency).

</div>

<div class="section level2">

## 1. `output/correction_status_final.csv` — The Run Summary (Open This First)

One row per pipeline run. It answers: *“did the cleaning work as
expected?”*

<div id="cb2" class="sourceCode">

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

</div>

<div class="section level2">

## 2. `output/step_flag_ledger.csv` — The Per-Step Flag Tracker (Open Second)

One row per step × per standard × per category. It answers: *“at which
step did which flag appear, and did it persist?”*

<div id="cb3" class="sourceCode">

``` r
ledger <- read.csv("output/step_flag_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

</div>

Each row answers: *“at this step, using this standard, how many records
fell into this category?”*

<div class="section level3">

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

## 3. Regression Check (compare against a previous run)

`output/correction_status_old.csv` is not written by any pipeline script
— you create it yourself as a saved baseline before rerunning:

<div id="cb5" class="sourceCode">

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

## 4. Quick Reference Card

| Check                 | What to run                                         | Pass if |
|-----------------------|-----------------------------------------------------|---------|
| Pipeline finished     | `file.exists("output/correction_status_final.csv")` | `TRUE`  |
| Reasonable TST        | `tst_mean_h` between 6–8.5                          | Yes     |
| Reasonable SOL        | `sol_mean_min` between 10–45                        | Yes     |
| Few errors            | `n_error < 0.01 * n_total`                          | Yes     |
| data\_category stable | Counts identical across Steps 6–8.5                 | Yes     |
| flag\_severity stable | Counts identical across Steps 7–8.5                 | Yes     |
| All records accounted | `equal_time_ok + skipped_na = n_total`              | Yes     |
| Deterministic         | Same input → same output every time                 | Yes     |

</div>

<div class="section level2">

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
|  4   | **02 Distribution Sleep Variables** | TST peaks 6–8 h, SOL right-skewed, WASO &lt; 60, SE &gt; 85%       | SOL flat/bimodal = AM/PM confusion        |
|  5   | **19 Unified Quality Status**       | Most records Clean/Minor; Error+Unusual &lt; 5%                    | High = review manual CSVs                 |

</div>

<div class="section level2">

## 6. Complete Figure-by-Figure Guide

This section is the definitive per-figure reference. Each row lists what
every part of the figure means, what it looks like when the data are
healthy, and what an anomaly means so you know where to dig next.

Figures land in `latest_visualization_<tag>_n<rows>/pipeline_cleaning/`
(diagnostic figures) and `.../research_ready/` (publication figures).
The `A1_Step_Flag_Ledger` replaced the old
`12_Pipeline_Correction_Progress`; the old
`08_Sleep_Duration_by_Category` and `12_*` files are no longer produced
(their questions are answered by A1 and by Figure 7). `11`, `14`, `15`
and `16` are intentionally skipped on real data (empty/blank by design).

**Terminology used below:** `data_category` is the per-record quality
class: `clean` \| `error` \| `unusual` \| `equal_time_ok` \|
`skipped_na`. `record_status` is the final disposition after manual
review.

<div class="section level3">

### 6.1 Diagnostic figures (`pipeline_cleaning/`)

| Figure                                   | What each part means                                                                                                                                                                                                                                                                                                                                                                                                               | Healthy look                                                                                                                                                     | Anomaly → what it means                                                                                                                                  |
|------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **01 Pipeline Record Flow Diagram**      | Vertical flow of 5 stages: Raw Load → Parsed → Algorithmic Correction → Manual Correction → Final Valid. Each box = record count + % of total; two correction stages also show participant counts. **Right-side annotation** breaks the final classification: Not Reported, Clean, Unusual (Accepted), Error (Reviewed), Equal Time, and “% of participants with ≥1 correction”. Bottom text = % of raw records entering analysis. | Flow narrows gently; Clean dominates the annotation; Error + Unusual small (&lt; 5%); correction stages show small counts (only genuinely broken records fixed). | Huge Error/Unusual share → AM/PM confusion or bad parsing upstream; near-zero correction counts on data known to contain errors → detection missed rows. |
| **06 Sleep Duration Post-Correction**    | Density curve of final TST (hours) after manual corrections; one curve over the whole dataset.                                                                                                                                                                                                                                                                                                                                     | Unimodal, peak 6–8 h, no spikes at 0 or &gt; 12.                                                                                                                 | Flat/bimodal → mixed 12h/24h formats survived parsing; spike at 0 → missing/zero-duration records.                                                       |
| **07 Flag Composition Stacked**          | Stacked histogram: x = sleep duration (h), y = count, **fill = `data_category`** (clean/error/unusual/equal\_time/skipped\_na). Shows how data quality varies with sleep duration.                                                                                                                                                                                                                                                 | Clean dominates every duration bin; colored slivers only at extremes (&lt; 3 h, &gt; 12 h) and at 0.                                                             | Error band wide across mid durations → systematic parsing problem, not extreme-value artifact.                                                           |
| **10 Extreme Sleep Durations**           | Scatter: x = TST (h), y = sleep efficiency (%), restricted to extreme durations (&lt; 4 h or &gt; 10 h). **Color = data quality**, **shape = short vs long sleeper**. Horizontal line at SE = 85% (poor-efficiency threshold).                                                                                                                                                                                                     | Extremes are a small scatter of points; short-sleep points mostly sit at reasonable SE (60–95%); long-sleep points high SE.                                      | Cluster of short-sleep points below SE 85% → genuine insomnia vs measurement issue; many points at exactly TST = 0 or 24 → parsing failure.              |
| **13 Error Category Distribution**       | Bar chart of auto-detection error/review categories with counts and % labels. Categories mirror `auto_error_desc` prefixes (Temporal / Metrics / Amount / Interval / Timestamp).                                                                                                                                                                                                                                                   | One or two dominant categories (usually Temporal); all categories small in absolute terms.                                                                       | Timestamp or Interval format errors large → participants used non-standard formats en masse; investigate parsing rules.                                  |
| **13B Adjacent Timestamp Gaps**          | Histogram of gap hours between adjacent diary events (bed→sleep, sleep→awake, awake→getup), **pre-correction raw times**. Negative gap = the later event’s clock time precedes the earlier one. Vertical reference line at 0.                                                                                                                                                                                                      | Mass of gaps in +0.5 to +2 h (positive, sane order); a small negative tail.                                                                                      | Large negative mass → widespread order errors the normalizer will flip; bimodal around ±12 h → 12h-dial AM/PM habit.                                     |
| **13C Detection Outcomes Heatmap**       | Tile heatmap from synthetic error-injection validation: rows/columns = injected error types, cells = detection outcome counts vs modal result. Validates the detector fires on the errors it should.                                                                                                                                                                                                                               | Strong diagonal (detected where injected); off-diagonal near zero.                                                                                               | Off-diagonal mass → detector misses a class or false-fires on clean controls.                                                                            |
| **13D Threshold vs Measurement Noise**   | Columns showing detection rate against the **threshold-to-Bland-Altman-noise ratio**; vertical line = the chosen operating point. Ties cleaning thresholds to measurement noise rather than arbitrary cutoffs.                                                                                                                                                                                                                     | Detection rate high and flat to the right of the vertical line; no cliff at the chosen point.                                                                    | Detection drops before the vertical line → threshold is inside noise band; raise the threshold.                                                          |
| **17 Top Participants by Flag Rate**     | Bar chart: top 15 participants by algorithm-flagged record RATE (flags ÷ days), with PID labels.                                                                                                                                                                                                                                                                                                                                   | Rates modest (&lt; 30%); no single participant dominating.                                                                                                       | One participant at &gt; 60% → habitual 12h-dial or recurring format issue; check their raw pattern.                                                      |
| **18 Auto-Detected Dashboard**           | Left text panel “Key Metrics”: total records, flagged records, manually-corrected count. Right: stacked bar of review\_source classes (Temporal Issues / Metrics Issues / Amount/Input Flags / Interval Format Errors / Timestamp Format Errors / Other).                                                                                                                                                                          | Flagged ≪ total; Temporal largest class; counts match `correction_status_final.csv`.                                                                             | Counts disagree with the CSV → ledger/table pipeline out of sync; Amount flags high → substance-use coding issue.                                        |
| **A1 Step Flag Ledger**                  | Grid table: rows = step × standard × category; columns = count, n\_total, n\_corrected. Standards: `field_misentry` (1.5), `data_category` (4), `flag_severity` (7), `duration_extreme` (7), `checkforerrors` (8). Read it like the CSV ledger (§2) rendered as a figure.                                                                                                                                                          | Each standard’s counts first appear at its step and stay constant after; `equal_time_ok + skipped_na = n_total` from Step 6 on.                                  | Counts change after first computation step → pipeline instability (see §2 validation rules).                                                             |
| **P26 Participants Worth a Second Look** | Bar chart of participants with the highest flagged-record rate, for manual review prioritization.                                                                                                                                                                                                                                                                                                                                  | Short list of a few participants; no runaway outlier.                                                                                                            | Long list → systemic issue affecting many participants, not individual behavior.                                                                         |

</div>

<div class="section level3">

### 6.2 Publication figures (`research_ready/`)

| Figure                                        | What each part means                                                                                                                                                                                                                                                                                                                                                                    | Healthy look                                                                                                                                        | Anomaly → what it means                                                                                                                                    |
|-----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **02 Correction Impact**                      | 4 panels: (A) TST delta lollipops — one row per modified record, x = ΔTST min, color orange = algorithmic, blue = manual; (B) same for SOL; (C) identity scatter TST-before vs TST-after, unchanged records at 3% opacity as gray backdrop, diagonal reference line; (D) summary table of TST/SOL mean ± SD before vs after. Caption states how many of how many records were modified. | Only a small fraction of points deviate from the diagonal; deltas clustered near 0; before/after means nearly identical (non-destructive cleaning). | Huge deltas or many rows → corrections are changing real data, not just fixing entry errors; means shift materially → investigate why so much got “fixed”. |
| **02B Distribution of Sleep Variables**       | Histograms + density curves for key sleep metrics (TST, SOL, WASO, SE) on the **final corrected** data.                                                                                                                                                                                                                                                                                 | TST 6–8 h peak; SOL right-skewed 10–45; WASO &lt; 60; SE &gt; 85%.                                                                                  | SOL flat/bimodal → AM/PM confusion left uncorrected; SE spike at 100% → many all-night-slept records.                                                      |
| **03 TST Distribution**                       | Histogram + density of total sleep time (h) with mean/median reference lines (“Enhanced”: sleep period minus WASO).                                                                                                                                                                                                                                                                     | Unimodal, 6–8 h center, mean ≈ median.                                                                                                              | Mean ≫ median → right tail of long sleepers; spike at 0 → zero-duration records.                                                                           |
| **04 Sleep Duration vs Time in Bed**          | Scatter TST (h) vs time-in-bed (h) with smooth trend + identity reference.                                                                                                                                                                                                                                                                                                              | Points hug the identity line; spread grows at longer TIB (people lounge in bed); no points with TST &gt; TIB.                                       | TST &gt; TIB region populated → duration arithmetic error (WASO subtraction missing); flat cloud → TIB and TST decoupled (parsing problem).                |
| **04B SOL vs Sleep Duration**                 | Scatter SOL (h) vs TST (h), **color = data quality**, SOL &gt; 3 h filtered out for clarity.                                                                                                                                                                                                                                                                                            | Negative correlation (long SOL → short TST); most points SOL &lt; 1 h; quality colors mixed uniformly.                                              | Cluster of error/unusual colors at high SOL → sleep-onset mis-entry pattern; vertical stripe at SOL = 0 → zero-latency reporting (equal-time).             |
| **05 Variability of Sleep Variables**         | Violin plots + inner boxplots, one per sleep variable, **free Y axis per panel**. Shows distribution shape and spread.                                                                                                                                                                                                                                                                  | Roughly symmetric violins for TST; right-skewed SOL/WASO; no panel dominated by spikes.                                                             | A violin split into two lobes → bimodal behavior (weekday/weekend or 12h-dial); wide flat violin → noisy measurement.                                      |
| **09 Bedtime vs Get-up Distribution**         | Two density curves over hour-of-day (0–24): bedtime distribution vs get-up distribution (final corrected times).                                                                                                                                                                                                                                                                        | Bedtime peak 22:00–00:00; get-up peak 06:00–08:00; curves don’t overlap much.                                                                       | Bedtime peak after 02:00 → delayed-sleep population or PM/AM decode error; get-up peak before 04:00 → mis-parsed evenings.                                 |
| **20 SOL Perception Bias**                    | Histogram of                                                                                                                                                                                                                                                                                                                                                                            | subjective SOL − computed SOL                                                                                                                       | (minutes) with reference line; shows perception bias magnitude.                                                                                            |
| **20B WASO Perception Bias**                  | Histogram of                                                                                                                                                                                                                                                                                                                                                                            | self-reported nighttime wakefulness − computed                                                                                                      | (minutes); same interpretation as Figure 20 but for WASO.                                                                                                  |
| **21 Substance Use Availability**             | Bar chart: % of records with data per substance (caffeine, alcohol, nicotine, cannabis).                                                                                                                                                                                                                                                                                                | High availability (&gt; 80%) for the substances your study asks about; low = expected skip pattern.                                                 | Near-zero availability for a substance you measure → column mapping or collection failure.                                                                 |
| **22 Substance Use Value Distribution**       | Boxplots + jitter of reported values per substance.                                                                                                                                                                                                                                                                                                                                     | Compact boxes at plausible doses (caffeine 0–4 cups; alcohol 0–3 drinks); few outliers.                                                             | Extreme outliers → amount flags (coding units wrong, e.g. drinks vs servings); wide box → non-standard dosing.                                             |
| **23 Caffeine Consumption**                   | Bar chart of caffeine distribution (cups/day) with counts.                                                                                                                                                                                                                                                                                                                              | Right-skewed, mode 0–1 cups.                                                                                                                        | Spike at implausible values (≥ 10) → unit confusion (cans vs cups) feeding `AMOUNT_FLAG`.                                                                  |
| **24 Alcohol Consumption**                    | Bar chart of alcohol distribution (drinks/day) with counts.                                                                                                                                                                                                                                                                                                                             | Right-skewed, mode 0.                                                                                                                               | Spike at high values → same unit concern as caffeine; verify `alcoholtoday_PM` coding.                                                                     |
| **R25 Sleep Regularity — Weekday vs Weekend** | Violin + boxplot of clock hours (bedtime and get-up) split by day type (weekday/weekend).                                                                                                                                                                                                                                                                                               | Weekend bedtimes \~0.5–1 h later; get-up \~1 h later; distributions otherwise similar.                                                              | Weekday = weekend exactly → day\_type mis-assigned or dates stripped; huge weekend shift → strong social jetlag (report it).                               |
| **R26 Sleep Composition — TIB Breakdown**     | Stacked bar of time-in-bed composition: TST + SOL + WASO (+ residual) as proportions.                                                                                                                                                                                                                                                                                                   | TST the dominant block (\~80–90% of TIB); SOL and WASO small slices.                                                                                | SOL or WASO consuming &gt; 30% of TIB → high sleep fragmentation or onset latency; negative residual → duration arithmetic bug.                            |
| **R27 Sleep Metrics Correlation Matrix**      | Corrplot upper-triangle of pairwise Pearson correlations among TST, SOL, WASO, SE, TIB (final corrected data). Red = negative, green = positive, coefficient printed in each cell.                                                                                                                                                                                                      | Strong expected signs: TST–SE strongly positive, SOL–SE negative, TST–TIB positive, WASO–SE negative.                                               | Sign flips (e.g. TST–SE negative) → metric definitions altered or units mixed; near-perfect ±1.0 → two metrics are the same column.                        |

</div>

<div class="section level3">

### 6.3 Key definitions

**`equal_time_ok` (Figure 1 annotation, `data_category`).** Counts
records where two adjacent diary timestamps came out identical but the
record is otherwise valid. Fires when:

-   bedtime == sleep time (reported falling asleep the instant they went
    to bed — zero sleep latency), **and/or**
-   awake time == getup time (reported getting out of bed the instant
    they woke — no lingering),
-   **and** the full sequence still satisfies bed ≤ sleep ≤ awake ≤
    getup (temporal order intact).

Three sub-patterns are tracked internally (`equal_time_type`):
`bed_sleep_equal`, `awake_getup_equal`, or `both_equal`. The code treats
a \~36-second tolerance (0.01 hours) as “equal” to absorb floating-point
rounding (`R/flag_standards.R`).

The key distinction from the error path: **sleep == awake (a zero-length
sleep period) is never classified as Equal Time** — that is always an
error, since a night with zero total sleep duration is a broken record,
not a benign reporting pattern. Equal Time is specifically the harmless
case where a participant reported two adjacent checkpoints (e.g. “went
to bed” and “fell asleep”) as the same clock time — a common, legitimate
way to fill a sleep diary. Such records flow straight through as valid
rather than going to manual review.

**`skipped_na`.** Any record with one or more of the four corrected
timestamps missing is classified `skipped_na` (not
clean/error/unusual/equal\_time), and is excluded from temporal-order
evaluation. From Step 6 onward `equal_time_ok + skipped_na = n_total`
must hold — this identity is the primary ledger sanity check.

**Unusual vs Error.** `unusual` = an order or gap pattern that is
suspicious but plausible (e.g. &gt; 3 h between bed and sleep with sane
order) — reviewed, often accepted as-is. `error` = impossible temporal
order or zero-length sleep — always reviewed and corrected when
confirmed.

</div>

</div>

</div>
