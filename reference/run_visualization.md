# Run only the visualization stage on already-cleaned data

Loads config + inputs and regenerates the diagnostic figures.

## Usage

``` r
run_visualization(config = NULL, project_dir = ".")
```

## Arguments

- config:

  Character or list. Path to a config YAML, a configuration list (from
  [`load_config()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/load_config.md)),
  or NULL for the bundled default.

- project_dir:

  Character. Path to the project root. Default ".".

## Value

Invisibly TRUE.
