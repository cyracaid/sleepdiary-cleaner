# Validate column types in a data frame

Checks that specified columns have the expected R types.

## Usage

``` r
validate_column_types(data, type_spec, label = "data")
```

## Arguments

- data:

  Data frame.

- type_spec:

  Named list mapping column names to expected types (e.g.
  `list(pid = "numeric", StartDate = "Date")`). Use `"numeric"`,
  `"character"`, `"POSIXct"`, `"Date"`.

- label:

  Character. Description of data being checked.

## Value

Invisibly TRUE. Stops with error on mismatch.
