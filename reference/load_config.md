<div id="main" class="col-md-9" role="main">

# Load pipeline configuration

<div class="ref-description section level2">

Reads a YAML config file and returns a list of settings. Falls back to
the bundled default config if no file is specified.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
load_config(config_file = NULL)
```

</div>

</div>

<div class="section level2">

## Arguments

-   config\_file:

    Character. Path to a YAML config file, or NULL to use the bundled
    default (`inst/config_default.yaml`).

</div>

<div class="section level2">

## Value

List of pipeline configuration values.

</div>

</div>
