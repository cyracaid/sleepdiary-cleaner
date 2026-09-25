# Canonical input schema validator

Single source of truth for raw input columns. Call right after
[`adapt_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/adapt_columns.md)
so missing or misnamed columns fail loudly.

## Usage

``` r
validate_schema(data, config, label = "raw EMA input (post-adaptation)")
```

## Arguments

- data:

  A data frame to validate.

- config:

  Pipeline configuration list.

- label:

  Character label for error messages.

## Details

Design: each schema entry is a logical field resolved through the config
column mapping. The validator accepts either the mapped internal key or
the raw default name, tolerating the current config-key vs
hardcoded-name mismatch.
