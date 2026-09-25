<div id="main" class="col-md-9" role="main">

# Run the full SPL Sleep pipeline

<div class="ref-description section level2">

Executes the complete sleep EMA data cleaning pipeline. Steps 2–7 now
flow through the S3 chain (v1.3.1), giving every step automatic
provenance tracking, contract assertions, and a 2.6x speed-up. Steps
that write files or read human-reviewed CSVs remain as direct `source()`
calls for backward compatibility.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
run_pipeline(
  config = NULL,
  project_dir = ".",
  skip_visualization = FALSE,
  finalize = TRUE,
  verbose = TRUE,
  data = NULL
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   config:

    Character or list. Path to a YAML config file, or a config list
    (from `load_config()`). If NULL, uses the bundled default.

-   project\_dir:

    Character. Path to the project root. Default ".".

-   skip\_visualization:

    Logical. If TRUE, skip visualization.

-   finalize:

    Logical. If TRUE (default) run `finalize_columns()` as Step 10 and
    write the delivered datasets. Set FALSE to stop after the cleaning
    run and inspect `corrected_ema_data` yourself. Before v1.4 this step
    had to be invoked by hand, which meant a plain `run_pipeline()`
    produced no Dataset A or B at all.

-   verbose:

    Logical. Print progress. Default TRUE.

-   data:

    Data frame. Optional data-first entry: supply the raw data directly
    instead of reading `data.files.main` from the config. When NULL
    (default) the pipeline reads from the config exactly as before
    (`data = NULL` is the backward-compatible zero-change path). When
    supplied, the file-reading branch of Step 1 is skipped and the
    config's column\_mapping is applied to `data`. Used by
    `clean_sleep_diary()`.

</div>

<div class="section level2">

## Value

Invisibly returns TRUE on successful completion.

</div>

</div>
