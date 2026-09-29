<div id="main" class="col-md-9" role="main">

# Per-step flag ledger (log\_step)

<div class="ref-description section level2">

Intercepts EVERY pipeline step and records, against the shared final
standards (see flag\_standards.R), how many records fall in each flag
category at that step. Produces the data behind the new Figure 12 step x
flag table.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
.step_ledger_env
```

</div>

</div>

<div class="section level2">

## Details

Two kinds of reduction are tracked separately: - n\_corrected : rows
fixed by a manual/auto correction (data changed) - n\_suppressed: rows a
human accepted as not-an-error (label withdrawn, data unchanged)

</div>

</div>
