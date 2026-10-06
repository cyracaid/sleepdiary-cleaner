# Objects left by the last pipeline run

[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
keeps its main results in the package, not in the global environment.
This returns them.

## Usage

``` r
pipeline_results()
```

## Value

A named list with `corrected_ema_data` (the data after corrections and
metrics), `review_output` (the review queue and the flagged data),
`checkforerrors_summary` and `pipeline_config`; elements not available
for the last run are `NULL`.

## Examples

``` r
if (FALSE) { # \dontrun{
run_pipeline(config = "my_study.yaml")
res <- pipeline_results()
head(res$corrected_ema_data)
} # }
```
