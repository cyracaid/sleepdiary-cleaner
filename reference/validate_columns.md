# Validate that required columns exist

Validate that required columns exist

## Usage

``` r
validate_columns(data, required, label = "data")
```

## Arguments

- data:

  Data frame.

- required:

  Character vector of column names that must exist.

- label:

  Character. Description of what's being checked (for error message).

## Value

Invisibly TRUE. Stops with error if columns are missing.
