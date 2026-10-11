# Describe what a pipeline run changed, in words a Methods section can use

Builds a short, factual description of the last pipeline run from the
objects the run already produced: how many entries and participants, how
many entries a rule corrected (by rule), how many a reviewer corrected,
how many remain in the review queue, and the reference thresholds in
use. It states only counts that can be read from the run; it makes no
claim about accuracy.

## Usage

``` r
cleaning_report(results = pipeline_results(), file = NULL)
```

## Arguments

- results:

  A list as returned by
  [`pipeline_results()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/pipeline_results.md)
  (the default), with at least `corrected_ema_data`. `review_output` and
  `pipeline_config` are used when present.

- file:

  Optional path. If given, the text is also written there as plain text
  (Markdown-compatible).

## Value

Invisibly, a list with `text` (a character vector, one element per
paragraph) and `counts` (a data frame of corrections by rule). The text
is also printed.

## Examples

``` r
if (FALSE) { # \dontrun{
run_pipeline(config = "my_study.yaml", include_manual_corrections = TRUE)
cleaning_report()
} # }
```
