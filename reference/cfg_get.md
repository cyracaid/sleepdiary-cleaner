# Safe config_get – fetches pipeline_config from global env automatically

Use this in standalone scripts (sleep_visualization.R,
checkforerrors_processing.R) where pipeline_config may not exist in the
calling scope.

## Usage

``` r
cfg_get(key, default = NULL, cfg = NULL)
```

## Arguments

- key:

  Character. Dot-separated key.

- default:

  Default value if key not found.

- cfg:

  Optional. A pipeline configuration list. When provided, this is used
  directly instead of falling back to the global environment. \*\*From
  v1.3.1, passing `cfg` explicitly is the preferred path.\*\* The
  global-environment fallback is deprecated and will emit a warning.

## Value

The config value, or `default`.
