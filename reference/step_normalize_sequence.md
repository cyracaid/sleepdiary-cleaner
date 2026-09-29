<div id="main" class="col-md-9" role="main">

# Step 4 – normalise sleep time sequence

<div class="ref-description section level2">

Step 4 – normalise sleep time sequence

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
step_normalize_sequence(x, flip_gap_hours = NULL, swap_threshold_hours = NULL)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A `sleep_diary` object.

-   flip\_gap\_hours:

    Numeric. Gap above which an AM/PM flip is applied. Defaults to the
    configured `timestamp.sequence.max_gap_hours`, or 12.

-   swap\_threshold\_hours:

    Numeric. Absolute gap below which a minor order error is corrected
    by swapping the pair. Defaults to the configured
    `normalize.swap_threshold_hours`, or 3.

</div>

<div class="section level2">

## Value

A `sleep_diary` object.

</div>

</div>
