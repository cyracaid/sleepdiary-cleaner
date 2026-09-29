<div id="main" class="col-md-9" role="main">

# Validate config file paths for R code expressions

<div class="ref-description section level2">

Checks that data file paths in the config are absolute paths, not R
expressions like paste0(...) or file.path(...). Call during pipeline
setup to catch config errors early.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
validate_no_r_code_in_paths(cfg)
```

</div>

</div>

<div class="section level2">

## Arguments

-   cfg:

    Config list (from load\_config)

</div>

</div>
