# Missing-data reason codes and single-day LOCF

Adds a `missing_reason` column that distinguishes why a row has
incomplete data. Optionally applies last-observation-carried-forward
(LOCF) to metric columns for single-day gaps. Timestamp columns are
never imputed; all filled values carry a `_imputed` companion column for
audit trail.

## Details

[`handle_missing`](https://cyracaid.github.io/sleepdiary-cleaner/reference/handle_missing.md)
and
[`summarise_missing`](https://cyracaid.github.io/sleepdiary-cleaner/reference/summarise_missing.md)
are documented individually.
