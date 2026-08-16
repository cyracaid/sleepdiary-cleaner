# Tag missing-data reason codes and optionally carry forward single-day gaps

Adds a `missing_reason` column that distinguishes why a row has
incomplete data, rather than lumping everything into `skipped_na`.
Optionally applies last-observation-carried-forward (LOCF) to metric
columns for single-day gaps.

## Usage

``` r
handle_missing(
  data,
  timestamp_cols = NULL,
  metric_cols = NULL,
  group_col = "pid",
  order_col = "day_num",
  max_gap = 1L
)
```

## Arguments

- data:

  A data frame from the pipeline.

- timestamp_cols:

  Character. Columns that carry the four sleep-event POSIXct timestamps.
  If `NULL`, auto-detects from common patterns.

- metric_cols:

  Character. Columns eligible for LOCF. If `NULL`, auto-detects the
  standard derived-metric columns.

- group_col:

  Character. Participant identifier. Default `"pid"`.

- order_col:

  Character. Within-participant ordering column. Default `"day_num"`.

- max_gap:

  Integer. Maximum consecutive missing days to fill via LOCF. Default 1.
  Set to 0 to disable LOCF entirely.

## Value

A copy of `data` with:

- `missing_reason`:

  Character. One of `"all_timestamps_na"`, `"partial_timestamps_na"`,
  `"derived_na"`, or `NA` (complete row).

- For each metric column when `max_gap > 0`::

  a companion `<col>_imputed` logical column, and the original column
  may contain LOCF-filled values.

## Design boundaries

\* Timestamp columns are \*\*never\*\* imputed – filling a missing
bedtime would fabricate an event that did not happen. \* Only metric
columns (SOL, WASO, TST, SE) are eligible for LOCF. \* LOCF is capped at
`max_gap` consecutive days (default 1) to avoid filling week-long gaps
with stale data. \* All imputed values carry an `_imputed` companion
column (`TRUE` / `FALSE`) for audit trail.

## Examples

``` r
if (FALSE) { # \dontrun{
handled <- handle_missing(corrected_ema_data)
table(handled$missing_reason)

# LOCF disabled -- only reason codes
handled <- handle_missing(corrected_ema_data, max_gap = 0)
} # }
```
