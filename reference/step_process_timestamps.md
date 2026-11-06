# Step 2 – parse timestamps

Step 2 – parse timestamps

## Usage

``` r
step_process_timestamps(
  x,
  vars = c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am",
    "caffeinetoday_PM", "alcoholtoday_PM", "nicotine_amount_pm", "cannabis_amount_pm"),
  tz = NULL
)
```

## Arguments

- x:

  A `sleep_diary` object.

- vars:

  Character vector of timestamp variables to process.

- tz:

  IANA time zone the diary times were written in. `NULL` (the default)
  uses the config value `data.timezone`, then
  `getOption("sleepcleanr.timezone", "America/Los_Angeles")`.

## Value

A `sleep_diary` object.
