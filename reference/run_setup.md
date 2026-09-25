<div id="main" class="col-md-9" role="main">

# Run the setup-only stage (package / input-file checks)

<div class="ref-description section level2">

Checks R packages and input files without loading or cleaning data.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
run_setup(config = NULL, project_dir = ".")
```

</div>

</div>

<div class="section level2">

## Arguments

-   config:

    Character or list. Path to a config YAML, a configuration list (from
    `load_config()`), or NULL for the bundled default.

-   project\_dir:

    Character. Path to the project root. Default ".".

</div>

<div class="section level2">

## Value

Invisibly TRUE.

</div>

</div>
