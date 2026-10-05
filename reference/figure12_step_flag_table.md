<div id="main" class="col-md-9" role="main">

# Figure 12 (new) — Step x Flag ledger table

<div class="ref-description section level2">

Replaces the coarse A-E bar chart. Renders one row per pipeline step
and, against the shared final standards, shows how each flag family is
generated and reduced across steps. "not computable at this step" shows
as "—".

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
figure12_step_flag_table(
  cfg = NULL,
  output_dir = ".",
  save_png = NULL,
  filename = "A1_Step_Flag_Ledger"
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   cfg:

    Pipeline configuration list.

-   output\_dir:

    Directory for saving output PNG.

-   save\_png:

    Optional save function for PNG output.

-   filename:

    Output PNG filename without extension.

</div>

<div class="section level2">

## Details

Drop-in: replace the current Figure 12 block in sleep\_visualization.R
with a call to \`figure12\_step\_flag\_table(cfg = cfg, output\_dir =
output\_dir, save\_png = save\_png)\`.

</div>

</div>
