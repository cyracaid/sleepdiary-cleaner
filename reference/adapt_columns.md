<div id="main" class="col-md-9" role="main">

# Apply column mapping to a data frame

<div class="ref-description section level2">

Renames columns in `data` according to the mapping defined in config.
Columns whose mapped name is NULL are skipped.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
adapt_columns(data, config)
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    Data frame. Raw input data with user's column names.

-   config:

    List. Configuration list from `load_config()`.

</div>

<div class="section level2">

## Value

Data frame with columns renamed to pipeline-internal names.

</div>

</div>
