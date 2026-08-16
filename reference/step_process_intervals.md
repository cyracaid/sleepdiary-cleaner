# Step 3 – parse interval durations

Step 3 – parse interval durations

## Usage

``` r
step_process_intervals(
  x,
  vars = c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am",
    "duration_totalmin_napstoday_PM", "exercisetoday_PM_totalmin_Light",
    "exercisetoday_PM_totalmin_Moderate", "exercisetoday_PM_totalmin_Vigorous",
    "exercisetoday_PM_totalmin_Strength")
)
```

## Arguments

- x:

  A `sleep_diary` object.

- vars:

  Character vector of interval variables to process.

## Value

A `sleep_diary` object.
