<div id="main" class="col-md-9" role="main">

# Record the flag state after a step.

<div class="ref-description section level2">

Record the flag state after a step.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
log_step(df, step_id, label, cfg = NULL, verbose = TRUE)
```

</div>

</div>

<div class="section level2">

## Arguments

-   df:

    Data frame in its state AFTER the step.

-   step\_id:

    Short ordered id, e.g. "1", "1.5", "2", ... "8.5".

-   label:

    Human-readable step name.

-   cfg:

    Config list (for thresholds).

-   verbose:

    Logical. Print progress messages. Default: TRUE.

</div>

<div class="section level2">

## Value

invisibly the row that was appended.

</div>

</div>
