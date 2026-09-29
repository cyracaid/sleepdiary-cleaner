<div id="main" class="col-md-9" role="main">

# Run only the visualization stage on already-cleaned data

<div class="ref-description section level2">

Loads config + inputs and regenerates the diagnostic figures.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
run_visualization(config = NULL, project_dir = ".")
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
