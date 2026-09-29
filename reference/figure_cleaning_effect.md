<div id="main" class="col-md-9" role="main">

# Figure 2 — Effect of cleaning (before vs after)

<div class="ref-description section level2">

Three-panel figure showing what cleaning actually changed.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
figure_cleaning_effect()
```

</div>

</div>

<div class="section level2">

## Value

The combined `ggplot` object, invisibly. Called for its side effect of
writing `figures/Figure_2_Cleaning_Effect.png`.

</div>

<div class="section level2">

## Details

The three panels are:

-   A:

    SOL before (self-reported) versus after (computed), drawn as a
    combined boxplot and violin.

-   B:

    TST distribution after cleaning, stacked by flag severity.

-   C:

    Individual record changes — self-reported versus computed SOL,
    coloured by correction type (automatic, manual, unchanged). This
    panel is the one that shows only corrected observations moved.

Takes no arguments. All data is extracted from `corrected_ema_data` in
the global environment, so the pipeline must have been run first —
otherwise the function stops with an explanatory message.

Requires the patchwork package for the combined layout.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`figure_pipeline_workflow` for the companion flow diagram, and
`run_pipeline` to produce the required input.

</div>

</div>

</div>
