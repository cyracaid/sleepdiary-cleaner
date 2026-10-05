# Get column mapping from config

Returns the user's column name for a given pipeline-internal column.

## Usage

``` r
config_col(config, internal_name)
```

## Arguments

- config:

  List. Configuration list.

- internal_name:

  Character. Pipeline-internal column name.

## Value

Character. User's column name, or `internal_name` if not mapped.
