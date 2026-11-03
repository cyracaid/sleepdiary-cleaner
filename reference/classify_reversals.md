# Classify nights whose self-reported times are out of order

A reversal is a night whose four self-reported times violate
`bed <= sleep onset <= final awakening <= get-up`. For each reversed
night this function records the three adjacent gaps and picks the
smallest edit that restores the order while keeping the night plausible:
exchange two fields (`swap`), shift one field by 12 hours (`pm12h`), or
shift two fields by 12 hours (`pm12h_x2`). Nights no edit can explain
are classed by what is visibly wrong with them: an impossible get-up
value (`D1_value_broken`), an awakening earlier than bedtime
(`D2_awake_before_bed`), or a rounding-sized gap (`D3_near_tie`);
everything else is `E_unexplained`. Nothing is changed.

## Usage

``` r
classify_reversals(x, near_tie_min = 10)
```

## Arguments

- x:

  A `sleep_diary` object, the `corrected_ema_data` data frame, or the
  list returned by
  [`pipeline_results()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/pipeline_results.md).
  The pre-correction columns `time_*_am_hhmm_ampm` must be present.

- near_tie_min:

  Numeric. A reversal whose inverted gaps are all at most this many
  minutes is classed as rounding. Default 10; `Inf` turns the check off.

## Value

A data frame with one row per reversed night: `row_id`, `pid`,
`day_num`, `pattern` (which adjacent pairs are inverted), the three
`gap_*_h` columns, `class`, `detail`, and the flags `is_near_tie`,
`value_broken`, `awake_before_bed`. The attribute `summary` holds the
counts and rates; see
[`reversal_summary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/reversal_summary.md).

## Details

The `detail` column names the field or pair, e.g. `"swap:bed-sleep"`,
`"pm12h:sleep-12h"`, or `"pm12h_x2:whole_night"`.

## See also

[`reversal_summary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/reversal_summary.md)

## Examples

``` r
if (FALSE) { # \dontrun{
run_pipeline(config = "my_study.yaml")
head(classify_reversals())
} # }
```
