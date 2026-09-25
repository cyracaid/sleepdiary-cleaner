<div id="main" class="col-md-9" role="main">

# Step 3 – parse interval durations

<div class="ref-description section level2">

Step 3 – parse interval durations

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
step_process_intervals(
  x,
  vars = c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am",
    "duration_totalmin_napstoday_PM", "exercisetoday_PM_totalmin_Light",
    "exercisetoday_PM_totalmin_Moderate", "exercisetoday_PM_totalmin_Vigorous",
    "exercisetoday_PM_totalmin_Strength")
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A `sleep_diary` object.

-   vars:

    Character vector of interval variables to process.

</div>

<div class="section level2">

## Value

A `sleep_diary` object.

</div>

</div>
