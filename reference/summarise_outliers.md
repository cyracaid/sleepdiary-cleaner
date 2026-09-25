# Summarise IQR outlier flags

Summarise IQR outlier flags

## Usage

``` r
summarise_outliers(data, group_col = "pid")
```

## Arguments

- data:

  A data frame after calling
  [`flag_statistical_outliers()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/flag_statistical_outliers.md).

- group_col:

  Character. Participant column.

## Value

A data frame: one row per participant with flag counts per metric.
