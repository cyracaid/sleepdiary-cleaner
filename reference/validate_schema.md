<div id="main" class="col-md-9" role="main">

# Canonical input schema validator

<div class="ref-description section level2">

Single source of truth for raw input columns. Call right after
`adapt_columns()` so missing or misnamed columns fail loudly.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
validate_schema(data, config, label = "raw EMA input (post-adaptation)")
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame to validate.

-   config:

    Pipeline configuration list.

-   label:

    Character label for error messages.

</div>

<div class="section level2">

## Details

Design: each schema entry is a logical field resolved through the config
column mapping. The validator accepts either the mapped internal key or
the raw default name, tolerating the current config-key vs
hardcoded-name mismatch.

</div>

</div>
