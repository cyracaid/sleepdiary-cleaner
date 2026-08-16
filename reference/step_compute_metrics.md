# Step 7 – compute derived sleep metrics

Produces the four public contract columns introduced in v1.2.0
(`sleep_efficiency_pct`, `sol_h`, `waso_h`, `sleep_duration_h`) that the
flag evaluators consume.

## Usage

``` r
step_compute_metrics(x)
```

## Arguments

- x:

  A `sleep_diary` object.

## Value

A `sleep_diary` object.
