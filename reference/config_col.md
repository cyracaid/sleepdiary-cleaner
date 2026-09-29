<div id="main" class="col-md-9" role="main">

# Get column mapping from config

<div class="ref-description section level2">

Returns the user's column name for a given pipeline-internal column.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
config_col(config, internal_name)
```

</div>

</div>

<div class="section level2">

## Arguments

-   config:

    List. Configuration list.

-   internal\_name:

    Character. Pipeline-internal column name.

</div>

<div class="section level2">

## Value

Character. User's column name, or `internal_name` if not mapped.

</div>

</div>
