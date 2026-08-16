# Assert that a sleep_diary carries the public contract columns

The interface contract Step 7 promises downstream consumers. Kept
separate from
[`step_compute_metrics()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_compute_metrics.md)
so tests can assert the contract without re-running the step.

## Usage

``` r
assert_contract_columns(x, error = TRUE)
```

## Arguments

- x:

  A `sleep_diary` object or data frame.

- error:

  Logical. If TRUE (default) raise on a missing column; if FALSE return
  the missing names.

## Value

Character vector of missing columns, invisibly.
