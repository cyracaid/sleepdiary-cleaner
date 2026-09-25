<div id="main" class="col-md-9" role="main">

# Assert that a sleep\_diary carries the public contract columns

<div class="ref-description section level2">

The interface contract Step 7 promises downstream consumers. Kept
separate from `step_compute_metrics()` so tests can assert the contract
without re-running the step.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
assert_contract_columns(x, error = TRUE)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A `sleep_diary` object or data frame.

-   error:

    Logical. If TRUE (default) raise on a missing column; if FALSE
    return the missing names.

</div>

<div class="section level2">

## Value

Character vector of missing columns, invisibly.

</div>

</div>
