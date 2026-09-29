<div id="main" class="col-md-9" role="main">

# Validate cleaning thresholds against Bland-Altman agreement limits

<div class="ref-description section level2">

Runs Bland-Altman analysis on the SOL and WASO self-report / computed
pairs, then compares each threshold in the pipeline configuration
against the 95 the two measurement methods).

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
validate_thresholds(data, cfg = NULL)
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame. Typically `corrected_ema_data` after
    `run_cleaning_chain()` or `run_pipeline()`.

-   cfg:

    A pipeline configuration list (from `load_config()` or
    `yaml::read_yaml()`). If `NULL`, reads reasonable defaults from the
    current `pipeline_config` global.

</div>

<div class="section level2">

## Value

A data frame with one row per evaluated threshold. Columns:
`threshold_name`, `value`, `loa_half_width`, `ratio`, `assessment`. The
object also carries a `summary` attribute with free-text interpretation
and `bland_altman` attributes holding the raw BA result lists.

</div>

<div class="section level2">

## Details

A threshold is considered **safe** (\\(\\checkmark\\)) when it sits at
least **3\\(\\times\\)** the typical disagreement away from zero bias.
Below 2\\(\\times\\) the threshold is inside the normal
measurement-noise range and will produce many false positives. Between
2\\(\\times\\) and 3\\(\\times\\) is borderline and warrants a close
look at the per-participant data.

This function is **advisory only**. It does not change any threshold and
its output is never fed back into the pipeline decision tree.

</div>

</div>
