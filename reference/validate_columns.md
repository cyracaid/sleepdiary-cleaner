<div id="main" class="col-md-9" role="main">

# Validate that required columns exist

<div class="ref-description section level2">

Validate that required columns exist

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
validate_columns(data, required, label = "data")
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    Data frame.

-   required:

    Character vector of column names that must exist.

-   label:

    Character. Description of what's being checked (for error message).

</div>

<div class="section level2">

## Value

Invisibly TRUE. Stops with error if columns are missing.

</div>

</div>
