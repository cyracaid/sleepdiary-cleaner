<div id="main" class="col-md-9" role="main">

# Figure 1 — Pipeline workflow flow diagram

<div class="ref-description section level2">

Produces a publication-quality left-to-right flow diagram showing how
raw records move through automatic validation, algorithmic correction,
manual review, and into the final clean dataset. Every box carries a
record count and its percentage of the raw total.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
figure_pipeline_workflow()
```

</div>

</div>

<div class="section level2">

## Value

The `ggplot` object, invisibly. Called for its side effect of writing
`figures/Figure_1_Pipeline_Workflow.png`.

</div>

<div class="section level2">

## Details

Takes no arguments. All counts are extracted from `corrected_ema_data`
in the global environment, so the pipeline must have been run first —
otherwise the function stops with an explanatory message.

The figure is written to `figures/Figure_1_Pipeline_Workflow.png` at 11
x 6.5 inches, 300 dpi, suitable for a manuscript Methods section.

Note that counts are reconstructed from the flag columns of the final
dataset, so they describe records that survived to the end of the
pipeline.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`figure_cleaning_effect` for the companion before/after figure, and
`run_pipeline` to produce the required input.

</div>

</div>

</div>
