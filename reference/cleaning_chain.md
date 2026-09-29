# Pipeline step adapters and the cleaning chain

The step adapters wrap the v1.2.0 pipeline scripts without changing
their logic, adding timing, column-diff tracking and ledger logging.
[`run_cleaning_chain()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_cleaning_chain.md)
composes them into a single callable chain.

## Details

Each adapter is documented individually:
[`run_cleaning_chain`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_cleaning_chain.md),
[`assert_contract_columns`](https://cyracaid.github.io/sleepdiary-cleaner/reference/assert_contract_columns.md),
[`step_process_timestamps`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_process_timestamps.md),
[`step_process_intervals`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_process_intervals.md),
[`step_normalize_sequence`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_normalize_sequence.md),
[`step_apply_corrections`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_apply_corrections.md),
[`step_apply_duration_corrections`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_apply_duration_corrections.md),
[`step_compute_metrics`](https://cyracaid.github.io/sleepdiary-cleaner/reference/step_compute_metrics.md).
