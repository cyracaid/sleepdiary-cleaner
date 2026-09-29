<div id="main" class="col-md-9" role="main">

# Validate column types in a data frame

<div class="ref-description section level2">

Checks that specified columns have the expected R types.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
validate_column_types(data, type_spec, label = "data")
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    Data frame.

-   type\_spec:

    Named list mapping column names to expected types (e.g.
    `list(pid = "numeric", StartDate = "Date")`). Use `"numeric"`,
    `"character"`, `"POSIXct"`, `"Date"`.

-   label:

    Character. Description of data being checked.

</div>

<div class="section level2">

## Value

Invisibly TRUE. Stops with error on mismatch.

</div>

</div>
