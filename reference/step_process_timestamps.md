<div id="main" class="col-md-9" role="main">

# Step 2 – parse timestamps

<div class="ref-description section level2">

Step 2 – parse timestamps

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
step_process_timestamps(
  x,
  vars = c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am",
    "caffeinetoday_PM", "alcoholtoday_PM", "nicotine_amount_pm", "cannabis_amount_pm")
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A `sleep_diary` object.

-   vars:

    Character vector of timestamp variables to process.

</div>

<div class="section level2">

## Value

A `sleep_diary` object.

</div>

</div>
