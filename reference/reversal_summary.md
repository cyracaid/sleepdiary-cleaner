# Summarise the reversals of a run

Counts the nights whose self-reported times are out of order, by
mechanism, and gives the two rates a Methods section quotes: all
reversals, and reversals excluding nights whose get-up field holds an
impossible value (those are a field-value problem rather than a sequence
problem).

## Usage

``` r
reversal_summary(x, near_tie_min = 10)
```

## Arguments

- x:

  A `sleep_diary` object, the `corrected_ema_data` data frame, or the
  list returned by
  [`pipeline_results()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/pipeline_results.md).
  The pre-correction columns `time_*_am_hhmm_ampm` must be present.

- near_tie_min:

  Numeric. A reversal whose inverted gaps are all at most this many
  minutes is classed as rounding. Default 10; `Inf` turns the check off.

## Value

A list with `n_complete` (nights with all four times), `counts`, `rates`
(percent), `by_class`, `by_detail`, and `near_tie_min`.

## See also

[`classify_reversals()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/classify_reversals.md)

## Examples

``` r
if (FALSE) { # \dontrun{
run_pipeline(config = "my_study.yaml")
str(reversal_summary())
} # }
```
