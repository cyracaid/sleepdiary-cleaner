<div id="main" class="col-md-9" role="main">

# Safe config\_get – fetches pipeline\_config from global env automatically

<div class="ref-description section level2">

Use this in standalone scripts (sleep\_visualization.R,
checkforerrors\_processing.R) where pipeline\_config may not exist in
the calling scope.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
cfg_get(key, default = NULL, cfg = NULL)
```

</div>

</div>

<div class="section level2">

## Arguments

-   key:

    Character. Dot-separated key.

-   default:

    Default value if key not found.

-   cfg:

    Optional. A pipeline configuration list. When provided, this is used
    directly instead of falling back to the global environment. \*\*From
    v1.3.1, passing `cfg` explicitly is the preferred path.\*\* The
    global-environment fallback is deprecated and will emit a warning.

</div>

<div class="section level2">

## Value

The config value, or `default`.

</div>

</div>
