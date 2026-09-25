<div id="main" class="col-md-9" role="main">

# Missing-data reason codes and single-day LOCF

<div class="ref-description section level2">

Adds a `missing_reason` column that distinguishes why a row has
incomplete data. Optionally applies last-observation-carried-forward
(LOCF) to metric columns for single-day gaps. Timestamp columns are
never imputed; all filled values carry a `_imputed` companion column for
audit trail.

</div>

<div class="section level2">

## Details

`handle_missing` and `summarise_missing` are documented individually.

</div>

</div>
