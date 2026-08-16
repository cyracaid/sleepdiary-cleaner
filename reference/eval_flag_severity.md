# Evaluate flag_severity (computed metric flags)

Prereq: Step 7 metrics. Clean (0) \| Minor issues (1 flag) \| Major
issues (2+ flags).

## Usage

``` r
eval_flag_severity(df, cfg = NULL)
```

## Arguments

- df:

  A data frame with sleep_efficiency_pct, sol_h, waso_h columns.

- cfg:

  Pipeline configuration list.
