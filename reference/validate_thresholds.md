# Validate cleaning thresholds against Bland-Altman agreement limits

Runs Bland-Altman analysis on the SOL and WASO self-report / computed
pairs, then compares each threshold in the pipeline configuration
against the 95 the two measurement methods).

## Usage

``` r
validate_thresholds(data, cfg = NULL)
```

## Arguments

- data:

  A data frame. Typically `corrected_ema_data` after
  [`run_cleaning_chain()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_cleaning_chain.md)
  or
  [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md).

- cfg:

  A pipeline configuration list (from
  [`load_config()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/load_config.md)
  or
  [`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html)).
  If `NULL`, reads reasonable defaults from the current
  `pipeline_config` global.

## Value

A data frame with one row per evaluated threshold. Columns:
`threshold_name`, `value`, `loa_half_width`, `ratio`, `assessment`. The
object also carries a `summary` attribute with free-text interpretation
and `bland_altman` attributes holding the raw BA result lists.

## Details

A threshold is considered **safe** (\\\checkmark\\) when it sits at
least **3\\\times\\** the typical disagreement away from zero bias.
Below 2\\\times\\ the threshold is inside the normal measurement-noise
range and will produce many false positives. Between 2\\\times\\ and
3\\\times\\ is borderline and warrants a close look at the
per-participant data.

This function is **advisory only**. It does not change any threshold and
its output is never fed back into the pipeline decision tree.
