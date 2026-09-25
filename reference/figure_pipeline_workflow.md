# Figure 1 — Pipeline workflow flow diagram

Produces a publication-quality left-to-right flow diagram showing how
raw records move through automatic validation, algorithmic correction,
manual review, and into the final clean dataset. Every box carries a
record count and its percentage of the raw total.

## Usage

``` r
figure_pipeline_workflow()
```

## Value

The `ggplot` object, invisibly. Called for its side effect of writing
`figures/Figure_1_Pipeline_Workflow.png`.

## Details

Takes no arguments. All counts are extracted from `corrected_ema_data`
in the global environment, so the pipeline must have been run first —
otherwise the function stops with an explanatory message.

The figure is written to `figures/Figure_1_Pipeline_Workflow.png` at 11
x 6.5 inches, 300 dpi, suitable for a manuscript Methods section.

Note that counts are reconstructed from the flag columns of the final
dataset, so they describe records that survived to the end of the
pipeline.

## See also

[`figure_cleaning_effect`](https://cyracaid.github.io/sleepdiary-cleaner/reference/figure_cleaning_effect.md)
for the companion before/after figure, and
[`run_pipeline`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
to produce the required input.
