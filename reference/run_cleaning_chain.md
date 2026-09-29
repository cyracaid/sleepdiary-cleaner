# The S3 cleaning chain

Runs the pure data-in / data-out portion of the pipeline as a single
composable chain. These are the six steps that take a data frame and
return a data frame with no file I/O and no reliance on the global
environment: timestamps, intervals, sequence normalisation, manual
corrections, duration corrections and metric computation.

## Usage

``` r
run_cleaning_chain(
  data,
  corrections_df = data.frame(),
  manual_unusual_df = data.frame(),
  cfg = NULL,
  verbose = getOption("sleepcleanr.verbose", TRUE)
)
```

## Arguments

- data:

  A raw data frame, or an existing `sleep_diary` object.

- corrections_df:

  Data frame of manual error corrections (Step 6). Pass an empty
  [`data.frame()`](https://rdrr.io/r/base/data.frame.html) to run
  without corrections.

- manual_unusual_df:

  Data frame of manual unusual-pattern decisions.

- cfg:

  List or NULL. Pipeline configuration. Defaults to the
  `pipeline_config` published by
  [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md),
  if present.

- verbose:

  Logical. Print per-step progress.

## Value

A `sleep_diary` object carrying the cleaned data and the full step
history. Call
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) on it to
recover a plain data frame identical in shape to the v1.2.0
`corrected_ema_data`.

## Details

The remaining steps of
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
– data loading (1), the field-misentry check (1.5), review-file
generation (5), second-review consensus (5.75), auto-detection (8), the
cross-participant check (8.5) and visualisation (9) – are deliberately
NOT part of the chain in v1.3.0. They write files or publish objects
into the global environment, so folding them in would change behaviour
rather than just re-shape it. They stay in
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
until snapshot tests cover them.

## Examples

``` r
if (FALSE) { # \dontrun{
cleaned <- run_cleaning_chain(raw_df, corrections, unusual)
summary(cleaned)
plot(cleaned)
corrected_ema_data <- as.data.frame(cleaned)
} # }
```
