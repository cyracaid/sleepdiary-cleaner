<div id="main" class="col-md-9" role="main">

# Validate a sleep\_diary object

<div class="ref-description section level2">

Checks the structural invariants the pipeline relies on. Called by the
step adapters so a malformed object fails loudly at the boundary rather
than silently three steps later.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
validate_sleep_diary(x)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    An object to validate.

</div>

<div class="section level2">

## Value

`x`, invisibly, if valid; otherwise an error is raised.

</div>

</div>
