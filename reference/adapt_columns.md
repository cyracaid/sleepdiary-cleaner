# Apply column mapping to a data frame

Renames columns in `data` according to the mapping defined in config.
Columns whose mapped name is NULL are skipped.

## Usage

``` r
adapt_columns(data, config)
```

## Arguments

- data:

  Data frame. Raw input data with user's column names.

- config:

  List. Configuration list from
  [`load_config()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/load_config.md).

## Value

Data frame with columns renamed to pipeline-internal names.
