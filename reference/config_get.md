<div id="main" class="col-md-9" role="main">

# Get a nested config value by dot-separated key

<div class="ref-description section level2">

Get a nested config value by dot-separated key

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
config_get(config, key, default = NULL)
```

</div>

</div>

<div class="section level2">

## Arguments

-   config:

    List. Configuration list from `load_config()`.

-   key:

    Character. Dot-separated key, e.g.
    `"classification.temporal.max_sol_minutes"`.

-   default:

    Default value if key not found.

</div>

<div class="section level2">

## Value

The config value, or `default`.

</div>

</div>
