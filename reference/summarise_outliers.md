<div id="main" class="col-md-9" role="main">

# Summarise IQR outlier flags

<div class="ref-description section level2">

Summarise IQR outlier flags

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
summarise_outliers(data, group_col = "pid")
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame after calling `flag_statistical_outliers()`.

-   group\_col:

    Character. Participant column.

</div>

<div class="section level2">

## Value

A data frame: one row per participant with flag counts per metric.

</div>

</div>
