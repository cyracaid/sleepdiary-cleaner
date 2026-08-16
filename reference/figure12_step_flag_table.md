# Figure 12 (new) — Step x Flag ledger table

Replaces the coarse A-E bar chart. Renders one row per pipeline step
and, against the shared final standards, shows how each flag family is
generated and reduced across steps. "not computable at this step" shows
as "—".

## Usage

``` r
figure12_step_flag_table(
  cfg = NULL,
  output_dir = ".",
  save_png = NULL,
  filename = "12_Pipeline_Correction_Progress"
)
```

## Arguments

- cfg:

  Pipeline configuration list.

- output_dir:

  Directory for saving output PNG.

- save_png:

  Optional save function for PNG output.

- filename:

  Output PNG filename without extension.

## Details

Drop-in: replace the current Figure 12 block in sleep_visualization.R
with a call to \`figure12_step_flag_table(cfg = cfg, output_dir =
output_dir, save_png = save_png)\`.
