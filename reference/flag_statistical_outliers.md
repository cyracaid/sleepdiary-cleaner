<div id="main" class="col-md-9" role="main">

# Per-participant statistical outlier detection via IQR

<div class="ref-description section level2">

Detects within-participant outliers on key sleep metrics using the
interquartile range (IQR) method: any value more than `1.5 * IQR` below
Q1 or above Q3 is flagged.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
flag_statistical_outliers(
  data,
  group_col = "pid",
  metrics = c(self_diffcalc_sol_minutes = "sol", self_diffcalc_totalsleeptime_minutes =
    "tst", self_diffcalc_sleepefficiency_percent = "se", avg_waso_estimate_am_minutes =
    "waso"),
  multiplier = 1.5,
  min_rows = 5L
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame from the pipeline (typically after Step 7).

-   group\_col:

    Character. Column identifying participants (default `"pid"`).

-   metrics:

    Character vector. Columns to scan for outliers. Defaults to the four
    primary derived metrics.

-   multiplier:

    Numeric. The IQR multiplier. Default 1.5 (Tukey's standard). Use 3.0
    for "far out" detection only.

-   min\_rows:

    Integer. Participants with fewer than this many valid rows are
    skipped (their IQR is unreliable).

</div>

<div class="section level2">

## Value

A copy of `data` with one new column:

-   `iqr_outlier`:

    Character. Names of the metrics that were out of range, separated by
    "+" (e.g. `"sol+tst"`). `NA` when no metric is flagged or the
    participant has too few rows.

</div>

<div class="section level2">

## Details

This complements (does NOT replace) the hard-threshold system in the
cleaning pipeline. Hard thresholds detect values that are implausible in
absolute terms (e.g. SOL &gt; 120 min). IQR flags detect values that are
unusual *for that specific participant* – a person who typically falls
asleep in 5 minutes suddenly reporting 45 minutes is worth a closer look
even though 45 min is below the hard cutoff.

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
if (FALSE) { # \dontrun{
flagged <- flag_statistical_outliers(corrected_ema_data)
table(flagged$iqr_outlier)
} # }
```

</div>

</div>

</div>
