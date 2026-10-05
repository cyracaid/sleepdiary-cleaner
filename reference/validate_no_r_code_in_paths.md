# Validate config file paths for R code expressions

Checks that data file paths in the config are absolute paths, not R
expressions like paste0(...) or file.path(...). Call during pipeline
setup to catch config errors early.

## Usage

``` r
validate_no_r_code_in_paths(cfg)
```

## Arguments

- cfg:

  Config list (from load_config)
