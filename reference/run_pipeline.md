# Run the full SPL Sleep pipeline

Executes the complete sleep EMA data cleaning pipeline. Steps 2–7 now
flow through the S3 chain (v1.3.1), giving every step automatic
provenance tracking, contract assertions, and a 2.6x speed-up. Steps
that write files or read human-reviewed CSVs remain as direct
[`source()`](https://rdrr.io/r/base/source.html) calls for backward
compatibility.

## Usage

``` r
run_pipeline(
  config = NULL,
  project_dir = ".",
  skip_visualization = FALSE,
  finalize = TRUE,
  verbose = TRUE
)
```

## Arguments

- config:

  Character or list. Path to a YAML config file, or a config list (from
  [`load_config()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/load_config.md)).
  If NULL, uses the bundled default.

- project_dir:

  Character. Path to the project root. Default ".".

- skip_visualization:

  Logical. If TRUE, skip visualization.

- finalize:

  Logical. If TRUE (default) run
  [`finalize_columns()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/finalize_columns.md)
  as Step 10 and write the delivered datasets. Set FALSE to stop after
  the cleaning run and inspect `corrected_ema_data` yourself. Before
  v1.4 this step had to be invoked by hand, which meant a plain
  `run_pipeline()` produced no Dataset A or B at all.

- verbose:

  Logical. Print progress. Default TRUE.

## Value

Invisibly returns TRUE on successful completion.
