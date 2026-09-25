<div id="main" class="col-md-9" role="main">

# Summarise missing-data patterns per participant

<div class="ref-description section level2">

Summarise missing-data patterns per participant

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
summarise_missing(data, group_col = "pid")
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame after calling `handle_missing()`.

-   group\_col:

    Character. Participant column.

</div>

<div class="section level2">

## Value

A data frame: per participant, counts of each missing reason and the
number of LOCF-filled values.

</div>

</div>
