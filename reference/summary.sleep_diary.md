<div id="main" class="col-md-9" role="main">

# Tabulate the whole pipeline chain recorded in a sleep\_diary

<div class="ref-description section level2">

Returns one row per step: how many records went in and out, how many
columns the step added, and how long it took. When the flag ledger from
`log_step()` is populated it is joined on, so the same call answers both
"what did each step do" and "how many records were flagged after it".

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
# S3 method for class 'sleep_diary'
summary(object, ...)
```

</div>

</div>

<div class="section level2">

## Arguments

-   object:

    A `sleep_diary` object.

-   ...:

    Unused.

</div>

<div class="section level2">

## Value

A data frame with one row per recorded step, invisibly printed.

</div>

</div>
