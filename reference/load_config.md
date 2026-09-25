# Load pipeline configuration

Reads a YAML config file and returns a list of settings. Falls back to
the bundled default config if no file is specified.

## Usage

``` r
load_config(config_file = NULL)
```

## Arguments

- config_file:

  Character. Path to a YAML config file, or NULL to use the bundled
  default (`inst/config_default.yaml`).

## Value

List of pipeline configuration values.
