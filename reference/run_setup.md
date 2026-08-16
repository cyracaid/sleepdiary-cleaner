# Run the setup-only stage (package / input-file checks)

Checks R packages and input files without loading or cleaning data.

## Usage

``` r
run_setup(config = NULL, project_dir = ".")
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
