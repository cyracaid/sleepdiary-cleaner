# Step 6.5 – apply duration corrections

Chains the three v1.2.0 correction appliers in their original order:
nap/exercise, then sleep-metric durations, then human metric
acceptances.

## Usage

``` r
step_apply_duration_corrections(x)
```

## Arguments

- x:

  A `sleep_diary` object.

## Value

A `sleep_diary` object.
