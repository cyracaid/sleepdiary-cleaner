# Figure 2 — Effect of cleaning (before vs after)

Three-panel figure showing what cleaning actually changed.

## Usage

``` r
figure_cleaning_effect()
```

## Value

The combined `ggplot` object, invisibly. Called for its side effect of
writing `figures/Figure_2_Cleaning_Effect.png`.

## Details

The three panels are:

- A:

  SOL before (self-reported) versus after (computed), drawn as a
  combined boxplot and violin.

- B:

  TST distribution after cleaning, stacked by flag severity.

- C:

  Individual record changes — self-reported versus computed SOL,
  coloured by correction type (automatic, manual, unchanged). This panel
  is the one that shows only corrected observations moved.

Takes no arguments. All data is extracted from `corrected_ema_data` in
the global environment, so the pipeline must have been run first —
otherwise the function stops with an explanatory message.

Requires the patchwork package for the combined layout.

## See also

[`figure_pipeline_workflow`](https://cyracaid.github.io/sleepdiary-cleaner/reference/figure_pipeline_workflow.md)
for the companion flow diagram, and
[`run_pipeline`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
to produce the required input.
