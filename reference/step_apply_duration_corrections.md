# Step 6.5 – apply duration corrections

Chains the correction appliers: nap/exercise, then sleep-metric
durations (manual file), then the clock-time rule for reinterpreted SOL
/ WASO text, then human metric acceptances.

## Usage

``` r
step_apply_duration_corrections(x)
```

## Arguments

- x:

  A `sleep_diary` object.

## Value

A `sleep_diary` object.
