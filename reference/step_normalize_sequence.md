# Step 4 – normalise sleep time sequence

Step 4 – normalise sleep time sequence

## Usage

``` r
step_normalize_sequence(x, flip_gap_hours = NULL, swap_threshold_hours = NULL)
```

## Arguments

- x:

  A `sleep_diary` object.

- flip_gap_hours:

  Numeric. Gap above which an AM/PM flip is applied. Defaults to the
  configured `timestamp.sequence.max_gap_hours`, or 12.

- swap_threshold_hours:

  Numeric. Absolute gap below which a minor order error is corrected by
  swapping the pair. Defaults to the configured
  `normalize.swap_threshold_hours`, or 3.

## Value

A `sleep_diary` object.
