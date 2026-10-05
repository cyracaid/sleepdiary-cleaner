# Evaluate checkforerrors (auto-detection flags)

Prereq: Step 8. TIMESTAMP_ISSUE \| DURATION_ISSUE \| AMOUNT_FLAG \|
SELF_REPORTED_FLAG \| CLEAN \| NEEDS_REVIEW.

## Usage

``` r
eval_checkforerrors(df, cfg = NULL)
```

## Arguments

- df:

  A data frame with checkforerrors columns.

- cfg:

  Pipeline configuration list.
