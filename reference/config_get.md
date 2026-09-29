# Get a nested config value by dot-separated key

Get a nested config value by dot-separated key

## Usage

``` r
config_get(config, key, default = NULL)
```

## Arguments

- config:

  List. Configuration list from
  [`load_config()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/load_config.md).

- key:

  Character. Dot-separated key, e.g.
  `"classification.temporal.max_sol_minutes"`.

- default:

  Default value if key not found.

## Value

The config value, or `default`.
