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
  verbose = TRUE,
  data = NULL,
  include_manual_corrections = FALSE,
  export_env = NULL
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

- data:

  Data frame. Optional data-first entry: supply the raw data directly
  instead of reading `data.files.main` from the config. When NULL
  (default) the pipeline reads from the config exactly as before
  (`data = NULL` is the backward-compatible zero-change path). When
  supplied, the file-reading branch of Step 1 is skipped and the
  config's column_mapping is applied to `data`. Used by
  [`clean_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/clean_sleep_diary.md).

- include_manual_corrections:

  Logical or character. Controls whether HUMAN-REVIEW corrections are
  applied to the data. **Default FALSE**: the pipeline runs
  algorithmic-only – every human-review file
  (manual_error/unusual/nap_exercise/sleep_metric_duration/
  metric_review_acceptances/second_review) is treated as absent, Step 5
  still generates the \[NEW\] review worksheets for inspection, and a
  prominent banner states that no human corrections were applied. TRUE:
  apply the manual-correction files configured in the config YAML (the
  pre-2026-09-29 behaviour). The strings "ask" / "y" / "n" / "yes" /
  "no" are also accepted: "ask" prompts interactively (in an interactive
  session only; in a non-interactive session it degrades to FALSE with a
  notice). The point of the default-off switch: a package user must OPT
  IN to human corrections so that a dataset can never be silently
  modified by review files left over in the working directory.

- export_env:

  An environment, or `NULL` (default). The pipeline no longer writes
  into the global environment. Its main results are kept in the package
  and returned by
  [`pipeline_results()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/pipeline_results.md).
  To also copy them into an environment of your choice (for example
  [`globalenv()`](https://rdrr.io/r/base/environment.html), the
  behaviour before version 1.5.0), pass it here.

## Value

Invisibly returns TRUE on successful completion.
