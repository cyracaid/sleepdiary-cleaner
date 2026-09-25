# Per-step flag ledger (log_step)

Intercepts EVERY pipeline step and records, against the shared final
standards (see flag_standards.R), how many records fall in each flag
category at that step. Produces the data behind the new Figure 12 step x
flag table.

## Usage

``` r
.step_ledger_env
```

## Details

Two kinds of reduction are tracked separately: - n_corrected : rows
fixed by a manual/auto correction (data changed) - n_suppressed: rows a
human accepted as not-an-error (label withdrawn, data unchanged)
